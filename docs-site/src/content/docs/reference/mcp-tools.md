---
title: MCP tools
description: The tools/list contract exposed by the platform's MCP server.
sidebar:
  order: 2
---

<!-- GENERATED FILE — do not edit. See docs-site/scripts/gen-mcp-reference.mjs -->

The platform runs an MCP server at `/mcp`. Tools act **as the calling user** —
the verified user token is threaded to each call — so an agent sees exactly the
data its operator is allowed to see, not an admin's view.

**64 tools.**

## `add_workspace_admin`

Promote a workspace administrator. Platform admin only.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `username` | string | yes | Keycloak username to add to the workspace admin group. |

## `add_workspace_member`

Add a member. Workspace admin or platform admin.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `username` | string | yes | Keycloak username to add to the workspace member group. |

## `attach_catalog`

Attach an existing catalog to a workspace. Platform admin only.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `catalog_name` | string | yes | Catalog to attach, from list_attachable_catalogs. |

## `cancel_dbt_run`

Cancel an in-flight dbt run in a workspace you belong to. No-op if already finished.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace that owns the dbt run. |
| `run_id` | string | yes | dbt run id returned by run_dbt_project / list_dbt_runs. No-op if the run already finished. |

## `create_branch`

Create a local git branch in a project's working tree.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `project_id` | string | yes | Project id from list_projects. |
| `branch_name` | string | yes | New branch name, e.g. 'feature/add-orders-model'. |

## `create_namespace`

Create a namespace through the platform API. Properties is a JSON object.

| Argument | Type | Required | Description |
|---|---|---|---|
| `namespace` | string | yes | Namespace (schema) to create, e.g. 'analytics_db'. |
| `properties` | string | no | JSON object of Iceberg namespace properties, e.g. '{"owner": "team-a"}'. |
| `catalog_name` | string | no | Catalog to create it in. Defaults to the session's catalog; pass a workspace catalog such as 'ws_team_a' to be explicit. |

## `create_project`

Create a project (kind 'dbt' or 'notebook') in a workspace. Requires workspace admin.
visibility is 'shared' or 'personal'. dbt_config is an optional JSON object string.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `kind` | string | yes | Project type: 'dbt' or 'notebook'. |
| `name` | string | yes | Project name, unique within the workspace. |
| `visibility` | string | no | 'shared' (all workspace members) or 'private' (creator only). |
| `connection_id` | string | no | Connection to run against, from list_connections. Required for dbt projects that will execute. |
| `dbt_config` | string | no | JSON object of dbt settings, e.g. target schema. Ignored for notebook projects. |

## `create_schedule`

Create a new schedule owned by the calling user.

Cron must be a 5-field expression (minute hour dom month dow).
Translation of plain English ("every weekday at 9am") into
cron is the agent's responsibility — see the schedule-assistant
flow's system prompt.

``job_type`` selects the runner shape:
- ``langflow``: ``target_id`` = flow id;
  ``target_config`` = ``{"message": "...", "context": {...}?}``
- ``dbt``: ``target_id`` = project id;
  ``target_config`` = ``{"models": [...], "full_refresh": false}``
- ``dq``: ``target_id`` = contract id;
  ``target_config`` = ``{"scope": "full"|"incremental"}``

``notify_targets`` is a list of HTTPS / mailto URIs to alert
on the ``notify_on`` condition (``always`` / ``failure`` /
``success``). Empty list means "don't notify".

Returns the created schedule (including the generated id) so
the agent can quote it back to the user for confirmation.

| Argument | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Human-readable schedule name, unique for the owner. |
| `cron_expression` | string | yes | Five-field cron expression, e.g. '0 6 * * *' for 06:00 daily. |
| `job_type` | string | yes | What to run, e.g. 'dbt', 'query' or 'flow'. Determines how target_id is interpreted. |
| `target_id` | string | yes | Identifier of the thing to run — a dbt project id, saved query id or flow id, depending on job_type. |
| `target_config_json` | string | no | JSON object of job-specific options, e.g. '{"command": "run"}' for dbt. |
| `description` | string | no | Optional free-text description. |
| `timezone_str` | string | no | IANA timezone the cron expression is evaluated in, e.g. 'Europe/Amsterdam'. Affects daylight-saving behaviour. |
| `enabled` | boolean | no | If false, the schedule is created but does not fire until enabled. |
| `notify_targets_json` | string | no | JSON array of notification targets, e.g. '["user@example.com"]'. |
| `notify_on` | string | no | When to notify: 'failure', 'success' or 'always'. |

## `create_workspace`

Create or reconcile a workspace. Platform admin only.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | URL-safe workspace slug, e.g. 'team-a'. Its catalog is derived as 'ws_team_a'. |
| `display_name` | string | yes | Human-readable workspace name. |
| `description` | string | no | Optional free-text description. |

## `delete_project`

Delete a project and its on-disk working tree. IRREVERSIBLE. Requires workspace admin.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `project_id` | string | yes | Project id from list_projects. Its on-disk working tree is deleted too — irreversible. |

## `delete_schedule`

Delete a schedule the caller owns. Idempotent: re-deleting
a missing row returns ``deleted=false`` rather than erroring,
so the agent's retry on a flaky network is safe.

| Argument | Type | Required | Description |
|---|---|---|---|
| `schedule_id` | string | yes | Schedule id from list_schedules. Must be one you own. |

## `delete_workspace`

Delete a workspace and its owned data. Run deletion preflight first.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Slug of the workspace to delete. |
| `force` | boolean | no | Delete the workspace row even when teardown steps (grant revocation, IdP group deletion, Polaris catalog deletion) fail. Without it a partial failure returns 409 and leaves the row in status=error. |

## `describe_table`

Get column names, types, and descriptions for a table. Pass catalog_name for tables outside the platform default catalog (e.g. workspace catalogs like ws_team_a).

| Argument | Type | Required | Description |
|---|---|---|---|
| `namespace` | string | yes | Namespace (schema) containing the table. |
| `table` | string | yes | Table or view to inspect. |
| `catalog_name` | string | no | Catalog containing the table. Defaults to the session's catalog. |

## `detach_catalog`

Detach a shared catalog from a workspace. Platform admin only.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `catalog_name` | string | yes | Shared catalog to detach, from list_workspace_catalogs. A workspace's own primary catalog cannot be detached — deprovision the workspace instead. |

## `drop_namespace`

Drop an empty namespace through the platform API.

| Argument | Type | Required | Description |
|---|---|---|---|
| `namespace` | string | yes | Namespace (schema) to drop. Must already be empty. |
| `catalog_name` | string | no | Catalog to target. Defaults to the session's catalog; pass a workspace catalog such as 'ws_team_a' to be explicit. |

## `drop_table`

Drop a table through the platform API.

| Argument | Type | Required | Description |
|---|---|---|---|
| `namespace` | string | yes | Namespace (schema) containing the table. |
| `table` | string | yes | Table to drop. |
| `purge` | boolean | no | If true, also delete the underlying data files. Destructive and not recoverable; false only removes the catalog entry. |
| `catalog_name` | string | no | Catalog containing the table. Defaults to the session's catalog. |

## `get_anomalies`

Get active data quality anomalies across contracts.

| Argument | Type | Required | Description |
|---|---|---|---|
| `domain` | string | no | Restrict to one business domain; empty means every domain. |
| `time_range_hours` | integer | no | Only report anomalies whose run started within this many hours. The detection baseline is unaffected — it always spans the last 50 quality runs, so a short window still compares against full history instead of returning nothing. |

## `get_contract`

Get a data contract by ID. Returns schema, quality rules, SLAs, owner.

| Argument | Type | Required | Description |
|---|---|---|---|
| `contract_id` | string | yes | Data-contract row id from list_contracts (the `id`, not the URN). |

## `get_dbt_run`

Get the status and logs of a dbt run.

``status`` is one of ``pending`` / ``running`` / ``success`` /
``failed`` / ``cancelled`` (the first two are non-terminal — keep
polling). ``log_output`` is populated once the run is terminal. You may
only read runs in workspaces you belong to.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace that owns the dbt run. |
| `run_id` | string | yes | dbt run id returned by run_dbt_project / list_dbt_runs. |

## `get_diff`

Return the git diff of uncommitted changes in a project's working tree.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `project_id` | string | yes | Project id from list_projects. |

## `get_flow`

Get an AI flow's metadata (name, description, type, category) by id.

| Argument | Type | Required | Description |
|---|---|---|---|
| `flow_id` | string | yes | Flow id from list_flows. |

## `get_namespace`

Get namespace properties in a catalog.

| Argument | Type | Required | Description |
|---|---|---|---|
| `namespace` | string | yes | Namespace (schema) to act on, dot-separated for nested levels. |
| `catalog_name` | string | no | Catalog to target. Defaults to the session's catalog; pass a workspace catalog such as 'ws_team_a' to be explicit. |

## `get_notebook`

Read one of YOUR notebook documents (.ipynb JSON) by path. Notebooks are personal;
the workspace arg is used only to check your membership.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug, used ONLY for the membership check — notebooks are personal to you. |
| `path` | string | yes | Notebook path from list_notebooks, e.g. 'analysis/eda.ipynb'. |

## `get_project`

Get a project's metadata (kind, name, visibility) by id, within a workspace you belong to.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `project_id` | string | yes | Project id from list_projects. |

## `get_quality_status`

Get the latest quality check results for a table.

| Argument | Type | Required | Description |
|---|---|---|---|
| `catalog_name` | string | yes | Catalog containing the table. Defaults to the session's catalog. |
| `namespace` | string | yes | Namespace (schema) containing the table. |
| `table` | string | yes | Table to report on. |

## `get_remote_status`

Return git status vs the remote (ahead/behind/dirty) for a project.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `project_id` | string | yes | Project id from list_projects. |

## `get_table`

Get full table metadata through the platform API.

| Argument | Type | Required | Description |
|---|---|---|---|
| `namespace` | string | yes | Namespace (schema) containing the table. |
| `table` | string | yes | Table to inspect. |
| `catalog_name` | string | no | Catalog containing the table. Defaults to the session's catalog. |

## `get_table_snapshots`

Get recent snapshots for a table through the platform API.

| Argument | Type | Required | Description |
|---|---|---|---|
| `namespace` | string | yes | Namespace (schema) containing the table. |
| `table` | string | yes | Table to inspect. |
| `limit` | integer | no | Maximum number of snapshots to return, newest first. |
| `catalog_name` | string | no | Catalog containing the table. Defaults to the session's catalog. |

## `git_commit`

Commit the project's working-tree changes LOCALLY (does not push). Returns the commit sha.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `project_id` | string | yes | Project id from list_projects. |
| `message` | string | yes | Commit message. |

## `git_pull`

Pull the latest from the remote. WARNING: discards uncommitted local changes
(git reset --hard && clean) before pulling.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `project_id` | string | yes | Project id from list_projects. Its uncommitted changes are discarded before the pull. |

## `git_push`

Push committed changes to the external remote. Requires workspace admin (irreversible, external).

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `project_id` | string | yes | Project id from list_projects. Its committed changes go to the external remote. |

## `grant_table_access`

Grant data access via Apache Ranger (the authoritative data-access backend).

Two modes. Normal: pass `privilege` — SELECT, INSERT, MODIFY, ALTER, MONITOR,
CREATE, `CREATE NAMESPACE` (aka `CREATE SCHEMA`), `CREATE VIEW`, DROP, USE,
MANAGE, ALL — which expands into one policy per resource level so the grantee can
actually reach the table. Advanced: pass `access_types` (exact polaris service-def
names) with `level` (catalog|namespace|table) for precise control and no expansion.

Prefer INSERT over MODIFY for pipelines that only append or update rows: MODIFY
additionally allows repointing the table at different storage.

`grant_option` is SQL WITH GRANT OPTION — it lets the grantee re-grant and revoke
this privilege. Off by default; holding a privilege never implies being able to
grant it.

namespace and table are optional: omit them for a catalog-level grant. grantee_type
is USER, ROLE, or GROUP. The grant is authorized by Ranger against YOUR identity,
so you can only grant what you are permitted to grant.

| Argument | Type | Required | Description |
|---|---|---|---|
| `catalog` | string | yes | Catalog the grant applies to, e.g. 'main_warehouse' or a workspace catalog 'ws_team_a'. |
| `grantee` | string | yes | Identity receiving the grant: a username when grantee_type is USER, or a role name when ROLE. |
| `namespace` | string \| null | no | Namespace (schema) to scope the grant to. Omit to grant at catalog level. |
| `table` | string \| null | no | Table to scope the grant to. Requires namespace. Omit to grant at namespace level. |
| `grantee_type` | string | no | USER or ROLE. Prefer ROLE for teams — Keycloak groups map to Ranger roles of the same name. |
| `privilege` | string | no | SQL-style privilege: SELECT, MODIFY, CREATE, DROP, USE, MANAGE or ALL. |
| `access_types` | array \| null | no | Ranger access types, as an escape hatch when 'privilege' does not express what you need. Leave unset to derive them from 'privilege'. |
| `level` | string \| null | no | Resource level to write the policy at when it cannot be inferred from namespace/table. Load-bearing: the wrong level silently widens or narrows the grant. |
| `grant_option` | boolean | no | If true, the grantee may re-grant this privilege to others (Ranger delegateAdmin). |

## `investigate_quality_drop`

Root cause analysis for a quality score drop.

| Argument | Type | Required | Description |
|---|---|---|---|
| `contract_id` | string | yes | Data-contract row id from list_contracts (the `id`, not the URN). Needs at least two quality runs. |

## `list_attachable_catalogs`

List catalogs available to attach. Platform admin only.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug the catalogs would be attached to. |

## `list_contracts`

List all data contracts, optionally filtered by domain or namespace.

| Argument | Type | Required | Description |
|---|---|---|---|
| `domain` | string | no | Restrict to one business domain; empty means every domain. |
| `namespace` | string | no | Restrict to contracts on tables in this namespace (exact match, e.g. 'sales.raw'); empty string means every namespace. |

## `list_dbt_runs`

List recent dbt runs for a project, newest first (excludes logs).

Spans every run on the project's persistent tree (all users). Use
``get_dbt_run(run_id)`` for a single run's logs. ``limit`` is clamped to
1–200.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `project_id` | string | yes | dbt project id from list_projects. |
| `limit` | integer | no | Max runs to return, newest first (1-200). |

## `list_files`

List the file tree of a project's working tree.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `project_id` | string | yes | Project id from list_projects. |

## `list_flows`

List the AI flows (Langflow assistants) available to you.

Each flow has a ``type`` of ``system`` (platform-provided, e.g. the
Platform Assistant) or ``user`` (custom). Use a flow's ``id`` with
``run_flow``. Pass ``flow_type='system'`` or ``'user'`` to filter.

| Argument | Type | Required | Description |
|---|---|---|---|
| `flow_type` | string | no | Filter: 'system', 'user', or '' for all flows. |

## `list_namespaces`

List all namespaces (data domains) in a catalog. Call this first to discover available data. catalog_name selects which catalog to list (e.g. a workspace catalog like ws_team_a); omit it for the platform default catalog.

| Argument | Type | Required | Description |
|---|---|---|---|
| `catalog_name` | string | no | Catalog to target. Defaults to the session's catalog; pass a workspace catalog such as 'ws_team_a' to be explicit. A workspace's namespaces look empty if you leave it at the default. |

## `list_notebooks`

List YOUR notebook documents (notebooks are personal, keyed to your user).
The workspace arg is used only to check your membership.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug, used ONLY for the membership check — notebooks are personal, so this does not scope results. |

## `list_projects`

List the projects in a workspace you belong to.

Projects are typed by ``kind`` — ``dbt`` or ``notebook``. Pass
``kind="dbt"`` or ``kind="notebook"`` to filter, or omit for both. Use a
project's ``id`` with ``run_dbt_project`` / ``list_dbt_runs`` (dbt
projects only — notebooks can be listed but not run from here).

``workspace`` is a slug from ``list_workspaces``. Returns shared projects
plus your own personal ones.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces, e.g. 'team-a'. |
| `kind` | string | no | Filter by project kind: 'dbt', 'notebook', or '' for both. |

## `list_quality_issues`

List all failing quality checks across all contracts.

| Argument | Type | Required | Description |
|---|---|---|---|
| `domain` | string | no | Restrict to one business domain; empty means every domain. |

## `list_roles`

List catalog roles through the platform API.

| Argument | Type | Required | Description |
|---|---|---|---|
| `catalog_name` | string | no | Catalog to target. Defaults to the session's catalog; pass a workspace catalog such as 'ws_team_a' to be explicit. |

## `list_schedules`

List schedules owned by the calling user.

``job_type`` filters to one of ``langflow`` / ``dbt`` / ``dq``
when set; pass an empty string to get every type. The agent
usually wants this when the user asks "what schedules do I
have?" or before editing a schedule (so it knows the IDs).

| Argument | Type | Required | Description |
|---|---|---|---|
| `job_type` | string | no | Restrict to one job type, e.g. 'dbt', 'langflow' or 'dq'; empty means every type. |

## `list_tables`

List all tables AND views in a namespace (ontology entities are views). IMPORTANT: namespaces live inside a catalog — pass catalog_name (e.g. ws_team_a, team_a_data; see the page context's platform key) or the platform default catalog is assumed and workspace namespaces will look empty.

| Argument | Type | Required | Description |
|---|---|---|---|
| `namespace` | string | yes | Namespace (schema) to list, from list_namespaces. |
| `catalog_name` | string | no | Catalog to target. Defaults to the session's catalog; pass a workspace catalog such as 'ws_team_a' to be explicit. A workspace's namespaces look empty if you leave it at the default. |

## `list_workspace_catalogs`

List catalogs owned by or attached to a workspace.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |

## `list_workspace_members`

List workspace members and administrators.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |

## `list_workspaces`

List the workspaces (tenants) you are a member of.

Each workspace owns an Iceberg catalog and its own dbt projects. Use the
returned ``slug`` as the ``workspace`` argument to the other workspace
tools (``list_projects``, ``run_dbt_project``, ``list_dbt_runs``), and
``primary_catalog`` as the ``catalog_name`` for the discovery tools to
browse that tenant's data.

_No arguments._

## `platform_status`

Check platform connectivity for a catalog and return object counts.

| Argument | Type | Required | Description |
|---|---|---|---|
| `catalog_name` | string | no | Catalog to target. Defaults to the session's catalog; pass a workspace catalog such as 'ws_team_a' to be explicit. |

## `query_data`

Run a SQL query against Iceberg tables. Authorization enforced by Trino + OPA. Use fully qualified names: namespace.table. Max 1000 rows returned.

| Argument | Type | Required | Description |
|---|---|---|---|
| `sql` | string | yes | A single SELECT statement. Use fully qualified namespace.table names; capped at 1000 rows. |

## `read_file`

Read a file from a project's working tree. Returns content + blob_sha (for write_file expected_sha).

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `project_id` | string | yes | Project id from list_projects. |
| `path` | string | yes | Path relative to the project root, e.g. 'models/staging/stg_orders.sql'. Use list_files to discover it. |

## `register_table`

Register an existing Iceberg table through the platform API.

| Argument | Type | Required | Description |
|---|---|---|---|
| `namespace` | string | yes | Namespace (schema) that will contain the table. |
| `table` | string | yes | Table name to register. |
| `metadata_location` | string | yes | Full URI of the existing Iceberg metadata JSON, e.g. 's3://bucket/path/metadata/00001-....metadata.json'. |
| `catalog_name` | string | no | Catalog to register into. Defaults to the session's catalog. |

## `remove_workspace_admin`

Demote a workspace administrator. Platform admin only.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `username` | string | yes | Keycloak username to demote, from the `admins` list in list_workspace_members. |

## `remove_workspace_member`

Remove a member. Workspace admin or platform admin.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `username` | string | yes | Keycloak username to remove, from list_workspace_members. |

## `revoke_table_access`

Revoke a privilege on a table from a Ranger user/role (group). Writes to Apache Ranger.

| Argument | Type | Required | Description |
|---|---|---|---|
| `catalog` | string | yes | Catalog the revoke applies to. |
| `grantee` | string | yes | Identity losing the grant: a username when grantee_type is USER, or a role name when ROLE. |
| `namespace` | string \| null | no | Namespace (schema) the grant was scoped to. Must match how it was granted. |
| `table` | string \| null | no | Table the grant was scoped to. Must match how it was granted. |
| `grantee_type` | string | no | USER or ROLE — must match the original grant. |
| `privilege` | string | no | Privilege to remove: SELECT, MODIFY, CREATE, DROP, USE, MANAGE or ALL. |
| `access_types` | array \| null | no | Explicit Ranger access types to remove, instead of deriving them from 'privilege'. |
| `level` | string \| null | no | Resource level the policy was written at, when it cannot be inferred from namespace/table. |

## `run_dbt_project`

Trigger a dbt build against a project's persistent tree.

``command`` is one of ``run`` / ``compile`` / ``seed`` / ``test``.
``models`` is an optional space- or comma-separated dbt selector list
(empty = all models; ignored for compile/seed). The run is asynchronous:
this returns ``{id, command, status}`` where status is usually
``pending`` or ``running`` — poll ``get_dbt_run(run_id)`` until it
reaches a terminal status (``success`` / ``failed`` / ``cancelled``).
Runs on the same project are serialized; different projects run in
parallel.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `project_id` | string | yes | dbt project id from list_projects (must be kind='dbt'). |
| `command` | string | no | One of: run, compile, seed, test. |
| `models` | string | no | Optional dbt selector list, space- or comma-separated; empty = all models. Ignored for compile/seed. |
| `full_refresh` | boolean | no | Pass --full-refresh (run only). |

## `run_flow`

Run an AI flow with a message and get its final answer.

The flow reasons server-side (Langflow) and may call other platform
tools on your behalf. The streamed response is aggregated into a single
``text`` result; ``session_id`` is returned so you can continue the
conversation. Use ``list_flows`` to discover flow ids.

| Argument | Type | Required | Description |
|---|---|---|---|
| `flow_id` | string | yes | Flow id from list_flows. |
| `message` | string | yes | The prompt to send to the flow. |
| `session_id` | string | no | Continue a prior conversation; omit to start fresh. |
| `persona` | string | no | Optional persona hint (query/dbt/insights/...); omit for auto. |

## `show_workspace`

Show a workspace and its catalog bindings. Members and platform admins only.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |

## `suggest_contract_improvements`

Analyze a contract for completeness and suggest improvements.

| Argument | Type | Required | Description |
|---|---|---|---|
| `contract_id` | string | yes | Data-contract row id from list_contracts (the `id`, not the URN). |

## `update_contract`

Replace a contract's YAML.

``contract_id`` is the row UUID returned by ``get_contract``.
``yaml_content`` must be a complete ODCS document — partial
diffs aren't supported because the editor and the AI both
submit the full property list. The platform service replaces
the property set wholesale, validates against ODCS, and
appends an audit row to the platform-wide audit_log.

The ``info.contractId`` (the URN) must match the existing
row's contract_id; changing it would silently break
downstream consumers (dbt sources, OPA tags, scheduler
target_id) that lock on it. Submit only edits to
schema/quality/SLA/team/description fields.

Returns the updated contract row (with properties joined
in) on success, or a tool_error when the row doesn't exist
or the YAML fails ODCS validation.

| Argument | Type | Required | Description |
|---|---|---|---|
| `contract_id` | string | yes | Data-contract row id from list_contracts (the `id`, not the URN). |
| `yaml_content` | string | yes | Complete ODCS document. Partial diffs are not supported — the property set is replaced wholesale, and info.contractId must match the existing row's. |

## `update_project`

Update a project's name/connection/default_branch/dbt_config. Requires workspace admin.
Empty string args are left unchanged. dbt_config is an optional JSON object string.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `project_id` | string | yes | Project id from list_projects. |
| `name` | string | no | New project name. Leave empty to keep the current one. |
| `connection_id` | string | no | New connection id. Leave empty to keep the current one. |
| `default_branch` | string | no | Git branch used when none is specified, e.g. 'main'. |
| `dbt_config` | string | no | Replacement JSON object of dbt settings. Leave empty to keep the current one. |

## `update_schedule`

Update fields on an existing schedule the caller owns.

``fields_json`` is a JSON object with any subset of:
``name``, ``description``, ``cron_expression``, ``timezone``,
``enabled``, ``notify_targets``, ``notify_on``,
``target_config``. Unknown keys are rejected by the
repository's whitelist.

Returns the updated schedule on success.

| Argument | Type | Required | Description |
|---|---|---|---|
| `schedule_id` | string | yes | Schedule id from list_schedules. Must be one you own. |
| `fields_json` | string | yes | JSON object with any subset of: name, description, cron_expression, timezone, enabled, notify_targets, notify_on, target_config. Unknown keys are rejected. |

## `workspace_deletion_preflight`

Preview destructive workspace deletion. Platform admin only.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |

## `write_file`

Write a file in a project's working tree. Pass expected_sha (from read_file) for
optimistic-concurrency; omit to force-write.

| Argument | Type | Required | Description |
|---|---|---|---|
| `workspace` | string | yes | Workspace slug from list_workspaces. |
| `project_id` | string | yes | Project id from list_projects. |
| `path` | string | yes | Path relative to the project root, e.g. 'models/staging/stg_orders.sql'. |
| `content` | string | yes | Full new file content. This replaces the file rather than patching it. |
| `expected_sha` | string | no | SHA returned by read_file, for optimistic concurrency. If it no longer matches the write is rejected instead of clobbering someone else's change. |
