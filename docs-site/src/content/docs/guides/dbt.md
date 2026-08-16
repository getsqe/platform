---
title: Transform data with dbt
description: Create a workspace, scaffold a dbt project, and run seed → compile → run → test entirely from the CLI.
sidebar:
  order: 1
---

dbt projects on the platform are **per workspace**. A project is scaffolded from a
platform template, stored server-side, and executed by the platform rather than
on your laptop — so a run uses your identity and the workspace's own catalog.

## Before you start

You need a workspace and workspace-admin rights in it. Everything below goes
through the `chameleon` CLI.

```sh frame="terminal"
chameleon login -u root -p "$ROOT_PASSWORD"
chameleon workspace create analytics-demo --name "Analytics demo"
```

## Scaffold a project

`dbt init` writes a complete, runnable project — `dbt_project.yml`, `profiles.yml`,
a sample source, a staging model, a seed and a test:

```sh frame="terminal"
chameleon dbt init analytics -w analytics-demo
```

```json
{
  "id": "8d8943dd-e94f-495e-9030-dd88c9ac857a",
  "name": "analytics",
  "warehouse": "ws_analytics_demo",
  "schema": "dev"
}
```

Note `warehouse`. The project points at the **workspace's own catalog**, not the
global default. This is deliberate and worth checking if you ever see
`Unable to find warehouse main_warehouse` — that error means something resolved
the global default instead of the workspace's.

## Run it

Each action is dispatched onto the platform's task queue and returns a run id
immediately. The run is asynchronous: a returned id means *accepted*, not
*finished*.

```sh frame="terminal"
chameleon dbt run seed    "$PROJECT_ID" -w analytics-demo
chameleon dbt run compile "$PROJECT_ID" -w analytics-demo
chameleon dbt run execute "$PROJECT_ID" -w analytics-demo
chameleon dbt run test    "$PROJECT_ID" -w analytics-demo
```

Poll a run until it reaches a terminal state:

```sh frame="terminal"
chameleon dbt run show "$RUN_ID" -w analytics-demo
```

Order matters for the scaffold: `seed` materialises the sample source table that
the staging model selects from, so running `execute` first will fail with
`Tried to load a table that does not exist`.

## Inspect history and logs

Every run is recorded, with the command, who ran it, and its timings:

```sh frame="terminal"
chameleon dbt run list "$PROJECT_ID" -w analytics-demo
```

```
┏━━━━━━━━━━━┳━━━━━━━━━┳━━━━━━━━━┳━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━━┳━━━━━━━━━━━┓
┃ id        ┃ command ┃ status  ┃ user_id ┃ started_… ┃ completed… ┃ created_… ┃
┡━━━━━━━━━━━╇━━━━━━━━━╇━━━━━━━━━╇━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━━╇━━━━━━━━━━━┩
│ fa902f7c… │ seed    │ success │ root    │ 2026-08-… │ 2026-08-1… │ 2026-08-… │
└───────────┴─────────┴─────────┴─────────┴───────────┴────────────┴───────────┘
```

The id is **truncated** in this view. Take the full id from the trigger response
or `--format json` if you need to pass it to another command.

Logs are durable — they survive the run, so a failure can be diagnosed after the
fact:

```sh frame="terminal"
chameleon dbt run logs "$RUN_ID" -w analytics-demo
```

## Where the scaffold puts things

Understanding this saves a confusing hour:

| Thing | Lands in | Why |
|---|---|---|
| seeds | `<schema>_raw` | `seeds: +schema: raw` in `dbt_project.yml` is a **suffix** on the target schema, not an absolute name |
| models | `<schema>` | the target schema, `dev` by default |
| silver / gold models | `<schema>_silver`, `<schema>_gold` | same suffix rule |

The scaffold's `models/sources.yml` declares the source in `<schema>_raw` to match
where `dbt seed` actually writes. If you point a source at the wrong schema, the
seed still reports **success** and the failure appears one step later, in the
model, as `Tried to load a table that does not exist`.

## Materialization

The scaffold defaults every model to `+materialized: table`.

:::caution
Do not change that to `view` without testing. dbt's own default is `view`, and
dbt-trino renders a view as Trino DDL carrying a `SECURITY` clause that the query
engine's parser currently rejects:

```
Parse error: sql parser error: Expected: AS, found: security at Line: 5, Column: 3
```

This is an open engine-side gap, not a configuration mistake on your part.
:::

## Clean up

```sh frame="terminal"
chameleon dbt delete "$PROJECT_ID" -w analytics-demo --yes
chameleon workspace delete analytics-demo --yes
```

## Scope

This guide covers the dbt project lifecycle: scaffold, seed, compile, run, test.

Scheduling a dbt run is covered in [Orchestration](/concepts/orchestration/). Lineage shows up
in passing in the [data engineer tutorial](/guides/tutorials/data-engineer/) and the
[dbt lifecycle use case](/guides/use-cases/dbt-lifecycle/), but isn't documented here. Dbt
sessions (the interactive editing surface behind the UI) and sources and freshness aren't
documented anywhere yet.
