---
title: Airflow provider
description: Operators, sensors and hooks for orchestrating the platform from Apache Airflow.
sidebar:
  order: 4
---

<!-- GENERATED FILE - do not edit. See docs-site/scripts/gen-airflow-reference.py -->

`apache-airflow-providers-chameleon` lets an Airflow DAG drive the platform:
run SQL, trigger dbt, manage projects and wait on results. It is **not published
to PyPI** — it is vendored in this repository and built into the
`chameleon-airflow` image.

Connections use the `chameleon` connection type, registered by the provider.
Each workspace gets its own connection (`chameleon_<slug>`) backed by a
workspace-bound service principal, which is what keeps one tenant's DAGs out of
another's data — see [System access with service
principals](/guides/service-principals/).

**19 classes.**

:::caution[Soft isolation]
Airflow multi-tenancy here is soft: one scheduler and one metadata database are
shared across workspaces. Data isolation comes from the per-workspace service
principal and its Ranger policies, not from Airflow. Hard isolation would mean one
Airflow per tenant.
:::

## Operators

### `ChameleonRunNowOperator`

Trigger an existing Chameleon schedule (mirrors DatabricksRunNowOperator).

```python
from airflow.providers.chameleon.operators.chameleon import ChameleonRunNowOperator
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `schedule_id` | `str` | required | yes |

### `ChameleonDbtRunOperator`

Run a dbt command on a Chameleon dbt project.

```python
from airflow.providers.chameleon.operators.chameleon import ChameleonDbtRunOperator
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `project_id` | `str` | required | yes |
| `action` | `str` | `'run'` |  |
| `models` | `list[str] \| None` | `None` | yes |
| `full_refresh` | `bool` | `False` |  |

### `ChameleonQualityRunOperator`

Run a data-quality contract (Chameleon-native).

```python
from airflow.providers.chameleon.operators.chameleon import ChameleonQualityRunOperator
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `contract_id` | `str` | required | yes |
| `scope` | `str` | `'full'` |  |

### `ChameleonNotebookOperator`

Run a notebook once, via a one-shot submit (mirrors DatabricksSubmitRunOperator).

```python
from airflow.providers.chameleon.operators.chameleon import ChameleonNotebookOperator
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `project_id` | `str` | required | yes |
| `notebook_path` | `str` | required | yes |
| `parameters` | `dict \| None` | `None` | yes |
| `output_path` | `str \| None` | `None` | yes |

### `ChameleonCreateScheduleOperator`

Create a Chameleon schedule (mirrors DatabricksCreateJobsOperator).

```python
from airflow.providers.chameleon.operators.chameleon import ChameleonCreateScheduleOperator
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `payload` | `dict` | required | yes |
| `chameleon_conn_id` | `str` | `'chameleon_default'` | yes |
| `workspace` | `str \| None` | `None` | yes |

### `ChameleonProjectCreateOperator`

Create a workspace project (``kind`` = notebook | dbt). Returns the project record.

```python
from airflow.providers.chameleon.operators.chameleon_project import ChameleonProjectCreateOperator
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `kind` | `str` | required |  |
| `name` | `str` | required | yes |
| `visibility` | `str` | `'shared'` |  |
| `connection_id` | `str \| None` | `None` | yes |
| `dbt_config` | `dict \| None` | `None` |  |

### `ChameleonProjectUpdateOperator`

Update a workspace project (PATCH: name / connection_id / default_branch / dbt_config).

```python
from airflow.providers.chameleon.operators.chameleon_project import ChameleonProjectUpdateOperator
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `project_id` | `str` | required | yes |
| `fields` | `dict` | required |  |

### `ChameleonProjectDeleteOperator`

Delete a workspace project.

```python
from airflow.providers.chameleon.operators.chameleon_project import ChameleonProjectDeleteOperator
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `project_id` | `str` | required | yes |

### `ChameleonProjectFilePutOperator`

Write a file into a workspace project's repo tree (DBFS-analogue).

```python
from airflow.providers.chameleon.operators.chameleon_project import ChameleonProjectFilePutOperator
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `project_id` | `str` | required | yes |
| `path` | `str` | required | yes |
| `content` | `str` | required | yes |

### `ChameleonProjectFileGetOperator`

Read a file from a workspace project's repo tree.

```python
from airflow.providers.chameleon.operators.chameleon_project import ChameleonProjectFileGetOperator
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `project_id` | `str` | required | yes |
| `path` | `str` | required | yes |

### `ChameleonProjectFileDeleteOperator`

Delete a file from a workspace project's repo tree.

```python
from airflow.providers.chameleon.operators.chameleon_project import ChameleonProjectFileDeleteOperator
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `project_id` | `str` | required | yes |
| `path` | `str` | required | yes |

### `ChameleonSqlOperator`

Run a SQL statement via the BFF query API (Trino by default).

```python
from airflow.providers.chameleon.operators.chameleon_sql import ChameleonSqlOperator
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `sql` | `str` | required | yes |
| `engine` | `str` | `'trino'` |  |
| `chameleon_conn_id` | `str` | `'chameleon_default'` | yes |
| `workspace` | `str \| None` | `None` | yes |
| `deferrable` | `bool` | `False` |  |
| `polling_period_seconds` | `int` | `30` |  |

## Sensors

### `ChameleonRunSensor`

Wait for a Chameleon run (dbt / schedule / quality) to reach a terminal state.

```python
from airflow.providers.chameleon.sensors.chameleon import ChameleonRunSensor
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `run_type` | `str` | required |  |
| `run_id` | `str` | required | yes |
| `schedule_id` | `str \| None` | `None` | yes |
| `chameleon_conn_id` | `str` | `'chameleon_default'` | yes |
| `workspace` | `str \| None` | `None` | yes |
| `deferrable` | `bool` | `False` |  |

### `ChameleonSqlSensor`

Poke by running ``sql`` via the BFF ``/query`` endpoint; True when rows return.

```python
from airflow.providers.chameleon.sensors.chameleon_sql import ChameleonSqlSensor
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `sql` | `str` | required | yes |
| `engine` | `str` | `'trino'` |  |
| `chameleon_conn_id` | `str` | `'chameleon_default'` | yes |
| `workspace` | `str \| None` | `None` | yes |
| `deferrable` | `bool` | `False` |  |
| `polling_period_seconds` | `int` | `30` |  |

### `ChameleonPartitionSensor`

Wait for an Iceberg table partition to exist.

```python
from airflow.providers.chameleon.sensors.chameleon_sql import ChameleonPartitionSensor
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `table` | `str` | required | yes |
| `partitions` | `dict` | required | yes |
| `partition_operator` | `str` | `'='` |  |
| `use_metadata_table` | `bool` | `False` |  |
| `resolve_partitions` | `bool` | `False` |  |
| `engine` | `str` | `'trino'` |  |
| `chameleon_conn_id` | `str` | `'chameleon_default'` | yes |
| `workspace` | `str \| None` | `None` | yes |

## Hooks

### `ChameleonRunState`

_No docstring._

```python
from airflow.providers.chameleon.hooks.chameleon import ChameleonRunState
```

_No constructor arguments._

### `ChameleonQueryState`

_No docstring._

```python
from airflow.providers.chameleon.hooks.chameleon import ChameleonQueryState
```

_No constructor arguments._

### `ChameleonHook`

BFF resource methods + a normalized run-status adapter.

```python
from airflow.providers.chameleon.hooks.chameleon import ChameleonHook
```

_No constructor arguments._

### `ChameleonBaseHook`

_No docstring._

```python
from airflow.providers.chameleon.hooks.chameleon_base import ChameleonBaseHook
```

| Argument | Type | Default | Templated |
|---|---|---|---|
| `chameleon_conn_id` | `str` | `'chameleon_default'` |  |
| `workspace` | `str \| None` | `None` |  |
| `timeout_seconds` | `int` | `180` |  |
| `retry_limit` | `int` | `3` |  |
| `retry_delay` | `float` | `1.0` |  |

