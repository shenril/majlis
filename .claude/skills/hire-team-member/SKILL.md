---
name: hire-team-member
description: The self-growing team pipeline. Use when a request needs expertise no current member has. Runs Jarvis → Researcher (Expertise Brief) → HR Lead (design & onboard the persona, write the agent file, register in roster) → delegate the original task. Grounds every hire in research so each AI persona mirrors a strong human expert.
---

# Hire a Team Member

How the team grows itself. When no existing member fits a request, run this pipeline **before**
attempting the work — never force a bad-fit member onto a specialist task.

## When to trigger
- A request needs a domain **no current member owns** (check `team/roster.md` first).
- The best-fit existing member would be a stretch outside their sharp scope.
- Do NOT trigger to duplicate a role that already exists — adapt the existing member instead.

## The pipeline
1. **Jarvis → Researcher (research).** Jarvis dispatches Researcher to produce an **Expertise Brief**:
   what a real, expert human in that domain actually does — core skills, tools, methods, typical
   deliverables, vocabulary, and the quality bar. Grounded in real sources, concrete not generic.
2. **Jarvis → HR Lead (design & onboard).** HR Lead turns the brief into a persona: a memorable
   name, identity/voice, a sharp system prompt, the minimal correct toolset, and an explicit
   scope (what they own AND what they do NOT do). HR Lead **writes the agent file** to
   `.claude/agents/<name>.md` and **registers** the hire in `team/roster.md`.
3. **Jarvis delegates the original task** to the freshly hired member.

**Separation of duties:** Researcher researches (never designs agents); HR Lead designs (never
invents skills from scratch — grounds them in Researcher's brief); Jarvis orchestrates (never does
the work). Members execute; nobody but Jarvis orchestrates.

## Expertise Brief template (Researcher's output)
```
# Expertise Brief — <role>

## Role summary
<one paragraph: what this expert does>

## Core competencies
- <concrete skills a top practitioner has>

## Tools & technologies
- <what they actually use day-to-day>

## Methodologies & frameworks
- <how they approach the work; name real frameworks>

## Domain vocabulary
<key terms/jargon the persona must know and use correctly>

## Typical deliverables
- <the outputs this role produces>

## Quality bar & standards
<what separates great from mediocre in this field>

## Adjacent skills / red flags
<what they should also know; common pitfalls; safety/regulatory lines>

## Sources
<references relied on>
```

## Agent-file format (HR Lead's output → `.claude/agents/<name>.md`)
```
---
name: <lowercase-handle>              # the subagent_type Jarvis dispatches
description: <when to use this member; what they own; what they do NOT do>
tools: <minimal correct set>          # e.g. Read, Write, Edit, Bash, Glob, Grep, ToolSearch, Skill
model: <opus | sonnet | haiku>        # opus for judgment-heavy roles
---

# You are <Name> — <Role>

## Identity & Persona
<personality, voice, one-line signature; how the owner addresses them; reports to Jarvis>

## Mission
<the outcome this member exists to produce>

## Scope — what you OWN / what you do NOT do
<sharp boundaries; respect separation of duties; any hard safety guardrails>

## Operating knowledge / standards
<frameworks, methods, vocabulary, quality bar — traceable to Researcher's brief>

## When you finish
<return-value discipline: the final message is what Jarvis receives — complete, not chatter>
```

## Checklist before delegating the task
- [ ] Expertise Brief exists and is concrete (Researcher).
- [ ] Persona has a distinct name (no collision with existing members).
- [ ] Scope has explicit "do / do NOT" boundaries + any safety guardrails.
- [ ] Toolset is least-privilege; `ToolSearch` added if the member must discover tools/skills.
- [ ] Agent file written to `.claude/agents/<name>.md` with valid frontmatter.
- [ ] Row added to `team/roster.md` (name, role, persona, owns, `subagent_type`, hired date).
- [ ] Jarvis delegates the original task to the new member.
