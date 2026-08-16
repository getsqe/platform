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
| Date | Screenshots reviewed | Notes |
|---|---|---|
| 2026-08-16 | 30/30 (all files in `docs-site/src/assets/screenshots/`) | PASS. Full per-file walkthrough via direct image review (not filename skim). Three files show the codename "Chameleon" (`notebook-analysis-editor.png` — kernel/workspace-slug prose; `grant-access-dialog.png` + `grant-access-list.png` — `chameleon-svc` grantee; `triggers-connect.png` — `chameleon.test` mock host) — accepted per spec D3, which publishes Chameleon as the real product name in documentation; only the site title is sanitized. See the "known-accepted" note above so this isn't re-litigated every refresh. Open, non-blocking question raised to the user: `dbt-lifecycle-connection.png` / `dbt-lifecycle-project.png` reference `https://github.com/sovereign-data/dbt-test-1`, a screenshot-only URL not present anywhere in the synced text content — unconfirmed whether that GitHub org is fictional or real; follow up before it recurs unexamined in a future refresh. |
