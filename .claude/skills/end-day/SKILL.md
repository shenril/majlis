---
name: end-day
description: The owner's end-of-day shutdown ritual — the daily cadence made executable. Use when the owner says they're done for the day, asks to close out, runs /end-day, or when a scheduled end-of-day trigger fires. Asks how the day went, logs habit check-ins, surfaces what rolled over as a question rather than carrying it silently, sets tomorrow's 1-3 MITs, and closes the day explicitly. Writes a dated daily file to the planning advisor's working memory — it does NOT stage SQL; the weekly review reconciles the week into the knowledge base in one pass.
---

# End of day — the shutdown ritual

Run by the **planning advisor** (see `team/roster.md` for who that is on this council).

This is the daily row of `run-review-cadence` made executable. Its job is to **close the day**,
not to review it: open loops get a home, tomorrow gets a decision, and the owner gets to stop
thinking about work.

> **Sixty seconds, not five minutes.** The owner is finishing their day, not starting a meeting.
> If this ever feels like the weekly review, it has failed.

## The one rule

**One question at a time, and one follow-up maximum.**

The owner types a sentence; you do the bookkeeping. Every number you need is already in the
knowledge base or in yesterday's file — never make them look something up, and never open with a
status dump. A wall of context gets a one-word answer.

## Steps

### 1. Load silently

Before you say anything, read:

- **Today's file** in your own working memory (`daily/<YYYY-MM-DD>.md`) — today's MITs, if
  `/start-day` set them.
- **Yesterday's file** — what rolled, what was promised.
- **Habits due today.** If the owner uses the knowledge base, `v_habits_due_today`. If not, the
  habit list from the most recent weekly review file.

Say none of this out loud. It is input, not output.

### 2. Ask how it went

> "How'd it go?"

Then stop. Let them answer in their own words.

**Phrase every question actively.** "Did you do your best to protect the deep-work block?" beats
"Did you do the deep-work block." Active questions ask about effort the owner controlled; passive
ones invite excuses about outcomes they didn't. This is the single highest-value wording choice in
the ritual.

### 3. Log the habit check-ins

Batch them into one exchange — a list to confirm, not a sequence of interrogations:

> "Habits: walk ✓, reading ✓, strength — miss?"

Record the answer exactly as given. **Never infer a habit was done because the day went well**, and
never fill a gap with a guess. An unanswered habit is unanswered, not missed.

### 4. Surface what rolled — as a question, never a carry

Any MIT or committed task that did not ship today gets **named and asked about**:

> "The vendor email didn't move today. Still worth doing, or dead?"

**Do not silently roll anything forward.** The friction is the feature: an item that isn't worth
re-committing to out loud wasn't worth doing. A task that rolls three days in a row is a signal —
say so plainly rather than quietly carrying it a fourth time.

### 5. Set tomorrow's MITs

**One to three, no more.** If the owner offers five, make them choose; a list of five MITs is a
list of zero. Where a commitment has a predictable obstacle, capture it as an if-then:

> "When the 9am runs long, then the deep-work block moves to after lunch."

If-then plans close the gap between intending and doing far better than a restated intention.

### 6. Close the day

End with an explicit boundary — the same phrase every time, so it becomes a cue:

> "Day closed. Tomorrow: <MIT 1>, <MIT 2>."

Nothing after that line. No summary, no encouragement, no extra question.

## What you write

One dated file in **your own** working memory — `Team's brain/<your-handle>/daily/<YYYY-MM-DD>.md`:

```markdown
# <YYYY-MM-DD> — day closed <HH:MM>

## MITs
- [x] <MIT 1>
- [ ] <MIT 2>          <!-- rolled: owner re-committed / dropped -->

## Habits
- walk: done
- reading: done
- strength: missed
- mobility: _(unanswered)_

## Notes
<the owner's own words, lightly trimmed — not paraphrased into management-speak>

## Tomorrow
- <MIT 1>
- <MIT 2>
- if-then: when <obstacle>, then <action>
```

**Write it even on a bad day.** A file saying "nothing shipped, low energy, dropped two" is data;
a missing file is a hole in the week the review cannot reason about.

## What you do NOT do

- **Do not stage SQL.** This ritual never calls `safe-staged-migration`. A daily check-in that ends
  in a keyed SQLCipher session is a daily check-in nobody runs. The week reconciles in one pass
  (below).
- **Do not compute streaks from the database mid-week.** It lags until the weekly reconciliation,
  so `v_habit_streaks` will under-report. Count the current week's streak from the daily files
  instead — a streak that reads low because the DB is stale actively discourages the behaviour
  you're trying to build.
- **Do not re-plan, re-prioritise, or coach.** Something that needs real thought is a note for the
  weekly review, not a conversation at 10pm.
- **Do not report to the owner on anything outside today.** Off-pace goals, stalled projects and
  overdue follow-ups belong to the weekly review and to `collect-open-tasks`.

## Hand-off to the weekly review

The daily files are the week's raw record. `run-review-cadence`'s **weekly** pass reads the seven
files, computes adherence and execution from them, and stages **one** `safe-staged-migration` file
covering the whole week — habit logs, plan results, the review row.

That keeps the owner's approval gate exactly where it belongs: one keyed session a week, not seven.
Because staged files are idempotent by construction, re-running a reconciliation is a clean no-op,
so a partially-applied week is safe to re-reconcile.

> **Working memory is not backed up.** `Team's brain/` is git-ignored by design. Up to a week of
> daily files live only on disk until the weekly review lands them in the knowledge base — which is
> one more reason the weekly review is the keystone and never skipped.

## Quality bar

- The whole exchange fits in **under a minute** of the owner's attention.
- The owner answered **one question**, plus at most one follow-up.
- Every unshipped commitment was **named and decided** — re-committed or dropped, never carried.
- Tomorrow has **1–3 MITs**, written down, and an if-then wherever an obstacle is known.
- The day ended with the **closing line** and nothing after it.
- A dated file exists, including on the days nothing happened.
