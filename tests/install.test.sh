#!/usr/bin/env bash
# =============================================================================
# tests/install.test.sh · the installer must render a council, and must retire
# what it no longer produces WITHOUT touching anything it did not generate.
# =============================================================================
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "  ok   — $1"; }
no(){ FAIL=$((FAIL+1)); echo "  FAIL — $1 ($2)"; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
( cd "$ROOT" && git ls-files -c -z 2>/dev/null | tar -cf - --null -T - ) | ( cd "$W" && tar -xf - )
cd "$W" || exit 1

echo "== install.py"

printf 'knowledge: Data Steward\nplanning: Operations Lead\nhealth: Wellness Coach\n' > answers1.yml
python3 install.py --answers answers1.yml >/dev/null 2>&1
[ -f .claude/agents/data-steward.md ] && ok "renders an advisor under its slugified handle" \
  || no "renders advisor" "watari.md missing"
[ "$(sed -n '2p' .claude/agents/wellness-coach.md)" = "name: wellness-coach" ] \
  && ok "frontmatter name is the slug of the display name" \
  || no "slug in frontmatter" "$(sed -n '2p' .claude/agents/wellness-coach.md)"
[ -f .claude/skills/data-steward-intake/SKILL.md ] && ok "each advisor gets its own intake skill" \
  || no "intake skill" "missing"
[ ! -f .claude/agents/finance-advisor.md ] && ok "an unchosen elective is not installed" \
  || no "unchosen elective absent" "present"
grep -rq "Finance Advisor\|Career Coach" .claude/agents .claude/skills team/roster.md team/owner-profile.md 2>/dev/null \
  && no "no textual trace of unchosen electives" "found a mention" \
  || ok "no textual trace of unchosen electives"

# A member added by the hiring pipeline is NOT ours to delete.
cat > .claude/agents/hired-scout.md <<'AGENT'
---
name: hired-scout
description: added by the hiring pipeline, not by install.py
---
AGENT

printf 'knowledge: Chief Librarian\nplanning: Operations Lead\nhealth: Wellness Coach\n' > answers2.yml
out="$(python3 install.py --answers answers2.yml 2>&1)"

[ ! -f .claude/agents/data-steward.md ] && ok "renaming an advisor retires the old agent file" \
  || no "old agent retired" "data-steward.md survived"
[ ! -d .claude/skills/data-steward-intake ] && ok "renaming retires the old intake skill" \
  || no "old intake retired" "data-steward-intake survived"
[ -f .claude/agents/chief-librarian.md ] && ok "the renamed advisor is installed" || no "new advisor" "missing"
[ -f .claude/agents/hired-scout.md ] && ok "a hired member is never pruned" \
  || no "hired member preserved" "DELETED — pruning is too aggressive"
[ -d "Team's brain/data-steward" ] && ok "working memory is preserved across a rename" \
  || no "brain preserved" "deleted"
printf '%s' "$out" | grep -q "Team's brain/data-steward/" && ok "orphaned brain folders are reported" \
  || no "orphan reported" "not mentioned"
[ -f .claude/agents/operations-lead.md ] && ok "an unchanged advisor survives a re-run" \
  || no "unchanged advisor" "missing"

python3 install.py --defaults >/dev/null 2>&1
[ "$(ls .claude/agents/*.md | wc -l | tr -d ' ')" = "8" ] \
  && ok "--defaults installs all 5 advisors + 2 core + the hired member" \
  || no "defaults count" "$(ls .claude/agents/*.md | wc -l | tr -d ' ')"
grep -rq '\${' .claude/agents team/roster.md team/owner-profile.md 2>/dev/null \
  && no "no unresolved placeholders" "found one" || ok "no unresolved placeholders"

echo "== $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
