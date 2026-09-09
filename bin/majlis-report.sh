#!/usr/bin/env bash
# =============================================================================
# majlis-report.sh · the single hook entry point for runtime integrations
# -----------------------------------------------------------------------------
# Claude Code calls this from .claude/settings.json on subagent lifecycle events.
# It reads the hook JSON on stdin, maps the event to a neutral verb, and hands
# it to the adapter named by $MAJLIS_BACKEND (see integrations/README.md).
#
#   SubagentStart  -> member_start   <handle> <agent_id>
#   SubagentStop   -> member_stop    <handle> <agent_id>
#   Notification   -> member_blocked <handle> <message>
#   Stop           -> member_release <handle>
#
# CONTRACT (all three are load-bearing — do not "improve" them away):
#   1. ALWAYS exit 0. A reporting failure must never break a dispatch.
#   2. Default to the `noop` adapter. Someone who has never heard of Herdr must
#      be completely unaffected by this file existing.
#   3. Never touch the network and never block. Hooks run on every dispatch.
# =============================================================================
set -u

# --- 0) Resolve the backend. Absent/noop => leave immediately. ---------------
BACKEND="${MAJLIS_BACKEND:-noop}"
[ -n "$BACKEND" ] && [ "$BACKEND" != "noop" ] || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ADAPTER="$ROOT/integrations/${BACKEND}.sh"
[ -r "$ADAPTER" ] || exit 0

PAYLOAD="$(cat 2>/dev/null || true)"
[ -n "$PAYLOAD" ] || exit 0

# --- 1) Read one flat string field out of the payload. ----------------------
# Uses jq when available; otherwise a sed fallback that is sufficient for the
# simple slug/uuid values these fields carry (handles, ids, event names).
# The fallback does not understand escaped quotes — acceptable here, and the
# consequence is a missing label, never a failure.
json_str() {
  local key="$1" out=""
  if command -v jq >/dev/null 2>&1; then
    out="$(printf '%s' "$PAYLOAD" | jq -r --arg k "$key" '.[$k] // empty' 2>/dev/null)"
  else
    out="$(printf '%s' "$PAYLOAD" \
      | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1)"
  fi
  printf '%s' "$out"
}

EVENT="$(json_str hook_event_name)"
HANDLE="$(json_str agent_type)"
AGENT_ID="$(json_str agent_id)"
SESSION="$(json_str session_id)"
ORCHESTRATOR="${MAJLIS_ORCHESTRATOR:-jarvis}"

# --- 2) Track who currently holds the floor. --------------------------------
# One marker file per live subagent, newest wins. This is how the documented
# "most recent active advisor" rule survives parallel dispatch: Jarvis can run
# several members at once, but the runtime shows one state for one session.
# Races here are benign — the worst case is a briefly stale label.
STATE_DIR="${TMPDIR:-/tmp}/majlis-report/${SESSION:-nosession}"

mark_start() { [ -n "$AGENT_ID" ] || return 0; mkdir -p "$STATE_DIR" 2>/dev/null || return 0
               printf '%s' "${HANDLE:-unknown}" >"$STATE_DIR/$AGENT_ID" 2>/dev/null || true; }
mark_stop()  { [ -n "$AGENT_ID" ] && rm -f "$STATE_DIR/$AGENT_ID" 2>/dev/null || true; }
mark_clear() { [ -n "${STATE_DIR:-}" ] && rm -rf "$STATE_DIR" 2>/dev/null || true; }

# Newest still-running member, or the orchestrator when the floor is free.
current_holder() {
  local newest
  newest="$(ls -t "$STATE_DIR" 2>/dev/null | head -1)"
  if [ -n "$newest" ] && [ -r "$STATE_DIR/$newest" ]; then
    cat "$STATE_DIR/$newest" 2>/dev/null
  else
    printf '%s' "$ORCHESTRATOR"
  fi
}

# --- 3) Map event -> neutral verb, then dispatch to the adapter. ------------
# The adapter is invoked, never sourced, so it may be written in any language
# and can never corrupt this script's state. Failures are swallowed by design.
emit() { "$ADAPTER" "$@" >/dev/null 2>&1 || true; }

case "$EVENT" in
  SubagentStart)
    mark_start
    emit member_start "${HANDLE:-unknown}" "$AGENT_ID"
    ;;
  SubagentStop)
    mark_stop
    # The parent session resumes work the moment a member returns, so hand the
    # floor back to whoever still holds it rather than reporting idle.
    emit member_stop "$(current_holder)" "$AGENT_ID"
    ;;
  Notification)
    emit member_blocked "$(current_holder)" "$(json_str message)"
    ;;
  Stop)
    mark_clear
    emit member_release "$ORCHESTRATOR"
    ;;
esac

exit 0
