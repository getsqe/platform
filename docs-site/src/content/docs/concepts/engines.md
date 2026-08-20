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

<svg viewBox="0 0 700 250" role="img" aria-labelledby="path-title path-desc" style="max-width:100%;height:auto;margin:1.25rem 0">
<title id="path-title">Where per-user enforcement happens on each engine path</title>
<desc id="path-desc">On the platform engine and Trino paths the end user's identity travels from the browser through the BFF and the engine to the catalog, which asks Ranger. On the Spark path the identity stops at the gateway: the gateway asks Ranger about the user, and the catalog sees a service identity instead.</desc>
<defs><marker id="a2" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="currentColor"/></marker></defs>
<g fill="none" stroke="currentColor" stroke-width="1.5" font-family="ui-sans-serif, system-ui, sans-serif" font-size="12">
<text x="8" y="20" fill="currentColor" stroke="none" font-size="12" font-weight="600">platform engine / Trino</text>
<rect x="8" y="32" width="86" height="36" rx="6" stroke-opacity="0.35"/>
<text x="26" y="55" fill="currentColor" stroke="none">browser</text>
<path d="M98 50 h34" marker-end="url(#a2)" stroke-opacity="0.8"/>
<rect x="136" y="32" width="62" height="36" rx="6" stroke-opacity="0.35"/>
<text x="152" y="55" fill="currentColor" stroke="none">BFF</text>
<path d="M202 50 h34" marker-end="url(#a2)" stroke-opacity="0.8"/>
<rect x="240" y="32" width="76" height="36" rx="6" stroke-opacity="0.35"/>
<text x="258" y="55" fill="currentColor" stroke="none">engine</text>
<path d="M320 50 h34" marker-end="url(#a2)" stroke-opacity="0.8"/>
<rect x="358" y="32" width="80" height="36" rx="6" stroke-opacity="0.35"/>
<text x="374" y="55" fill="currentColor" stroke="none">catalog</text>
<path d="M442 50 h34" marker-end="url(#a2)" stroke-opacity="0.8"/>
<rect x="480" y="32" width="76" height="36" rx="6" stroke-width="2"/>
<text x="497" y="55" fill="currentColor" stroke="none" font-weight="600">Ranger</text>
<text x="8" y="92" fill="currentColor" stroke="none" font-size="11.5" opacity="0.7">the end user's identity travels the whole way — the catalog asks about the person</text>
<line x1="8" y1="112" x2="692" y2="112" stroke-opacity="0.2"/>
<text x="8" y="142" fill="currentColor" stroke="none" font-size="12" font-weight="600">Spark</text>
<rect x="8" y="154" width="86" height="36" rx="6" stroke-opacity="0.35"/>
<text x="26" y="177" fill="currentColor" stroke="none">browser</text>
<path d="M98 172 h34" marker-end="url(#a2)" stroke-opacity="0.8"/>
<rect x="136" y="154" width="62" height="36" rx="6" stroke-opacity="0.35"/>
<text x="152" y="177" fill="currentColor" stroke="none">BFF</text>
<path d="M202 172 h34" marker-end="url(#a2)" stroke-opacity="0.8"/>
<rect x="240" y="154" width="76" height="36" rx="6" stroke-width="2"/>
<text x="252" y="177" fill="currentColor" stroke="none" font-weight="600">gateway</text>
<path d="M278 148 v-30" marker-end="url(#a2)" stroke-opacity="0.6" stroke-dasharray="4 3"/>
<text x="288" y="132" fill="currentColor" stroke="none" font-size="11">asks Ranger about the user, here</text>
<path d="M320 172 h34" marker-end="url(#a2)" stroke-opacity="0.8"/>
<rect x="358" y="154" width="80" height="36" rx="6" stroke-opacity="0.35"/>
<text x="378" y="177" fill="currentColor" stroke="none">Spark</text>
<path d="M442 172 h34" marker-end="url(#a2)" stroke-opacity="0.8"/>
<rect x="480" y="154" width="80" height="36" rx="6" stroke-opacity="0.35"/>
<text x="496" y="177" fill="currentColor" stroke="none">catalog</text>
<text x="8" y="214" fill="currentColor" stroke="none" font-size="11.5" opacity="0.7">the identity stops at the gateway — the catalog sees a service identity, so catalog</text>
<text x="8" y="232" fill="currentColor" stroke="none" font-size="11.5" opacity="0.7">grants alone do not tell you who can read what</text>
</g>
</svg>

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
