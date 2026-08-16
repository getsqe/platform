---
title: "Multi-tenancy: workspaces, scoping, and isolated tenants"
description: "Provision isolated tenants (workspaces) with Terraform — a workspace, its catalog, its groups, its grants, and a workspace-scoped dbt project — and the"
---

# Multi-tenancy with workspaces

A **workspace** is an isolated tenant. Creating one provisions its own Polaris
catalog (`ws_<slug>`), warehouse/staging buckets, and two Keycloak groups
(`ws-<slug>-admins`, `ws-<slug>-members`). Catalog- and dbt-family resources can
be **scoped** to a workspace with `workspace_slug`, and the provider resolves the
slug to the workspace's catalog for you.

This guide builds one tenant end-to-end, then shows the two-tenant module pattern.

## Prerequisites

- A **platform-admin** identity for the provider — workspace create/update/delete,
  admin add/remove, and catalog attach/detach require it. See the README's
  *Platform-admin service account* section.
- For a workspace's data to be **queryable and loadable**, the platform stack must
  have (these are deployment settings, not provider config):
  - SQE `[query] catalog_discovery = "polaris-auto"` — so the engine resolves
    dynamically-created workspace catalogs (the `static` default only knows the
    statically-listed warehouse → *"unknown catalog"*).
  - `TABLE_LOAD_STAGING_BUCKET` set on the BFF — so `chameleon_table_load`'s upload
    path can stage files.
  - For **scheduled** dbt/DQ jobs (`chameleon_schedule`) to authenticate as the
    schedule owner, set `SCHEDULER_TOKEN_EXCHANGE_CLIENT_ID` /
    `SCHEDULER_TOKEN_EXCHANGE_CLIENT_SECRET` on the BFF (a Keycloak client with
    token-exchange/impersonation). Without it the scheduler dispatches jobs with no
    user token and a dbt build fails parsing (`Env var required ... 'DBT_ACCESS_TOKEN'`).
    Interactive runs (`chameleon_dbt_run`) are unaffected — they carry the provider's token.

## 1. The workspace and its people

```terraform
resource "chameleon_workspace" "team_a" {
  slug         = "team-a" # immutable identity; forces replacement
  display_name = "Team A"
  description  = "Analytics workspace for Team A"
}

resource "chameleon_workspace_admin" "lead" {
  workspace_slug = chameleon_workspace.team_a.slug
  username       = "team-a-lead"
}

resource "chameleon_workspace_member" "dev" {
  workspace_slug = chameleon_workspace.team_a.slug
  username       = "team-a-dev"
}
```

The create is an idempotent upsert: re-applying an existing workspace is a no-op,
and `display_name`/`description` update in place. Only `slug` forces replacement.

## 2. Namespaces, tables, and grants — scoped to the workspace

Pass `workspace_slug` instead of `catalog`. The provider resolves it to the
workspace's primary catalog and derives the member/admin groups locally.

```terraform
resource "chameleon_namespace" "public" {
  workspace_slug = chameleon_workspace.team_a.slug
  name           = "public"
}

resource "chameleon_namespace" "limited" {
  workspace_slug = chameleon_workspace.team_a.slug
  name           = "limited"
}

resource "chameleon_table" "events" {
  workspace_slug = chameleon_workspace.team_a.slug
  namespace      = chameleon_namespace.public.name
  name           = "events"
  columns = [
    { name = "event_id", type = "long", required = true },
    { name = "occurred_at", type = "timestamp" },
    { name = "payload", type = "string" },
  ]
}

# Members read the public namespace; admins additionally read limited.
resource "chameleon_grant" "members_read_public" {
  workspace_slug = chameleon_workspace.team_a.slug
  namespace      = chameleon_namespace.public.name
  table          = "*"
  privilege      = "SELECT"
  grantee_type   = "GROUP"
  grantee_name   = chameleon_workspace.team_a.member_group
  effect         = "allow"
}

resource "chameleon_grant" "admins_read_limited" {
  workspace_slug = chameleon_workspace.team_a.slug
  namespace      = chameleon_namespace.limited.name
  table          = "*"
  privilege      = "SELECT"
  grantee_type   = "GROUP"
  grantee_name   = chameleon_workspace.team_a.admin_group
  effect         = "allow"
}
```

Pass **exactly one** of `catalog` or `workspace_slug` to these resources.

## 3. Load data into the workspace catalog

```terraform
# Local file → multipart upload → staged in TABLE_LOAD_STAGING_BUCKET → loaded.
# table_load is admin-scoped (not workspace-scoped): give it the resolved
# `catalog` — the namespace exposes it after workspace_slug resolution.
resource "chameleon_table_load" "events" {
  catalog      = chameleon_namespace.public.catalog
  namespace    = chameleon_namespace.public.name
  table        = chameleon_table.events.name
  format       = "csv"
  file_path    = "${path.module}/seed/events.csv"
  header       = true
  infer_schema = true
}
```

Use `source_uri = "s3://bucket/key.csv"` instead of `file_path` to load a file
already in S3 (no staging bucket needed).

## 4. Workspace-scoped dbt

Connections and dbt projects are **always** workspace-scoped (`workspace_slug`
required). The provider sends an `X-Workspace` header; the BFF binds them to the
tenant and writes models into the workspace's own catalog.

```terraform
resource "chameleon_connection" "dbt" {
  name           = "team-a-dbt"
  type           = "github"
  url            = var.dbt_repo_url
  credentials    = var.dbt_git_credentials
  workspace_slug = chameleon_workspace.team_a.slug
}

resource "chameleon_dbt_project" "dbt" {
  name           = "team-a-dbt"
  repo_url       = var.dbt_repo_url
  repo_path      = "dbt"
  default_branch = "main"
  connection_id  = chameleon_connection.dbt.id
  workspace_slug = chameleon_workspace.team_a.slug
  warehouse      = "ws_team_a" # the workspace's own catalog (server-derived)
}
```

## 4b. Schedule a recurring dbt build (workspace-scoped)

The unified scheduler runs dbt, DQ, and Iceberg-housekeeping jobs on a cron. A dbt
schedule targets an **open session** (`target_id` = the session id); because the
session is already bound to the workspace, the scheduled run lands in the tenant's
catalog — the schedule itself carries no `workspace_slug`/`X-Workspace`.

```terraform
resource "chameleon_dbt_session" "this" {
  project_id     = chameleon_dbt_project.dbt.id
  workspace_slug = chameleon_workspace.team_a.slug
}

resource "chameleon_schedule" "dbt_nightly" {
  name            = "team-a-dbt-build"
  job_type        = "dbt"
  target_id       = chameleon_dbt_session.this.id # the workspace-bound session
  cron_expression = "0 6 * * *"                   # daily 06:00; empty disables
  timezone        = "UTC"
  enabled         = true
  # target_config omitted: build all models, full_refresh off. (The BFF coerces
  # full_refresh with Python bool(), so "false" reads as TRUE — never set it to "false".)
}
```

The provider returns `next_run_at` once the scheduler registers the entry; re-applying
is a clean no-op (`target_config` round-trips as `{}`). See the platform prerequisites
above for the token-exchange setting a scheduled build needs to authenticate.

## 5. Two tenants in one apply

Wrap the blocks above in a module and call it once per tenant. Each gets its own
catalog, groups, grants, and dbt project — no shared state.

```terraform
module "team_a" {
  source = "./modules/workspace"
  slug   = "team-a"
}

module "team_b" {
  source = "./modules/workspace"
  slug   = "team-b"
}
```

A full two-team example ships in
[`examples/fullstack/modules/workspaces`](https://github.com/schubergphilis/terraform-provider-chameleon/tree/main/examples/fullstack).

## Cross-workspace sharing (optional)

Attach an existing catalog to a workspace **read-only**. Discover valid candidates
with the `chameleon_attachable_catalogs` data source. This is gated by a platform
flag (`CATALOG_SHARING_ENABLED`) — isolation is the default.

```terraform
data "chameleon_attachable_catalogs" "for_team_a" {
  workspace_slug = chameleon_workspace.team_a.slug
}

resource "chameleon_workspace_catalog_attachment" "shared" {
  workspace_slug = chameleon_workspace.team_a.slug
  catalog_name   = "ws_shared"
}
```

## Import

A workspace can be imported by slug:

```shell
terraform import chameleon_workspace.team_a team-a
```
