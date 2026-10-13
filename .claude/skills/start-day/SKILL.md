---
name: start-day
description: The owner's morning kickoff — the cue that starts the day. Use when the owner starts their working day, asks what they should focus on, runs /start-day, or when a scheduled morning trigger fires. Reads yesterday's close, confirms today's 1-3 MITs rather than re-eliciting them, carries forward any if-then plan, and names only what is genuinely due today. Writes today's dated file to the planning advisor's working memory — it stages no SQL, and it deliberately does not report off-pace goals or anything the weekly review owns.
---

# Start of day — the morning cue

Run by the **planning advisor** (see `team/roster.md` for who that is on this council).

This is the morning half of the daily cadence. `end-day` closes yesterday and decides today;
this skill **starts** it. Its job is to be the cue that gets the owner moving, not to brief them.

> **Three lines and one question.** The owner is beginning work, not attending a status meeting.
> If they have to read a report before answering, this has failed.

## The one rule

**Confirm, don't re-elicit.**

If `end-day` ran last night, today's MITs are already decided — ask whether they still hold, not
what they should be. Re-asking a question the owner already answered wastes the decision they
made when they had better context than they have at 8am.

Only ask fresh when there is genuinely nothing to confirm.

## Steps

### 1. Load silently

Read, and say none of it out loud:

- **Yesterday's file** in your own working memory (`daily/<YYYY-MM-DD>.md`) — what shipped, what
  rolled, the MITs it set for today, and any if-then plan it captured.
- **What is genuinely due today.** If the owner uses the knowledge base: habits due
  (`v_habits_due_today`), follow-ups dated today (`v_followups_due`), today's agenda
  (`v_daily_agenda`). If not, the commitments named in yesterday's file.
- **Today's real load**, if the owner has told you about it. A day with five hours of meetings
  cannot hold three MITs, and saying so now is worth more than saying so tonight.

### 2. Give three lines, maximum

A cue, not a digest:

> "Yesterday: deep-work block shipped, vendor email rolled.
> Today: finish the migration doc, call the accountant.
> Heads-up — the 2pm runs long, so the doc needs the morning."

That is the ceiling, not the target. Two lines is better. **Never paginate the knowledge base at
the owner**: the views are your input, and three lines are the output. The charter is explicit
that verbosity belongs in `Owner's Inbox/`, not in conversation.

### 3. Ask one question

When yesterday set MITs:

> "Still the right two?"

When it didn't, or there is no file:

> "What's your one thing today?"

Then stop. Let them answer before you write anything.

### 4. Re-cut the day if the answer calls for it

If the owner changes a MIT, takes one out, or tells you the day just filled up, adjust without
argument and without a lecture about commitment. **Three MITs is the ceiling; one is a perfectly
good day.** If they offer four, make them choose.

Where yesterday captured an if-then plan, restate it once as a reminder — then let it go:

> "Still: when the 9am runs long, the block moves to after lunch."

### 5. Open the day

End with a single line and nothing after it:

> "Day open. First: <MIT 1>."

No encouragement, no summary, no second question. The owner should be working within a few seconds
of reading it.

## What you write

Create or update today's file in **your own** working memory —
`Team's brain/<your-handle>/daily/<YYYY-MM-DD>.md`:

```markdown
# <YYYY-MM-DD> — day open <HH:MM>

## MITs
- <MIT 1>
- <MIT 2>

## Carried in
- <item the owner re-committed to at end-day, if any>
- if-then: when <obstacle>, then <action>

## Due today
- habits: walk, reading
- follow-up: <name> re <thing>
```

`end-day` appends to this same file tonight — results, habit check-ins, tomorrow. One file per
day, written at both ends.

## What you do NOT do

- **Do not stage SQL.** Same contract as `end-day`: the daily ritual writes Markdown, and the
  weekly review reconciles the week into the knowledge base in one staged, owner-applied write.
  A morning cue that ends in a keyed SQLCipher session is a morning cue nobody runs.
- **Do not report off-pace goals, stalled projects, or slipping habit adherence.** That is the
  weekly review's job, and 8am is the worst possible moment for it. A goal that is behind will
  still be behind on Sunday, when there is time to do something about it.
- **Do not run the blocked-on-you sweep.** `collect-open-tasks` owns that, and it is a separate
  question the owner asks when they want it.
- **Do not scold a missing `end-day`.** If last night's file is absent, just ask fresh. The ritual
  has to survive being skipped, or it will be skipped permanently.
- **Do not list everything due this week.** Only what is genuinely actionable today.

## When there is no yesterday

First run, a skipped evening, or a fresh install: there is nothing to confirm and nothing to
carry. Ask "What's your one thing today?", write the file, open the day. **Do not** backfill, do
not interview, and do not send the owner to the intake — a cold start is a one-question day, same
as any other.

## Quality bar

- The owner read **three lines or fewer** before being asked anything.
- They answered **one question**.
- Today's MITs came from yesterday's decision wherever one existed, rather than being re-elicited.
- Nothing from the weekly review's territory appeared — no pace, no adherence percentages, no
  stalled-project list.
- The day ended **open**, with a named first action, and nothing after that line.
- A dated file exists, even on a cold start.
