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

## Shipped skills (v1)
Majlis v1 ships six reusable skills:

| Skill | Used by | What it does |
|-------|---------|--------------|
| **owner-intake-interview** | any specialist | Structured first-contact interview to build the owner's baseline in a domain; captures answers to the owner profile / requests DB tables from Knowledge Engineer; delivers a baseline summary. |
| **collect-open-tasks** | Jarvis | "Round the table" sweep — polls active members for items genuinely blocked on the owner, dedupes, prioritizes, and digests into one action-first list. |
| **hire-team-member** | Jarvis / Researcher / HR Lead | The self-growing pipeline: Researcher's Expertise Brief → HR Lead designs & onboards the persona → Jarvis delegates the task. |
| **run-review-cadence** | Chief of Staff | Runs the daily/weekly/monthly/quarterly review loop so reviews happen on schedule and change behavior. |
| **goal-pace-check** | Chief of Staff | Proactive surfacing of off-pace KRs, stalled projects, and slipping habits with specifics and numbers. |
| **safe-staged-migration** | Knowledge Engineer | Dry-runs every staged SQL file against a throwaway rebuild from `schema.sql` before it touches the real database. |

## Adding a skill
1. Create `.claude/skills/<skill-name>/SKILL.md` with frontmatter and instructions.
2. Ensure the agents that should use it have `Skill` in their `tools` frontmatter (Researcher,
   Career Coach, Health Coach, Finance Advisor, Chief of Staff, and Knowledge Engineer already do).
3. Keep each skill focused and self-contained — one clear job per skill.

See the Claude Code documentation for the full `SKILL.md` format and capabilities.
