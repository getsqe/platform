---
title: Web portal routes
description: Every route the web portal serves, generated from the router.
sidebar:
  order: 5
---

<!-- GENERATED FILE - do not edit. See docs-site/scripts/gen-ui-reference.mjs -->

The portal is organised into a handful of top-level areas. Paths with a
`:parameter` segment are detail views reached by clicking through from a list.

**66 routes**, plus 10 redirects kept for old links.

:::caution[This is a map, not a manual]
It tells you what exists and where to find it. It does **not** describe what each
screen does, which fields mean what, or how to complete a task — and it has no
screenshots.

Writing that honestly means driving each screen and recording what it actually
does, rather than inferring behaviour from a component name. Until that is done,
these pages are listed rather than documented, which is the accurate state.
:::

## Explore

Browse catalogs, namespaces and tables, and read their metadata.

| Route | Page component |
|---|---|
| `explore` | — |
| `explore/catalog/:catalog` | — |
| `explore/catalog/:catalog/namespace/:namespace` | — |
| `explore/catalogs/:catalog/namespaces/:namespace/tables/:table` | — |

## Build

Author things: dbt projects, notebooks, workspace projects, event triggers.

| Route | Page component |
|---|---|
| `build/dbt/connections` | — |
| `build/dbt/lineage/:sessionId` | — |
| `build/dbt/project/:projectId` | — |
| `build/dbt/projects` | — |
| `build/dbt/sources/:sessionId` | — |
| `build/dbt/workspace/:projectId` | — |
| `build/notebooks` | — |
| `build/notebooks/:notebookId` | — |
| `build/projects` | — |
| `build/projects/:projectId/notebooks/:notebookId` | — |
| `build/triggers` | — |

## Govern

Access control, contracts, data quality, schedules, lineage and audit.

| Route | Page component |
|---|---|
| `govern/access-control` | — |
| `govern/audit` | — |
| `govern/catalogs` | — |
| `govern/contracts` | — |
| `govern/contracts/:contractId` | — |
| `govern/contracts/:id/edit` | — |
| `govern/contracts/dashboard` | — |
| `govern/contracts/new` | — |
| `govern/contracts/repositories` | — |
| `govern/data-quality` | — |
| `govern/metadata` | — |
| `govern/namespaces` | — |
| `govern/overview` | — |
| `govern/principals` | — |
| `govern/roles` | — |
| `govern/schedules` | — |

## Admin

Platform-wide administration. Requires platform-admin rights.

| Route | Page component |
|---|---|
| `admin` | — |
| `admin/ai-flows` | — |
| `admin/audit-digest` | — |
| `admin/benchmarks` | — |
| `admin/demo` | — |
| `admin/features` | — |
| `admin/lineage-admin` | — |
| `admin/security-alerts` | — |
| `admin/service-principals` | — |
| `admin/storage` | — |
| `admin/system-health` | — |
| `admin/system-versions` | — |
| `admin/workspaces` | — |

## Insights

Ad-hoc analysis surface.

| Route | Page component |
|---|---|
| `insights` | — |

## Lineage

Lineage graph viewer.

| Route | Page component |
|---|---|
| `lineage` | — |
| `lineage/datasets/:id` | — |
| `lineage/jobs/:id` | — |

## Workspace-scoped

The same surfaces, entered in the context of one workspace (`/ws/:slug/…`).

| Route | Page component |
|---|---|
| `/ws/:slug/login` | — |
| `ws/:slug` | `WorkspaceRouteGuard` |

## Other

Sign-in, callbacks and top-level routes.

| Route | Page component |
|---|---|
| `/*` | — |
| `/auth-callback` | `AuthCallbackPage` |
| `/login` | `LoginPage` |
| `/logout` | `LogoutPage` |
| `manage/grants` | — |
| `manage/members` | — |
| `ontology` | — |
| `ontology/ask` | — |
| `ontology/assign/:versionId` | — |
| `ontology/browse` | — |
| `ontology/design/:versionId` | — |
| `ontology/import` | — |
| `ontology/wizard` | — |
| `ops` | — |
| `query` | — |
| `select-workspace` | — |

## Redirects

Kept so older bookmarks and links keep working. Several surfaces moved from
`govern/` to `admin/` when platform-wide administration was separated from
per-workspace governance.

| Route | Forwards to |
|---|---|
| `govern/ai-flows` | its new location |
| `govern/audit-digest` | its new location |
| `govern/benchmarks` | its new location |
| `govern/demo` | its new location |
| `govern/features` | its new location |
| `govern/lineage-admin` | its new location |
| `govern/security-alerts` | its new location |
| `govern/storage` | its new location |
| `govern/system-health` | its new location |
| `manage/namespaces` | another route |
