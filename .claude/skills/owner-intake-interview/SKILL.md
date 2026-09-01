---
name: owner-intake-interview
description: A specialist's structured first-contact interview to build the owner's baseline in a given domain (career, health, finance, planning, knowledge, etc.). Use when a specialist engages a domain for the first time and has no baseline about the owner. Produces a captured owner-profile section (+ knowledge-base table requests to Knowledge Engineer) and a baseline summary in Owner's Inbox/.
---

# Owner Intake Interview

A repeatable way for any specialist to establish the owner's **baseline** in their domain before
doing real work. A plan built on guesses is a wish; this skill turns guesses into captured facts.

## When to trigger
- You are a specialist (Career Coach, Health Coach, Finance Advisor, Chief of Staff, Knowledge Engineer, or a future hire) engaging your
  domain and there is **no baseline** for the owner yet.
- **Check first:** read `team/owner-profile.md`. If a fact is already answered there (or, for
  Health/Finance, already in the encrypted `knowledge.db`), it is **settled — do NOT re-ask.**
  Only interview for the genuine gaps.
- Do NOT trigger for a one-off task where the needed facts are already known.

## The domain-agnostic question framework
Cover these six buckets, in order. Translate each into your domain's concrete questions.

1. **Current state** — where the owner is today (the raw picture: status, numbers, what exists).
2. **Goals + timeframe** — what they want, by when; how they'll know it's achieved (success
   criteria); stretch vs committed.
3. **Constraints** — time budget, money, energy, hard non-negotiables, dependencies.
4. **History** — what they've tried before, what worked, what was abandoned and why.
5. **Preferences** — how they like to work, be communicated with, be pushed; tone; cadence.
6. **Risk / safety flags** — anything that gates the work or must route to a licensed professional
   (health red flags → physician; cross-border finance → mandatory cross-border pros; legal/tax →
   refer out). **If a safety flag fires, honor your guardrails before anything else.**

## How to probe gaps
- **One question at a time when it matters;** batch only trivially related items.
- **Prefer specifics over vibes:** "how many hours on which days," not "are you busy."
- **Reflect back** what you heard and confirm before capturing it as settled.
- **Mark confidence:** capture answered facts as settled; leave a blank line + `_(pending)_` for
  anything not yet answered — never invent an answer.
- **Follow the [M]/[H]/[O] priority** in the owner-profile template: get all must-haves first.

## How to capture results
- **Write plaintext identity/planning/preference answers** into your section of
  `team/owner-profile.md` (copy from `owner-profile.template.md` if it doesn't exist yet). Stamp
  `captured: YYYY-MM-DD` and update the top `last_intake:`.
- **Sensitive Health & Finance answers are NEVER written in plaintext.** They go into the encrypted
  `knowledge.db`. To store them you **request the needed tables/columns from Knowledge Engineer** (state
  table/column names, types, constraints, the query they serve, and the SQLCipher
  encryption-at-rest requirement). **You never run DDL yourself.** If the table doesn't exist yet,
  flag the dependency and request it — don't improvise around it.
- Leave the inbox folders clean; deliver the summary as one file (below).

## Deliverable — baseline summary → `Owner's Inbox/`
Write one self-contained file naming: what you captured, what's still pending, any table requests
sent to Knowledge Engineer, any safety referrals, and the recommended first next step. Reference the
originating request. Carry any standing disclaimer (Health Coach/Finance Advisor).

## Example question sets

**Career (Career Coach)**
- Current state: current role/level, scope, team size, employer, recent wins.
- Goals + timeframe: target level, by when; what "promoted" looks like as observable behaviors.
- Constraints: usable hours/day + weekend; energy; the power-of-saying-no candidates.
- History: past promo attempts/feedback; what stalled.
- Preferences: candor tolerance; public-brand appetite vs aversion.
- Risk flags: anything requiring HR/legal/immigration/comp-negotiation → refer out.

**Health (Health Coach)** — sensitive → encrypted DB, not plaintext
- Current state: height/weight, activity level, diagnosed conditions, meds, recent labs + ranges.
- Goals + timeframe: top 1–3 goals, 3mo/12mo success, priority (aesthetic/performance/health).
- Constraints: weekly hours for training + meal-prep; equipment; injuries/limitations.
- History: past attempts — worked/abandoned + why.
- Preferences: dietary pattern, foods loved/refused, training style.
- Risk flags: RED-FLAG screen (chest pain/SOB/dizziness/fainting, pregnancy, ED history) →
  physician clearance gates the plan.

**Finance (Finance Advisor)** — sensitive → encrypted DB, masked identifiers only
- Current state: account inventory (institution/type/country/currency/rough balance, masked id),
  liabilities, cash buffer.
- Goals + timeframe: goals & horizons, retirement timing + country, risk tolerance.
- Constraints: income rhythm, fixed expenses, savings rate.
- History: existing strategy, recurring contributions, existing pros.
- Preferences: engagement level (weekly/monthly/hands-off), values (ESG/liquidity).
- Risk flags: cross-border tax/residency → MANDATORY referral to licensed pros in BOTH
  jurisdictions; verify every figure.
