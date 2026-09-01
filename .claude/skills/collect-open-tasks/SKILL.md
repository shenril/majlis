---
name: collect-open-tasks
description: The orchestrator's "round the table" sweep — answers "what needs my input?" for the owner. Use when the owner asks what's waiting on them, at the start of a working session, or before a review. Polls active members in parallel for items GENUINELY blocked on the owner, excludes done/in-progress/parked work, dedupes, prioritizes, and digests into ONE action-first list.
---

# Collect Open Tasks ("round the table")

Jarvis's sweep to surface **only what genuinely needs the owner's input** — no noise, no
re-chasing things already handled.

## When to trigger
- The owner asks "what needs me / what's waiting on me / what's open?"
- Start of a working session, or before a weekly/monthly review.

## Steps
1. **Identify active members.** Read `team/roster.md`; consider members with live workstreams.
2. **Poll in parallel.** Dispatch each relevant member (Agent tool; `SendMessage` to preserve
   context for already-running members) with a tight ask: *"List ONLY items genuinely blocked on
   the owner's input/decision right now. For each: one-line ask, why it's blocking, urgency/date.
   Exclude anything you can proceed on yourself."* Run independent polls concurrently.
3. **Apply exclusion rules** (drop the item if ANY apply):
   - It's **done** or already delivered to `Owner's Inbox/`.
   - It's **in progress** and the member can proceed without the owner.
   - It's **PARKED / someday / deferred** by prior owner decision.
   - The owner has **already answered or scheduled** it (check recent deliverables/decisions).
   - It's a member-to-member handoff (route it, don't surface it to the owner).
4. **Dedupe overlaps.** Collapse the same underlying decision raised by multiple members into one
   line, noting who's waiting.
5. **Prioritize** in this order: **overdue → decisions blocking the team → time-sensitive (soon)
   → low / nice-to-have.**
6. **Digest into ONE action-first list.** Do NOT forward or copy-paste member replies. Name only
   what matters; lead with the action.

## Output format
```
What needs you (N items)

⛔ Overdue
- <action the owner must take> — <who's blocked, why> [due <date>]

🔗 Blocking the team
- <action> — <which member(s) waiting>

⏳ Soon
- <action> — <by when>

▫️ Low / when you have a minute
- <action>
```
If nothing qualifies: say so plainly ("Nothing needs you right now — everything's in progress or
parked") rather than padding the list.

## Guardrails
- **Blocked-on-owner only.** If a member can move it forward, it does not belong here.
- **Digest, don't relay.** Verbosity lives in the members' `Owner's Inbox/` docs, not this list.
- **Don't re-chase** items the owner already scheduled or answered.
