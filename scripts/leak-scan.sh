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

LEAK_RE='[0-9]{12}|chore/|feat/|eu-(central|west|north)-[0-9]|amazonaws|MR !|chameleon\.local|realms/[A-Za-z0-9_-]+'

if [[ $# -eq 0 ]]; then
  echo "usage: leak-scan.sh <dir-or-file> ..." >&2
  exit 2
fi

hits=0
while IFS= read -r -d '' f; do
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    echo "  LEAK: $f: $line"
    hits=$((hits + 1))
  done < <(grep -nEi "$LEAK_RE" "$f" || true)
done < <(find "$@" -type f \( -name '*.md' -o -name '*.json' -o -name '*.html' -o -name '*.svg' \) -print0)

if [[ "$hits" -gt 0 ]]; then
  echo "leak-scan: $hits hit(s) — ABORT" >&2
  exit 1
fi
echo "leak-scan: clean (0 hits)"
