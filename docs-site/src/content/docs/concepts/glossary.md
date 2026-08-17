---
title: Glossary
description: The words this platform uses, and what they mean here specifically.
sidebar:
  order: 9
---

Several of these words mean something ordinary elsewhere and something specific
here. Where a term has a platform-specific meaning, that meaning wins.

## The data hierarchy

**Workspace** — the unit of tenancy. Owns exactly one catalog, its own storage
buckets, and the Keycloak groups that administer and use it. See
[The platform model](/docs/concepts/platform-model/).

**Catalog** — the top of the data hierarchy, and the first part of a three-part
SQL name. A workspace's catalog name is *derived* from its slug:
`acme-analytics` → `ws_acme_analytics`.

**Namespace** — a grouping inside a catalog. The same thing SQL calls a schema,
and dbt calls a schema.

**Table** — an Apache Iceberg table. One definition, read by every engine, stored
in object storage you own.

**Warehouse** — storage backing a catalog. Note that older material sometimes
uses "warehouse" loosely for the catalog itself.

## Identity and access

**Principal** — an identity as the catalog knows it. Every person or system that
touches data has one, and its name must match the identity claim that arrives
from the identity provider.

**Service principal** — a confidential OIDC client for a *system*, not a person.
Provisioned through the platform so it is governed like any other identity:
least privilege, read-only unless stated otherwise. Use one per system.

**Grant** — permission for an identity to do something to a resource, authored
once through the platform's access API and enforced by Ranger at query time.

**Role** — in Ranger, the mirror of a Keycloak group. Granting to a role is how
you grant to a team.

**Keycloak** — the identity provider. Where people and systems are defined.
Identity comes from here; the platform does not keep its own directory.

**Apache Ranger** — the single authority for data access. Decides for the **end
user**, not for the engine they arrived through.

**Apache Polaris** — the Iceberg REST catalog. Holds the table metadata and
consults Ranger for authorization.

## Building and running work

**dbt** — the tool that turns SQL files in a git repository into managed tables.
The platform clones the repository and runs dbt as the person who asked.

**Seed** — in dbt, a small CSV committed to the repository and loaded as a table.
Run it before your first `run`, or the models have no source data.

**Model** — a table (or view) defined by a SQL file in a dbt project.

**Lineage** — the recorded path from source to finished table: what was built
from what. Read it after a run rather than before.

**Trigger** — turns an outside event into platform work. An authenticated HTTP
POST, or a file landing in S3. Per workspace, with its own authentication.

**Schedule** — the same idea on a clock rather than an event.

**Task queue** — where triggered and scheduled work waits to run.

## Interfaces

**BFF** — backend-for-frontend. The portal's server side, which holds tokens so
the browser never has to.

**MCP** — Model Context Protocol. How an AI assistant reaches the platform's
tools, with the caller's own permissions rather than elevated ones.

**CLI** — the `chameleon` command. The supported way to script the platform.

**Engine** — what actually executes a query: the platform's own SQL engine,
Trino, or Spark. Authorization does not change between them, because it follows
the end user.
