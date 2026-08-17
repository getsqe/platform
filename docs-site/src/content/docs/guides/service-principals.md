---
title: System access with service principals
description: Identities for systems, not for people — and why giving a person one defeats per-user authorization.
sidebar:
  order: 3
---

:::danger[A service principal is not how you give a person access]
If a human needs data, grant it to **their own identity** and let them
authenticate normally. Per-user authorization is the point of this platform: the
end user's identity travels browser → BFF → engine → catalog → Ranger, so grants,
row filters and audit all name the actual person.

Hand someone a service principal and every one of those properties is lost at
once. The audit trail says `reporting-tool`, not who ran the query; the grant
covers everyone holding the secret; and revoking one person means rotating a
credential shared by all of them. It also cannot be scoped per person, because
there is only one identity.

The preferred model is **user → principal, group → role**: identity comes from the
IdP and the platform mirrors it onto the data plane. Service principals are fully
supported and can be created or granted like any other identity — an existing IdP
client can be granted directly — but they are the second choice, for when there is
no person.

Use [Workspaces and access](/docs/guides/workspaces-and-access/) for people, and the
[identity model](/docs/concepts/identity/#the-identity-model) for how the mapping works.
Use this page for systems.
:::

A **service principal** is a **system** identity: a Keycloak confidential client
using the `client_credentials` grant, with its own least-privilege Ranger
policies. It exists for the case where there is genuinely no person present — an
engine, a scheduler, an external pipeline.

## Prefer generating them over creating them by hand

The healthy pattern is that a service principal is **provisioned as part of
standing up a system**, not created ad hoc when someone needs access. The
platform already does this:

- **engines** get theirs at bootstrap. On a running stack the only service
  identities holding Ranger policies are `chameleon-svc` (control plane) and
  `service-account-spark-service-client` (the Spark path) — two systems, no
  people.
- **per-workspace system integrations** get one from a provisioning script.
  `quickstart/sqe/scripts/provision-airflow-tenant.sh <slug>` mints a
  workspace-bound principal, registers the matching Airflow connection and
  creates the per-workspace role, in one step.

If you find yourself creating principals one at a time, that is the signal to
write the provisioning step instead — it keeps the naming, the catalog scoping and
the least-privilege mode consistent, and it means the credential has an owner.

Two properties make a generated principal safer than a hand-made one:

- **`served_catalogs` is required** and explicit, so a principal cannot silently
  end up scoped to every catalog.
- **`mode: "read"`** produces read access types only — no admin, principal or
  policy verbs. A read-only principal genuinely cannot escalate.

## Create one

```sh frame="terminal"
curl -X POST "$API/service-principals" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
        "name": "reporting-tool",
        "served_catalogs": ["main_warehouse"],
        "mode": "read",
        "credential_mode": "vended",
        "authorizer": "ranger"
      }'
```

```json
{
  "name": "reporting-tool",
  "keycloak_client_id": "reporting-tool",
  "client_secret": "…",
  "audience": ["sqe", "account"],
  "authorization_ready_in_seconds": 60,
  "note": "The client secret is shown only once — store it securely now."
}
```

The secret really is shown once. `POST /service-principals/{name}/rotate-secret`
issues a new one if it is lost.

## What gets created

Three planes, in one call:

| Plane | What appears |
|---|---|
| Keycloak | a confidential client with `client_credentials` enabled |
| Catalog | a principal with the same name |
| Ranger | **three** policies — one per resource level |

The three Ranger policies matter when you go looking for them:

```
policy 22  root=*, catalog=main_warehouse                    → catalog-list, catalog-properties-read
policy 23  root=*, catalog=main_warehouse, namespace=*       → namespace-list, namespace-properties-read
policy 24  root=*, catalog=main_warehouse, namespace=*, table=*
                                                             → table-data-read, table-list, table-properties-read
```

Ranger permits only one policy per distinct resource map, which is why the grant
is split this way. **Inspecting one policy proves nothing** — union the access
types across all policies naming the principal. An e2e check that read only the
first of the three spent time reporting a read-gate failure that did not exist.

## Use it

```sh frame="terminal"
curl -s -X POST "$KEYCLOAK/realms/example/protocol/openid-connect/token" \
  -d grant_type=client_credentials \
  -d "client_id=reporting-tool" \
  -d "client_secret=$SECRET"
```

Then present the token as a bearer to the catalog or an engine.

:::caution[Wait for the grant]
`authorization_ready_in_seconds` is not decoration. Ranger's plugin polls roughly
every five seconds, so a call made immediately after creation can return **403**
even though everything is configured correctly. Observed sequence on a fresh
principal: `403`, then `200` about eight seconds later. Retry before diagnosing.
:::

## The identity trap

This is the one thing to understand about service principals.

A `client_credentials` token carries **two different names**:

```
azp                = reporting-tool                   ← the client id
preferred_username = service-account-reporting-tool   ← Keycloak's service-account user
```

The catalog resolves the principal from `preferred_username`. Provisioning
therefore has to force that claim to the bare name, and it does — but the
mechanism is worth knowing, because it failed silently in the past:

- a hardcoded-claim mapper alone is **not** enough. Keycloak's default `profile`
  client scope contributes a built-in `username` → `preferred_username` mapper
  that *wins* the merge.
- renaming the service-account user is rejected on Keycloak 26+
  (`error-user-attribute-read-only`).

The fix is to detach the `profile` scope from service-principal clients so the
hardcoded mapper is the only writer. If a service principal ever returns **401**
with nothing obviously wrong, decode its token first — this is the cause.

See [Identity](/docs/concepts/identity/) for the full picture.

## Delete

Deletion removes the identity from all three planes:

```sh frame="terminal"
curl -X DELETE "$API/service-principals/reporting-tool" -H "Authorization: Bearer $ADMIN_TOKEN"
```
