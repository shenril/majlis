#!/usr/bin/env bash
# =============================================================================
# tests/validate-staged.test.sh · the pre-apply gate must gate.
#
# Asserts on EXIT CODES, not printed text — the bug this fixes (#6) was a script
# that printed a verdict its exit code contradicted.
# =============================================================================
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
V="$ROOT/database/validate_staged.sh"
F="$ROOT/tests/fixtures"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "  ok   — $1"; }
no(){ FAIL=$((FAIL+1)); echo "  FAIL — $1"; echo "         $2"; }

echo "== validate_staged.sh"

out=$("$V" "$F/idempotent.sql" 2>&1); rc=$?
[ $rc -eq 0 ] && ok "idempotent fixture exits 0" \
              || no "idempotent fixture exits 0" "rc=$rc :: $out"
printf '%s' "$out" | grep -q "^PASS:" && ok "idempotent fixture reports PASS" \
                                      || no "idempotent fixture reports PASS" "$out"

out=$("$V" "$F/non_idempotent.sql" 2>&1); rc=$?
[ $rc -ne 0 ] && ok "non-idempotent fixture exits NON-ZERO (the #6 bug)" \
              || no "non-idempotent fixture exits NON-ZERO (the #6 bug)" "rc=$rc :: $out"
printf '%s' "$out" | grep -q "^FAIL:" && ok "non-idempotent fixture reports FAIL, not PASS" \
                                      || no "non-idempotent fixture reports FAIL, not PASS" "$out"
printf '%s' "$out" | grep -q "^PASS" && no "verdict line must not start with PASS" "$out" \
                                     || ok "no PASS anywhere in a failing verdict"

out=$("$V" "$F/does-not-exist.sql" 2>&1); rc=$?
[ $rc -ne 0 ] && ok "missing staged file exits non-zero" \
              || no "missing staged file exits non-zero" "rc=$rc :: $out"

echo "== $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
