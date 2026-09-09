# Skills

This directory holds reusable **Claude Code skills** — self-contained `SKILL.md` packages that
any Majlis agent can invoke via the **Skill** tool.

## How skills work
A skill is a folder containing a `SKILL.md` file (plus any supporting scripts, templates, or
reference files it needs):

```
.claude/skills/
└── <skill-name>/
    └── SKILL.md        ← the skill definition (name, description, instructions)
```

`SKILL.md` uses frontmatter (`name`, `description`) followed by instructions. When an agent has
the `Skill` tool and a task matches a skill's description, Claude Code can load and run it. This
lets you package a repeatable methodology (e.g. a deep-research workflow, a document formatter, a
data-import routine) once and reuse it across agents.

## Shipped skills

Five reusable skills are tracked here. A sixth kind — the **per-advisor intake interview** — is
*generated*: `install.py` renders `<handle>-intake` for each installed advisor from
`templates/shared/intake-spine.md` plus that advisor's own question set. Those folders are
git-ignored build artifacts, so they will not appear in a fresh clone.

| Skill | Used by | What it does |
|-------|---------|--------------|
| **collect-open-tasks** | Jarvis | "Round the table" sweep — polls active members for items genuinely blocked on the owner, dedupes, prioritizes, and digests into one action-first list. |
| **hire-team-member** | Jarvis / Researcher / HR Lead | The self-growing pipeline: Researcher's Expertise Brief → HR Lead designs & onboards the persona → Jarvis delegates the task. |
| **run-review-cadence** | the planning advisor | Runs the daily/weekly/monthly/quarterly review loop so reviews happen on schedule and change behavior. |
| **goal-pace-check** | the planning advisor | Proactive surfacing of off-pace KRs, stalled projects, and slipping habits with specifics and numbers. |
| **safe-staged-migration** | the data specialist | Dry-runs every staged SQL file against a throwaway rebuild from `schema.sql` before it touches the real database. |

## Adding a skill
1. Create `.claude/skills/<skill-name>/SKILL.md` with frontmatter and instructions.
2. Ensure the agents that should use it have `Skill` in their `tools` frontmatter — Researcher and
   every shipped advisor template already do. Advisor templates live in `templates/advisors/`.
3. Keep each skill focused and self-contained — one clear job per skill.

See the Claude Code documentation for the full `SKILL.md` format and capabilities.
