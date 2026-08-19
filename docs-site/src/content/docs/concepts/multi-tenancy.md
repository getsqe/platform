---
title: Tenancy and isolation
description: What a workspace separates, which layer actually enforces it, and where the isolation is soft.
sidebar:
  order: 2
---

Several teams share one platform. This page is about what keeps them apart — and,
just as importantly, which parts only *look* like they do.

## A tenant is a workspace

A workspace is the unit teams are given. Creating one produces a set of objects
named after its slug, so what belongs to whom is legible from the name:

| Object | Name | Purpose |
|---|---|---|
| Catalog | derived from the slug | the tables the workspace owns |
| Storage | `ws-<slug>`, `ws-<slug>-staging` | where those tables live |
| Admin group | `ws-<slug>-admins` | who may manage the workspace |
| Member group | `ws-<slug>-members` | who may use it |

A catalog belongs to **one** workspace. That single rule is what makes the rest
coherent: a workspace-scoped page needs no catalog picker, a query needs no
qualifier to find the right warehouse, and a grant has an unambiguous owner. See
[the platform model](/docs/concepts/platform-model/) for what else follows from it.

## Three layers, only one of which is a boundary

It is worth being precise about which layer stops what, because two of the three
are organisational and will not hold against someone who goes around the UI.

**1. Scoping — where things appear.** Workspace pages live under `/ws/<slug>/…`,
and API calls carry the workspace in an `X-Workspace` header. This decides what a
person is *shown*. It is not a security boundary: it shapes the request, and the
server still has to decide whether to honour it.

**2. Membership — who may act.** Membership of the two Keycloak groups decides who
reaches a workspace at all and who may administer it. A workspace admin manages
their own members, and their access-control page is pinned to their own catalog —
they cannot grant on someone else's, and the server enforces that rather than
trusting the UI. Sharing a catalog *between* workspaces is possible, but it is a
platform-admin action and deliberately not the default.

**3. Data access — what the engine returns.** The real boundary. Every query is
authorized by Apache Ranger against the **end user** who ran it, at whatever point
in the path holds their identity. Membership of a workspace gets you to the page;
it is the grant that returns rows. See [access control](/docs/concepts/access-control/).

The practical consequence: if you want to know whether two teams are actually
separated, do not read the workspace list. Read the grants, and the audit trail of
what was allowed.

## Where the isolation is soft

Stated plainly, because the alternative is finding out later.

**Airflow is soft multi-tenancy.** Teams map to Airflow roles and see their own
DAGs, and each workgroup gets its own service principal so its DAGs are authorized
by Ranger like any other identity. But the scheduler and the metadata database are
shared. Hard isolation would mean one Airflow per tenant. Reach for it last — see
[making work happen](/docs/concepts/orchestration/).

**Not every engine path carries the end user.** Per-user enforcement needs the
user's identity to survive as far as the decision point, and not every path keeps
it in the same place. Where it does not, the enforcement point moves rather than
disappears — the same Ranger, consulted somewhere else. Which engine does what is
in [engines](/docs/concepts/engines/), and it matters most when you are debugging why
someone can or cannot see something.

**Anything that runs as a service identity is not the user.** Scheduled and
triggered work runs under an identity of its own. That identity should be scoped to
the workspace it serves, which is what the provisioning path does by default — but
it is a separate identity with separate grants, and it will keep working after the
person who created the job loses access.

## Checking it rather than assuming it

Three habits that catch the failures this design can still produce:

- **Read effective access, not intent.** A grant that exists is not a grant that
  resolves. The access surface can list what a specific principal actually has.
- **Watch for the confident empty result.** A page showing no tables can mean "you
  have no grant" just as easily as "there is nothing here", and neither logs an
  error. If a namespace you expect to be populated looks empty, treat it as an
  authorization question first.
- **Use the audit trail.** It records the decisions, per user, per resource. It is
  the only place that distinguishes "was never asked" from "was asked and denied".
