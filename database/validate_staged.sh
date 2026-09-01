#!/bin/bash
# =============================================================================
# validate_staged.sh · Knowledge Engineer — PRE-APPLY GATE for staged SQL
# -----------------------------------------------------------------------------
# USAGE:  database/validate_staged.sh <staged.sql> [fixture.sql]
#
# Builds a THROWAWAY plaintext SQLite DB from database/schema.sql (the canonical
# structure), optionally seeds [fixture.sql] (minimal rows so a guarded UPDATE/
# INSERT path is actually exercised), then `.read`s <staged.sql> under `.bail on`
# and reports PASS/FAIL with the exact parse error / missing-column / phantom-
# object. Re-applies a second time and diffs the full .dump to confirm idempotency
# (a correct staged file's 2nd run changes nothing).
#
# It NEVER touches the encrypted knowledge.db — schema-only, plaintext scratch.
# Run this on every staged file BEFORE it reaches the owner's terminal.
# =============================================================================
set -u
# Resolve the database dir relative to this script, so it works from any CWD.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA="$DIR/schema.sql"
STAGED="${1:?usage: validate_staged.sh <staged.sql> [fixture.sql]}"
FIXTURE="${2:-}"
TMP="$(mktemp -d)"; DB="$TMP/scratch.db"; trap 'rm -rf "$TMP"' EXIT
[ -f "$STAGED" ] || { echo "FAIL: staged file not found: $STAGED"; exit 1; }

hdr(){ echo "== validate: $(basename "$STAGED") ${FIXTURE:+(fixture: $(basename "$FIXTURE"))}"; }
errlines(){ grep -iE "error|no such|no column|has no column|constraint|syntax|misuse" | head -6; }
# run a sqlite session (dot-commands + sql) via STDIN; return sqlite exit code
run(){ sqlite3 "$DB" 2>"$TMP/e"; }

# 1) schema
if ! printf '.bail on\n.read %s\n' "$SCHEMA" | run; then
  hdr; echo "FAIL: schema.sql did not load:"; errlines <"$TMP/e"; exit 1; fi
# 2) fixture (optional)
if [ -n "$FIXTURE" ]; then
  if ! printf '.bail on\nPRAGMA foreign_keys=ON;\n.read %s\n' "$FIXTURE" | run; then
    hdr; echo "FAIL: fixture did not load:"; errlines <"$TMP/e"; exit 1; fi
fi
# 3) first apply
out1=$(printf '.bail on\nPRAGMA foreign_keys=ON;\n.read %s\n' "$STAGED" | sqlite3 "$DB" 2>&1)
if [ $? -ne 0 ]; then
  hdr; echo "FAIL: staged file errored on FIRST apply:"; echo "$out1" | errlines; exit 1; fi
sqlite3 "$DB" ".dump" >"$TMP/d1" 2>/dev/null
# 4) second apply (idempotency / re-runnability)
out2=$(printf '.bail on\nPRAGMA foreign_keys=ON;\n.read %s\n' "$STAGED" | sqlite3 "$DB" 2>&1)
if [ $? -ne 0 ]; then
  hdr; echo "FAIL: staged file errored on SECOND apply (not re-runnable):"; echo "$out2" | errlines; exit 1; fi
sqlite3 "$DB" ".dump" >"$TMP/d2" 2>/dev/null

hdr
if diff -q "$TMP/d1" "$TMP/d2" >/dev/null; then
  echo "PASS: parses, applies, idempotent (2nd run = no state change)."
else
  echo "PASS (parses+applies) — WARNING: 2nd run changed state, NOT idempotent:"
  diff "$TMP/d1" "$TMP/d2" | grep -E '^[<>]' | head -12
fi
