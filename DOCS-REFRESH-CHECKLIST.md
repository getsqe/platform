# /docs refresh checklist

Run on every refresh of platform.getsqe.com/docs.

## Automated
- [ ] `bash scripts/sync-docs-from-dp.sh` — aborts on a leak or a missing `openapi.json`
- [ ] `bash scripts/build-with-docs.sh` — builds both sites, composes, gates

## Manual — nothing automated covers these
- [ ] **Re-read `$DP/docs-site/astro.config.mjs`.** Our `docs-site/astro.config.mjs`
      is authored locally and is NOT synced. A new sidebar directory at source is
      omitted here **silently**. The source is actively developed.
- [ ] **Eyeball every screenshot** in `docs-site/src/assets/screenshots/` (30 as of
      2026-08-16). No text gate can scan a PNG. Look for usernames, internal
      hostnames, real table names, account ids, token fragments.
      - **Known-accepted, do not re-flag:** the codename "Chameleon" appears by
        design (spec D3 — the user chose to publish Chameleon as the real
        product name in documentation; only the site *title* is sanitized).
        You will see it as a notebook-kernel label, a `chameleon-svc`
        grantee/service-account name, and a `chameleon.test` mock hostname
        (an RFC 2606 reserved, non-resolving `.test` TLD — not the internal
        `chameleon.local` dev host, which IS redacted). These are consistent
        with the ~32 bare "Chameleon" mentions and 527 `chameleon_*`
        identifiers already published in the docs body. If a *new* screenshot
        surfaces `chameleon.local`, a real account id, a real hostname/IP, or
        a real person's name/email, that is a genuine leak — recapture at
        `$DP`, don't edit the synced PNG.
      - `energy-co` / "Energy Co" is the codebase's standard fictional demo
        tenant (unit tests, docker-compose, quickstart/demos/energy-utility)
        — not a leak.
      - `Acme Analytics` / `ws_acme_analytics` is the demo workspace/catalog
        used throughout the product UI — not a leak.
- [ ] **Confirm `openapi.json` is fresh.** It is generated from the live FastAPI
      app and uncommitted at source; the sync aborts if absent but cannot tell
      stale from current.
- [ ] Bump `src/components/AsOf.astro`.
- [ ] Confirm the marketing site still does not link `/docs`.

## Review log

**2026-08-16 — PASS (30/30 reviewed, direct image review, not a filename skim).**
Two items surfaced and dispositioned below; everything else clean. See per-file
table.

| # | File | Verdict |
|---|---|---|
| 1 | audit-trail-alerts.png | Clean. Tenant "Acme Analytics" (fictional demo), users root/adminuser/testuser, IP 172.19.0.1 (RFC1918 private, docker-bridge typical), Ranger plugin references — none identifying. |
| 2 | audit-trail-digest.png | Clean. Empty digest state, no data rendered. |
| 3 | audit-trail-log.png | Clean. User "root", generic API paths (/features, /dbt/projects, /workspaces, /chat/flows/...). |
| 4 | browse-catalog-catalog.png | Clean. Catalog `ws_acme_analytics`, `s3.endpoint = http://s3:9000` (generic docker service name), `us-east-1` (generic demo region). |
| 5 | browse-catalog-namespace.png | Clean. Generic namespace/table names (analytics_db, product_sales). |
| 6 | browse-catalog-overview.png | Clean. Empty "pick a catalog" state. |
| 7 | browse-catalog-table.png | Clean. `product_sales` table, generic demo columns (product_name, category, region, units_sold, revenue). |
| 8 | dbt-lifecycle-connection.png | **OPEN QUESTION (non-blocking):** demo git remote `https://github.com/sovereign-data/dbt-test-1`. Not an account id/secret/PII, but a real, resolvable GitHub URL that does not appear anywhere in the synced text content — unconfirmed whether that org is fictional or real. Raised to the user directly; follow up before this recurs unexamined in a future refresh. |
| 9 | dbt-lifecycle-ide.png | Clean. Generic dbt project file tree (gold/silver models, schema.yml). |
| 10 | dbt-lifecycle-lineage.png | Clean. Generic seed/model lineage graph (products/orders/customers -> stg_* -> dim_*/fct_*). |
| 11 | dbt-lifecycle-project.png | Same open question as #8 (`ws_acme_analytics.dbt_models`, same `sovereign-data` remote). |
| 12 | dbt-lifecycle-run.png | Clean. dbt run log output (dbt 1.11.12, trino adapter), no secrets. |
| 13 | dbt-lifecycle-tests.png | Clean. dbt_utils internal file tree, generic test names, all passing. |
| 14 | grant-access-dialog.png | Codename "Chameleon" visible (`chameleon-svc` grantee). **Accepted per spec D3** — see note above; not a leak. |
| 15 | grant-access-list.png | Same `chameleon-svc` grantee visible in the Access Control table. **Accepted, same disposition.** |
| 16 | manage-workspace-list.png | Clean. Workspace slugs (acme-analytics, e2e-pw, qa-access, wsgrant), all demo/test names. |
| 17 | notebook-analysis-create.png | Clean. "New notebook" dialog (revenue_forecast, ML experiment starter), no codename text visible. |
| 18 | notebook-analysis-editor.png | Codename "Chameleon" visible in markdown-cell prose ("Chameleon Python kernel", "this Chameleon workspace slug"). **Accepted per spec D3.** |
| 19 | notebook-analysis-list.png | Clean. probe_ml.ipynb only. |
| 20 | platform-health-system-health.png | Clean. Keycloak/Polaris/Storage health panel, generic service-account names (spark-service-client, service-account-polaris-init-client, service-account-sqe-client). |
| 21 | run-query-editor.png | Clean. Empty query editor (`SHOW CATALOGS`). |
| 22 | run-query-results.png | Clean. SELECT over product_sales, generic demo rows. |
| 23 | service-principal-list.png | Clean. Principal names (e2e-test-sp, probe-scope, probe-scope2, probe-rot, probe-sp-shape); "secret fingerprint" column is a truncated `sha256(secret)` (non-reversible reference per source docstring), not an actual secret. |
| 24 | sign-in-landing.png | Clean. Product marketing panel ("cloud independent / data platform"), integration badges (Keycloak, Polaris, SQE Flight/Trino), "© 2026 Schuberg Philis" footer — expected, SBP is public-facing per CLAUDE.md. |
| 25 | sign-in-login.png | Clean. Same screen, no PII, no codename. |
| 26 | triggers-connect.png | `chameleon.test` mock hostname visible in the curl "Connect" example (appears twice), plus `auth.test/realms/iceberg/...`. **Accepted per spec D3** — `.test` is an RFC 2606 reserved, non-resolving TLD (not the internal `chameleon.local` dev host, which the gate does redact); `chameleon.test` already appears unsanitized and gate-clean in the published text (`start/web-portal.md`, `start/quickstart.md`, `assets/screenshots/manifest.json`). |
| 27 | triggers-create.png | Clean. Generic SQL trigger form (daily_sales_rollup), no codename/hostname. |
| 28 | triggers-list.png | Clean. |
| 29 | triggers-monitoring.png | Clean. Generic succeeded/failed charts. |
| 30 | triggers-runs.png | Clean. Generic run history table. |

(30 files confirmed via `ls docs-site/src/assets/screenshots/*.png | wc -l`.)
