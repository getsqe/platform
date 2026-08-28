---
title: The platform model
description: Workspace, catalog, namespace, table — the four words everything else assumes you know.
sidebar:
  order: 0
---

Four words carry most of this platform. Every guide, every API path and every
error message assumes you know them, so they are worth ten minutes now rather
than an hour of confusion later.

## The shape

<svg viewBox="0 0 660 250" role="img" aria-labelledby="shape-title shape-desc" style="max-width:100%;height:auto;margin:1.25rem 0">
<title id="shape-title">What a workspace owns</title>
<desc id="shape-desc">A workspace owns exactly one catalog, plus its storage buckets and its admin and member groups. Inside the catalog are namespaces, and inside those, Apache Iceberg tables. A table is named in full as catalog.namespace.table.</desc>
<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="currentColor"/></marker></defs>
<g fill="none" stroke="currentColor" stroke-width="1.5" font-family="ui-sans-serif, system-ui, sans-serif" font-size="13">
<rect x="8" y="8" width="196" height="234" rx="8" stroke-opacity="0.45"/>
<text x="24" y="34" fill="currentColor" stroke="none" font-weight="600">workspace</text>
<text x="24" y="54" fill="currentColor" stroke="none" opacity="0.65" font-size="12">the unit a team is given</text>
<rect x="24" y="72" width="164" height="34" rx="6" stroke-opacity="0.3"/>
<text x="38" y="94" fill="currentColor" stroke="none" font-size="12">storage buckets</text>
<rect x="24" y="118" width="164" height="34" rx="6" stroke-opacity="0.3"/>
<text x="38" y="140" fill="currentColor" stroke="none" font-size="12">admins + members</text>
<text x="24" y="196" fill="currentColor" stroke="none" font-size="12" opacity="0.65">owns exactly one</text>
<path d="M150 208 h56" marker-end="url(#arrow)" stroke-opacity="0.8"/>
<rect x="236" y="8" width="416" height="234" rx="8" stroke-opacity="0.45"/>
<text x="256" y="34" fill="currentColor" stroke="none" font-weight="600">catalog</text>
<text x="256" y="54" fill="currentColor" stroke="none" opacity="0.65" font-size="12">what an engine connects to</text>
<rect x="256" y="72" width="378" height="156" rx="6" stroke-opacity="0.3"/>
<text x="274" y="94" fill="currentColor" stroke="none" font-size="12">namespace</text>
<text x="352" y="94" fill="currentColor" stroke="none" font-size="12" opacity="0.6">read it as a schema</text>
<rect x="274" y="110" width="342" height="102" rx="6" stroke-opacity="0.3"/>
<text x="292" y="132" fill="currentColor" stroke="none" font-size="12">table</text>
<text x="336" y="132" fill="currentColor" stroke="none" font-size="12" opacity="0.6">an Apache Iceberg table</text>
<text x="292" y="168" fill="currentColor" stroke="none" font-size="12" opacity="0.7">named in full as</text>
<text x="292" y="190" fill="currentColor" stroke="none" font-size="12.5" font-family="ui-monospace, SFMono-Regular, monospace">catalog.namespace.table</text>
</g>
</svg>

**Workspace** — the unit of tenancy, and the thing a team is given. It owns a
catalog, its own storage buckets, and the groups whose members administer or use
it.

**Catalog** — the top of the data hierarchy. It is what an engine connects to,
and what you name first in a three-part SQL identifier.

**Namespace** — a grouping inside a catalog. If it helps, read it as *schema*;
SQL treats it that way, and dbt calls it a schema too.

**Table** — an [Apache Iceberg](https://iceberg.apache.org/) table. Not a copy,
not an extract: one definition that Trino, Spark and the platform's own engine
all read.

So a fully-qualified name reads `catalog.namespace.table`, for example
`ws_acme_analytics.analytics_db.product_sales`.

## One catalog belongs to exactly one workspace

This is the rule that makes tenancy work, and the one that surprises people.

A workspace is not a folder or a label. When a workspace is created the platform
provisions its catalog, its warehouse and staging buckets, and its Keycloak admin
and member groups. Because a catalog belongs to exactly one workspace, "who can
reach this data" has a single, structural answer rather than a per-table one.

**The catalog name is derived, not chosen.** A workspace with the slug
`acme-analytics` gets the catalog `ws_acme_analytics` — the slug with dashes
turned into underscores, prefixed. Pick the slug as carefully as you would pick a
database name, because it is what everyone will type in SQL for as long as the
workspace exists.

## What follows from it

Several behaviours that look arbitrary are consequences of this model:

- **A workspace-scoped thing defaults to the workspace's catalog.** A trigger or
  a dbt project that does not name a catalog runs against the workspace's own —
  not a platform-wide default. That is why a dbt project has no catalog field.
- **Requests carry the workspace.** Workspace-scoped API calls send an
  `X-Workspace` header, and the portal only sends it on `/ws/:slug/*` routes. A
  request made outside those routes is deliberately workspace-less, and the API
  will reject it rather than guess.
- **Access is granted against this hierarchy.** A grant names a catalog, a
  namespace or a table — and grants at a higher level do not always imply the
  traversal a query needs. See [Access control](/docs/concepts/access-control/).

## What a workspace is not

- **Not a copy of the data.** Tables live in object storage you own, in an open
  format. A workspace is the ownership and access boundary around them, not a
  container they are inside.
- **Not an isolation guarantee at the infrastructure level.** Workspaces separate
  data and access. Shared services — the scheduler, the metadata database — are
  shared. Where isolation is soft rather than hard, the documentation says so.
- **Not free to rename.** The derived catalog name is in every query anyone has
  written. Treat the slug as permanent.

## Where to go next

- [Identity](/docs/concepts/identity/) — what a caller is *called* at each hop, which
  is where the expensive failures happen.
- [Access control](/docs/concepts/access-control/) — how a grant becomes an enforced
  decision.
- [Set up a workspace for a team](/docs/guides/tutorials/platform-engineer/) — the
  same model, applied.
