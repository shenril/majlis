#!/usr/bin/env bash
# =============================================================================
# integrations/herdr.sh · report council state to a Herdr pane
# -----------------------------------------------------------------------------
# Usage:  integrations/herdr.sh <verb> <handle> [extra]
# Enable: export MAJLIS_BACKEND=herdr
#
# Majlis members are Claude Code subagents dispatched with the Agent tool: they
# run IN-PROCESS and never occupy their own pane. Herdr detects agents per pane,
# so it sees one Claude Code process, not seven advisors. This adapter does not
# fight that — it ANNOTATES the one pane with which advisor currently holds the
# floor, which is exactly what `report-agent` exists for ("state that is not
# visible in the native terminal UI").
#
# Spawning a pane per advisor is deliberately out of scope: it would abandon the
# Agent tool, lose in-process return values and SendMessage continuity, and
# break the charter's requirement that Jarvis synthesizes member output.
# =============================================================================
set -u

VERB="${1:-}"; HANDLE="${2:-unknown}"

# Not running under Herdr => nothing to talk to. Keeping this test here rather
# than in bin/majlis-report.sh keeps Herdr-specific knowledge in the Herdr file.
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
[ -n "${HERDR_BIN_PATH:-}" ] && [ -x "${HERDR_BIN_PATH}" ] || exit 0

report() {
  "$HERDR_BIN_PATH" pane report-agent "$HERDR_PANE_ID" \
    --source "custom:majlis" --agent "$HANDLE" --state "$1" >/dev/null 2>&1 || true
}

case "$VERB" in
  member_start)   report working ;;
  member_stop)    report working ;;   # the floor returned to the orchestrator
  member_blocked) report blocked ;;   # fires immediately; Herdr's own Claude Code
                                      # blocked detection is strict and lags
  member_release)
    "$HERDR_BIN_PATH" pane release-agent "$HERDR_PANE_ID" \
      --source "custom:majlis" >/dev/null 2>&1 || true
    ;;
esac
exit 0
