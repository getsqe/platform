#!/usr/bin/env bash
# Sync the /docs content FROM the private data-platform docs-site.
#
#   DP_DIR=/path/to/data-platform bash scripts/sync-docs-from-dp.sh
#
# Read-only against the source. Copies CONTENT ONLY — astro.config.mjs is
# authored locally and is deliberately NOT synced, because it carries the
# /docs base path, the public site title and the noindex head. Steps:
#   1. rsync --delete content, assets, styles, data, generated JSON, public/
#   2. Sanitize the synced COPY (deterministic, re-run safe; source untouched)
#   3. Run the BLOCKING leak-scan gate. Any hit aborts (exit 1).
set -euo pipefail

DP_DIR="${DP_DIR:-/Users/jjverhoeks/git/schuberg/vpf-data-ai/chameleon/Applications/data-platform}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$DP_DIR/docs-site"
DEST="$HERE/docs-site"

[[ -d "$SRC" ]] || { echo "ERROR: docs-site source not found: $SRC" >&2; exit 1; }

# starlight-openapi reads this at build time. It is GENERATED from the live
# FastAPI app and deliberately uncommitted at source, so a missing file means
# someone forgot to regenerate it. Publishing a stale or absent API reference
# silently is worse than failing here.
if [[ ! -f "$SRC/src/openapi.json" ]]; then
  echo "ERROR: $SRC/src/openapi.json is missing." >&2
  echo "  Regenerate it at the source first:" >&2
  echo "    cd $DP_DIR/backend && .venv/bin/python scripts/export_openapi.py ../docs-site/src/openapi.json" >&2
  exit 1
fi

echo "→ syncing content from $SRC"
mkdir -p "$DEST/src" "$DEST/public"
for d in content assets styles data; do
  [[ -d "$SRC/src/$d" ]] || continue
  rsync -a --delete "$SRC/src/$d/" "$DEST/src/$d/"
done
rsync -a --delete "$SRC/public/" "$DEST/public/"
for f in openapi.json cli-help.json mcp-tools.json; do
  [[ -f "$SRC/src/$f" ]] && cp "$SRC/src/$f" "$DEST/src/$f"
done

echo "→ sanitizing synced copies (source untouched)"
# Deterministic, order-sensitive redactions applied to the COPY only.
# NOTE: chameleon_* / chameleon-svc are the real public Terraform provider
# namespace (registry.terraform.io/schubergphilis/chameleon) and ship verbatim.
# Only the internal HOSTNAME chameleon.local is rewritten — the \b guards stop
# it matching chameleon_* identifiers. Likewise the two "Schuberg Philis" /
# schubergphilis.com rules below target only the capitalised display name and
# the literal marketing-site URL (brand chrome the site policy keeps off
# every page but About) — they do not match the lowercase schubergphilis org
# slug in the public Terraform registry/GitHub URLs, which ship verbatim.
#
# The realm-name pair below is deliberately NOT a blanket `iceberg` replace:
# "iceberg" appears 113 times in the synced tree (Apache Iceberg, the product
# this platform is built on) and only twice as the internal Keycloak realm
# name, both as a bare quoted default (`Defaults to 'iceberg'`, `(default
# "iceberg")`) rather than the `realms/iceberg` URL-path form the rule above
# already catches. Scoping to a `realm` token within 60 chars of a quoted
# `iceberg` targets exactly those two lines; a backreference for the quote
# char doesn't work under BSD sed, hence two rules, one per quote style. The
# `I` flag makes both case-insensitive (`CHAMELEON_REALM="iceberg"` is
# uppercase `REALM`, not `[Rr]ealm`) — without it the gate's matching LEAK_RE
# rule (also case-insensitive) would catch a form this sanitiser couldn't
# rewrite, aborting the sync instead of self-healing it.
#
# The gate's LEAK_RE additionally has an UNQUOTED-form realm rule
# (`CHAMELEON_REALM=iceberg`, `realm: iceberg`) with no sanitiser counterpart
# here: nothing ships in that form today, so if a future re-sync introduces
# one, failing the sync closed (forcing a sanitiser rule to be added then) is
# the correct outcome, not a bug.
#
# Walks BOTH src and public: public/ is rsynced too (e.g. public/scripts/*.js)
# and must not be a sanitizer/gate blind spot just because it isn't "docs
# content" in the narrow sense.
while IFS= read -r -d '' f; do
  sed -i '' -E \
    -e 's#chameleon\.local#platform.example#g' \
    -e 's#realms/[A-Za-z0-9_-]+#realms/example#g' \
    -e 's#s3\.eu-(central|west|north)-[0-9]\.amazonaws\.com#s3.eu-example-1.aws-endpoint.com#g' \
    -e 's#eu-(central|west|north)-[0-9]#eu-example-1#g' \
    -e 's#\*Powered by \[Schuberg Philis\]\(https://schubergphilis\.com\)[^*]*\*##g' \
    -e 's#"name": "Schuberg Philis"#"name": "Cloud Independent Data Platform"#g' \
    -e 's#https://schubergphilis\.com#https://platform.example#g' \
    -e "s#([Rr]ealm[^']{0,60})'iceberg'#\1'example'#gI" \
    -e "s#([Rr]ealm[^\"]{0,60})\"iceberg\"#\1\"example\"#gI" \
    "$f"
done < <(find "$DEST/src" "$DEST/public" -type f \( \
  -name '*.md' -o -name '*.mdx' -o -name '*.json' -o -name '*.html' \
  -o -name '*.svg' -o -name '*.js' -o -name '*.mjs' -o -name '*.xml' \
  -o -name '*.txt' -o -name '*.yml' -o -name '*.yaml' -o -name '*.css' \
  \) -print0)

echo "→ leak-scan gate over synced source"
bash "$HERE/scripts/leak-scan.sh" "$DEST/src" "$DEST/public"
echo "✓ docs sync clean: $DEST"
