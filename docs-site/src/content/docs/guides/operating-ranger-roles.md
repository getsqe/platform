---
title: Keeping Ranger tidy
description: Why deleted workspaces leave empty Ranger roles behind, and how to prune them safely.
sidebar:
  order: 4
---

Deleting a workspace does not delete its Ranger roles. That is deliberate, and
knowing why saves you from treating it as a leak.

## What deprovision actually does

When a workspace is deprovisioned the platform revokes its grants, deletes the
Keycloak groups, and then **empties** the Ranger roles those groups had
materialised — rather than deleting them. The code says why:

> Empty the Ranger roles that group_sync materialised for these groups. The
> Keycloak groups are now gone but the Ranger roles are not — leaving stale
> membership that a same-slug recreate would inherit.

Emptying is the half that matters for security, and it works: **an empty role
matches nobody**. Recreating a workspace with the same slug therefore starts with
no inherited members.

What is missing is only the tidy-up. The platform's Ranger client can ensure a
role exists and keep it in sync, but has no delete operation — so the empty
shells accumulate. On the stack this was written against, **32 of 36**
workspace-shaped roles belonged to workspaces that no longer existed.

That is noise, not exposure. It makes role listings hard to read and makes a real
problem harder to spot.

## Prune them

```sh frame="terminal"
cd quickstart/sqe
bash scripts/prune-orphan-ranger-roles.sh            # report only
bash scripts/prune-orphan-ranger-roles.sh --apply    # delete
```

A role is deleted only when **both** hold: its slug is not in the live workspace
list, **and** it has no users and no groups.

## A role with members is a finding, not litter

The script reports non-empty orphans and refuses to touch them:

```
LEFT ALONE ws-example-admins (users=1, groups=0) — deprovision did not run; investigate
```

An orphaned role that still has members means the workspace did not go through
deprovision — someone deleted the row directly, or teardown failed partway. That
is worth understanding before it is tidied away, because those members still
match if a policy references the role.

## The trap this script exists to avoid

:::danger[An empty workspace list means "cannot tell", not "nothing is live"]
The obvious implementation — list workspaces, list roles, delete anything whose
slug is not in the list — is dangerous, because the failure mode of the first
step is an **empty list**.

An expired CLI session makes `workspace list` return an error. Parse that
leniently and you get zero workspaces, at which point *every* role looks orphaned
and the script deletes the roles of every live workspace.

This is not hypothetical: it happened while this page was being written. The
first classification reported "live workspaces: none" and 33 deletable roles;
there were in fact two live workspaces, and four of those roles were theirs.

The script therefore re-authenticates unconditionally and **aborts** if the
workspace list cannot be read, rather than treating an empty result as an answer.
:::

## Related

Workspace deprovision also leaves the workspace's **namespaces** in place, and
does not delete S3 buckets — the latter is documented as requiring an operator
action. Neither is covered by this script.
