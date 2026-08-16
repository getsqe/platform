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
#   realm...['"]iceberg['"] - the internal realm name as a bare quoted default
#                      (not just the realms/ URL-path form above), scoped to a
#                      `realm` token within 60 chars so it can't fire on
#                      ordinary Apache Iceberg prose
#   realm...iceberg    - same, unquoted forms (CHAMELEON_REALM=iceberg,
#                      `realm: iceberg`, backticked `` `iceberg` ``, `realm =
#                      "iceberg"`), scoped to an assignment/default context
#                      (`realm` then `:`/`=` then optionally a quote, or
#                      `realm` then a backtick) rather than mere proximity —
#                      a bare-proximity version (realm within N chars of
#                      iceberg) produced false positives on ordinary
#                      documentation prose given this platform's subject
#                      matter (Keycloak realms AND Iceberg REST catalogs
#                      genuinely appear near each other in real sentences).
#                      One irreducible false positive remains by design:
#                      "Choose a realm: Iceberg tables..." is textually
#                      identical to the YAML form (`realm: iceberg`) this
#                      rule exists to catch — see leak-scan.test.sh.
#   vpf-data-ai        - internal GitLab group path
#   sbp\.gitlab        - internal GitLab hostname fragment
#   sovereign-data     - internal Harbor registry identifier
#                      (repo.sovereign-data.org, per $DP/Makefile + RELEASE.md)
#   /Users/[a-z]+/git  - .sh-ONLY (see SH_LEAK_RE below): a maintainer's local
#                      home-directory checkout path (this is exactly how the
#                      DP_DIR default leak shipped: a hardcoded path in a
#                      public sync script). Not applied to published content —
#                      would false-positive on ordinary prose showing a local
#                      checkout path unrelated to any real leak.
set -euo pipefail

# Text extensions that reach the published output. Keep in sync across the
# three site gates; a gap here is silent.
#
# .mdx is NOT optional: the docs-site content under /docs is largely .mdx
# (every use-case and tutorial page). .js matters because generated SEARCH
# INDEXES are JavaScript — Starlight's pagefind and mdBook's searchindex both
# embed the full text of every page, so an HTML-only scan passes while the
# index still carries a leaked string the site's search box will surface.
# .sh matters because the sync SCRIPTS THEMSELVES are published in this repo —
# a hardcoded source path in a script is exactly the leak this gate now exists
# to catch (see the DP_DIR incident this rule set was added for).
SCAN_EXTS=(md mdx json html svg js mjs xml txt yml yaml css sh)

LEAK_RE="[0-9]{12}|chore/|feat/|eu-(central|west|north)-[0-9]|amazonaws|MR !|chameleon\\.local|realms/[A-Za-z0-9_-]+|realm[^'\"]{0,60}['\"]iceberg['\"]|realm[^A-Za-z0-9]{0,4}[:=][^A-Za-z0-9\"']{0,4}[\"'\`]?iceberg|realm[^A-Za-z0-9]{0,3}\`iceberg\`|vpf-data-ai|sbp\\.gitlab"

# NOT a rule: `sovereign-data`. It looks internal (repo.sovereign-data.org is
# the container registry, per the source repo's Makefile/RELEASE.md) but the
# apex domain is PUBLIC-FACING — info@sovereign-data.org is this very site's
# published contact address, on the live index page since 2026-06-09. Adding it
# here trips the gate on our own marketing copy. Verified by doing exactly that.

# .sh files get a NARROWER rule set: only internal-identifier/path rules, not
# content rules (eu-region, amazonaws, realm/iceberg forms). Sync scripts
# legitimately describe those redaction TARGETS in their own sed commands and
# comments (e.g. `-e 's/chameleon\.local/platform.example/g'`), which would
# otherwise self-trigger the moment .sh became scannable. The identifier rules
# below have no such legitimate occurrence — they exist to catch exactly the
# DP_DIR-style hardcoded path this whole rule set was added for.
# `/Users/[a-z]+/git` is .sh-ONLY (not in LEAK_RE above): it would
# false-positive on ordinary published prose (e.g. a docs snippet showing a
# local checkout path) that has nothing to do with the maintainer's own
# machine — `vpf-data-ai` already catches the real leak this rule targets.
SH_LEAK_RE="[0-9]{12}|vpf-data-ai|sbp\\.gitlab|/Users/[a-z]+/git|sovereign-data"

# The gate's own pattern-definition file and its behavioural-test fixtures are
# exempt by their OWN PATH (not a bare basename match, which would also skip
# any synced file that happened to be named identically): their entire
# purpose is to contain the literal strings above, either as regex source or
# as synthetic examples of what the gate must catch. That is not a real
# disclosure — no different from a scanner's own signature file containing
# its signatures — so scanning them adds noise, not safety. Nothing else is
# exempt.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF_EXEMPT=("$SELF_DIR/leak-scan.sh" "$SELF_DIR/leak-scan.test.sh")

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
  resolved_f="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
  for ex in "${SELF_EXEMPT[@]}"; do
    [[ "$resolved_f" == "$ex" ]] && continue 2
  done
  scanned=$((scanned + 1))
  re="$LEAK_RE"
  [[ "$f" == *.sh ]] && re="$SH_LEAK_RE"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    echo "  LEAK: $f: $line"
    hits=$((hits + 1))
  done < <(sed -E "$ALLOWLIST_SED" "$f" | grep -nEi "$re" || true)
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
