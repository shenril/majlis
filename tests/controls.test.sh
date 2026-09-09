#!/usr/bin/env bash
# =============================================================================
# tests/controls.test.sh · the runtime controls must actually refuse things.
# Asserts on EXIT CODES: 0 allows, 2 blocks.
# =============================================================================
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/bin/majlis-guard.sh"; GATE="$ROOT/bin/majlis-sql-gate.sh"
export CLAUDE_PROJECT_DIR="$ROOT"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "  ok   — $1"; }
no(){ FAIL=$((FAIL+1)); echo "  FAIL — $1 ($2)"; }

fire(){ printf '{"hook_event_name":"PreToolUse","agent_type":"%s","tool_name":"Write","tool_input":{"file_path":"%s/%s"}}' "$1" "$ROOT" "$2" | "$GUARD" >/dev/null 2>&1; echo $?; }
main(){ printf '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s/%s"}}' "$ROOT" "$1" | "$GUARD" >/dev/null 2>&1; echo $?; }

echo "== majlis-guard.sh (lane guard)"
[ "$(fire health-coach '.claude/agents/finance-advisor.md')" = 2 ] \
  && ok "advisor blocked from editing a member definition" || no "advisor blocked from member definition" "$(fire health-coach '.claude/agents/finance-advisor.md')"
[ "$(fire hr-lead '.claude/agents/new-hire.md')" = 0 ] \
  && ok "HR Lead allowed to write member definitions (its lane)" || no "hr-lead allowed" "$(fire hr-lead '.claude/agents/new-hire.md')"
[ "$(fire health-coach 'templates/advisors/health/agent.md')" = 2 ] \
  && ok "advisor blocked from editing install templates" || no "templates blocked" "$(fire health-coach 'templates/advisors/health/agent.md')"
[ "$(fire health-coach "Team's brain/finance-advisor/notes.md")" = 2 ] \
  && ok "advisor blocked from another member's brain folder" || no "cross-brain blocked" "$(fire health-coach "Team's brain/finance-advisor/notes.md")"
[ "$(fire health-coach "Team's brain/health-coach/notes.md")" = 0 ] \
  && ok "advisor allowed in its OWN brain folder" || no "own brain allowed" "$(fire health-coach "Team's brain/health-coach/notes.md")"
[ "$(fire health-coach "Owner's Inbox/plan.md")" = 0 ] \
  && ok "normal deliverable write is unaffected" || no "deliverable allowed" "$(fire health-coach "Owner's Inbox/plan.md")"
[ "$(main '.claude/agents/anything.md')" = 0 ] \
  && ok "main thread (the owner) is never restricted" || no "main thread allowed" "$(main '.claude/agents/anything.md')"

echo "== majlis-sql-gate.sh (staged SQL)"
gate(){ printf '{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1" | "$GATE" >/dev/null 2>&1; echo $?; }
[ "$(gate "$ROOT/tests/fixtures/idempotent.sql")" = 0 ] \
  && ok "idempotent staged file passes the automatic gate" || no "idempotent passes" "$(gate "$ROOT/tests/fixtures/idempotent.sql")"
[ "$(gate "$ROOT/tests/fixtures/non_idempotent.sql")" = 0 ] \
  && ok "non-staged path ignored (fixtures live outside database/)" || no "path scoping" "$(gate "$ROOT/tests/fixtures/non_idempotent.sql")"
cp "$ROOT/tests/fixtures/non_idempotent.sql" "$ROOT/database/_gate_probe.sql"
[ "$(gate "$ROOT/database/_gate_probe.sql")" = 2 ] \
  && ok "non-idempotent file in database/ is reported back" || no "bad staged file blocked" "$(gate "$ROOT/database/_gate_probe.sql")"
rm -f "$ROOT/database/_gate_probe.sql"
[ "$(gate "$ROOT/database/schema.sql")" = 0 ] \
  && ok "schema.sql is exempt (not a staged write)" || no "schema exempt" "$(gate "$ROOT/database/schema.sql")"
[ "$(gate "$ROOT/README.md")" = 0 ] \
  && ok "non-SQL writes are ignored" || no "non-sql ignored" "$(gate "$ROOT/README.md")"

echo "== $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
