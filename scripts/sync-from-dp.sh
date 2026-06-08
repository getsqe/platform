#!/usr/bin/env bash
# Sync platform.getsqe.com content FROM the private data-platform repo.
# Read-only against the source. Run manually on demand.
#
#   DP_DIR=/path/to/data-platform bash scripts/sync-from-dp.sh
#
# Steps:
#   1. Copy the single curated marketing doc -> src/content/source/
#   2. Sanitize the synced COPY (deterministic, re-run safe; source untouched).
#   3. Run the BLOCKING leak-scan gate. Any hit aborts (exit 1).
set -euo pipefail

DP_DIR="${DP_DIR:-/Users/jjverhoeks/git/schuberg/vpf-data-ai/chameleon/Applications/data-platform}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$DP_DIR/docs/marketing/cloud-independent-data-platform.md"
DEST="$HERE/src/content/source/cloud-independent-data-platform.md"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: source doc not found: $SRC" >&2
  exit 1
fi

echo "→ syncing from $SRC"
mkdir -p "$(dirname "$DEST")"
cp "$SRC" "$DEST"

echo "→ sanitizing synced copy (source untouched)"
# Deterministic redactions. Order matters: 13+-digit ids before 12-digit rule.
sed -i '' -E \
  -e 's/[0-9]{13,}/SNAPSHOT_ID/g' \
  -e 's/[0-9]{12}/ACCOUNT_ID/g' \
  -e 's/eu-(central|west|north)-[0-9]/eu-example-1/g' \
  -e 's/chameleon\.local/platform.example/g' \
  -e 's#realms/[A-Za-z0-9_-]+#realms/example#g' \
  "$DEST"

echo "→ leak-scan gate"
bash "$HERE/scripts/leak-scan.sh" "$DEST"
echo "✓ sync clean: $DEST"
