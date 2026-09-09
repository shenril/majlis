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
#
# EXIT CODE IS THE CONTRACT: 0 means PASS and only PASS. A file that parses and
# applies but is NOT idempotent is a FAIL — re-applying it would double-write
# the owner's knowledge base, which is the exact failure this gate exists to
# catch. Never make a non-idempotent file exit 0 "with a warning".
# =============================================================================
set -u
# Resolve the database dir relative to this script, so it works from any CWD.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA="$DIR/schema.sql"
STAGED="${1:?usage: validate_staged.sh <staged.sql> [fixture.sql]}"
FIXTURE="${2:-}"
TMP="$(mktemp -d)"; DB="$TMP/scratch.db"; trap 'rm -rf "$TMP"' EXIT
[ -f "$STAGED" ] || { echo "FAIL: staged file not found: $STAGED"; exit 1; }
[ -f "$SCHEMA" ] || { echo "FAIL: schema.sql not found: $SCHEMA"; exit 1; }

# --- toolchain preflight -----------------------------------------------------
# Checked up front so a missing tool or a feature-less sqlite3 build reports the
# ACTUAL problem. Without this, a build lacking FTS5 fails while loading the
# schema and the error blames schema.sql — sending the reader somewhere else
# entirely. sqlcipher is NOT required: validation runs on a plaintext scratch DB
# and only the owner's apply step needs it.
command -v sqlite3 >/dev/null 2>&1 || {
  echo "FAIL: sqlite3 not found on PATH — required to validate staged SQL."; exit 1; }
if ! sqlite3 ":memory:" "CREATE VIRTUAL TABLE t USING fts5(x);" >/dev/null 2>&1; then
  echo "FAIL: this sqlite3 build lacks FTS5, which schema.sql requires (search_fts)."
  echo "      sqlite3: $(command -v sqlite3)  ($(sqlite3 --version 2>/dev/null | cut -d' ' -f1))"
  exit 1
fi

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
  exit 0
fi

# Parses and applies, but re-running changes state. That is a FAIL: the owner
# applies these by hand and may not remember whether a file already ran, so a
# non-idempotent file silently double-writes the knowledge base.
echo "FAIL: parses and applies, but the 2nd run changed state — NOT idempotent."
echo "      Guard the writes (INSERT OR IGNORE / ON CONFLICT / UPDATE ... WHERE not-already-done)"
echo "      until re-running the file is a clean no-op. Diff of the 2nd apply:"
diff "$TMP/d1" "$TMP/d2" | grep -E '^[<>]' | head -12
exit 1
