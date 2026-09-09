#!/usr/bin/env bash
# =============================================================================
# integrations/log.sh · append council lifecycle events as JSONL
# -----------------------------------------------------------------------------
# Usage:  integrations/log.sh <verb> <handle> [extra]
# Enable: export MAJLIS_BACKEND=log
#
# Useful with no agent runtime at all — it makes dispatch auditable on its own,
# and it is what the test suite asserts against. Writes into Jarvis's brain
# folder, which .gitignore already excludes from version control.
# =============================================================================
set -u

VERB="${1:-}"; HANDLE="${2:-unknown}"; EXTRA="${3:-}"
ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Kept on its own line: an apostrophe inside a ${x:-default} expansion confuses
# the bash parser, and the brain folder is literally named "Team's brain".
DEFAULT_OUT="$ROOT/Team's brain/jarvis/agent-events.jsonl"
OUT="${MAJLIS_LOG_FILE:-$DEFAULT_OUT}"

mkdir -p "$(dirname "$OUT")" 2>/dev/null || exit 0

esc() { printf '%s' "${1:-}" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr -d '\n\r'; }

printf '{"ts":"%s","verb":"%s","handle":"%s","extra":"%s"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(esc "$VERB")" "$(esc "$HANDLE")" "$(esc "$EXTRA")" \
  >>"$OUT" 2>/dev/null || true
exit 0
