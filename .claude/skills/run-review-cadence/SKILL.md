---
name: run-review-cadence
description: Run the daily/weekly/monthly/quarterly review loop that keeps a goal system honest. Use when it's time for a scheduled review, when the owner asks "where do things stand", or before setting the next period's outcomes. Pulls current numbers (goal/KR pace, habit adherence, open tasks, off-pace items, stalled projects, overdue follow-ups), proactively surfaces what's slipping, produces a numbers-loaded review scaffold for the owner to complete, then records the review via the safe-staged-migration skill.
---

# Run the review cadence

A goal system without review is the cardinal sin — goals drift, habits slip, and
"motion" gets mistaken for "progress". This skill runs the review loop that turns
intentions into a tracked, accountable system. Reviews must **change behavior**,
not just be logged.

## When each cadence runs

| Cadence | Cadence trigger | Duration | What it measures |
|---|---|---|---|
| **Daily** | End of day / start of next | ~5 min | Did the day's 1–3 MITs ship? Habit check-ins logged? Loose ends captured? Tomorrow's MITs set? |
| **Weekly** | Same weekday each week (keystone) | 30–60 min | Outcomes vs the weekly scorecard, execution %, habit adherence %, projects & next-actions reviewed, inboxes to zero, next week's 1–3 outcomes |
| **Monthly** | First/last day of month | ~30 min | Monthly goal progress, score the quarter's key results, review ongoing-area health, adjust habits |
| **Quarterly** | End of the execution cycle | ~60–90 min | Score objectives/key results 0.0–1.0, retro (stop/start/continue), set next quarter, refresh the cycle plan against the annual direction |

The **weekly review is the keystone — never skip it.** Everything else can slip a
day; the weekly cannot.

## Steps (every cadence follows the same shape)

### 1. Pull the current numbers (never review from memory)
Query the live data and load real figures before writing a word of prose:

- **Goals / key results with pace** — current value vs target, and the pace signal
  (on/ahead/behind the linear line to the deadline). For any dated goal, run the
  **`goal-pace-check`** skill rather than eyeballing it.
- **Habit adherence over OBSERVED days** — adherence % against each habit's
  frequency target over a rolling window (e.g. 7-day and 30-day), plus current and
  longest streak and the trend. Measure adherence-vs-target, not naive streaks: a
  5×/week habit done 5× is 100%, not a broken chain.
- **Open tasks / next-actions** — what's due, what's overdue, what's a
  next-action vs a stalled project.
- **Off-pace items** — key results behind the linear pace toward target.
- **Stalled projects** — no activity for N days; each should have a defined next
  action.
- **Overdue follow-ups** — people/threads past their contact cadence.

### 2. Proactively surface what's slipping — with specifics and numbers
This is the behavior that earns the review its keep. Never nag vaguely. State each
slip with the number and the required correction, e.g.:

- "Week 8 of 12, KR2 at 40% — needs ~+8%/wk to land at 0.7."
- "Habit X adherence 3/7 this week (target 5) — below frequency target two weeks
  running."
- "Project Y: no activity 11 days; no next-action defined."
- "Goal Z has no linked next-action — the cascade is broken there."

### 3. Produce the review scaffold (numbers pre-loaded, prose blank)
Reduce the owner's cognitive load: you load every number; the owner supplies only
judgment. Hand back a scaffold with **numbers filled in and prose fields blank**
(see the template below). Never write the owner's reflections for them.

### 4. Record the review
Persist the completed review (wins / lessons / adjustments, plus a snapshot of the
scores) to the datastore by staging the write through the **`safe-staged-migration`**
skill — do NOT hand-edit the database. That skill owns schema and safe data writes;
you supply the row content, it stages, validates, and gates the apply. Cite any
journal entries in the review's lessons.

## Reusable weekly-review scaffold template

Copy this, replace `<...>` placeholders with pulled numbers, leave the prose fields
blank for the owner.

```markdown
# Weekly Review — <YYYY-MM-DD> to <YYYY-MM-DD>  (Week <n> of <N>)

## Numbers (pre-loaded — do not edit)
- Execution %: <planned tactics completed>/<planned> = <pct>%   (target ~85%)
- Outcomes set last week: <n> · hit: <n>
- Key results (pace):
  - <KR-1 desc>: <current> / <target> — <on/ahead/behind> pace (<attainment>)
  - <KR-2 desc>: <current> / <target> — <on/ahead/behind> pace (<attainment>)
- Habit adherence (7d · 30d vs target):
  - <habit-1>: <x/target this week> · <30d %>  (streak <cur>/<longest>, trend <up/flat/down>)
  - <habit-2>: <x/target this week> · <30d %>
- Off-pace / slipping (surfaced):
  - <item — number — required correction>
- Stalled projects: <name — days idle — next action?>
- Overdue follow-ups: <who — days overdue>

## Part 1 — What moved (owner)
<blank>

## Part 2 — What slipped (owner)
<blank>

## Part 3 — Lessons (owner)
<blank>

## Part 4 — Next period's 1–3 outcomes (owner)
1. <blank>
2. <blank>
3. <blank>
```

Adapt the same four-part shape (what moved / what slipped / lessons / next
outcomes) for daily (lighter), monthly, and quarterly (add KR scores 0.0–1.0 and a
stop/start/continue retro) cadences.

## Quality bar
- Numbers are pulled fresh, never remembered.
- Every slip is surfaced with a specific number and a required correction.
- The scaffold hands the owner judgment work only — cognitive load goes down.
- The review is recorded via `safe-staged-migration` and used to change behavior.
- Dated-goal pace is always computed with `goal-pace-check`, never asserted.
```
