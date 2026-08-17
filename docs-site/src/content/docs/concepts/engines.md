---
title: Query engines
description: Three engines over one copy of the data, and what changes when you switch.
sidebar:
  order: 5
---

The platform runs more than one query engine over **the same tables**. Not
copies, not extracts — the same Iceberg tables in the same storage. Switching
engine changes how a query is executed, not what it can see.

## The three

**The platform's own engine** is the default. Queries go over Arrow Flight, which
keeps results in a columnar form the whole way rather than serialising them into
rows and back. It is what the query editor uses unless you choose otherwise, and
it is the right choice for interactive work.

**Trino** is the one to reach for when a query is large, federated, or written
against Trino-specific SQL. It is a mature distributed engine with a wide SQL
surface.

**Spark** is for work that is a *program* rather than a query — heavy
transformation, machine-learning pipelines, anything already written against
Spark. It is reached through a gateway that handles sign-on, so an interactive
Spark session belongs to the person who opened it.

## What does not change

Switching engine does not change what data exists, because there is one catalog
and one copy of each table. It does not change the SQL identifier either:
`catalog.namespace.table` means the same thing in all three.

## What does change: how per-user enforcement is reached

This is the part worth reading twice, because "authorization follows the end
user" is true on every path but arrives by different routes.

On the **platform engine** and **Trino** paths, the end user's identity travels
with the query to the catalog, which consults Ranger. The person asking is the
person Ranger decides about.

On the **Spark** path, the end-user token does not travel all the way through:
Spark reaches the catalog as a **service identity**. Per-user enforcement instead
happens at the gateway, which checks the user against Ranger before the query
runs — the same Ranger, sharing the same policies, so masks and row filters
apply. But it is a different enforcement point, and that matters when you are
debugging why someone can read something.

The practical consequence: **do not reason about Spark access by looking only at
catalog grants.** Check what the gateway enforces too.

## Choosing

- **Interactive question, human waiting** → the platform engine. It is the
  default for a reason.
- **Large or federated query, or Trino-specific SQL** → Trino.
- **A program, not a query** → Spark.

Most people never switch. The engine picker exists because the platform does not
want to decide for you when the work genuinely differs.

## Where to go next

- [Run a query](/docs/guides/use-cases/run-query/) — the query editor, with the CLI,
  MCP and API equivalents.
- [Access control](/docs/concepts/access-control/) — how a grant becomes an enforced
  decision, and where enforcement happens.
- [The platform model](/docs/concepts/platform-model/) — why one catalog serves every
  engine.
