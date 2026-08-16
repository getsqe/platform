---
title: Making work happen
description: Triggers, schedules, dbt and Airflow — four ways to run work, and when each is the right one.
sidebar:
  order: 4
---

There are four ways to make the platform do something without a person clicking
a button. They overlap enough that people pick one by accident, then discover the
constraint that mattered. This page is the choice, stated once.

## The short answer

| You want work to run… | Use |
|---|---|
| when an **event** happens — a file lands, a system calls you | a **trigger** |
| on a **clock** — nightly, hourly | a **schedule** |
| because **data changed and models must be rebuilt** | **dbt**, invoked by either of the above |
| across **several systems**, with dependencies between them | **Airflow** |

If two of these look equally right, pick the simpler one. A trigger and a
schedule are platform objects with a UI, a history and an owner; an Airflow DAG
is a program someone has to maintain.

## Triggers — run on an event

A trigger turns something happening outside the platform into work inside it. The
event arrives either as an authenticated **HTTP POST**, or as a **file landing in
S3** routed through EventBridge and SQS.

A trigger belongs to **one workspace** and carries its own authentication:

- **Service token** — the caller presents an OAuth2 client-credentials token, and
  the service principal must be bound to the trigger's workspace.
- **Webhook secret** — Standard Webhooks HMAC signing, for senders that cannot
  fetch a token.
- **No authentication** — only where the platform explicitly allows it, off by
  default.

What a trigger can start: a **SQL** statement, a **file ingest**, a **dbt**
project, a **notebook**, an **MLflow** run, or a **Langflow** flow.

Two properties worth knowing. A `sql` trigger that does not name a catalog runs
against the **workspace's own catalog** — not a platform-wide default. And every
firing is recorded, so the Monitoring tab shows what fired, what it produced, and
the **full failure reason** rather than an opaque id.

Prove the wiring with **Test fire** before anything depends on it: it dispatches
through the real path, works while the trigger is disabled, and appears in the
history like any other firing.

## Schedules — run on a clock

A schedule is a cron expression plus an IANA timezone (`Europe/Amsterdam`, not an
offset — so daylight saving is handled rather than drifted through). Both are
validated when you save, not when the schedule first tries to fire.

A schedule can run a **dbt** project, a **notebook**, a **data-quality** check, an
**Iceberg** maintenance job, or a **Langflow** flow.

Schedules can notify on failure. Notification targets are restricted to an
allowlist of schemes on purpose: an unrestricted target turns a scheduler into a
way to make the platform issue requests to arbitrary internal addresses.

There is also a **one-shot run** — execute a job now, without creating a
schedule. It runs under the caller's own identity, which makes it the honest way
to test a job before committing it to a cron expression.

## dbt — rebuild models from code

dbt is not a third scheduler; it is the *work*. A dbt project turns SQL files in a
git repository into managed tables, and something else decides when to run it:
you in the browser, a trigger, a schedule, or `chameleon dbt run`.

It runs **as the person who asked**, against that workspace's catalog. See
[Build and test a dbt project](/guides/use-cases/dbt-lifecycle/).

## Airflow — orchestrate across systems

Airflow earns its place when work spans systems and has dependencies — this,
then that, unless the other thing failed. It runs as a separate deployment with
its own sign-on, and reaches the platform through a per-team service principal
that is authorized by Ranger like any other identity.

Its multi-tenancy is **soft**: teams map to Airflow roles and see their own DAGs,
but the scheduler and metadata database are shared. Hard isolation would mean one
Airflow per tenant. Where that distinction matters to you, it should decide
whether Airflow is the right home for the work.

## Choosing, in practice

- **Start with a trigger** if there is a real event. It is the shortest path from
  "the file arrived" to "the table is fresh", and its history answers the
  question you will actually be asked, which is *did it run and what happened*.
- **Use a schedule** when nothing announces itself, or when you want a floor
  under a trigger — rebuild nightly even if nothing fired.
- **Reach for Airflow last.** It is the most capable and the most to maintain,
  and its isolation story is weaker than the platform's own.

## Where to go next

- [Fire a task from an external event](/guides/use-cases/triggers/) — a trigger,
  end to end, with screenshots.
- [Build your first pipeline](/guides/tutorials/data-engineer/) — dbt and a
  trigger together.
- [The platform model](/concepts/platform-model/) — why workspace-scoped work
  defaults to the workspace's catalog.
