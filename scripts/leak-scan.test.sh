#!/usr/bin/env bash
# Behavioural tests for the publish-safety gate. Run: bash scripts/leak-scan.test.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/leak-scan.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

expect () { # <desc> <want-exit> <file-content>
  local desc="$1" want="$2" body="$3"
  rm -rf "$TMP/c"; mkdir -p "$TMP/c"
  printf '%s\n' "$body" > "$TMP/c/page.md"
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

[ "$fails" -eq 0 ] && echo "leak-scan.test: all passed" || { echo "leak-scan.test: $fails failed"; exit 1; }
