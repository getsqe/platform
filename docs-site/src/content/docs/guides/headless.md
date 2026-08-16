---
title: Driving the platform headless
description: Bootstrap a workspace with the CLI, then run everything else from Airflow — no portal required.
sidebar:
  order: 5
---

Everything in the other guides assumes a person at the query editor. This page is for
the opposite case: a workspace that is created once, then driven entirely by DAGs. The
CLI does the one-time bootstrap; `apache-airflow-providers-chameleon` does the rest —
SQL, dbt runs, and anything that reaches the platform's own API surface.

## What you need

Every Chameleon operator and sensor authenticates through an Airflow **connection**,
and that connection is backed by a **service principal** — a Keycloak confidential
client, not a person. Ranger authorizes that principal exactly like it authorizes a
human: by name, with real grants, subject to the same fail-closed rules.

This is the step people skip. A DAG with no connection configured for its workspace
doesn't fail at authoring time — it fails days later as "Airflow can't see my table,"
which is a grant problem wearing an Airflow costume. See [System access with service
principals](/guides/service-principals/) for what a service principal is and is not
for, and [Workspaces and access](/guides/workspaces-and-access/) for how Ranger grants
work in general.

## 1. Create the workspace

The workspace is the one piece that isn't Airflow, because it's the bootstrap step
that creates the identity everything downstream runs as: creating a workspace also
provisions its primary catalog and the Keycloak groups behind its admin/member roles.

```sh frame="terminal"
chameleon workspace create energy-co --name "Energy Co"
chameleon workspace admin add energy-co ops-lead
```

The catalog is named after the slug with hyphens replaced by underscores:
`energy-co` becomes `ws_energy_co`. If the workspace also needs an existing catalog
that isn't its own, attach it explicitly — attaching grants no data access by itself:

```sh frame="terminal"
chameleon workspace attach energy-co some_other_catalog
```

## 2. Provision the Airflow tenant

`quickstart/sqe/scripts/provision-airflow-tenant.sh <slug>` does the rest of the
bootstrap in one step:

1. mints a workspace-bound service principal via the platform's own API;
2. registers a matching Airflow connection, `chameleon_<slug>`, inside the scheduler;
3. creates the per-workspace Airflow role `ws_<slug>` (DAG-level visibility is
   granted separately, per DAG — see the next section).

```sh frame="terminal"
export PLATFORM_ADMIN_TOKEN="$ADMIN_TOKEN"
quickstart/sqe/scripts/provision-airflow-tenant.sh energy-co
```

:::caution[This can fail for reasons that have nothing to do with the script]
Service-principal creation is refused unless engine-per-user enforcement is asserted
for the deployment — a platform-level setting, not something the script or the
request body controls. If provisioning fails, that assertion is the first thing to
check, not the script's arguments.
:::

The service principal is scoped to the workspace's own catalog at creation time, so
a DAG that only touches its own workspace needs no further grant. Reaching into any
other catalog is a normal grant, covered in [Where grants come from](#where-grants-come-from)
below.

## 3. First SQL from a DAG

`ChameleonSqlOperator` runs a single statement through the BFF query API. This is the
DAG to prove the connection works before building anything on top of it:

```python
import pendulum
from airflow import DAG
from airflow.providers.chameleon.operators.chameleon_sql import ChameleonSqlOperator

WS = "energy_co"

with DAG(
    dag_id="chameleon_sync_query",
    schedule="@daily",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    tags=["chameleon", f"ws:{WS}"],
    access_control={f"ws_{WS}": {"can_read", "can_edit"}},
) as dag:
    ChameleonSqlOperator(
        task_id="select_one",
        chameleon_conn_id=f"chameleon_{WS}",
        sql="SELECT 1 AS ok",
        engine="trino",
        do_xcom_push=True,
    )
```

Two details matter more than the SQL itself:

- `chameleon_conn_id` points at the connection the tenant script created —
  `chameleon_<slug>`, not the provider's own default of `chameleon_default`.
- `access_control={f"ws_{WS}": {"can_read", "can_edit"}}` scopes the DAG itself to
  the workspace's Airflow role. Without it, the DAG is visible to every tenant
  sharing this Airflow instance — Airflow multi-tenancy here is soft (one scheduler,
  one metadata database), so this line is doing real isolation work, not decoration.

## 4. A real transform

`ChameleonDbtRunOperator` runs a dbt command against a Chameleon-managed dbt project
(`project_id`, `action` — default `'run'` — `models`, `full_refresh`). Chaining a
`run` and a `test` action is the shape of a real transform:

```python
from airflow.providers.chameleon.operators.chameleon import ChameleonDbtRunOperator

PROJECT_ID = "{{ var.value.get('chameleon_demo_project_id') }}"

run = ChameleonDbtRunOperator(
    task_id="dbt_run",
    chameleon_conn_id=f"chameleon_{WS}",
    project_id=PROJECT_ID,
    action="run",
    deferrable=True,
)
test = ChameleonDbtRunOperator(
    task_id="dbt_test",
    chameleon_conn_id=f"chameleon_{WS}",
    project_id=PROJECT_ID,
    action="test",
    deferrable=True,
)
run >> test
```

`deferrable=True` matters for anything that takes longer than a few seconds: the
operator releases the worker slot while the dbt run is in progress and resumes when
it reaches a terminal state, instead of holding a worker thread for the entire run.
For a `SELECT 1` it makes no difference; for a dbt run against real data, it's the
difference between one worker per running DAG and none.

`ChameleonRunSensor` solves a related but different problem: waiting on a run you
triggered somewhere else in the DAG, rather than one an operator is already blocking
on for you — for example, a run kicked off by `ChameleonRunNowOperator` against an
existing schedule:

```python
from airflow.providers.chameleon.operators.chameleon import ChameleonRunNowOperator
from airflow.providers.chameleon.sensors.chameleon import ChameleonRunSensor

trigger = ChameleonRunNowOperator(
    task_id="trigger_schedule",
    chameleon_conn_id=f"chameleon_{WS}",
    schedule_id="{{ var.value.chameleon_schedule_id }}",
)
wait = ChameleonRunSensor(
    task_id="wait_for_run",
    chameleon_conn_id=f"chameleon_{WS}",
    run_type="dbt",
    run_id="{{ ti.xcom_pull(task_ids='trigger_schedule') }}",
    deferrable=True,
)
trigger >> wait
```

## 5. Custom work: `KubernetesPodOperator`

:::caution[Cannot run on the quickstart, for two independent reasons]
1. `quickstart/sqe` runs Airflow with `LocalExecutor` under Docker Compose — there is
   no Kubernetes underneath it.
2. The Airflow image ships no `cncf.kubernetes` provider, so
   `from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator`
   fails to import.

There is also no Chameleon Kubernetes operator or CRD — the pattern below is plain
`KubernetesPodOperator`, and it needs a Kubernetes-backed Airflow with the
`cncf.kubernetes` provider installed before it will run anywhere.
:::

For work that doesn't fit a Chameleon operator — a custom Python job, a third-party
tool — the general shape is to hand the pod the same service-principal credential the
Airflow connection already holds, as environment variables, and let the job
authenticate itself:

```python
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
from airflow.hooks.base import BaseHook

conn = BaseHook.get_connection(f"chameleon_{WS}")

custom_job = KubernetesPodOperator(
    task_id="custom_job",
    name="chameleon-custom-job",
    image="my-registry/my-job:latest",
    env_vars={
        "CHAMELEON_CLIENT_ID": conn.login,
        "CHAMELEON_CLIENT_SECRET": conn.password,
        "CHAMELEON_WORKSPACE": WS,
    },
)
```

The job authenticates the same way any service principal does — a `client_credentials`
token exchange against Keycloak — and Ranger authorizes it the same way it authorizes
everything else on this page: by principal name, not by which system asked.

## Where grants come from

Everything above runs as the service principal, and the service principal is a real
identity in Ranger — it is authorized exactly like a human user, not by some
Airflow-specific mechanism. So "Airflow gets a 403" is never an Airflow problem; it's
a grant problem, and it's debugged the same way you'd debug one for a person:

```sh frame="terminal"
chameleon access show --user sp-airflow-energy-co
```

The tenant script grants the service principal on its own workspace catalog at
creation time. Anything outside that — another catalog, a narrower table-level
grant — is a normal grant, made to the principal by name:

```sh frame="terminal"
chameleon access grant --user sp-airflow-energy-co \
  --catalog some_other_catalog --namespace sales --table orders --privilege SELECT
```

If a DAG gets a 401 instead of a 403, that's the identity claim, not the grant — see
the [identity trap](/guides/service-principals/#the-identity-trap) in the service
principals guide before assuming the token itself is broken.
