---
title: Querying data
description: Run SQL through the platform, and understand which identity each engine presents to the catalog.
sidebar:
  order: 0
---

You can run SQL from the CLI, the query editor in the web UI, or the REST API.
The CLI is what the end-to-end tests use, so it is the path most exercised.

```sh frame="terminal"
chameleon data query --engine flight "SELECT count(*) FROM main_warehouse.analytics_db.user_summary"
```

```
┏━━━━━┓
┃ c   ┃
┡━━━━━┩
│ 3   │
└─────┘

1 row(s), 89ms
```

## Access levels

DDL and DML are gated server-side by an access level, so a read-only session
cannot create or drop:

```sh frame="terminal"
chameleon data query --engine flight --access-level admin "SHOW SCHEMAS FROM ws_team_a"
chameleon data query --engine flight --access-level write  "INSERT INTO ws_team_a.sales.orders VALUES (1)"
chameleon data query --engine flight                       "SELECT * FROM ws_team_a.sales.orders"
```

## Three-part names

Always qualify with the catalog. A two-part name resolves against the session's
default catalog, which is not necessarily the one you mean — and in a
multi-workspace setup it usually is not.

```sql
SELECT * FROM ws_team_a.sales.orders   -- catalog.namespace.table
```

## Which engine sees which identity

This is the part that matters for security, and it is not uniform:

| Engine | Identity at the catalog | What that means |
|---|---|---|
| **SQE** (`--engine flight`) | the **end user's** JWT, forwarded | authorization is genuinely per-user; two people running the same SQL can legitimately see different rows |
| **Spark** (via Kyuubi) | the `spark-service-client` **service principal** | the catalog sees one identity for everyone. Per-user enforcement happens earlier, in Kyuubi's own Ranger check |
| **Trino** | `service-account-trino-client` | same shape as Spark |

:::caution[A grant on one plane does not constrain the other]
Because Spark and Trino reach the catalog as a service principal, a grant written
only against the catalog plane does not restrict what a Spark user can read.
Coarse grants are therefore **dual-written** to both Ranger services — the
`polaris` service and the `hive` service that the Spark path checks.

If you are testing enforcement, test it on the engine you actually care about.
Proving a denial on SQE proves nothing about Spark.
:::

## Why a query can be slower the first time

The engine caches table metadata per user. A first read pays a catalog round
trip; subsequent reads inside the cache window do not.

That cache is also why a **revoke** may not take effect immediately for a user who
has already read the table — see
[Workspaces and access](/guides/workspaces-and-access/#revoking).

## When a query says the table does not exist

Three genuinely different causes produce nearly the same message:

1. **It does not exist.** Check with an admin identity.
2. **You are not allowed to see it.** The catalog fails closed, so an unauthorized
   read can surface as *not found* rather than a permission error.
3. **The catalog has not caught up.** After creating a table in a brand-new
   workspace catalog, the engine may not see it for a few seconds. The
   engine-side refresh is `CALL system.refresh_catalog_cache()`.

Distinguish 1 from 2 before assuming anything: if an admin can see the table and
you cannot, it is a grant problem, not a missing object.
