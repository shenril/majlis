---
doc: Owner Dossier (TEMPLATE)
status: template
maintained_by: Knowledge Engineer
last_intake:            # stamp YYYY-MM-DD each time you fill/revise an answer
storage_note: >
  Sections A/B/C are PLAINTEXT (identity, UX, and planning fields).
  Sections D (Health) and E (Finance) are SENSITIVE: store their answers ONLY in the
  encrypted knowledge.db (never in this file). This dossier holds only the question list
  plus a [SENSITIVE → encrypted] pointer for those two sections.
db: <REPO_ROOT>/database/knowledge.db
---

# Owner Dossier — TEMPLATE

> **How to use this template:** copy this file to `team/owner-profile.md` (which is git-ignored)
> and fill in the blanks. It becomes the team's single source of truth about the owner and doubles
> as a **ready-to-fill interview sheet** — every question has a blank answer line to complete once
> the owner is interviewed ("prep now, interview later"). **Ship NO real personal data in this
> template.**

## How to use this dossier

- **Read before you ask.** If a fact is answered here, it is settled — do **not** re-ask the
  owner. Pull it from here (or, for Health/Finance, from the encrypted DB).
- **One writer per section.** Only the named owner teammate edits their section:
  A → Knowledge Engineer · B → *(your UX/design member)* · C → Chief of Staff · D → Health Coach · E → Finance Advisor.
- **Date every change.** Stamp `captured:` (and update the top `last_intake:`) whenever you
  fill or revise an answer. Use ISO dates (`YYYY-MM-DD`).
- **Sensitive health & finance → encrypted DB.** Sections D and E answers are **never** written
  in plaintext here. They live in the encrypted `knowledge.db`. This file keeps only the question
  list and a `[SENSITIVE → encrypted]` pointer.
- **This file is the source of truth for future hires.** Any new teammate reads this dossier
  before interacting with the owner.

**Legend:** `[M]` must-have · `[H]` high-value · `[O]` optional/nice-to-have.

---

## Section A — Core Profile
**owner: Knowledge Engineer** · plaintext (identity fields OK here)

### A1 · Identity
`captured:`
- Full legal name + preferred name [M]
  - _answer:_ ______________________________________________
- Pronouns [M]
  - _answer:_ ______________________________________________
- Date of birth (full) / age [H]
  - _answer:_ ______________________________________________
- Languages spoken + preferred writing language, with any per-context exceptions [M]
  - _answer:_ ______________________________________________
- Tone/address preferences [O]
  - _answer:_ ______________________________________________

### A2 · Location & cross-border
`captured:`
- Current city/country + home time zone [M]
  - _answer:_ ______________________________________________
- Time split across countries (% or seasonal), if any [M]
  - _answer:_ ______________________________________________
- Tax/residency status high-level [H]
  - _answer:_ ______________________________________________
- Citizenship(s)/visa [H]
  - _answer:_ ______________________________________________
- Home bases/labels [O]
  - _answer:_ ______________________________________________

### A3 · Occupation
`captured:`
- What you do (role/profession) [M]
  - _answer:_ ______________________________________________
- Employer or own business — name+type [M]
  - _answer:_ ______________________________________________
- Work rhythm — hours/days/peak/quiet/remote/async-vs-meeting [H]
  - _answer:_ ______________________________________________
- Industry/domain [H]
  - _answer:_ ______________________________________________
- Side ventures/board seats [O]
  - _answer:_ ______________________________________________
- Professional background [H]
  - _answer:_ ______________________________________________

### A4 · Household & relationships (high-level)
`captured:`
- Household/inner circle — names, relationship, role [M]
  - _answer:_ ______________________________________________
- Often-referenced people (assistant, partner, accountant, doctor) [H]
  - _answer:_ ______________________________________________
- Default contact cadence for closest people [H]
  - _answer:_ ______________________________________________
- Recurring important dates [O]
  - _answer:_ ______________________________________________

### A5 · Active projects & priorities
`captured:`
- 3–7 active projects/threads [M]
  - _answer:_ ______________________________________________
- Current top priorities this quarter [M]
  - _answer:_ ______________________________________________
- Known deadlines next 90 days [H]
  - _answer:_ ______________________________________________
- What's stalled/stressing [H]
  - _answer:_ ______________________________________________
- Someday/maybe ambitions [O]
  - _answer:_ ______________________________________________

### A6 · Knowledge capture
`captured:`
- Note/journaling style + what to remember automatically [M]
  - _answer:_ ______________________________________________
- Where thoughts currently land (capture habits) [H]
  - _answer:_ ______________________________________________
- Preferred terminology/tags you already use [O]
  - _answer:_ ______________________________________________

### A7 · Personality / working style (optional)
`captured:`
> If the owner has a personality profile (e.g. a self-report questionnaire) they want the team to
> use as a working lens, capture it here. Treat any such result as a **tendency map, not a fixed
> fact** — always let actual behavior override the type.
- Communication preferences [H]
  - _answer:_ ______________________________________________
- Feedback style (giving & receiving) [H]
  - _answer:_ ______________________________________________
- Decision-making style [H]
  - _answer:_ ______________________________________________
- Autonomy / trust preferences [H]
  - _answer:_ ______________________________________________
- Strengths to leverage [O]
  - _answer:_ ______________________________________________
- Blind spots / growth edges [O]
  - _answer:_ ______________________________________________

---

## Section B — UX Preferences
**owner: *(your UX/design member)*** · plaintext

### B1 · Devices
`captured:`
- Which devices you'll use + your PRIMARY [M]
  - _answer:_ ______________________________________________
- Primary screen size/window habit [M]
  - _answer:_ ______________________________________________
- On-the-go vs desktop-only [H]
  - _answer:_ ______________________________________________

### B2 · Usage
`captured:`
- When/where you'll use it most [M]
  - _answer:_ ______________________________________________
- Which 2–3 surfaces you live in day-to-day [M]
  - _answer:_ ______________________________________________
- What to put front-and-center on open [H]
  - _answer:_ ______________________________________________

### B3 · Accessibility
`captured:`
- Any a11y needs (vision/motor/color-vision/screen-reader/large text) [M]
  - _answer:_ ______________________________________________
- Default text size + contrast preference [H]
  - _answer:_ ______________________________________________
- Motion/animation appetite (reduced-motion?) [H]
  - _answer:_ ______________________________________________
- Keyboard vs pointer/touch [H]
  - _answer:_ ______________________________________________

### B4 · Taste
`captured:`
- Airy vs information-dense [H]
  - _answer:_ ______________________________________________
- Notification/badge appetite [H]
  - _answer:_ ______________________________________________
- Apps whose feel you love/hate [O]
  - _answer:_ ______________________________________________

### B5 · Locale
`captured:`
- UI language + date format + week start (Mon/Sun) + default currency display [M]
  - _answer:_ ______________________________________________

---

## Section C — Planning & Accountability
**owner: Chief of Staff** · plaintext

### C1 · North Star
`captured:`
- 3–5yr vision (what's true that isn't today) [M]
  - _answer:_ ______________________________________________
- This year's theme [M]
  - _answer:_ ______________________________________________
- Rank life domains by attention NOW [M]
  - _answer:_ ______________________________________________
- Any domain over-getting energy [H]
  - _answer:_ ______________________________________________
- Hard constraints/non-negotiables [H]
  - _answer:_ ______________________________________________

### C2 · Goals
`captured:`
- Main goals this year [M]
  - _answer:_ ______________________________________________
- Existing OKRs/monthly/12-week plan to import [M]
  - _answer:_ ______________________________________________
- How you'd know each goal is achieved [H]
  - _answer:_ ______________________________________________
- Stretch (~70%) vs committed targets [H]
  - _answer:_ ______________________________________________
- Stalled goals + why [H]
  - _answer:_ ______________________________________________
- Repeatedly-missed goals [O]
  - _answer:_ ______________________________________________

### C3 · Daily rhythm
`captured:`
- Peak-focus window + reliable crash time [M]
  - _answer:_ ______________________________________________
- Ideal day structure [M]
  - _answer:_ ______________________________________________
- Calendar/task tools today [M]
  - _answer:_ ______________________________________________
- How you capture tasks/ideas + where they get lost [M]
  - _answer:_ ______________________________________________
- Protected focus hours/weekday [H]
  - _answer:_ ______________________________________________
- Time-blocks vs ordered MIT list [H]
  - _answer:_ ______________________________________________
- Weekly fixed anchors [H]
  - _answer:_ ______________________________________________
- Energy/mood/sleep tracking [O]
  - _answer:_ ______________________________________________

### C4 · Habits
`captured:`
- Habits to build + frequency [M]
  - _answer:_ ______________________________________________
- Habits to break/reduce [M]
  - _answer:_ ______________________________________________
- Target identity [H]
  - _answer:_ ______________________________________________
- Habit stack anchors [H]
  - _answer:_ ______________________________________________
- Previously-dropped habits + why [H]
  - _answer:_ ______________________________________________
- Numeric-measured habits [O]
  - _answer:_ ______________________________________________

### C5 · Review cadence
`captured:`
- Which reviews D/W/M/Q [M]
  - _answer:_ ______________________________________________
- Day+time for each [M]
  - _answer:_ ______________________________________________
- Summary-you-read vs prompts-you-answer [H]
  - _answer:_ ______________________________________________
- Realistic weekly-review time [H]
  - _answer:_ ______________________________________________
- Journal to pull from [O]
  - _answer:_ ______________________________________________

### C6 · Accountability
`captured:`
- How hard to push when slipping [M]
  - _answer:_ ______________________________________________
- How to surface off-pace (daily digest / realtime / review-time) [M]
  - _answer:_ ______________________________________________
- What helps you re-engage [H]
  - _answer:_ ______________________________________________
- Propose fixes vs surface-only [H]
  - _answer:_ ______________________________________________
- Areas to stay quiet [O]
  - _answer:_ ______________________________________________

### C7 · Definition & pain
`captured:`
- "My life feels well-organized when…" [M]
  - _answer:_ ______________________________________________
- Biggest current stressor to fix first [M]
  - _answer:_ ______________________________________________
- Main planning-friction source [H]
  - _answer:_ ______________________________________________
- Overwhelmed-day cause [H]
  - _answer:_ ______________________________________________
- Past productivity systems liked/disliked [O]
  - _answer:_ ______________________________________________

---

## Section D — Health
**owner: Health Coach** · `[SENSITIVE — answers stored encrypted in knowledge.db, owned by Health Coach]`

> **Framing:** this is a **coaching intake, not medical care**. Health Coach does not diagnose,
> prescribe, or order tests. **Physician clearance gates any plan** that touches a condition,
> medication, or symptom. All answers below are stored **encrypted only** (in the SQLCipher
> knowledge.db) — **never written in plaintext here**. 🔒 marks especially sensitive items.

`[SENSITIVE → encrypted]` — capture answers into `knowledge.db`, not into this file. Question list:

### D1 · Goals
- Top 1–3 health goals [M]
- 3mo & 12mo success + aesthetic/performance/health priority [M]
- Deeper why [H]
- Past attempts — worked/abandoned + why [M]
- Weekly hours for training+meal-prep + which days [M]
- Events to periodize toward [O]

### D2 · Health data 🔒
- Height + current weight [M]
- Diagnosed conditions [M]
- Medications + doses [M]
- Supplements [M]
- Recent labs/biomarkers with their reference ranges [M if available]
- Family history + age of onset [H]
- RHR/BP/HRV/VO2max/BF% if known [H]
- Last physical + regular physician [H]
- RED-FLAG screen — chest pain/SOB/dizziness/fainting/fatigue-on-exertion, pregnancy, eating-disorder history [M]

### D3 · Nutrition
- Allergies/intolerances [M]
- Dietary pattern + foods loved/refused [M]
- Typical day of eating [M]
- Cooking situation [M]
- Cultural/regional food context [H]
- Alcohol + caffeine [M]
- Water [H]
- Appetite/cravings/digestion [H]
- Budget/sourcing [O]

### D4 · Training
- Activity level/steps/job [M]
- Training history [M]
- Injuries/surgeries/limitations [M]
- Equipment access per location [M]
- Enjoyed sports [H]
- Performance/aesthetic targets [H]
- Recovery — sleep/stress/soreness [M]
- Preferred training style [O]

### D5 · Wearables/sleep
- Wearable + willingness to share exports [H]
- Sleep schedule/quality + any jet-lag pattern [M]
- Preferred logging method [H]
- Check-in/trend-review frequency [H]

---

## Section E — Finance
**owner: Finance Advisor** · `[SENSITIVE — answers stored encrypted in knowledge.db, owned by Finance Advisor]`

> **Framing:** this is **organizing/coaching, not licensed advice**. Any cross-border
> tax/residency question is a **MANDATORY referral to licensed pros in BOTH jurisdictions**. All
> answers are **encrypted only** (in the SQLCipher knowledge.db) — **never plaintext here**. Store
> **MASKED account identifiers only** (never full numbers/credentials). Every figure is
> **provisional → verify against statements**. 🔒 marks especially sensitive items.

`[SENSITIVE → encrypted]` — capture answers into `knowledge.db`, not into this file. Question list:

### E1 · Assets 🔒
- Account inventory — institution/type/country/currency/owner/rough balance, masked id [M]
- Holdings inside each wrapper [H]
- Real/physical assets — property/vehicle/business/pension [H]
- Liabilities/debts — balance/currency/rate/country [M]
- Cash & emergency buffer [M]

### E2 · Cross-border 🔒
- Tax residency & filing in each country (owner's current understanding) [M, highest-risk]
- Cross-border account map + when you moved [M]
- Foreign-asset reporting awareness [M]
- Beneficiaries designated & current [H]
- Documents on hand (statements/tax docs/exports) [H]
- Currency split of income/spending/assets [H]

### E3 · Investing
- Goals & horizons — target/currency/date [M]
- Retirement timing + country [M]
- Risk tolerance (reaction to 20–30% drop) [M]
- Existing strategy + recurring contributions [H]
- Constraints/values incl. ESG/liquidity [O]

### E4 · Cash flow 🔒
- Income sources & amounts (net preferred) + rhythm [M]
- Recurring fixed expenses [M]
- Variable/discretionary spend [H]
- Savings rate [H]
- Money leaks + how/how often you move money across currencies (FX cost) [H]

### E5 · Priorities
- Top financial worries [M]
- Top 3 to fix this quarter [M]
- Engagement level (weekly/monthly/hands-off) [H]
- Existing pros — financial planner / tax advisor / attorney [H]
