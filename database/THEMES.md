# Database themes — which tables serve which part of your life

`database/schema.sql` is one canonical 2,400-line file holding **63 tables and 44 views**. Which of
them belong to which domain is *implicit in the order they appear and declared nowhere* — you learn
that `mesocycles` is a training table by noticing it sits between `training_programs` and `workouts`.

This page is the map. Its machine-readable twin is
[`theme-map.yaml`](theme-map.yaml), kept honest by `tests/theme-map.test.sh`.

> **The schema is never subsetted.** Every table below exists in every install, whether or not you
> use the theme. This map is **descriptive, not enforced** — it tells advisors and reviewers what is
> in scope; it does not gate a single write.

## Themes at a glance

| Theme | Tables | Always installed | Owner |
|---|---:|---|---|
| [core](#core) | 17 | yes | data specialist |
| [planning](#planning) | 8 | yes | planning advisor |
| [health](#health) | 18 | elective | health advisor |
| [finance](#finance) | 15 | elective | finance advisor |
| [career](#career) | 5 | elective | career advisor |

**core** and **planning** are always installed. They are infrastructure rather than life themes:
core owns the entity graph every record links into, and planning owns the goal cascade every other
advisor hands habits and goals to. The elective themes depend on them; neither depends on an
elective theme.

---

## core

*The temporal spine, the entity graph, the search layer.* Everything links into these.

| Table | Purpose |
|---|---|
| `entries` | The journal spine — dated entries of every kind. |
| `entity_types` | Canonical entity-type strings used by `taggings` and `links`. |
| `people` | Personal CRM: who you know, relationship strength, last contact. |
| `organizations` | Companies and institutions people belong to. |
| `interactions` | Individual touchpoints with a person. |
| `meetings` | Meetings with notes and outcomes. |
| `meeting_attendees` | Join table: who was in which meeting. |
| `projects` | Ongoing bodies of work. |
| `milestones` | Dated checkpoints within a project. |
| `tasks` | The unified task list — next actions, due dates, contexts. |
| `assets` | Ingested files and images, with hashes for dedup. |
| `asset_metadata` | Namespaced key/value metadata for an asset. |
| `tags` | The tag vocabulary. |
| `taggings` | Polymorphic tag attachments across entity types. |
| `links` | The cross-entity graph — the backbone of backlinks. |
| `search_fts` | FTS5 virtual table powering full-text search. |
| `professionals` | Licensed humans you're referred to — doctors, tax advisors, lawyers. |

**Why `professionals` sits in core.** Health uses it for physician referrals and finance for
cross-border tax professionals — it is genuinely shared, so it belongs to neither. A judgement call
worth revisiting if a third theme starts writing to it.

**The cross-cutting three.** `search_fts`, `links` and `taggings` are written by *every* theme. They
are listed under core because they must always exist, but no theme owns them exclusively — a
migration touching them is normal from any advisor.

---

## planning

*The goal cascade and the review rhythm.* Annual North Star → quarterly OKRs → monthly SMART goals →
weekly outcomes → daily MITs, plus habit adherence.

| Table | Purpose |
|---|---|
| `goals` | Goals at every level of the cascade. |
| `key_results` | Measurable KRs hanging off a quarterly objective. |
| `key_result_sources` | Where a KR's current value is read from. |
| `daily_plans` | The plan for a given day. |
| `plan_blocks` | Time blocks within a daily plan. |
| `reviews` | Daily / weekly / monthly / quarterly review records. |
| `habits` | Habit definitions and their targets. |
| `habit_logs` | One row per habit per day — the adherence record. |

---

## health

*Nutrition, biomarkers, and training.* **Sensitive** — encrypted at rest, and never written to the
plaintext owner dossier.

| Table | Purpose |
|---|---|
| `owner_health_profile` | Baseline profile: conditions, constraints, context. |
| `intake_redflags` | Screening flags that gate the plan until a doctor clears them. |
| `medications` | Current medications. |
| `supplements` | Current supplements. |
| `family_history` | Familial risk factors. |
| `lab_results` | Biomarker results with reference ranges. |
| `body_metrics` | Weight, composition, circumferences over time. |
| `wearable_rollups` | Daily wearable signals — explicitly *not* medical grade. |
| `meal_plans` | A structured plan over a date range. |
| `meals` | A meal within a plan. |
| `meal_items` | The foods composing a meal. |
| `foods` | Reference table of per-serving macros. |
| `nutrition_logs` | Actual intake, reconciled against targets. |
| `exercises` | Reference table of movements. |
| `training_programs` | A periodised program. |
| `mesocycles` | A training block within a program. |
| `workouts` | A single session. |
| `workout_sets` | Sets, reps, load and RPE within a session. |

---

## finance

*Accounts, cash flow, net worth, and the cross-border picture.* **Sensitive** — encrypted at rest,
and account identifiers are stored **masked**.

| Table | Purpose |
|---|---|
| `accounts` | The account inventory — institution, type, country, currency. |
| `balance_snapshots` | Point-in-time balance per account. |
| `holdings` | Positions held within an account. |
| `transactions` | Individual movements. |
| `asset_items` | Non-account assets (property, vehicles, valuables). |
| `liabilities` | Debts and obligations. |
| `net_worth_snapshots` | Computed net-worth points over time. |
| `investment_plans` | The Investment Policy Statement. |
| `financial_goals` | Funding targets with horizons. |
| `fx_rates` | Reference rates for cross-currency rollups. |
| `tax_profile` | Residency and filing posture — drives cross-border guardrails. |
| `beneficiaries` | Designations recorded per account. |
| `investment_profile` | Risk tolerance, constraints, stated preferences. |
| `equity_grants` | Equity compensation grants, referenced masked. |
| `vesting_events` | Vesting schedule events against a grant. |

**Why equity sits in finance, not career.** `equity_grants` is a foreign key onto `accounts` — a
brokerage stock-plan account — carries ISO-4217 currency, and is subject to the finance masking
guardrail. It is compensation by origin but an account holding by structure, and the structure is
what the schema enforces.

---

## career

*Levelling evidence, sponsorship, coaching, and the brand pipeline.*

| Table | Purpose |
|---|---|
| `career_goals` | Target level and the phases toward it. |
| `promotion_evidence` | Evidence entries mapped to levelling axes. |
| `sponsors_network` | Sponsors and advocates, and the state of each relationship. |
| `coaching_log` | Coaching sessions and what came out of them. |
| `brand_artifacts` | Talks, posts and publications in the brand pipeline. |

Career carries the fewest tables because most of its work rides on **core** (people, interactions,
entries) and **planning** (the goal cascade). Its views — `v_promotion_evidence_log`,
`v_sponsor_map`, `v_brand_pipeline` — join across all three.

---

## Views are deliberately not mapped

The schema defines **44 views**, and many span themes by design: `v_health_kr_progress` joins health
to planning; `v_prioritized_tasks` joins core to planning; `v_net_worth` sits over finance but is
read during planning reviews.

Forcing each into a single theme would mean either arbitrary choices or a multi-theme membership
model that buys nothing today. Views are therefore **out of scope for the map** — a deliberate first
cut, revisitable if a consumer ever needs it.

## Keeping this honest

`schema.sql` is regenerated from the live database after every DDL migration, while this map is
hand-maintained. `tests/theme-map.test.sh` asserts that **every table in the schema appears in
exactly one theme, and every table named here exists in the schema** — so the two cannot drift
apart silently.

```bash
tests/theme-map.test.sh
```

When a migration adds or drops a table, update `theme-map.yaml` in the same change.
