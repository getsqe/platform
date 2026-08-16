---
title: CLI
description: The chameleon command-line interface, generated from its own help output.
sidebar:
  order: 3
---

<!-- GENERATED FILE - do not edit. See docs-site/scripts/gen-cli-reference.mjs -->

The `chameleon` CLI is the supported way to drive the platform from a script.
Every end-to-end test under `quickstart/` goes through it rather than calling the
API directly, which is what keeps this reference exercised rather than aspirational.

```
Usage: chameleon [OPTIONS] COMMAND [ARGS]...

 Chameleon data platform CLI.

Options:
--version             -V        Show version and exit.
--install-completion            Install completion for the current shell.
--show-completion               Show completion for the current shell, to copy it or customize
                                the installation.
--help                          Show this message and exit.

Commands:
login      Authenticate with the data platform.
logout     Log out and remove local session.
version    Show CLI version.
chat       Chat with the platform assistant (server-side system flow).
data       Query and browse data catalogs.
access     Manage data-access grants (Apache Ranger).
admin      Platform administration commands.
workspace  Manage workspaces.
mcp        MCP server tools — list and call MCP tools directly.
project    Manage workspace projects, files, Git, and locks.
notebook   Manage notebook documents, kernels, and runs.
dbt        Manage dbt projects and runs.
mlflow     Manage MLflow experiments, runs, and registered models through the BFF gateway.
flow       Run and manage AI flows (Langflow assistants).
trigger    Manage per-workspace event triggers (ws-admin).
agent      AI agent for conversational data exploration.
```

## `chameleon access`

```
Usage: chameleon access [OPTIONS] COMMAND [ARGS]...

 Manage data-access grants (Apache Ranger).

Options:
--help          Show this message and exit.

Commands:
grant   Grant data access.
revoke  Revoke data access (mirror of grant).
show    List grants, optionally filtered. Reads them back from Ranger.
audit   Report Ranger policies earlier, narrower writers left behind.
```

## `chameleon admin`

```
Usage: chameleon admin [OPTIONS] COMMAND [ARGS]...

 Platform administration commands.

Options:
--help          Show this message and exit.

Commands:
audit      Audit logs.
bootstrap  Run supported platform bootstrap operations.
catalog    Manage catalogs.
grant      Manage grants.
health     Health checks and system validation.
namespace  Manage namespaces.
policy     Manage policies.
preview    Preview table data.
role       Manage roles.
storage    Manage storage buckets.
user       Manage users.
warehouse  Manage warehouses.
```

## `chameleon agent`

```
Usage: chameleon agent [OPTIONS] COMMAND [ARGS]...

 AI agent for conversational data exploration.

Options:
--help          Show this message and exit.

Commands:
chat  Chat with your data platform.
```

## `chameleon chat`

```
Usage: chameleon chat [OPTIONS] [MESSAGE]

 Chat with the platform assistant (server-side system flow).

Arguments:
  message      [MESSAGE]  One-shot message; omit for interactive chat.

Options:
--flow               TEXT  Flow id (default: system assistant).
--workspace  -w      TEXT
--session            TEXT  Resume a conversation.
--new                      Start a fresh session.
--help                     Show this message and exit.
```

## `chameleon data`

```
Usage: chameleon data [OPTIONS] COMMAND [ARGS]...

 Query and browse data catalogs.

Options:
--help          Show this message and exit.

Commands:
catalog    Browse catalogs.
namespace  Browse namespaces.
table      Browse tables.
query      Execute SQL queries.
```

## `chameleon dbt`

```
Usage: chameleon dbt [OPTIONS] COMMAND [ARGS]...

 Manage dbt projects and runs.

Options:
--help          Show this message and exit.

Commands:
list    List dbt projects in a workspace.
show    Show a dbt project.
init    Initialize a dbt project from the platform template.
delete  Delete a dbt project.
run     Trigger and inspect dbt runs.
```

## `chameleon flow`

```
Usage: chameleon flow [OPTIONS] COMMAND [ARGS]...

 Run and manage AI flows (Langflow assistants).

Options:
--help          Show this message and exit.

Commands:
list      List AI flows available to you (system and user).
show      Show an AI flow's metadata.
run       Run an AI flow and stream its answer live.
schedule  Schedule AI flows on a cron trigger.
```

## `chameleon login`

```
Usage: chameleon login [OPTIONS]

 Authenticate with the data platform.

Options:
*  --username  -u      TEXT  Username [required]
*  --password  -p      TEXT  Password [required]
   --help                    Show this message and exit.
```

## `chameleon logout`

```
Usage: chameleon logout [OPTIONS]

 Log out and remove local session.

Options:
--help          Show this message and exit.
```

## `chameleon mcp`

```
Usage: chameleon mcp [OPTIONS] COMMAND [ARGS]...

 MCP server tools — list and call MCP tools directly.

Options:
--help          Show this message and exit.

Commands:
tools  List available MCP tools.
test   Connect to MCP server, list all tools, and run each with test data.
call   Call an MCP tool with optional JSON arguments.
```

## `chameleon mlflow`

```
Usage: chameleon mlflow [OPTIONS] COMMAND [ARGS]...

 Manage MLflow experiments, runs, and registered models through the BFF gateway.

Options:
--help          Show this message and exit.

Commands:
experiment  Manage MLflow experiments.
run         Inspect and delete MLflow runs.
model       Manage registered MLflow models.
```

## `chameleon notebook`

```
Usage: chameleon notebook [OPTIONS] COMMAND [ARGS]...

 Manage notebook documents, kernels, and runs.

Options:
--help          Show this message and exit.

Commands:
list       List the caller's notebook documents.
get        Print or save a notebook document.
put        Upload an .ipynb document.
delete     Delete a notebook document.
validate   Validate Python syntax without executing it.
kernel     Manage notebook kernels.
execution  Inspect notebook execution history.
```

## `chameleon project`

```
Usage: chameleon project [OPTIONS] COMMAND [ARGS]...

 Manage workspace projects, files, Git, and locks.

Options:
--help          Show this message and exit.

Commands:
list    List projects visible to the caller.
show    Show a project.
create  Create a notebook or dbt project.
delete  Delete a project.
update  Update project metadata.
file    Manage project files.
git     Run project Git actions.
lock    Manage collaborative project locks.
```

## `chameleon trigger`

```
Usage: chameleon trigger [OPTIONS] COMMAND [ARGS]...

 Manage per-workspace event triggers (ws-admin).

Options:
--help          Show this message and exit.

Commands:
list           List triggers in a workspace.
show           Show a trigger's configuration (secrets masked).
create         Create a trigger. target/source config are JSON objects matching the API.
update         Patch a trigger. Only provided fields are changed.
enable         Enable a trigger (reconciles pollers for sqs).
disable        Disable a trigger (stops its poller for sqs).
delete         Delete a trigger.
connection     Show connection info (events URL + secret) for http/catalog triggers.
rotate-secret  Rotate the Standard Webhooks secret (webhook_secret auth only).
test           Fire a synthetic test event through the trigger (ws-admin).
runs           Recent trigger firings with their outcome (dispatch ledger joined to tasks).
stats          Per-trigger dispatch/outcome counts + a success/fail time series.
```

## `chameleon version`

```
Usage: chameleon version [OPTIONS]

 Show CLI version.

Options:
--help          Show this message and exit.
```

## `chameleon workspace`

```
Usage: chameleon workspace [OPTIONS] COMMAND [ARGS]...

 Manage workspaces.

Options:
--help          Show this message and exit.

Commands:
create               Create or update a workspace (idempotent).
reconcile-grants     Re-apply a workspace's Ranger grants (idempotent).
list                 List workspaces.
show                 Show workspace detail (including bound catalogs).
delete               Deprovision a workspace.
catalogs             List catalogs bound to a workspace.
attach               Attach an existing catalog to the workspace (grants no data access by
                     itself).
detach               Detach a catalog from the workspace.
attachable-catalogs  List catalogs that can be attached to the workspace.
attachable           List catalogs that can be attached to the workspace.
deletion-preflight   Show the resources and data that workspace deletion would remove.
member               Manage workspace members.
admin                Manage workspace administrators.
```
