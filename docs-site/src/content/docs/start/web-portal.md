---
title: Finding your way around the portal
description: How the web portal is organised, and which surface owns which job.
sidebar:
  order: 2
---

Sign in at the platform URL (`https://chameleon.test` on a local stack). The
portal splits into a few top-level areas, and knowing which one owns a job is
most of finding it.

## The areas

| Area | For | Examples |
|---|---|---|
| **Explore** | reading the catalog | browse catalogs, namespaces and tables; inspect a table's schema and metadata |
| **Build** | authoring | dbt projects, notebooks, workspace projects and files, event triggers |
| **Govern** | control and oversight | access control, contracts, data quality, schedules, lineage, audit, roles and principals |
| **Admin** | platform-wide administration | workspaces, service principals, storage, system health and versions, feature flags |
| **Insights** | ad-hoc analysis | question-driven exploration |
| **Lineage** | provenance | the lineage graph |

Two distinctions are worth internalising early, because they explain why a screen
is where it is:

**Govern is per-workspace; Admin is platform-wide.** Several surfaces moved from
`govern/` to `admin/` when the two were separated, and the old paths still
redirect — so an old bookmark landing somewhere unexpected is that, not a bug.

**Most surfaces exist twice**: once globally, and once scoped to a workspace under
`/ws/:slug/…`. The workspace-scoped variant is the one that shows only that
workspace's data and is what a workspace admin normally uses.

## What you see depends on who you are

The portal is not a fixed set of screens. Visibility is driven by your grants and
group membership, so two people can sign in and legitimately see different
catalogs, different tables, and different navigation entries.

:::caution[The UI's visibility layer is advisory]
Navigation and listings are filtered on a best-effort basis and are documented as
**fail-open**. They are not the enforcement point — the catalog and Ranger are. If
the UI and an actual query disagree, **the query is authoritative**.

The practical consequence: never conclude you have access because a table is
listed, and never conclude you lack it because a table is missing. Run the query.
See [Identity](/docs/concepts/identity/).
:::

## Where things are

The complete route list is generated from the router — see
[Web portal routes](/docs/reference/ui-routes/).

## What is missing here

:::caution[Not every screen is documented yet]
This page and the route reference tell you what exists and where. Neither
describes what every screen does or which fields mean what.

The gap is being closed a flow at a time, and only by driving the product:
inferring behaviour from a component name produces documentation that reads well
and misleads. The [use-case guides](/docs/guides/use-cases/) are generated from a
capture run against a live stack, so their steps are steps a test executed and
their screenshots are what it saw — the core flows are covered there, with
images. Longer journeys are written up as guides: [Transform data with
dbt](/docs/guides/dbt/) and [Workspaces and access](/docs/guides/workspaces-and-access/).

With 66 routes, documenting the remainder is still a body of work in its own
right.
:::
