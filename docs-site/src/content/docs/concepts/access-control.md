---
title: Access control
description: "How a grant becomes an enforced decision, and who decides."
sidebar:
  order: 3
---

{/* GENERATED from docs/access-management.md by docs-site/scripts/gen-concepts-from-repo.mjs.
    Edit that file, not this one. */}

How data-access grants are authored, stored, and enforced on the platform.
This is the reference for operators, integrators (Terraform/MCP/CLI), and
developers working on the authorization layer.

> **TL;DR.** Apache **Ranger** is the single authority for **data access**.
> You author grants through one BFF API — `POST /api/platform/v1/access/grant`
> — and the same `AccessGrantService` backs the frontend, Terraform, MCP, and
> the CLI. Grants are enforced **at query time**: the end-user's JWT flows
> **SQE → Polaris → Ranger**, and Ranger's decision is authoritative. The BFF's
> own visibility checks are *advisory* (best-effort, fail-open); the write gate
> on the grant API is *fail-closed*.

---

## 1. Mental model: two planes

| Plane | Owns | Backed by |
|-------|------|-----------|
| **Control plane** | *Who may use which platform feature* (dbt, lineage, contracts, MCP tools, grant authoring) — derived from data access + workspace role | BFF (Python), Keycloak groups, `FeatureAuthorizer` |
| **Data plane** | *Who may read/write which catalog / namespace / table* | **Apache Ranger**, enforced by Polaris's embedded Ranger authorizer |

This document is about the **data plane**. Control-plane feature gating
(e.g. "you can run dbt if you can read the source tables") is documented
separately; it consumes the data-plane decisions described here.

**Key principle:** there is exactly **one** grant model — Ranger. The legacy
Polaris *catalog-role* grant path is retired for data access (it is a no-op
under the Ranger authorizer). Polaris *principal-roles* remain only for admin
identity and Polaris management-API auth, not for data grants.

---

## 2. Architecture & request flows

### Authoring a grant (control path)

```
 Frontend (Access Control UI) ─┐
 Terraform (chameleon_grant) ──┤ HTTPS   ┌────────────────────────┐
 Any external tool ────────────┴────────▶│ BFF /api/platform/v1/  │
                                          │   access/{grant,…}     │
 MCP tools (grant_table_access) ─┐        │  authorize_grant()     │
 CLI (data-platform-access) ─────┴ in-proc│  AccessGrantService    │──▶ Apache Ranger
                                          └────────────────────────┘    (policy store)
```

- **External clients** (browser, Terraform, other tools) call the HTTP
  `/access` API.
- **In-process clients** (MCP tools, the CLI) call the **same**
  `AccessGrantService` directly — no loopback HTTP — but pass through the
  **same** `authorize_grant()` gate.
- `AccessGrantService` translates the grant into a Ranger policy and writes it
  to Ranger Admin as the control account **`chameleon-svc`**.

### Enforcing a grant (data path — the authoritative one)

```
 User's browser ──JWT──▶ BFF ──exchanged/forwarded JWT──▶ SQE (Trino/Flight)
                                                            │  end-user JWT
                                                            ▼
                                                          Polaris (Iceberg REST catalog)
                                                            │  embedded Ranger authorizer
                                                            ▼
                                                          Ranger decision  ✅/❌
```

The query engine (**SQE**) forwards the **end-user's** identity to Polaris on
every catalog operation. Polaris's embedded Ranger authorizer evaluates the
operation against the downloaded Ranger policies and **allows or denies**. This
is the only authoritative enforcement point — a grant "takes effect" when
Ranger has the policy and Polaris has downloaded it.

---

## 3. Core concepts

### 3.1 Grantees — users and groups → Ranger users and roles

A grant targets a **grantee**:

| `grantee_type` | Meaning | Maps to in Ranger |
|----------------|---------|-------------------|
| `USER` | a single principal (`preferred_username`) | Ranger **user** |
| `GROUP` | a Keycloak group (team) | Ranger **role** |

- **Groups are the recommended unit.** A Keycloak group is materialized as a
  Ranger **role** (same name) by group-sync; membership is kept in step as users
  join/leave the group. Ranger evaluates a caller's roles from the **`groups`**
  claim in their JWT (`quarkus.oidc.roles.role-claim-path: groups`).
- `USER` grants are keyed on `preferred_username` (never the Keycloak UUID
  `sub`, which is rename-safe storage-path identity only).

> Ranger requires a grantee user/role to **exist** before a grant can target
> it. The platform provisions them as users are created / added to workspaces
> (group-sync + bootstrap), so you normally don't manage Ranger users directly.

### 3.2 Resources — catalog / namespace / table (+ `root`)

A grant applies to a resource at one of three levels, and **every** Ranger
resource map carries `root="*"` because Polaris sends `root` in every
authorization request:

```json
{"root": "*", "catalog": "analytics"}                          // catalog-level
{"root": "*", "catalog": "analytics", "namespace": "sales"}     // namespace-level
{"root": "*", "catalog": "analytics", "namespace": "sales", "table": "orders"} // table
```

In the API and CLI you supply `catalog` (required) + optional `namespace` +
optional `table`; the dotted form `catalog.namespace.table` is how grants are
displayed.

### 3.3 Privileges → Ranger access types

You grant a **privilege** (SQL-style verb). The platform expands it into
explicit Ranger **access types** — the authorizer does **not** honour
implied grants, so each underlying capability is listed explicitly:

> **Where this mapping lives.** The privilege→access-type mapping ships as a canonical,
> machine-readable **grant profile**, generated alongside the Python module the backend
> actually imports. It is a **contract shared with other writers** — SQE authors Ranger
> policies too, and the profile exists so both sides mean the same thing by `SELECT`.
>
> It ships **seeds**, not finished access-type lists. The transitive closure — the access-type
> implication graph — is authored in this repo; the upstream Ranger service definition for
> Polaris declares no implied grants of its own. As of profile **v5** that graph travels inside
> the grant profile itself, so a writer vendoring the profile no longer needs a separate service
> definition alongside it to compute the closure. The closure is applied at **write** time by
> `ranger_authorizer.expand_access_types`; because Polaris's authorizer ignores `impliedGrants`,
> a policy listing only the seed is enforced as *just* the seed. A contract test keeps the
> profile's copy of the graph and the generated module the backend imports in step.

| Privilege | Ranger access types |
|-----------|---------------------|
| `LOAD_TABLE` | `table-properties-read` |
| `SELECT` | `table-properties-read`, `table-data-read` |
| `INSERT` | `table-data-write` |
| `CREATE_TABLE` | `table-create` |
| `DROP_TABLE` | `table-drop` |
| `LIST_TABLES` | `table-list` |
| `CREATE_NAMESPACE` | `namespace-create` |
| `DROP_NAMESPACE` | `namespace-drop` |
| `LIST_NAMESPACES` | `namespace-list` |
| `LOAD_NAMESPACE_METADATA` | `namespace-properties-read` |

The grant API also accepts the higher-level verbs `USE / SELECT / MODIFY /
CREATE / DROP / MANAGE / ALL`. Any unknown value is passed through lowercased,
so you can name a **raw Ranger access type** directly when you need one not in
the table above.

> **Visibility vs. data read.** A table becomes *visible* (listable / loadable
> in the UI) when the grantee has `table-properties-read` — this is what Polaris
> gates `LOAD_TABLE` on. Reading the actual data also needs `table-data-read`
> (both are included by `SELECT`). The engine reads Parquet with its own object
> credentials, so `table-data-read` is the SELECT gate rather than
> credential-vending.

### 3.3b What Polaris actually asks Ranger for — measured

The table above is what the platform *writes*. This is what Polaris *checks*, observed
on Polaris 1.7.0 + Ranger 2.8 by running each statement as a user holding **only** the
named grant on one table, then reading the Ranger audit.

This is the ground truth the grant profile approximates. When a grant returns `201`
and the query still fails, the mismatch is between these two lists.

| Statement | Grant held | Access types Polaris requested |
|---|---|---|
| `SELECT * FROM c.n.t` | `SELECT` | catalog `namespace-list` → namespace `namespace-properties-read` → table `table-properties-read`, `table-list` |
| `INSERT INTO c.n.t …` | `INSERT` | the same three, then table `table-snapshot-add`, `table-snapshot-ref-set` |
| `ALTER TABLE c.n.t SET PROPERTIES …` | `MODIFY` | table `table-properties-set` |
| `ALTER TABLE c.n.t ADD COLUMN …` | `MODIFY` | table `table-schema-add`, `table-schema-set-current` |

Three things worth taking from it:

1. **Every level of the plan is really used.** A `SELECT` touches the catalog, the
   namespace *and* the table. Catalog-level `namespace-list` is not defensive padding —
   SQE issues `GET /{catalog}/namespaces` while planning even a fully-qualified query,
   and a `403` there aborts the whole statement (§7.2).
2. **Property mutation is gated on `table-properties-set`, not `table-properties-write`.**
   The latter was never requested on any measured path and looks unreachable on the Ranger
   path. This is why `MODIFY` deliberately does not confer it.
3. **None of the 33 access types the profile does not model was ever requested.** They are
   all role/grant administration, which is inert here because Ranger holds the grants
   rather than Polaris.

**To measure another operation:** run it as a narrowly-granted user, then

```bash
docker compose logs --since 5m polaris 2>&1 | grep "user=<name>" \
  | grep -oE "resourceType=[^;]+;action=[^;]+;accessResult=[0-9]+" | sort -u
```

`accessResult=1` is allow, `0` is deny. Audit lines age out of the container log, so
capture inside a window rather than mining history.

### 3.4 Allow-only via the API; deny lives in Ranger

The `/access` API issues **`allow`** grants only. `effect=deny` is rejected
with `400` — deny policies (which take precedence over allows) are an advanced
case you manage **directly in Ranger Admin**. Revoking removes the allow grant;
it does not create a deny.

---

## 4. The `/access` API

Base path: **`/api/platform/v1/access`**. All endpoints require an
authenticated BFF session/JWT.

### 4.1 `POST /access/grant`

Create an allow grant.

```jsonc
// request body (GrantRequest)
{
  "privilege": "SELECT",            // USE|SELECT|MODIFY|CREATE|DROP|MANAGE|ALL or a raw access type
  "catalog": "analytics",           // required
  "namespace": "sales",             // optional
  "table": "orders",                // optional
  "grantee_type": "GROUP",          // GROUP or USER
  "grantee_name": "SG-DataAnalysts",
  "effect": "allow"                 // allow only; "deny" → 400
}
```

```bash
curl -sS -X POST https://<host>/api/platform/v1/access/grant \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"privilege":"SELECT","catalog":"analytics","namespace":"sales",
       "grantee_type":"GROUP","grantee_name":"SG-DataAnalysts"}'
```

Returns `201` with the echoed grant. After a grant, the BFF best-effort busts
its permission cache so the change is visible within a round-trip; the engine
picks it up on Ranger's next policy poll (default `pollIntervalMs=5000`).

### 4.2 `POST /access/revoke`

Remove a grant (same body shape, no `effect`).

```bash
curl -sS -X POST https://<host>/api/platform/v1/access/revoke \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"privilege":"SELECT","catalog":"analytics","namespace":"sales",
       "grantee_type":"GROUP","grantee_name":"SG-DataAnalysts"}'
```

### 4.3 `GET /access/grants`

List grants, with optional filters
(`catalog`, `namespace`, `table`, `grantee_type`, `grantee_name`, `privilege`).

```bash
curl -sS "https://<host>/api/platform/v1/access/grants?catalog=analytics" \
  -H "Authorization: Bearer $TOKEN"
```

```jsonc
// response — each entry is a Ranger GrantEntry
{"grants": [
  {"access_type": "table-data-read", "resource": "analytics.sales.orders",
   "grantee_type": "ROLE", "grantee_name": "SG-DataAnalysts", "effect": "ALLOW"}
]}
```

Note the response is the **Ranger-native** shape: individual `access_type`
entries, a dotted `resource` string, and `grantee_type` of `USER`/`ROLE`
(a `GROUP` grant is stored as a `ROLE`). There is no per-grant `id` — grants are
identified by their tuple.

### 4.4 `POST /access/check`

Answer "can user *X* do *privilege* on *resource*?" — used for diagnostics and
the advisory UI. It resolves **the target user's** groups (not the caller's).

```bash
curl -sS -X POST https://<host>/api/platform/v1/access/check \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"user":"alice","privilege":"SELECT","catalog":"analytics","namespace":"sales","table":"orders"}'
# → {"allowed": true}
```

> `/access/check` and `/access/grants` are **read** endpoints gated to platform
> admins. Authoritative enforcement is always at the engine — `/check` is a
> convenience that evaluates the same Ranger policies locally.

---

## 5. Who may author grants — `authorize_grant`

Every grant/revoke entry point (HTTP, MCP, CLI) runs the **same** gate before
touching Ranger:

> **Allowed if** the caller is a **platform admin** (`PLATFORM_ADMIN_GROUPS`, or
> the `service_admin`/`catalog_admin` principal-roles) **OR** a **workspace
> admin of the workspace that owns the target catalog**.

Catalog ownership is derived **server-side** from `workspace_catalogs` — never
from the request body, so a caller cannot claim ownership of a catalog they
don't administer. A caller who is neither is rejected:

- HTTP → `403`
- MCP tool → tool-error
- CLI → non-zero exit

The gate is **fail-closed**: if the workspace service is unavailable, only
platform admins may grant.

---

## 6. Managing grants from each surface

All four go through the same `AccessGrantService` + `authorize_grant`.

### 6.1 Frontend
The **Access Control** UI (and the Roles page's grant tab) call the `/access`
API directly. Grants issued there enforce via Ranger.

### 6.2 Terraform — `chameleon_grant`
The `terraform-provider-chameleon` provider's `chameleon_grant` resource maps
1:1 to a Ranger grant via `/access`:

```hcl
resource "chameleon_grant" "analysts_read_sales" {
  privilege    = "SELECT"
  catalog      = "analytics"
  namespace    = "sales"
  table        = "*"        # supports `*` and `%` wildcards; omit for namespace-level
  grantee_type = "GROUP"    # GROUP (Keycloak group / Polaris role) or USER
  grantee_name = "SG-DataAnalysts"
  effect       = "allow"    # allow (default) or deny (deny wins on conflicts)
}

# Workspace-scoped variant: pass `workspace_slug` instead of `catalog` to grant
# on the workspace's own catalog and target an auto-provisioned group.
resource "chameleon_grant" "team_a_read_public" {
  privilege      = "SELECT"
  workspace_slug = chameleon_workspace.team_a.slug
  namespace      = "public"
  table          = "*"
  grantee_type   = "GROUP"
  grantee_name   = chameleon_workspace.team_a.member_group
}
```

Every settable attribute forces replacement (there's no PATCH upstream — a
change is applied as revoke-then-grant). The old `chameleon_policy` resource is
retired — use `chameleon_grant`.

### 6.3 MCP — `grant_table_access` / `revoke_table_access`
AI agents manage grants through MCP tools that call `AccessGrantService`
in-process (gated by `authorize_grant`, so a non-authorized caller's grant
never reaches Ranger):

```
grant_table_access(catalog, namespace, table, grantee,
                   grantee_type="ROLE", privilege="SELECT")
revoke_table_access(...)
```

### 6.4 CLI — `data-platform-access`
An operator/bootstrap tool that calls `AccessGrantService` directly (no HTTP),
running as the platform service identity:

```bash
data-platform-access grant  analytics sales orders SG-DataAnalysts --grantee-type ROLE --privilege SELECT
data-platform-access revoke analytics sales orders SG-DataAnalysts --grantee-type ROLE --privilege SELECT
data-platform-access list   --catalog analytics
```

---

## 7. Enforcement through SQE — what is and isn't protected

Ranger only enforces per-user when the **end-user's identity reaches Polaris**.

| Path | Identity at the engine | Per-user Ranger enforcement |
|------|------------------------|------------------------------|
| Interactive query via **SQE** (Trino HTTP / Flight SQL) | end-user JWT forwarded | ✅ yes — authoritative |
| **dbt** runs | end-user token (minted via Keycloak token-exchange → `DBT_ACCESS_TOKEN` → SQE's Trino `jwt` profile) | ✅ yes |
| **Spark batch** / any engine running under a **service identity** | service principal, not the end user | ❌ no — Ranger sees the service account, not the user |

The implication: data-access guarantees hold for engine paths that **forward
the end-user JWT**. SQE does this (and is multi-catalog aware); jobs that run
under a shared service identity are not constrained per-user by Ranger and must
be treated as trusted.

**SQE configuration.** SQE itself runs with `[policy] engine = "passthrough"` —
it does no local authorization; it forwards the user's token to Polaris, where
Ranger decides. SQE holds a static object-store key, so a read that Ranger
allows succeeds; there is no separate credential-vending gate for reads.

### 7.1 A view is **not** a privilege boundary

`SELECT VIEW` is grantable on a single view — a view has no resource level of its
own in the Polaris service definition, so it is addressed by putting its name in
the `table` slot.

But granting a view does **not** confer access to the tables it reads. SQE expands
the view's SQL and plans against the base tables, so the reader needs their own
grant there too. Granting only the view produces a base-table denial surfacing
through the view:

```
Failed to plan view 'v' SQL: table 'cat.ns.orders' not found
```

This differs from Snowflake secure views and Databricks views, where the
definer's privileges apply and the reader needs nothing on the base table. **There
is no definer's-rights mode here: a view cannot be used to expose a subset of a
table to someone who may not read the table.**

Use a row filter or a column mask for that. Those still apply *through* a view,
because the rewrite happens on the expanded scan — so a view is safe (it cannot
launder a masked column) but not sufficient (it cannot stand in for a grant).

### 7.2 Any grant lets the grantee list the catalog's namespaces

Polaris resolves the catalog before the table, so every grant also carries
catalog-level `namespace-list`. A grantee can therefore enumerate every namespace
in that catalog, including ones they cannot read.

No rows, columns or table contents are exposed — but namespace **names** are.
Where a name is itself sensitive, put the dataset in its own catalog: the catalog
is the enumeration boundary, and one-catalog-per-workspace is the existing way to
draw it.

---

## 8. Advisory visibility vs. authoritative enforcement

The BFF also evaluates Ranger policies **locally** to decide what to *show* in
the UI (catalog/namespace/table visibility, lineage, contracts, etc.). This is
**advisory**:

- It maps to the `table-properties-read` access type (what Polaris gates
  `LOAD_TABLE` on), so "visible in the UI" matches "loadable".
- It **fails open**: if Ranger is unreachable, the BFF does not blank the UI —
  it shows the resource and lets the **authoritative** engine path enforce.

Contrast with the grant **write** gate (`authorize_grant`) and the saved-query
write gate, which **fail closed** — a write must never succeed on uncertainty.

> Rule of thumb: **reads/visibility fail open** (advisory; the engine is the
> backstop); **writes/grant-authoring fail closed**.

---

## 9. Identity & role model

- **Ranger roles come from Keycloak `groups`.** group-sync materializes each
  group as a same-named Ranger role and keeps membership in sync; Polaris reads
  `groups` from the JWT and passes them as the caller's roles.
- **Principal-roles stay** — but only for *admin identity* (`is_platform_admin`,
  the frontend admin checks) and Polaris management-API auth. They are **not**
  used for data-access decisions.
- **`chameleon-svc`** is the single shared **control account**. The BFF and SQE
  use it to author/read Ranger policies; Polaris authenticates to Ranger as it
  to **download** policies. It is *not* a data user — end users are evaluated by
  their own identity.

---

## 10. Bootstrap & configuration

On a fresh stack, Ranger is wired before Polaris starts:

1. **`ranger-setup`** (quickstart `bootstrap-ranger.sh`) and the backend
   **`RangerBootstrapManager`** register the `polaris` **service-def** and
   **service**, create `chameleon-svc` + the `platform-admin` role, and seed the
   admin policy across every resource map (each carrying `root="*"`).
2. The `polaris` service is created with the **download-auth** config so the
   non-admin `chameleon-svc` may download policies (see §11):

   ```
   policy.download.auth.users   = chameleon-svc
   tag.download.auth.users      = chameleon-svc
   policy.grantrevoke.auth.users = chameleon-svc
   ```

3. Polaris is configured to delegate authz to Ranger:

   ```
   polaris.authorization.type = ranger
   polaris.authorization.ranger.service-name = polaris
   polaris.authorization.ranger.authz.default.policy.rest.url      = http://ranger-admin:6080
   polaris.authorization.ranger.authz.default.policy.rest.client.username = chameleon-svc
   polaris.authorization.ranger.authz.default.policy.pollIntervalMs = 5000
   quarkus.oidc.roles.role-claim-path = groups
   ```

   `polaris.authorization.type` is a **total replacement**, not a layer.
   Polaris ships three `PolarisAuthorizerFactory` implementations selected by
   that one key via a SmallRye `@Identifier` — `default`
   (`PolarisAuthorizerImpl`, the built-in grant evaluator), `opa` (retired
   here), and `ranger` (`RangerPolarisAuthorizer`). Setting `ranger` means
   `PolarisAuthorizerImpl` is **never instantiated**, on the data plane *and*
   the management plane: nothing else in the distribution references it.

   This is why Polaris's own grant evaluation plays no part in data access
   (§9 — principal-roles survive for admin identity only). It is also a
   standing trap when reading Polaris release notes: **any authorization
   behaviour described against `PolarisAuthorizerImpl` does not apply to us.**
   Check that the claim names `RangerPolarisAuthorizer` before believing it —
   Polaris 1.7's per-privilege denial diagnostics are exactly this case, see
   §11.

All 6 quickstarts (`minimal/full/demo/sqe/e2e/spark-connect-polaris`) run
Polaris 1.7.0 + Apache Ranger 2.8.0 with this wiring.

---

## 11. Operations & troubleshooting

### "User doesn't have permission to download policy/UserGroupRoles" (403)

Polaris logs, every `pollIntervalMs`:

```
RangerAdminRESTClient Error getting policies. secureMode=true,
  403 "User doesn't have permission to download policy", serviceName=polaris
```

**Cause:** `chameleon-svc` (a non-admin `ROLE_USER`) is the policy downloader,
but the `polaris` service's `policy.download.auth.users` does not include it →
Ranger denies the download → Polaris has **no policies** → effectively
**deny-all**.

**Fix (fresh stacks):** the service is created with the download-auth config
(§10.2) — nothing to do.

**Fix (a running stack created before the config existed):**
1. Update the service config (GET the service, merge `configs`, PUT by id):
   ```bash
   # run from inside the docker network; the host-published port can 401
   docker compose exec polaris sh -c \
     "curl -u admin:rangerR0cks! http://ranger-admin:6080/service/public/v2/api/service/name/polaris"
   #   → merge policy.download.auth.users / tag.download.auth.users /
   #     policy.grantrevoke.auth.users = chameleon-svc, then PUT to
   #     /service/public/v2/api/service/{id}  with header  X-XSRF-HEADER: x
   ```
2. **Restart ranger-admin** — the service config is **cached**, so a PUT alone
   does not take effect until ranger-admin re-reads it:
   ```bash
   docker compose restart ranger-admin
   ```
   Confirm: the 403s stop and Polaris logs
   `RangerBasePlugin Switched policy engine from [N] to [N+1]`.

### Querying / editing Ranger directly

- Query **from inside the docker network** (`docker compose exec polaris sh -c
  "curl … http://ranger-admin:6080/…"`). The host-published port may return
  `401`, and `localhost` vs `127.0.0.1` can give an empty response.
- State-changing requests need the **`X-XSRF-HEADER: x`** header.
- Default admin credentials: `admin` / `rangerR0cks!`
  (`RANGER_ADMIN_PASSWORD`). `chameleon-svc`'s password must equal
  `RANGER_SVC_PASSWORD` (defaults to the same), or Polaris/BFF auth fails.

### A grant "isn't working"

1. Is the grantee a **Ranger user/role** that exists? (`USER` grants need the
   exact `preferred_username`; `GROUP` grants need the synced role.)
2. Does the caller's **JWT carry the `groups`** claim? (Token-exchange can strip
   it; the BFF re-resolves membership from Keycloak as a fallback, but the
   *engine* path relies on the JWT's `groups`.)
3. Did you grant the right **access types**? `SELECT` needs both
   `table-properties-read` and `table-data-read`; visibility-only is
   `table-properties-read`.
4. Has Polaris **polled** since the grant? Wait `pollIntervalMs` (5 s) or check
   `Switched policy engine` in the logs.
5. Is the query path forwarding the **end-user JWT**? A service-identity engine
   path is not constrained per-user (see §7).

Polaris will **not** tell you which privilege was missing. On a denial the
Ranger authorizer logs only:

```
Principal '<user>' is not authorized for op '<OPERATION>'
```

Polaris 1.7 added per-privilege denial diagnostics (`missing <PRIVILEGE> on
<ENTITY>`), but they live in `PolarisAuthorizerImpl` — the **default**
authorizer. We run `polaris.authorization.type = ranger`, which selects
`RangerPolarisAuthorizer` instead, and that class is byte-for-byte unchanged
between 1.6.0 and 1.7.0. `PolarisAuthorizerImpl` is referenced by exactly one
class in the distribution (`DefaultPolarisAuthorizerFactory`), so under Ranger
it is never instantiated and the diagnostics are unreachable — on the data
**and** management planes. Diagnose from the Ranger side instead: the operation
name in the log maps to the access types in `grant-profile.json`, and Ranger's
own audit records the resource and the policy that decided.

---

## 12. Security model & current limitations

- **Authoritative enforcement is at the engine** (Polaris embedded Ranger
  authorizer), reached with the **end-user JWT**. The BFF's visibility checks
  are advisory and fail-open by design.
- **Write gates fail closed** (grant authoring; saved-query writes).
- **Allow-only via the API**; deny is managed directly in Ranger.
- **No column masking or row-level filtering yet.** Authorization is
  **table-grain** — you can grant/deny a whole table, but "mask the SSN column"
  or "analysts see only their region's rows" are not available. Ranger supports
  these as first-class policy types, but they are inherently **engine-level**
  (Polaris vends metadata/credentials and never sees result rows), so they are a
  planned SQE-side track, not implemented today.
- **Engine identity matters.** Only engine paths that forward the end-user JWT
  (SQE; dbt via token-exchange) are constrained per-user. Treat
  service-identity batch jobs as trusted.

---

## 13. Quick end-to-end example

Grant a team read access to a table and verify it:

```bash
# 1. Grant SELECT on analytics.sales.orders to the analysts group
curl -sS -X POST https://<host>/api/platform/v1/access/grant \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H 'Content-Type: application/json' \
  -d '{"privilege":"SELECT","catalog":"analytics","namespace":"sales","table":"orders",
       "grantee_type":"GROUP","grantee_name":"SG-DataAnalysts"}'

# 2. Confirm the advisory check for a member of that group
curl -sS -X POST https://<host>/api/platform/v1/access/check \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H 'Content-Type: application/json' \
  -d '{"user":"alice","privilege":"SELECT","catalog":"analytics","namespace":"sales","table":"orders"}'
# → {"allowed": true}

# 3. Authoritative check: alice queries through SQE (her JWT → Polaris → Ranger)
#    SELECT * FROM analytics.sales.orders LIMIT 10;   → succeeds
#    A user NOT in SG-DataAnalysts → Polaris/Ranger denies the LOAD_TABLE.
```
