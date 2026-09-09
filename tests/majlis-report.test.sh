#!/usr/bin/env bash
# =============================================================================
# tests/majlis-report.test.sh · drive bin/majlis-report.sh with recorded hook
# payloads and assert the verbs it emits. Uses the `log` adapter as the probe.
# No dependencies beyond bash. Run: tests/majlis-report.test.sh
# =============================================================================
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT="$ROOT/bin/majlis-report.sh"
PASS=0; FAIL=0

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export CLAUDE_PROJECT_DIR="$ROOT"
export MAJLIS_LOG_FILE="$TMP/events.jsonl"

ok(){ PASS=$((PASS+1)); echo "  ok   — $1"; }
no(){ FAIL=$((FAIL+1)); echo "  FAIL — $1"; echo "         $2"; }

# Feed one hook payload. Each case gets a fresh session id so the marker-file
# state from a previous case can never leak into the next.
fire(){ printf '%s' "$1" | "$REPORT"; }
reset(){ : >"$MAJLIS_LOG_FILE"; SID="s$RANDOM$RANDOM"; }
log(){ cat "$MAJLIS_LOG_FILE" 2>/dev/null; }

payload(){ # <event> [agent_type] [agent_id] [message]
  printf '{"hook_event_name":"%s","session_id":"%s","agent_type":"%s","agent_id":"%s","message":"%s"}' \
    "$1" "$SID" "${2:-}" "${3:-}" "${4:-}"
}

echo "== majlis-report.sh"

# --- default-off is the headline guarantee ----------------------------------
reset; unset MAJLIS_BACKEND 2>/dev/null || true
fire "$(payload SubagentStart health-coach a1)"
[ ! -s "$MAJLIS_LOG_FILE" ] \
  && ok "no MAJLIS_BACKEND => nothing emitted" \
  || no "no MAJLIS_BACKEND => nothing emitted" "$(log)"

reset; MAJLIS_BACKEND=noop fire "$(payload SubagentStart health-coach a1)"
[ ! -s "$MAJLIS_LOG_FILE" ] \
  && ok "explicit noop => nothing emitted" \
  || no "explicit noop => nothing emitted" "$(log)"

export MAJLIS_BACKEND=log

# --- the advisor is named, not just "something is running" ------------------
reset; fire "$(payload SubagentStart health-coach a1)"
grep -q '"verb":"member_start","handle":"health-coach"' "$MAJLIS_LOG_FILE" \
  && ok "SubagentStart names the advisor from agent_type" \
  || no "SubagentStart names the advisor from agent_type" "$(log)"

# --- floor returns to the orchestrator, not to idle -------------------------
reset; fire "$(payload SubagentStart health-coach a1)"; fire "$(payload SubagentStop health-coach a1)"
grep -q '"verb":"member_stop","handle":"jarvis"' "$MAJLIS_LOG_FILE" \
  && ok "SubagentStop hands the floor back to the orchestrator" \
  || no "SubagentStop hands the floor back to the orchestrator" "$(log)"

# --- parallel dispatch: newest still-running advisor wins -------------------
reset
fire "$(payload SubagentStart health-coach a1)"
sleep 1                                   # ls -t needs a distinguishable mtime
fire "$(payload SubagentStart finance-advisor a2)"
fire "$(payload Notification '' '' 'needs your input')"
grep -q '"verb":"member_blocked","handle":"finance-advisor"' "$MAJLIS_LOG_FILE" \
  && ok "parallel dispatch reports the most recent advisor" \
  || no "parallel dispatch reports the most recent advisor" "$(log)"

# --- and falls back once that advisor returns -------------------------------
fire "$(payload SubagentStop finance-advisor a2)"
: >"$MAJLIS_LOG_FILE"
fire "$(payload Notification '' '' 'still blocked')"
grep -q '"verb":"member_blocked","handle":"health-coach"' "$MAJLIS_LOG_FILE" \
  && ok "floor falls back to the advisor still running" \
  || no "floor falls back to the advisor still running" "$(log)"

# --- Stop releases and clears state -----------------------------------------
reset; fire "$(payload SubagentStart health-coach a1)"; fire "$(payload Stop)"
grep -q '"verb":"member_release","handle":"jarvis"' "$MAJLIS_LOG_FILE" \
  && ok "Stop emits member_release" \
  || no "Stop emits member_release" "$(log)"
[ ! -d "${TMPDIR:-/tmp}/majlis-report/$SID" ] \
  && ok "Stop clears the session marker directory" \
  || no "Stop clears the session marker directory" "state dir survived"

# --- robustness: a hook must never break a dispatch -------------------------
reset
printf 'not json at all' | "$REPORT"; rc=$?
[ $rc -eq 0 ] && ok "malformed payload still exits 0" || no "malformed payload still exits 0" "rc=$rc"

reset; MAJLIS_BACKEND=does-not-exist fire "$(payload SubagentStart health-coach a1)"; rc=$?
[ $rc -eq 0 ] && ok "unknown backend still exits 0" || no "unknown backend still exits 0" "rc=$rc"

reset; printf '%s' "$(payload UnhandledEvent x y)" | "$REPORT"; rc=$?
[ $rc -eq 0 ] && [ ! -s "$MAJLIS_LOG_FILE" ] \
  && ok "unhandled event is ignored cleanly" \
  || no "unhandled event is ignored cleanly" "rc=$rc $(log)"

echo "== $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
