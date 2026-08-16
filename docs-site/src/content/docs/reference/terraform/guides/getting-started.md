---
title: "Getting started: from a single warehouse to a full platform"
description: "A progressive, copy-pasteable tutorial for the Chameleon Terraform provider — from one warehouse to a fully governed data platform (catalog, access,"
---

# Getting started

This tutorial builds a Chameleon data platform with Terraform, one layer at a
time. Each level is runnable on its own and builds on the previous one:

1. [Provider setup & auth](#1-provider-setup)
2. [A warehouse and a namespace](#2-a-warehouse-and-a-namespace)
3. [Tables and loading data](#3-tables-and-loading-data)
4. [Access control: users, roles, grants](#4-access-control)
5. [An ontology (semantic layer)](#5-an-ontology)
6. [dbt: connection → project → session → run → schedule](#6-dbt)
7. [Data contracts & quality (ODCS + DQ schedules)](#7-data-contracts--quality)
8. [The full-blown setup](#8-the-full-blown-setup)
9. [Tear down](#9-tear-down)

Everything here is verified against a live stack. Where a behaviour is
non-obvious, a **Note** calls it out.

## 1. Provider setup

The provider authenticates to the Chameleon BFF. Credentials come from
`CHAMELEON_*` environment variables, so the `provider` block stays empty and no
secrets land in your `.tf` files.

```terraform
terraform {
  required_providers {
    chameleon = {
      source  = "registry.terraform.io/schubergphilis/chameleon"
      version = "~> 0.1"
    }
  }
}

# Auth is read from the environment:
#   CHAMELEON_ENDPOINT        BFF base URL (e.g. https://platform.example)
#   CHAMELEON_OIDC_ENDPOINT   Keycloak base URL
#   CHAMELEON_REALM           realm (default "example")
#   CHAMELEON_USERNAME        ROPC username   (or CHAMELEON_TOKEN for a bearer)
#   CHAMELEON_PASSWORD        ROPC password
provider "chameleon" {}
```

```sh
# Load auth, then run Terraform:
set -a && source .env && set +a
terraform init
terraform apply
```

-> **Tip** All `id`/timestamps are computed; you only set the inputs shown.

## 2. A warehouse and a namespace

A *warehouse* is a Polaris (Iceberg) catalog; a *namespace* is a schema inside
it.

```terraform
resource "chameleon_warehouse" "analytics" {
  name = "main_warehouse"
}

resource "chameleon_namespace" "analytics_db" {
  catalog = chameleon_warehouse.analytics.name
  name    = "analytics_db" # dot-separated for nesting, e.g. "analytics.raw"
}
```

~> **Note** The query engine (SQE) only resolves statically-configured catalog
names. In a single-tenant dev stack, keep the warehouse name stable (e.g.
`main_warehouse`) — don't append a random suffix, or queries fail with "unknown
catalog".

## 3. Tables and loading data

Create an Iceberg table with primitive columns, then load a CSV into it. The
`chameleon_table_load` resource is one-shot: changing an input replaces it and
re-loads.

```terraform
resource "chameleon_table" "orders" {
  catalog   = chameleon_warehouse.analytics.name
  namespace = chameleon_namespace.analytics_db.name
  name      = "orders"

  columns = [
    { name = "order_id", type = "string", required = true },
    { name = "customer_id", type = "string", required = true },
    { name = "total", type = "double", required = true },
    { name = "placed_at", type = "timestamptz", required = false },
  ]
}

# Load a CSV already staged in S3 (use file_path instead for a local upload).
resource "chameleon_table_load" "orders_seed" {
  catalog    = chameleon_warehouse.analytics.name
  namespace  = chameleon_namespace.analytics_db.name
  table      = chameleon_table.orders.name
  format     = "csv"
  source_uri = "s3://iceberg-warehouse/seed/orders.csv"
  header     = true
  mode       = "append"
}
```

-> **Tip** For a local file use `file_path = "${path.module}/orders.csv"`
instead of `source_uri` (the two are mutually exclusive). A change to the
file's contents is detected via `file_hash` and triggers a reload.

## 4. Access control

Chameleon access control is managed through:

* **Polaris/SQL grants** — `chameleon_principal_role`, `chameleon_catalog_role`,
  their assignments, and `chameleon_grant` (SQL-style `allow`/`deny` privileges).
* **Identity roles** — `chameleon_keycloak_role` for realm-level Keycloak roles.

> **Note** The OPA-era `chameleon_policy` resource has been removed. Use
> `chameleon_grant` (→ `/access`, full CRUD) for access control rules.

```terraform
# A platform user.
resource "chameleon_user" "alice" {
  username = "alice"
  password = "ChangeMe123!" # initial only; rotate in Keycloak afterwards
}

# Identity-layer role (Keycloak realm role).
resource "chameleon_keycloak_role" "analyst" {
  name        = "data-analyst"
  description = "Read-only access to analytics datasets"
}

# SQL privilege: let the analyst group SELECT from the warehouse.
resource "chameleon_grant" "analyst_select" {
  catalog      = chameleon_warehouse.analytics.name
  grantee_type = "GROUP"
  grantee_name = "data-analyst"
  privilege    = "SELECT"
}

# Deny the analyst group access to the PII table (deny wins on overlap).
resource "chameleon_grant" "analyst_deny_pii" {
  catalog      = chameleon_warehouse.analytics.name
  grantee_type = "GROUP"
  grantee_name = "data-analyst"
  privilege    = "SELECT"
  effect       = "deny"
  resource_namespace = chameleon_namespace.analytics_db.name
  resource_table     = "people"
}
```

## 5. An ontology

The ontology is a semantic layer over your physical tables: entity types with
attributes and relations, then *mappings* that bind them to columns/joins.
Build it in a **draft** version, then publish.

```terraform
resource "chameleon_ontology_version" "v1" {
  name    = "ecommerce-v1"
  publish = false # flip to true after entities/mappings exist
}

resource "chameleon_ontology_entity_type" "customer" {
  version_id   = chameleon_ontology_version.v1.id
  name         = "customer"
  display_name = "Customer"
}

resource "chameleon_ontology_attribute" "customer_id" {
  entity_type_id = chameleon_ontology_entity_type.customer.id
  name           = "customer_id"
  display_name   = "Customer ID"
  data_type      = "string"
}

# Mappings bind the entity/attribute to physical columns; see the full example
# in examples/fullstack/modules/ontology for table + column mappings and
# relations (join_sql) wired end-to-end.
```

~> **Note** Publishing validates the draft, so publish only **after** entities,
attributes, and mappings exist — publishing an empty draft fails. The common
pattern is two applies: build the draft (`publish = false`), then set
`publish = true`.

## 6. dbt

The dbt flow is: a git **connection** → a **project** → a **session** (clones
the repo into a workspace) → **runs** and **schedules** against that session.

```terraform
resource "chameleon_connection" "dbt_git" {
  name        = "analytics-dbt-git"
  type        = "github" # github | gitlab | bitbucket | generic_git | github_app
  url         = "https://github.com/your-org/analytics-dbt"
  credentials = var.dbt_git_token # a PAT; pass via TF_VAR_dbt_git_token
  team_id     = "data-platform"
}

resource "chameleon_dbt_project" "analytics" {
  name           = "analytics"
  repo_url       = chameleon_connection.dbt_git.url
  default_branch = "main"
  warehouse      = chameleon_warehouse.analytics.name
  namespace      = chameleon_namespace.analytics_db.name
  connection_id  = chameleon_connection.dbt_git.id
  team_id        = "data-platform" # required by the BFF
}

# Opening a session clones the repo; destroying closes the workspace.
resource "chameleon_dbt_session" "analytics" {
  project_id = chameleon_dbt_project.analytics.id
}

# A one-shot build right now:
resource "chameleon_dbt_run" "build" {
  session_id = chameleon_dbt_session.analytics.id
}

# A recurring build on the unified scheduler.
resource "chameleon_schedule" "dbt_daily" {
  name            = "analytics-dbt-daily"
  job_type        = "dbt"
  target_id       = chameleon_dbt_session.analytics.id # dbt jobs target a session
  cron_expression = "0 6 * * *"
  enabled         = true
}

variable "dbt_git_token" {
  type      = string
  sensitive = true
}
```

~> **Note** A `dbt` schedule's `target_id` is a **session id**, not a project
id — the BFF's dbt runner executes against a session workspace. That's why the
session is a first-class resource. (A `dq` schedule targets a contract id; a
`langflow` schedule a flow id.)

## 7. Data contracts & quality

A contract is an **ODCS v3** document bound to a physical table. You can author
a single contract inline, point the platform at a whole git repo of contracts,
and schedule recurring quality runs.

```terraform
resource "chameleon_contract" "orders" {
  yaml_content = <<-EOT
    apiVersion: v3.1.0
    kind: DataContract
    id: orders-contract
    name: orders
    version: 1.0.0
    status: active
    domain: analytics
    schema:
      - name: orders
        physicalName: main_warehouse.analytics_db.orders
        physicalType: table
        properties:
          - name: order_id
            logicalType: string
            primaryKey: true
            required: true
          - name: total
            logicalType: number
            required: true
        quality:
          - type: library
            metric: rowCount
            mustBeGreaterThan: 0
    team:
      name: analytics
      members:
        - username: data-platform
          role: Owner
  EOT
}

# Run quality checks now (one-shot).
resource "chameleon_quality_run" "orders" {
  contract_id = chameleon_contract.orders.id
  scope       = "full"
}

# Recurring DQ run for the contract.
resource "chameleon_schedule" "orders_dq" {
  name            = "orders-dq-6h"
  job_type        = "dq"
  target_id       = chameleon_contract.orders.id
  cron_expression = "0 */6 * * *"
  target_config   = { scope = "full" }
}

# Or register a whole repo of contracts the platform keeps in sync.
resource "chameleon_contract_repository" "all" {
  connection_id = chameleon_connection.dbt_git.id
  path_filter   = "/contracts"
  branch        = "main"
  auto_sync     = true
  sync_cron     = "0 */6 * * *"
}
```

~> **Note** The contract YAML must be real **ODCS** (`apiVersion`/`kind:
DataContract`/`schema[].physicalName`), parsed by
`open-data-contract-standard` — not the datacontract.com `dataContractSpecification`
format. `schema[0].physicalName` must be `<catalog>.<namespace>.<table>` so the
contract binds to the physical Iceberg table.

## 8. The full-blown setup

Levels 2–7 composed into reusable modules — storage, catalog + seed, ontology,
access, dbt (with session + schedule), and contracts — live in
[`examples/fullstack/`](https://github.com/schubergphilis/terraform-provider-chameleon/tree/main/examples/fullstack).
It boots an entire platform from one `terraform apply`:

```hcl
module "storage"   { source = "./modules/storage"   ... }
module "catalog"   { source = "./modules/catalog"   ... } # warehouse + ns + tables + seed
module "ontology"  { source = "./modules/ontology"  ... } # entities + mappings + publish
module "access"    { source = "./modules/access"    ... } # roles + grants
module "dbt"       { source = "./modules/dbt"       ... } # connection + project + session + schedule
module "contracts" { source = "./modules/contracts" ... } # ODCS contract + DQ schedule
```

Toggle layers with `enable_dbt`, `enable_contracts`, `dbt_schedule_cron`,
`contract_dq_cron`, etc. See the example's `README.md` and `terraform.tfvars`
for the full variable set.

## 9. Tear down

```sh
terraform destroy
```

Destroy is ordered by dependencies: schedules and runs first, then sessions
(which are *closed*, cleaning up the cloned workspace), contracts, tables,
namespace, and finally the warehouse.

~> **Note** A dbt **session** has no get-by-id endpoint, so a session closed
out-of-band won't be detected as drift. dbt **runs** are historical and removing
the resource just drops it from state (nothing is deleted upstream).
