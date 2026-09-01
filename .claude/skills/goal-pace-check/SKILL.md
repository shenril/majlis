---
name: goal-pace-check
description: The honest-math skill for any DATED goal. Use it every single time you report progress toward a goal that has a target value and a real deadline. Computes the required per-week and per-month rate to hit the target by the deadline, projects the endpoint if the current pace holds, and states on-course / off-course bluntly with the numbers shown. Core rule — NEVER assert "on pace" without doing the arithmetic against the real deadline.
---

# Goal pace check

A coach guardrails and tells the truth; a coach never flatters. This skill exists
because "on pace" was once asserted without the math behind it. From now on, any
claim about progress toward a dated goal must be backed by the arithmetic below,
with the numbers shown.

**Core rule:** NEVER say "on pace", "on track", "ahead", or "behind" about a dated
goal until you have computed the required rate against the REAL deadline and
projected the endpoint. If you don't have the real deadline, you don't have a pace
verdict — get the deadline first.

## When to use

- Any time you report progress toward a goal that has a **target value** and a
  **deadline** (weight, revenue, savings, word count, reps, users — anything
  measurable with a date).
- Inside every review (`run-review-cadence`) for each dated key result.
- Any time you're tempted to type "on pace".

## Inputs (get all four — refuse to verdict without them)

| Input | Symbol | Note |
|---|---|---|
| Baseline value | `B` | where you started |
| Current value | `C` | latest real measurement |
| Target value | `T` | the goal |
| Deadline | `D` | the REAL date the target must be hit |
| (derived) Today | `today` | the date `C` was measured |

Also note the direction: a **loss/decrease** goal has `T < B`; a
**growth/increase** goal has `T > B`. The formulas below use signed remaining
distance so they work for both.

## The math

Let:

```
weeks_remaining   = (D - today) / 7          # in days, then /7
months_remaining  = (D - today) / 30.44      # avg days per month
remaining         = T - C                    # signed: negative for a loss goal
done              = C - B                     # signed progress so far
elapsed_weeks     = (today - start_date) / 7  # weeks since progress began
```

**Required rate (to hit T by D):**

```
required_per_week  = remaining / weeks_remaining
required_per_month = remaining / months_remaining
```

**Projected endpoint (if the CURRENT observed pace holds):**

```
observed_rate_per_week = done / elapsed_weeks
projected_value_at_D    = C + observed_rate_per_week * weeks_remaining
```

**Verdict:**

```
on-course  if projected_value_at_D meets-or-beats T
             (>= T for a growth goal, <= T for a loss goal)
off-course otherwise — and by how much:
             gap_at_deadline = projected_value_at_D - T   (show it)
             rate_shortfall  = required_per_week - observed_rate_per_week
```

Round sensibly (2 decimals for rates), show your units, and state the verdict
plainly. If `weeks_remaining <= 0` the deadline has passed — say so and score
final, do not project.

## Output template

```
Goal: <name> — <B> → <T> by <D>
Now (<today>): <C>  (<done> done, <remaining> to go)

Required rate to hit target:  <required_per_week>/wk  (<required_per_month>/mo)
Current observed pace:        <observed_rate_per_week>/wk
Projected at deadline:        <projected_value_at_D>  (target <T>)

VERDICT: <ON-COURSE | OFF-COURSE by <gap_at_deadline>>.
<if off-course:> To recover, lift pace from <observed>/wk to <required>/wk
                 (+<rate_shortfall>/wk) or move the deadline.
```

## Worked example (placeholder numbers)

```
Goal: Placeholder metric — B=100 → T=80 by 2027-04-01   (loss goal)
Now (2026-09-01): C=96   (done -4, remaining -16)

weeks_remaining  = ~30.4      months_remaining = ~7.0
required_per_week  = -16 / 30.4 ≈ -0.53 /wk   (≈ -2.28 /mo)
elapsed_weeks (since 2026-07-01) ≈ 8.9
observed_rate    = -4 / 8.9 ≈ -0.45 /wk
projected_at_D   = 96 + (-0.45 * 30.4) ≈ 82.3   (target 80)

VERDICT: OFF-COURSE by +2.3 (lands at ~82.3, not 80).
To recover, lift pace from -0.45/wk to -0.53/wk (about -0.08/wk more) or move the deadline.
```

## Quality bar
- Four inputs present (baseline, current, target, real deadline) or no verdict.
- Both the required rate AND the projected endpoint are shown, with units.
- The verdict is blunt and quantified — no flattery, no "on pace" without the math.
- Works for both loss and growth goals via signed remaining distance.
```
