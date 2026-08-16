#!/usr/bin/env bash
# Publish-safety leak gate for platform.getsqe.com. Single source of truth for
# the sync script and the deploy workflow. Adapted from the SQE gate for the
# data-platform (Chameleon) source signature.
#
#   scripts/leak-scan.sh <dir-or-file> [<dir-or-file> ...]
#
# Scans *.md / *.json / *.html / *.svg. Exits 1 on any hit (prints file:line),
# 0 if clean. Rules are prefix/substring heuristics:
#   [0-9]{12}          - AWS account ids
#   eu-(central|west|north)-[0-9]  - internal AWS regions
#   amazonaws          - AWS endpoints
#   chore/ | feat/ | MR ! - internal branch / merge-request refs
#   chameleon\.local   - the platform's internal dev hostname
#   realms/[A-Za-z0-9_-]+ - Keycloak realm paths (internal realm names)
set -euo pipefail

# Text extensions that reach the published output. Keep in sync across the
# three site gates; a gap here is silent.
#
# .mdx is NOT optional: the docs-site content under /docs is largely .mdx
# (every use-case and tutorial page). .js matters because generated SEARCH
# INDEXES are JavaScript — Starlight's pagefind and mdBook's searchindex both
# embed the full text of every page, so an HTML-only scan passes while the
# index still carries a leaked string the site's search box will surface.
SCAN_EXTS=(md mdx json html svg js mjs xml txt yml yaml css)

LEAK_RE='[0-9]{12}|chore/|feat/|eu-(central|west|north)-[0-9]|amazonaws|MR !|chameleon\.local|realms/[A-Za-z0-9_-]+'

# Strip the sanitiser's OWN placeholders before matching. The realms rule is
# deliberately broad (any realm name is internal), which means it also matches
# the `realms/example` the sanitiser writes. Allowlisting the placeholder keeps
# the broad rule intact; weakening the rule instead would let real realm names
# through. Anchoring prevents bare substring strips that would let `realms/example-prod`
# or similar pass when they should be caught. `platform.example` is defensive
# (currently no LEAK_RE rule matches it) and kept anchored for future compatibility.
ALLOWLIST_SED='s#realms/example([^A-Za-z0-9_-]|$)#\1#g; s#platform\.example([^A-Za-z0-9_-]|$)#\1#g'

if [[ $# -eq 0 ]]; then
  echo "usage: leak-scan.sh <dir-or-file> ..." >&2
  exit 2
fi

find_expr=()
for ext in "${SCAN_EXTS[@]}"; do
  [[ ${#find_expr[@]} -eq 0 ]] || find_expr+=(-o)
  find_expr+=(-name "*.${ext}")
done

hits=0
scanned=0
while IFS= read -r -d '' f; do
  scanned=$((scanned + 1))
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    echo "  LEAK: $f: $line"
    hits=$((hits + 1))
  done < <(sed -E "$ALLOWLIST_SED" "$f" | grep -nEi "$LEAK_RE" || true)
done < <(find "$@" -type f \( "${find_expr[@]}" \) -print0)

if [[ "$hits" -gt 0 ]]; then
  echo "leak-scan: $hits hit(s) — ABORT" >&2
  exit 1
fi

# A scan that matched nothing is indistinguishable from a clean one in the
# output, and a wrong path is an easy mistake. Refuse to report "clean" for it.
if [[ "$scanned" -eq 0 ]]; then
  echo "leak-scan: matched 0 files under: $* — refusing to report clean" >&2
  exit 2
fi
echo "leak-scan: clean (0 hits, $scanned files)"
