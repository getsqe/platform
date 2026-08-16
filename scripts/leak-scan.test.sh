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
# Public product identifiers must NOT be treated as leaks.
expect "chameleon_ resource allowed"   0 'resource "chameleon_workspace" "team_a" {}'
expect "terraform registry allowed"    0 'source = "registry.terraform.io/schubergphilis/chameleon"'
# Regression guards: placeholders must be anchored, not bare substring strips.
expect "realms/example-prod caught"    1 'curl "$KC/realms/example-prod/protocol/openid-connect/token"'
expect "platform.example.internal allowed" 0 'endpoint = "http://platform.example.internal.corp"'

[ "$fails" -eq 0 ] && echo "leak-scan.test: all passed" || { echo "leak-scan.test: $fails failed"; exit 1; }
