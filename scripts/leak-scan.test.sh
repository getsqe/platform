#!/usr/bin/env bash
# Behavioural tests for the publish-safety gate. Run: bash scripts/leak-scan.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/leak-scan.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

expect () { # <desc> <want-exit> <file-content> [filename, default page.md]
  local desc="$1" want="$2" body="$3" fname="${4:-page.md}"
  rm -rf "$TMP/c"; mkdir -p "$TMP/c"
  printf '%s\n' "$body" > "$TMP/c/$fname"
  bash "$GATE" "$TMP/c" >/dev/null 2>&1
  local got=$?
  if [ "$got" = "$want" ]; then
    printf '  PASS  %s\n' "$desc"
  else
    printf '  FAIL  %s (exit %s, want %s)\n' "$desc" "$got" "$want"; fails=$((fails+1))
  fi
}

# Sanitiser placeholders are clean.
expect "realms/example allowed"        0 'curl "$KC/realms/example/protocol/openid-connect/token"'
expect "platform.example allowed"      0 'endpoint = "http://platform.example"'
# Real internal values still caught.
expect "real realm caught"             1 'curl "$KC/realms/iceberg/protocol/openid-connect/token"'
expect "chameleon.local caught"        1 'endpoint = "http://chameleon.local"'
expect "account id caught"             1 'arn:aws:iam::987654321098:role/r'
expect "bare quoted realm default caught" 1 'CHAMELEON_REALM           realm (default "iceberg")'
expect "unquoted realm=iceberg caught"  1 'CHAMELEON_REALM=iceberg'
expect "yaml realm: iceberg caught"     1 'realm: iceberg'
# Public product identifiers must NOT be treated as leaks.
expect "chameleon_ resource allowed"   0 'resource "chameleon_workspace" "team_a" {}'
expect "terraform registry allowed"    0 'source = "registry.terraform.io/schubergphilis/chameleon"'
# Regression guards: placeholders must be anchored, not bare substring strips.
expect "realms/example-prod caught"    1 'curl "$KC/realms/example-prod/protocol/openid-connect/token"'
expect "platform.example.internal allowed" 0 'endpoint = "http://platform.example.internal.corp"'
# The realm-default rule must not fire on ordinary Apache Iceberg prose.
expect "Apache Iceberg prose allowed"  0 'Apache Iceberg is the table format this platform is built on.'
expect "Iceberg-near-realm prose allowed" 0 'Iceberg tables in the realm are managed by Polaris.'
# The unquoted-form rule requires an assignment/default context (realm then
# :/= then optionally a quote, or realm then a backtick) rather than mere
# proximity — a bare-proximity version produced false positives on ordinary
# prose given this platform's subject matter (Keycloak realms AND Iceberg
# REST catalogs genuinely appear near each other in real sentences).
expect "realm/Iceberg semicolon prose allowed" 0 'Polaris exposes a security realm; Iceberg REST clients authenticate against it directly.'
expect "realm/Iceberg parenthetical allowed" 0 'See the realm (Iceberg REST catalog OAuth2 scope) documentation for details.'
expect "realm = \"iceberg\" assignment caught" 1 'realm = "iceberg"'
# Known accepted false positive, NOT a bug: this sentence is textually
# identical to the YAML form (`realm: iceberg`) the rule exists to catch, so
# it cannot be excluded without also losing that case. Documented, not fixed.
expect "accepted FP: 'Choose a realm: Iceberg...' caught" 1 'Choose a realm: Iceberg tables inherit namespace-level access from it.'
# Internal-path rules added after the DP_DIR hardcoded-default leak.
# `/Users/[a-z]+/git` is .sh-ONLY (see SH_LEAK_RE comment): a home-directory
# checkout path in ordinary published .md/.json prose is not this rule's
# target (vpf-data-ai already catches the real leak), so this case is
# exercised in a .sh file, not the default page.md.
expect "maintainer home-directory checkout path caught (.sh only)" 1 \
  'DP_DIR="${DP_DIR:-/Users/someuser/git/schuberg/data-platform}"' \
  'some-sync-script.sh'
expect "vpf-data-ai group path caught"  1 'gitlab.example.com/vpf-data-ai/chameleon/data-platform'
# sovereign-data.org is NOT gated: the apex domain is this site's own published
# contact address (info@sovereign-data.org, live on the index page since
# 2026-06-09), so a rule on it trips the gate on our own marketing copy. The
# registry subdomain looks internal but cannot be separated from the public
# apex by a substring rule. Asserting the CURRENT behaviour so a future change
# is a deliberate decision rather than an accident.
expect "sovereign-data.org NOT gated (public contact domain)" 0 'email info@sovereign-data.org for a quote'
# .sh scanning specifically: the class of leak that motivated adding .sh to
# SCAN_EXTS (a hardcoded home-directory default in a sync script) must be
# caught when it actually lands in a .sh file, not just a .md fixture.
expect "DP_DIR hardcoded default caught in a real .sh file" 1 \
  'DP_DIR="${DP_DIR:-/Users/someuser/git/schuberg/vpf-data-ai/chameleon/Applications/data-platform}"' \
  'some-sync-script.sh'
# .sh files get the NARROWER rule set: a sanitizer describing its own
# redaction target (e.g. the chameleon.local sed rule in sync-from-dp.sh) must
# not self-trigger just because .sh is now scanned.
expect "sanitizer's own chameleon.local sed rule allowed in .sh" 0 \
  "sed -i '' -e 's/chameleon\\.local/platform.example/g' \"\$DEST\"" \
  'some-sync-script.sh'

# Self-exemption is by the gate's OWN PATH, not a bare basename match — a
# temp-dir copy named leak-scan.sh is NOT exempt (it isn't the real file), but
# the actual repo scripts/ directory is: running the gate against it must not
# flag leak-scan.sh's or leak-scan.test.sh's own regex source / test fixtures.
self_check_out="$TMP/self-check.out"
if bash "$GATE" "$HERE" >"$self_check_out" 2>&1; then
  if grep -qE 'LEAK: .*/(leak-scan\.sh|leak-scan\.test\.sh):' "$self_check_out"; then
    printf '  FAIL  %s\n' "real scripts/ scan flags the gate's own files (should be path-exempt)"
    fails=$((fails+1))
  else
    printf '  PASS  %s\n' "real scripts/ scan does not flag the gate's own files"
  fi
else
  printf '  FAIL  %s\n' "real scripts/ scan aborted unexpectedly (see $self_check_out)"
  fails=$((fails+1))
fi

[ "$fails" -eq 0 ] && echo "leak-scan.test: all passed" || { echo "leak-scan.test: $fails failed"; exit 1; }
