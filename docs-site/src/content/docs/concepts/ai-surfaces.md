---
title: The AI surfaces
description: The MCP server, Langflow flows and the ontology — three ways an agent reaches this platform, all under the caller's own permissions.
sidebar:
  order: 7
---

There are three AI-facing surfaces here, and they answer different questions. The
property they share is the one that matters: **an agent acts as the person who
called it**, not as an administrator.

| Surface | What it is | Reach it from |
|---|---|---|
| **MCP server** | the platform's tools, exposed to any MCP client | an AI client, the CLI, code |
| **Flows** | server-side assistants built in Langflow | the portal, the CLI, MCP, triggers, schedules |
| **Ontology** | a business vocabulary over your tables | the portal, its own MCP tools |

## The MCP server

The platform runs an MCP server at `/mcp`, exposing several dozen tools —
workspaces, catalogs, namespaces, tables, queries, dbt projects and runs,
schedules, flows, platform status. [The MCP tools
reference](/docs/reference/mcp-tools/) lists every one of them with its arguments, and
is generated from the server itself, so it is the count and contract to trust.

Two things about it are worth understanding before you wire an agent to it:

**It runs as you.** The caller's verified token is threaded through to each tool
call, so an agent sees exactly what its operator is allowed to see. There is no
service account behind it widening the view, and no way to ask it for more than
the caller has been granted — a tool call that exceeds the caller's grants fails
the same way the query would.

**It is a bearer-authenticated, rate-limited HTTP surface.** Treat the token you
give an agent as the credential it is: it carries that user's access, and an agent
holding it can do anything that user could do through any other route.

## Flows

A flow is an assistant that runs server-side. Flows are built in Langflow, and the
platform treats them as first-class objects rather than as something bolted on:
they are listed, run, scheduled and audited like any other work.

- **A system assistant** ships with the platform — it is what the portal's chat
  answers with, and what `chameleon chat` talks to.
- **Your own flows** appear alongside it, visible to whoever you share them with.

Every route reaches the same flows: the portal's chat, `chameleon flow run`,
the MCP tools `list_flows` / `get_flow` / `run_flow`, a
[schedule](/docs/concepts/orchestration/#schedules--run-on-a-clock) on a cron
expression, or a [trigger](/docs/concepts/orchestration/#triggers--run-on-an-event) on
an event. Because the flow reasons server-side and may call other platform tools
while it does, the identity question above applies to it too: it runs on behalf of
the caller, and it can do what the caller can.

## The ontology

The ontology is where a table becomes something a person — or an agent — can ask
about in their own words. You describe entities, their attributes and their
relations, map them onto real tables, and publish a version. Publishing creates
**views**, so an ontology entity is queryable by any engine, not just by the
assistant.

The part that is easy to miss: **publishing changes the tools an agent has.** The
ontology exposes its own MCP surface — separate from the platform server above, at
`/api/platform/v1/ontology/mcp`, bearer-authenticated the same way and likewise
running as the caller — and its per-entity tools (a query and a lookup per entity)
are rebuilt on every publish. An agent's vocabulary therefore follows the published
version rather than lagging behind it, and an entity that was never published is
not something an agent can be asked about.

The ontology is versioned for the same reason: a published vocabulary is what other
things depend on, so changing it is a deliberate act rather than an edit.

## What none of this changes

Two boundaries hold regardless of which surface is used:

**Ranger still decides.** Every read an agent performs is authorized against the
calling user, per resource, exactly as if they had typed the query. Adding an AI
surface adds no privilege — which is why granting access to a *person* is the only
step needed to let their agent work, and why revoking it is enough to stop it.

**Feature visibility is advisory, access is not.** Whether a part of the portal is
offered to someone is a product decision that fails open; whether they can read a
table is an authorization decision that fails closed. Do not read the first as
evidence about the second. See [access control](/docs/concepts/access-control/).
