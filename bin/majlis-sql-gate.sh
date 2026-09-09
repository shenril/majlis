#!/usr/bin/env bash
# =============================================================================
# majlis-sql-gate.sh · PostToolUse gate for staged SQL
# -----------------------------------------------------------------------------
# Issue #6 made validate_staged.sh fail correctly on a non-idempotent file, but
# running it was still an instruction in a skill — i.e. dependent on an agent
# remembering. This runs it automatically the moment a staged .sql is written,
# so the gate is enforced by the harness instead.
#
# Non-blocking by design: it reports the failure back to Claude so the agent
# fixes the file, rather than rejecting a write that has already happened.
# =============================================================================
set -u

PAYLOAD="$(cat 2>/dev/null || true)"
[ -n "$PAYLOAD" ] || exit 0

if command -v jq >/dev/null 2>&1; then
  FILE="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
else
  FILE="$(printf '%s' "$PAYLOAD" \
    | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi
[ -n "$FILE" ] || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REL="${FILE#"$ROOT"/}"

# Only staged migrations. schema.sql and inspect.sql are not staged writes.
case "$REL" in
  database/*.sql) ;;
  *) exit 0 ;;
esac
case "$(basename "$REL")" in
  schema.sql|inspect.sql) exit 0 ;;
esac

V="$ROOT/database/validate_staged.sh"
[ -x "$V" ] || exit 0

if ! out="$("$V" "$FILE" 2>&1)"; then
  echo "majlis-sql-gate: $REL did NOT pass the pre-apply gate — do not hand it to the owner." >&2
  echo "$out" >&2
  exit 2
fi
exit 0
