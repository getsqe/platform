---
title: Workspaces and access
description: Create a workspace, grant a user access to a table, and prove that another user is denied.
sidebar:
  order: 2
---

:::tip[Grant to people, not to credentials]
Everything on this page grants to a **user or a group**. That is deliberate and it
is the normal path — the end user's identity reaches Ranger, so the grant, any row
filter, and the audit record all name the actual person.

Reach for a [service principal](/guides/service-principals/) only when there is no
person: an engine, a scheduler, an external pipeline. Giving a human one collapses
per-user authorization into a shared secret.
:::

A **workspace** is the unit of tenancy. Creating one provisions a dedicated
catalog, the Keycloak groups that back its admin and member roles, and the Ranger
roles those groups map to.

## Create a workspace

```sh frame="terminal"
chameleon workspace create team-a --name "Team A"
```

The catalog is named after the slug with hyphens replaced: `team-a` becomes
`ws_team_a`. Worth knowing, because that is the name you use in SQL.

```sh frame="terminal"
chameleon data query --engine flight "SHOW SCHEMAS FROM ws_team_a"
```

## Grant access to a user

Grants are written to Ranger and enforced against the **end user**, not against
the service the query happens to travel through.

```sh frame="terminal"
chameleon access grant --user analyst \
  --catalog ws_team_a --namespace sales --table orders --privilege SELECT
```

Then check what an identity actually holds:

```sh frame="terminal"
chameleon access show --user analyst
```

:::caution[Grants are not instant]
Ranger's plugin polls roughly every five seconds. A read attempted immediately
after a grant can legitimately return 403. Retry before concluding the grant
failed — a single immediate probe is the most common source of false negatives
when testing access control.
:::

## Prove the denial

A grant you have not seen fail is not a grant you have tested. Query the same
table as a user who was not granted it:

```sh frame="terminal"
chameleon login -u other-user -p "$OTHER_PASSWORD"
chameleon data query --engine flight "SELECT count(*) FROM ws_team_a.sales.orders"
```

:::caution[A denial may not look like one]
The catalog fails closed, so an unauthorized read can surface as **table not
found** rather than a permission error. Treat a missing row count as *denied*,
not as *absent* — and confirm the table exists as an admin before drawing any
conclusion from a 404. `verify-polaris-oidc-roles.sh` encodes exactly this rule.
:::

## Groups and roles

Granting to every user individually does not scale. Keycloak groups map to Ranger
**roles** of the same name, so a grant to a role covers everyone in the group.

Two halves are required and they fail differently:

1. the role must exist and hold the grant;
2. the role's **membership** must be synced from Keycloak.

With the policy but no membership, the role matches nobody and every member is
denied — with no error anywhere to explain it. If a group grant appears to do
nothing, check membership first.

## Revoking

```sh frame="terminal"
chameleon access revoke --user analyst \
  --catalog ws_team_a --namespace sales --table orders --privilege SELECT
```

:::danger[A revoke may not take effect immediately on a running engine]
Ranger's state is correct the moment the revoke returns. But an engine holding a
per-user metadata cache can keep serving a table the user has **already read**,
for as long as that cache lives. A table the user has never read is correctly
denied.

Verify a revoke against Ranger, not against the engine. If you need certainty on
a running stack, restart the engine. This is a known open defect on the engine
side, not a misconfiguration.
:::

## Tear down

Deprovisioning removes the workspace, its catalog and its groups.

```sh frame="terminal"
chameleon workspace delete team-a --yes
```
