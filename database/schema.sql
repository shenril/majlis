-- =============================================================================
-- schema.sql · CANONICAL STRUCTURE REFERENCE for knowledge.db
-- -----------------------------------------------------------------------------
-- Regenerated 2026-08-31 from the live database. DDL-ONLY — NO DATA.
-- This is the single source of truth for the database STRUCTURE: 68 tables
-- (incl. the search_fts FTS5 virtual table + its shadow tables), 44 views,
-- 116 triggers.
--
-- RULE: regenerate this file after EVERY DDL migration, so it always matches the
-- live schema. Structure questions are answered here; never guess a column.
--
-- IT LOADS CLEANLY into a fresh plaintext SQLite (verified 2026-08-31):
--     sqlite3 fresh.db ".read schema.sql"
-- The pre-apply validator (database/validate_staged.sh) builds its throwaway DB
-- from THIS file, so every staged .sql is checked against the real structure
-- before it can reach the owner's terminal.
--
-- NOTE ON THE FTS5 SHADOW TABLES: a raw .schema/.dump of an FTS5 database also
-- emits explicit `CREATE TABLE 'search_fts_data'(...)` etc. for FTS internals.
-- Those are auto-created by `CREATE VIRTUAL TABLE search_fts USING fts5(...)`;
-- if left in, the reload aborts with "table 'search_fts_data' already exists".
-- They are dump artifacts, not authored schema, and are intentionally omitted
-- here so the file reloads. The DDL you authored is otherwise byte-faithful.
--
-- LAST MIGRATION (2026-08-30, applied): +body_metrics.is_kr_eligible (phase-clean
-- guard, DEFAULT 1), +key_results.stretch_value; v_plan_progress redefined
-- (weight source filters is_kr_eligible=1; time_fraction from KR baseline date).
-- =============================================================================

CREATE TABLE entity_types (
    name        TEXT PRIMARY KEY,        -- canonical entity_type string
    domain      TEXT NOT NULL,           -- knowledge | planning | habits | health | finance
    description TEXT
) STRICT, WITHOUT ROWID;
CREATE TABLE entries (
    id          INTEGER PRIMARY KEY,
    kind        TEXT NOT NULL DEFAULT 'note'
                  CHECK (kind IN ('journal','note','daily','literature','permanent')),
    title       TEXT,
    body        TEXT,
    mood        TEXT,                    -- free text / scale for journal entries
    highlight   TEXT,                    -- the day's highlight (daily notes)
    entry_date  TEXT,                    -- YYYY-MM-DD the note is "about"
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE organizations (
    id          INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,
    type        TEXT,                    -- employer, vendor, club, ...
    notes       TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE people (
    id                    INTEGER PRIMARY KEY,
    name                  TEXT NOT NULL,
    org_id                INTEGER REFERENCES organizations(id) ON DELETE SET NULL,
    relationship_strength INTEGER CHECK (relationship_strength BETWEEN 1 AND 5),
    contact_cadence_days  INTEGER,       -- desired days between contacts (NULL = no cadence)
    last_contacted_at     TEXT,          -- denormalized cache, maintained by trigger
    email                 TEXT,
    phone                 TEXT,
    location              TEXT,
    birthday              TEXT,          -- YYYY-MM-DD (year optional convention)
    notes                 TEXT,
    created_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at            TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
, is_self INTEGER NOT NULL DEFAULT 0
    CHECK (is_self IN (0,1))) STRICT;
CREATE TABLE projects (
    id          INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active','on_hold','done','archived','someday')),
    description TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE milestones (
    id          INTEGER PRIMARY KEY,
    project_id  INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    due_date    TEXT,                    -- YYYY-MM-DD
    status      TEXT NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','done','cancelled')),
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE tasks (
    id                INTEGER PRIMARY KEY,
    title             TEXT NOT NULL,
    notes             TEXT,
    status            TEXT NOT NULL DEFAULT 'inbox'
                        CHECK (status IN ('inbox','next','waiting','scheduled','done','someday','cancelled')),
    is_next_action    INTEGER NOT NULL DEFAULT 0 CHECK (is_next_action IN (0,1)),
    context           TEXT,              -- GTD @context (@home, @calls, @errands, ...)
    project_id        INTEGER REFERENCES projects(id) ON DELETE SET NULL,
    milestone_id      INTEGER REFERENCES milestones(id) ON DELETE SET NULL,
    assigned_person_id INTEGER REFERENCES people(id) ON DELETE SET NULL,
    goal_id           INTEGER,           -- → goals(id); see Section 2 (no hard FK, see note)
    due_date          TEXT,              -- YYYY-MM-DD
    scheduled_for     TEXT,              -- YYYY-MM-DD
    completed_at      TEXT,              -- ISO-8601 UTC timestamp
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
, effort TEXT CHECK (effort IS NULL OR effort IN ('quick_win','light','moderate','deep_work')), priority_rank INTEGER) STRICT;
CREATE TABLE meetings (
    id          INTEGER PRIMARY KEY,
    title       TEXT NOT NULL,
    occurred_at TEXT,                    -- ISO-8601 UTC timestamp
    location    TEXT,
    agenda      TEXT,
    body        TEXT,                    -- discussion notes
    decisions   TEXT,                    -- decisions kept DISTINCT from discussion
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE meeting_attendees (
    meeting_id  INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    person_id   INTEGER NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    role        TEXT,                    -- organizer, presenter, attendee, ...
    PRIMARY KEY (meeting_id, person_id)
) STRICT, WITHOUT ROWID;
CREATE TABLE interactions (
    id          INTEGER PRIMARY KEY,
    person_id   INTEGER NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    type        TEXT NOT NULL
                  CHECK (type IN ('call','email','meeting','message','in_person')),
    occurred_at TEXT NOT NULL,           -- ISO-8601 UTC timestamp
    summary     TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE assets (
    id                INTEGER PRIMARY KEY,
    sha256            TEXT NOT NULL UNIQUE,         -- exact-duplicate detection
    perceptual_hash   TEXT,                         -- near-dup detection (images)
    mime_type         TEXT,                         -- determined by magic bytes
    bytes             INTEGER,
    original_filename TEXT,
    storage           TEXT NOT NULL DEFAULT 'path'
                        CHECK (storage IN ('path','blob')),
    path              TEXT,                          -- when storage='path'
    blob              BLOB,                          -- when storage='blob' (small items)
    -- promoted EXIF / IPTC / Dublin-Core metadata (hot columns) --------------
    width             INTEGER,
    height            INTEGER,
    captured_at       TEXT,                          -- EXIF DateTimeOriginal (ISO-8601)
    camera_make       TEXT,                          -- EXIF
    camera_model      TEXT,                          -- EXIF
    gps_lat           REAL,                          -- EXIF GPS
    gps_lon           REAL,                          -- EXIF GPS
    dc_title          TEXT,                          -- Dublin Core / IPTC title
    dc_creator        TEXT,                          -- Dublin Core creator / IPTC byline
    dc_description    TEXT,                          -- Dublin Core / IPTC caption
    dc_subject        TEXT,                          -- Dublin Core keywords (raw)
    iptc_copyright    TEXT,
    extracted_text    TEXT,                          -- OCR / document text extraction
    ingested_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE asset_metadata (
    id        INTEGER PRIMARY KEY,
    asset_id  INTEGER NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
    ns        TEXT NOT NULL,             -- namespace: exif | iptc | xmp | dc | pdf | ...
    key       TEXT NOT NULL,
    value     TEXT,
    UNIQUE (asset_id, ns, key)
) STRICT;
CREATE TABLE goals (
    id             INTEGER PRIMARY KEY,
    title          TEXT NOT NULL,
    description    TEXT,
    horizon        TEXT NOT NULL
                     CHECK (horizon IN ('theme','annual','quarter','month','week','day')),
    framework      TEXT CHECK (framework IN ('okr','smart','12wy','theme')),
    period_start   TEXT,                 -- YYYY-MM-DD
    period_end     TEXT,                 -- YYYY-MM-DD
    parent_goal_id INTEGER REFERENCES goals(id) ON DELETE SET NULL,  -- cascade link
    status         TEXT NOT NULL DEFAULT 'active'
                     CHECK (status IN ('active','done','missed','dropped','deferred')),
    created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE key_results (
    id            INTEGER PRIMARY KEY,
    goal_id       INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    description   TEXT NOT NULL,
    metric_type   TEXT NOT NULL DEFAULT 'number'
                    CHECK (metric_type IN ('number','percent','currency','binary')),
    currency      TEXT,                  -- ISO-4217 when metric_type='currency'
    start_value   REAL,
    target_value  REAL,
    current_value REAL,
    kr_kind       TEXT NOT NULL DEFAULT 'aspirational'
                    CHECK (kr_kind IN ('aspirational','committed')),  -- 0.7 vs 1.0 target
    score         REAL CHECK (score IS NULL OR (score BETWEEN 0.0 AND 1.0)),
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
, stretch_value REAL) STRICT;
CREATE TABLE daily_plans (
    id           INTEGER PRIMARY KEY,
    plan_date    TEXT NOT NULL UNIQUE,   -- YYYY-MM-DD, one plan per day
    highlight    TEXT,                   -- Make Time daily highlight
    intention    TEXT,
    energy_level INTEGER CHECK (energy_level IS NULL OR energy_level BETWEEN 1 AND 5),
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE plan_blocks (
    id            INTEGER PRIMARY KEY,
    daily_plan_id INTEGER NOT NULL REFERENCES daily_plans(id) ON DELETE CASCADE,
    start_time    TEXT,                  -- HH:MM (local plan time) or ISO-8601
    end_time      TEXT,
    label         TEXT,
    task_id       INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
    is_mit        INTEGER NOT NULL DEFAULT 0 CHECK (is_mit IN (0,1)),
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE reviews (
    id           INTEGER PRIMARY KEY,
    cadence      TEXT NOT NULL CHECK (cadence IN ('daily','weekly','monthly','quarterly')),
    period_start TEXT NOT NULL,          -- YYYY-MM-DD
    period_end   TEXT NOT NULL,          -- YYYY-MM-DD
    wins         TEXT,
    lessons      TEXT,
    adjustments  TEXT,
    okr_snapshot TEXT,                   -- JSON snapshot of OKR scores at review time
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE habits (
    id                 INTEGER PRIMARY KEY,
    name               TEXT NOT NULL,
    identity_statement TEXT,             -- "I am a runner."
    cue                TEXT,
    reward             TEXT,
    habit_stack_anchor TEXT,             -- "After [anchor], I will [habit]."
    measure_type       TEXT NOT NULL DEFAULT 'binary'
                         CHECK (measure_type IN ('binary','quantitative')),
    unit               TEXT,             -- for quantitative habits
    target_value       REAL,             -- per-occurrence target (quantitative)
    frequency          TEXT NOT NULL DEFAULT 'daily'
                         CHECK (frequency IN ('daily','weekdays','x_per_week','specific_days')),
    frequency_target   INTEGER,          -- e.g. x_per_week => 4
    specific_days      TEXT,             -- CSV of weekday codes when frequency='specific_days'
    linked_goal_id     INTEGER REFERENCES goals(id) ON DELETE SET NULL,
    area               TEXT,             -- PARA Area (health, finance, ...)
    active             INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
    created_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE habit_logs (
    id         INTEGER PRIMARY KEY,
    habit_id   INTEGER NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
    log_date   TEXT NOT NULL,            -- YYYY-MM-DD
    completed  INTEGER NOT NULL DEFAULT 1 CHECK (completed IN (0,1)),
    value      REAL,                     -- quantitative actual
    note       TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    UNIQUE (habit_id, log_date)          -- one log per habit per day
) STRICT;
CREATE TABLE meal_plans (
    id             INTEGER PRIMARY KEY,
    name           TEXT,
    period_start   TEXT,                 -- YYYY-MM-DD
    period_end     TEXT,                 -- YYYY-MM-DD
    pattern        TEXT,                 -- mediterranean | high_protein | keto | dash | plant_based | tre | ...
    target_kcal    REAL,
    target_protein_g REAL,
    target_carb_g  REAL,
    target_fat_g   REAL,
    notes          TEXT,
    created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE foods (              -- reference table (per-serving macros)
    id            INTEGER PRIMARY KEY,
    name          TEXT NOT NULL,
    serving_desc  TEXT,                  -- "100 g", "1 cup", ...
    serving_grams REAL,
    kcal          REAL,
    protein_g     REAL,
    carb_g        REAL,
    fat_g         REAL,
    micros        TEXT,                  -- JSON of key micronutrients
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE meals (
    id           INTEGER PRIMARY KEY,
    meal_plan_id INTEGER REFERENCES meal_plans(id) ON DELETE CASCADE,
    name         TEXT,                   -- breakfast, lunch, ...
    day_of_plan  INTEGER,                -- 1..N within the plan
    sort_order   INTEGER,
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE meal_items (
    id          INTEGER PRIMARY KEY,
    meal_id     INTEGER NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
    food_id     INTEGER REFERENCES foods(id) ON DELETE SET NULL,
    quantity    REAL,                    -- number of servings or grams
    quantity_unit TEXT,                  -- 'serving' | 'g'
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE nutrition_logs (    -- ACTUAL intake (reconciled vs targets)
    id          INTEGER PRIMARY KEY,
    log_date    TEXT NOT NULL,           -- YYYY-MM-DD
    food_id     INTEGER REFERENCES foods(id) ON DELETE SET NULL,
    description TEXT,                     -- free text when no food_id
    quantity    REAL,
    quantity_unit TEXT,
    kcal        REAL,                     -- computed/actual
    protein_g   REAL,
    carb_g      REAL,
    fat_g       REAL,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE lab_results (
    id                   INTEGER PRIMARY KEY,
    result_date          TEXT NOT NULL,  -- YYYY-MM-DD
    marker               TEXT NOT NULL,  -- ApoB, LDL, HbA1c, hs-CRP, TSH, ...
    value                REAL,
    value_text           TEXT,           -- for non-numeric results
    unit                 TEXT,
    reference_range_low  REAL,           -- the lab's own low bound (with the value)
    reference_range_high REAL,           -- the lab's own high bound (with the value)
    reference_range_text TEXT,           -- qualitative ranges ("Negative", ...)
    source               TEXT,           -- issuing lab / assay
    clinician_note       TEXT,
    created_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at           TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE body_metrics (
    id           INTEGER PRIMARY KEY,
    metric_date  TEXT NOT NULL,          -- YYYY-MM-DD
    weight_kg    REAL,
    body_fat_pct REAL,
    waist_cm     REAL,
    hip_cm       REAL,
    bp_systolic  INTEGER,
    bp_diastolic INTEGER,
    resting_hr   INTEGER,
    hrv_ms       REAL,
    vo2max       REAL,
    note         TEXT,
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
, thigh_l_cm REAL, thigh_r_cm REAL, arm_l_cm REAL, arm_r_cm REAL, is_kr_eligible INTEGER NOT NULL DEFAULT 1
        CHECK (is_kr_eligible IN (0,1))) STRICT;
CREATE TABLE wearable_rollups (  -- daily wearable signals (NOT medical-grade)
    id              INTEGER PRIMARY KEY,
    rollup_date     TEXT NOT NULL UNIQUE,  -- YYYY-MM-DD
    sleep_minutes   INTEGER,
    steps           INTEGER,
    hr_zone_minutes TEXT,                  -- JSON {z1:..,z2:..,...}
    readiness       REAL,
    training_load   REAL,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
, sleep_score INTEGER, rem_minutes INTEGER, awake_minutes INTEGER, energy_expended_kcal INTEGER, distance_km REAL, active_zone_minutes INTEGER, spo2_pct REAL, source TEXT, granularity TEXT NOT NULL DEFAULT 'daily' CHECK (granularity IN ('daily','weekly'))) STRICT;
CREATE TABLE exercises (         -- reference table
    id           INTEGER PRIMARY KEY,
    name         TEXT NOT NULL,
    muscle_group TEXT,
    modality     TEXT,                   -- resistance | zone2 | hiit | mobility | ...
    notes        TEXT,
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE training_programs (
    id           INTEGER PRIMARY KEY,
    name         TEXT NOT NULL,
    goal         TEXT,                   -- hypertrophy | strength | longevity | endurance | ...
    period_start TEXT,                   -- YYYY-MM-DD
    period_end   TEXT,
    notes        TEXT,
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE mesocycles (
    id                  INTEGER PRIMARY KEY,
    training_program_id INTEGER NOT NULL REFERENCES training_programs(id) ON DELETE CASCADE,
    name                TEXT,
    week_count          INTEGER,
    focus               TEXT,            -- accumulation | intensification | deload | ...
    sort_order          INTEGER,
    created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE workouts (
    id           INTEGER PRIMARY KEY,
    workout_date TEXT NOT NULL,          -- YYYY-MM-DD
    mesocycle_id INTEGER REFERENCES mesocycles(id) ON DELETE SET NULL,
    title        TEXT,
    duration_min INTEGER,
    rpe          REAL,                   -- session RPE
    notes        TEXT,
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE workout_sets (
    id          INTEGER PRIMARY KEY,
    workout_id  INTEGER NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
    exercise_id INTEGER REFERENCES exercises(id) ON DELETE SET NULL,
    set_number  INTEGER,
    reps        INTEGER,
    load_kg     REAL,
    rpe         REAL,                    -- RPE / RIR
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE balance_snapshots (
    id            INTEGER PRIMARY KEY,
    account_id    INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    snapshot_date TEXT NOT NULL,         -- YYYY-MM-DD
    balance       REAL NOT NULL,
    currency      TEXT NOT NULL,         -- ISO-4217 (currency on every monetary row)
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    UNIQUE (account_id, snapshot_date)
) STRICT;
CREATE TABLE holdings (
    id           INTEGER PRIMARY KEY,
    account_id   INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    instrument   TEXT NOT NULL,          -- ticker / fund name
    as_of_date   TEXT NOT NULL,          -- YYYY-MM-DD
    quantity     REAL,
    cost_basis   REAL,
    market_value REAL,
    currency     TEXT NOT NULL,          -- ISO-4217
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE transactions (
    id           INTEGER PRIMARY KEY,
    txn_date     TEXT NOT NULL,          -- YYYY-MM-DD
    account_id   INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
    amount       REAL NOT NULL,          -- signed; convention: + inflow, - outflow
    currency     TEXT NOT NULL,          -- ISO-4217
    category     TEXT NOT NULL DEFAULT 'expense'
                   CHECK (category IN ('income','expense','transfer')),
    subcategory  TEXT,
    counterparty TEXT,
    description  TEXT,
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE asset_items (
    id           INTEGER PRIMARY KEY,
    name         TEXT NOT NULL,
    type         TEXT,                   -- real_estate | vehicle | collectible | ...
    jurisdiction TEXT,                   -- country A | country B | ...
    value        REAL,
    currency     TEXT NOT NULL,          -- ISO-4217
    as_of_date   TEXT,                   -- YYYY-MM-DD
    notes        TEXT,
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE liabilities (
    id            INTEGER PRIMARY KEY,
    name          TEXT NOT NULL,
    type          TEXT,                  -- mortgage | loan | credit_card | ...
    jurisdiction  TEXT,
    balance       REAL,
    currency      TEXT NOT NULL,         -- ISO-4217
    interest_rate REAL,
    as_of_date    TEXT,                  -- YYYY-MM-DD
    notes         TEXT,
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE net_worth_snapshots (
    id              INTEGER PRIMARY KEY,
    snapshot_date   TEXT NOT NULL UNIQUE, -- YYYY-MM-DD
    total_assets    REAL,
    total_liabilities REAL,
    net_worth       REAL,
    base_currency   TEXT NOT NULL,        -- ISO-4217 the rollup is expressed in
    fx_note         TEXT,                 -- rate/date used for cross-currency rollup
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE investment_plans (  -- Investment Policy Statement (IPS)
    id              INTEGER PRIMARY KEY,
    name            TEXT NOT NULL,
    target_allocation TEXT,             -- JSON {equities:.., bonds:.., ...}
    time_horizon    TEXT,
    risk_profile    TEXT,
    rebalancing     TEXT,
    notes           TEXT,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE financial_goals (
    id            INTEGER PRIMARY KEY,
    title         TEXT NOT NULL,
    target_amount REAL,
    currency      TEXT NOT NULL,         -- ISO-4217
    target_date   TEXT,                  -- YYYY-MM-DD
    jurisdiction  TEXT,                  -- country A | country B | ...
    goal_id       INTEGER REFERENCES goals(id) ON DELETE SET NULL,  -- link into Chief of Staff's cascade
    status        TEXT NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','done','missed','dropped','deferred')),
    notes         TEXT,
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE fx_rates (          -- reference table for cross-currency rollups
    id        INTEGER PRIMARY KEY,
    rate_date TEXT NOT NULL,            -- YYYY-MM-DD
    pair      TEXT NOT NULL,            -- e.g. 'JPYEUR' meaning 1 base->quote; document convention
    base_ccy  TEXT NOT NULL,           -- ISO-4217
    quote_ccy TEXT NOT NULL,           -- ISO-4217
    rate      REAL NOT NULL,           -- 1 base_ccy = rate quote_ccy
    source    TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    UNIQUE (rate_date, base_ccy, quote_ccy)
) STRICT;
CREATE TABLE tags (
    id         INTEGER PRIMARY KEY,
    name       TEXT NOT NULL UNIQUE,
    color      TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE taggings (
    id          INTEGER PRIMARY KEY,
    tag_id      INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL REFERENCES entity_types(name),
    entity_id   INTEGER NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    UNIQUE (tag_id, entity_type, entity_id)
) STRICT;
CREATE TABLE links (
    id         INTEGER PRIMARY KEY,
    src_type   TEXT NOT NULL REFERENCES entity_types(name),
    src_id     INTEGER NOT NULL,
    dst_type   TEXT NOT NULL REFERENCES entity_types(name),
    dst_id     INTEGER NOT NULL,
    relation   TEXT NOT NULL DEFAULT 'relates_to',
    note       TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    UNIQUE (src_type, src_id, dst_type, dst_id, relation)
) STRICT;
CREATE TABLE owner_health_profile (
    id                  INTEGER PRIMARY KEY,
    person_id           INTEGER NOT NULL UNIQUE REFERENCES people(id) ON DELETE CASCADE,
    biological_sex      TEXT,        -- for physiological calculations (free text)
    height_cm           REAL,
    blood_type          TEXT,
    activity_baseline   TEXT,        -- sedentary | light | moderate | active | athlete
    dietary_pattern     TEXT,        -- omnivore | pescatarian | vegetarian | ...
    cooking_situation   TEXT,
    alcohol             TEXT,        -- pattern/frequency
    caffeine            TEXT,
    physician_name      TEXT,
    physician_clinic    TEXT,
    last_physical_date  TEXT,        -- YYYY-MM-DD
    wearable_device     TEXT,
    sleep_schedule      TEXT,        -- typical schedule/quality
    jetlag_notes        TEXT,        -- cross-timezone travel context
    goals_summary       TEXT,        -- top 1-3 health goals (3mo/12mo)
    deeper_why          TEXT,
    physician_clearance TEXT,        -- clearance status gating any plan touching a condition/med/symptom
    notes               TEXT,
    created_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at          TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE medications (
    id          INTEGER PRIMARY KEY,
    person_id   INTEGER NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    dose        TEXT,
    frequency   TEXT,
    route       TEXT,               -- oral | topical | injection | ...
    indication  TEXT,               -- condition it treats
    prescriber  TEXT,
    start_date  TEXT,               -- YYYY-MM-DD
    end_date    TEXT,               -- YYYY-MM-DD (NULL while current)
    is_current  INTEGER NOT NULL DEFAULT 1 CHECK (is_current IN (0,1)),
    notes       TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE supplements (
    id          INTEGER PRIMARY KEY,
    person_id   INTEGER NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    dose        TEXT,
    frequency   TEXT,
    brand       TEXT,
    reason      TEXT,               -- why taken
    start_date  TEXT,               -- YYYY-MM-DD
    end_date    TEXT,
    is_current  INTEGER NOT NULL DEFAULT 1 CHECK (is_current IN (0,1)),
    notes       TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
, status TEXT NOT NULL DEFAULT 'active'
      CHECK (status IN ('active','gated','as_needed','discontinued')), gate_reason TEXT, gate_task_id INTEGER
      REFERENCES tasks(id) ON DELETE SET NULL) STRICT;
CREATE TABLE family_history (
    id            INTEGER PRIMARY KEY,
    person_id     INTEGER NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    relation      TEXT NOT NULL,     -- mother | father | sibling | grandparent | ...
    condition     TEXT NOT NULL,
    age_of_onset  INTEGER,
    is_deceased   INTEGER CHECK (is_deceased IN (0,1)),
    notes         TEXT,
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE intake_redflags (
    id                INTEGER PRIMARY KEY,
    person_id         INTEGER NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    screen_date       TEXT NOT NULL,   -- YYYY-MM-DD
    flag              TEXT NOT NULL,   -- chest_pain | shortness_of_breath | dizziness | fainting | fatigue_on_exertion | pregnancy | eating_disorder_history | other
    present           TEXT NOT NULL DEFAULT 'unknown' CHECK (present IN ('yes','no','unknown')),
    detail            TEXT,
    physician_cleared INTEGER NOT NULL DEFAULT 0 CHECK (physician_cleared IN (0,1)),
    notes             TEXT,
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE tax_profile (
    id                                INTEGER PRIMARY KEY,
    person_id                         INTEGER NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    jurisdiction                      TEXT NOT NULL,   -- country A | country B | ...
    tax_year                          INTEGER,
    residency_status_stated           TEXT,            -- owner's current understanding
    filing_status                     TEXT,
    moved_date                        TEXT,            -- YYYY-MM-DD (move to/from country)
    foreign_asset_reporting_awareness TEXT,            -- foreign-account / overseas-asset reporting awareness
    currency_split_note               TEXT,            -- income/spend/asset currency split
    is_owner_stated                   INTEGER NOT NULL DEFAULT 1 CHECK (is_owner_stated IN (0,1)),
    is_verified                       INTEGER NOT NULL DEFAULT 0 CHECK (is_verified IN (0,1)),
    verified_source                   TEXT,            -- which licensed pro confirmed (if any)
    notes                             TEXT,
    created_at                        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at                        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    UNIQUE (person_id, jurisdiction, tax_year)
) STRICT;
CREATE TABLE beneficiaries (
    id                 INTEGER PRIMARY KEY,
    account_id         INTEGER REFERENCES accounts(id) ON DELETE CASCADE,
    asset_item_id      INTEGER REFERENCES asset_items(id) ON DELETE CASCADE,
    name               TEXT NOT NULL,
    relationship       TEXT,
    share_pct          REAL,
    designation_target TEXT,          -- what the designation applies to (policy/clause/etc.)
    is_current         INTEGER NOT NULL DEFAULT 1 CHECK (is_current IN (0,1)),
    last_reviewed_date TEXT,          -- YYYY-MM-DD
    notes              TEXT,
    created_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at         TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE investment_profile (
    id                      INTEGER PRIMARY KEY,
    person_id               INTEGER NOT NULL UNIQUE REFERENCES people(id) ON DELETE CASCADE,
    risk_tolerance          TEXT,     -- conservative | moderate | aggressive
    drawdown_reaction       TEXT,     -- reaction to a 20-30% drop
    time_horizon_years      INTEGER,
    retirement_target_age   INTEGER,
    retirement_country      TEXT,     -- country A | country B | ...
    liquidity_needs         TEXT,
    values_constraints      TEXT,     -- ESG / exclusions / other constraints
    existing_strategy       TEXT,
    recurring_contributions TEXT,
    engagement_level        TEXT,     -- weekly | monthly | hands_off
    notes                   TEXT,
    created_at              TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at              TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE professionals (
    id          INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,
    type        TEXT,               -- financial-advisor | tax-advisor | accountant | attorney | notary | physician | ...
    domain      TEXT,               -- finance | health | legal | tax
    org         TEXT,
    country     TEXT,               -- country A | country B | ...
    person_id   INTEGER REFERENCES people(id) ON DELETE SET NULL,  -- optional CRM link
    email       TEXT,
    phone       TEXT,
    notes       TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE INDEX idx_entries_date ON entries(entry_date);
CREATE INDEX idx_entries_kind ON entries(kind);
CREATE INDEX idx_organizations_name ON organizations(name);
CREATE INDEX idx_people_org ON people(org_id);
CREATE INDEX idx_people_last_contacted ON people(last_contacted_at);
CREATE INDEX idx_people_strength ON people(relationship_strength);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_milestones_project ON milestones(project_id);
CREATE INDEX idx_milestones_due ON milestones(due_date);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_context ON tasks(context);
CREATE INDEX idx_tasks_project ON tasks(project_id);
CREATE INDEX idx_tasks_milestone ON tasks(milestone_id);
CREATE INDEX idx_tasks_person ON tasks(assigned_person_id);
CREATE INDEX idx_tasks_goal ON tasks(goal_id);
CREATE INDEX idx_tasks_due ON tasks(due_date);
CREATE INDEX idx_tasks_scheduled ON tasks(scheduled_for);
CREATE INDEX idx_tasks_next ON tasks(is_next_action, status);
CREATE INDEX idx_meetings_occurred ON meetings(occurred_at);
CREATE INDEX idx_meeting_attendees_person ON meeting_attendees(person_id);
CREATE INDEX idx_interactions_person ON interactions(person_id);
CREATE INDEX idx_interactions_occurred ON interactions(occurred_at);
CREATE INDEX idx_assets_mime ON assets(mime_type);
CREATE INDEX idx_assets_phash ON assets(perceptual_hash);
CREATE INDEX idx_assets_captured ON assets(captured_at);
CREATE INDEX idx_assets_ingested ON assets(ingested_at);
CREATE INDEX idx_asset_metadata_asset ON asset_metadata(asset_id);
CREATE INDEX idx_asset_metadata_key ON asset_metadata(ns, key);
CREATE INDEX idx_goals_parent ON goals(parent_goal_id);
CREATE INDEX idx_goals_horizon ON goals(horizon);
CREATE INDEX idx_goals_status ON goals(status);
CREATE INDEX idx_goals_period ON goals(period_start, period_end);
CREATE INDEX idx_key_results_goal ON key_results(goal_id);
CREATE INDEX idx_daily_plans_date ON daily_plans(plan_date);
CREATE INDEX idx_plan_blocks_plan ON plan_blocks(daily_plan_id);
CREATE INDEX idx_plan_blocks_task ON plan_blocks(task_id);
CREATE INDEX idx_reviews_cadence ON reviews(cadence);
CREATE INDEX idx_reviews_period ON reviews(period_start, period_end);
CREATE INDEX idx_habits_goal ON habits(linked_goal_id);
CREATE INDEX idx_habits_active ON habits(active);
CREATE INDEX idx_habit_logs_habit ON habit_logs(habit_id);
CREATE INDEX idx_habit_logs_date ON habit_logs(log_date);
CREATE INDEX idx_meal_plans_period ON meal_plans(period_start, period_end);
CREATE INDEX idx_foods_name ON foods(name);
CREATE INDEX idx_meals_plan ON meals(meal_plan_id);
CREATE INDEX idx_meal_items_meal ON meal_items(meal_id);
CREATE INDEX idx_meal_items_food ON meal_items(food_id);
CREATE INDEX idx_nutrition_logs_date ON nutrition_logs(log_date);
CREATE INDEX idx_nutrition_logs_food ON nutrition_logs(food_id);
CREATE INDEX idx_lab_results_date ON lab_results(result_date);
CREATE INDEX idx_lab_results_marker ON lab_results(marker);
CREATE INDEX idx_body_metrics_date ON body_metrics(metric_date);
CREATE INDEX idx_wearable_rollups_date ON wearable_rollups(rollup_date);
CREATE INDEX idx_exercises_name ON exercises(name);
CREATE INDEX idx_mesocycles_program ON mesocycles(training_program_id);
CREATE INDEX idx_workouts_date ON workouts(workout_date);
CREATE INDEX idx_workouts_mesocycle ON workouts(mesocycle_id);
CREATE INDEX idx_workout_sets_workout ON workout_sets(workout_id);
CREATE INDEX idx_workout_sets_exercise ON workout_sets(exercise_id);
CREATE INDEX idx_balance_snapshots_account ON balance_snapshots(account_id);
CREATE INDEX idx_balance_snapshots_date ON balance_snapshots(snapshot_date);
CREATE INDEX idx_holdings_account ON holdings(account_id);
CREATE INDEX idx_holdings_date ON holdings(as_of_date);
CREATE INDEX idx_transactions_date ON transactions(txn_date);
CREATE INDEX idx_transactions_account ON transactions(account_id);
CREATE INDEX idx_transactions_category ON transactions(category);
CREATE INDEX idx_asset_items_date ON asset_items(as_of_date);
CREATE INDEX idx_liabilities_date ON liabilities(as_of_date);
CREATE INDEX idx_net_worth_date ON net_worth_snapshots(snapshot_date);
CREATE INDEX idx_financial_goals_goal ON financial_goals(goal_id);
CREATE INDEX idx_financial_goals_date ON financial_goals(target_date);
CREATE INDEX idx_fx_rates_date ON fx_rates(rate_date);
CREATE INDEX idx_fx_rates_pair ON fx_rates(base_ccy, quote_ccy);
CREATE INDEX idx_taggings_entity ON taggings(entity_type, entity_id);
CREATE INDEX idx_taggings_tag ON taggings(tag_id);
CREATE INDEX idx_links_src ON links(src_type, src_id);
CREATE INDEX idx_links_dst ON links(dst_type, dst_id);
CREATE INDEX idx_links_relation ON links(relation);
CREATE INDEX idx_medications_person ON medications(person_id);
CREATE INDEX idx_medications_current ON medications(is_current);
CREATE INDEX idx_supplements_person ON supplements(person_id);
CREATE INDEX idx_supplements_current ON supplements(is_current);
CREATE INDEX idx_family_history_person ON family_history(person_id);
CREATE INDEX idx_intake_redflags_person ON intake_redflags(person_id);
CREATE INDEX idx_intake_redflags_date ON intake_redflags(screen_date);
CREATE INDEX idx_tax_profile_person ON tax_profile(person_id);
CREATE INDEX idx_tax_profile_jurisdiction ON tax_profile(jurisdiction);
CREATE INDEX idx_beneficiaries_account ON beneficiaries(account_id);
CREATE INDEX idx_beneficiaries_asset ON beneficiaries(asset_item_id);
CREATE INDEX idx_professionals_person ON professionals(person_id);
CREATE INDEX idx_professionals_type ON professionals(type);
CREATE UNIQUE INDEX idx_people_one_self ON people(is_self) WHERE is_self = 1;
CREATE VIRTUAL TABLE search_fts USING fts5(
    entity_type UNINDEXED,
    entity_id   UNINDEXED,
    title,
    body,
    tokenize = 'porter unicode61'
)
/* search_fts(entity_type,entity_id,title,body) */;
CREATE TRIGGER trg_entries_ai AFTER INSERT ON entries BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('entry', NEW.id,
            COALESCE(NEW.title,''),
            COALESCE(NEW.body,'')||' '||COALESCE(NEW.highlight,'')||' '||COALESCE(NEW.mood,''));
END;
CREATE TRIGGER trg_entries_ad AFTER DELETE ON entries BEGIN
    DELETE FROM search_fts WHERE entity_type='entry' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_entries_au AFTER UPDATE ON entries BEGIN
    DELETE FROM search_fts WHERE entity_type='entry' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('entry', NEW.id,
            COALESCE(NEW.title,''),
            COALESCE(NEW.body,'')||' '||COALESCE(NEW.highlight,'')||' '||COALESCE(NEW.mood,''));
END;
CREATE TRIGGER trg_people_ai AFTER INSERT ON people BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('person', NEW.id, COALESCE(NEW.name,''), COALESCE(NEW.notes,''));
END;
CREATE TRIGGER trg_people_ad AFTER DELETE ON people BEGIN
    DELETE FROM search_fts WHERE entity_type='person' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_people_au AFTER UPDATE ON people BEGIN
    DELETE FROM search_fts WHERE entity_type='person' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('person', NEW.id, COALESCE(NEW.name,''), COALESCE(NEW.notes,''));
END;
CREATE TRIGGER trg_orgs_ai AFTER INSERT ON organizations BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('organization', NEW.id, COALESCE(NEW.name,''), COALESCE(NEW.notes,''));
END;
CREATE TRIGGER trg_orgs_ad AFTER DELETE ON organizations BEGIN
    DELETE FROM search_fts WHERE entity_type='organization' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_orgs_au AFTER UPDATE ON organizations BEGIN
    DELETE FROM search_fts WHERE entity_type='organization' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('organization', NEW.id, COALESCE(NEW.name,''), COALESCE(NEW.notes,''));
END;
CREATE TRIGGER trg_projects_ai AFTER INSERT ON projects BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('project', NEW.id, COALESCE(NEW.name,''), COALESCE(NEW.description,''));
END;
CREATE TRIGGER trg_projects_ad AFTER DELETE ON projects BEGIN
    DELETE FROM search_fts WHERE entity_type='project' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_projects_au AFTER UPDATE ON projects BEGIN
    DELETE FROM search_fts WHERE entity_type='project' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('project', NEW.id, COALESCE(NEW.name,''), COALESCE(NEW.description,''));
END;
CREATE TRIGGER trg_tasks_ai AFTER INSERT ON tasks BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('task', NEW.id, COALESCE(NEW.title,''), COALESCE(NEW.notes,''));
END;
CREATE TRIGGER trg_tasks_ad AFTER DELETE ON tasks BEGIN
    DELETE FROM search_fts WHERE entity_type='task' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_tasks_au AFTER UPDATE ON tasks BEGIN
    DELETE FROM search_fts WHERE entity_type='task' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('task', NEW.id, COALESCE(NEW.title,''), COALESCE(NEW.notes,''));
END;
CREATE TRIGGER trg_meetings_ai AFTER INSERT ON meetings BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('meeting', NEW.id, COALESCE(NEW.title,''),
            COALESCE(NEW.agenda,'')||' '||COALESCE(NEW.body,'')||' '||COALESCE(NEW.decisions,''));
END;
CREATE TRIGGER trg_meetings_ad AFTER DELETE ON meetings BEGIN
    DELETE FROM search_fts WHERE entity_type='meeting' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_meetings_au AFTER UPDATE ON meetings BEGIN
    DELETE FROM search_fts WHERE entity_type='meeting' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('meeting', NEW.id, COALESCE(NEW.title,''),
            COALESCE(NEW.agenda,'')||' '||COALESCE(NEW.body,'')||' '||COALESCE(NEW.decisions,''));
END;
CREATE TRIGGER trg_interactions_ai AFTER INSERT ON interactions BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('interaction', NEW.id, COALESCE(NEW.type,''), COALESCE(NEW.summary,''));
END;
CREATE TRIGGER trg_interactions_ad AFTER DELETE ON interactions BEGIN
    DELETE FROM search_fts WHERE entity_type='interaction' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_interactions_au AFTER UPDATE ON interactions BEGIN
    DELETE FROM search_fts WHERE entity_type='interaction' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('interaction', NEW.id, COALESCE(NEW.type,''), COALESCE(NEW.summary,''));
END;
CREATE TRIGGER trg_goals_ai AFTER INSERT ON goals BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('goal', NEW.id, COALESCE(NEW.title,''), COALESCE(NEW.description,''));
END;
CREATE TRIGGER trg_goals_ad AFTER DELETE ON goals BEGIN
    DELETE FROM search_fts WHERE entity_type='goal' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_goals_au AFTER UPDATE ON goals BEGIN
    DELETE FROM search_fts WHERE entity_type='goal' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('goal', NEW.id, COALESCE(NEW.title,''), COALESCE(NEW.description,''));
END;
CREATE TRIGGER trg_reviews_ai AFTER INSERT ON reviews BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('review', NEW.id, NEW.cadence||' review '||NEW.period_start,
            COALESCE(NEW.wins,'')||' '||COALESCE(NEW.lessons,'')||' '||COALESCE(NEW.adjustments,''));
END;
CREATE TRIGGER trg_reviews_ad AFTER DELETE ON reviews BEGIN
    DELETE FROM search_fts WHERE entity_type='review' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_reviews_au AFTER UPDATE ON reviews BEGIN
    DELETE FROM search_fts WHERE entity_type='review' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('review', NEW.id, NEW.cadence||' review '||NEW.period_start,
            COALESCE(NEW.wins,'')||' '||COALESCE(NEW.lessons,'')||' '||COALESCE(NEW.adjustments,''));
END;
CREATE TRIGGER trg_assets_ai AFTER INSERT ON assets BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('asset', NEW.id,
            COALESCE(NEW.dc_title, NEW.original_filename, ''),
            COALESCE(NEW.dc_description,'')||' '||COALESCE(NEW.dc_subject,'')||' '||COALESCE(NEW.extracted_text,''));
END;
CREATE TRIGGER trg_assets_ad AFTER DELETE ON assets BEGIN
    DELETE FROM search_fts WHERE entity_type='asset' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_assets_au AFTER UPDATE ON assets BEGIN
    DELETE FROM search_fts WHERE entity_type='asset' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('asset', NEW.id,
            COALESCE(NEW.dc_title, NEW.original_filename, ''),
            COALESCE(NEW.dc_description,'')||' '||COALESCE(NEW.dc_subject,'')||' '||COALESCE(NEW.extracted_text,''));
END;
CREATE TRIGGER trg_entries_touch AFTER UPDATE ON entries BEGIN
    UPDATE entries SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_people_touch AFTER UPDATE ON people BEGIN
    UPDATE people SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_organizations_touch AFTER UPDATE ON organizations BEGIN
    UPDATE organizations SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_projects_touch AFTER UPDATE ON projects BEGIN
    UPDATE projects SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_milestones_touch AFTER UPDATE ON milestones BEGIN
    UPDATE milestones SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_tasks_touch AFTER UPDATE ON tasks BEGIN
    UPDATE tasks SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_meetings_touch AFTER UPDATE ON meetings BEGIN
    UPDATE meetings SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_interactions_touch AFTER UPDATE ON interactions BEGIN
    UPDATE interactions SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_assets_touch AFTER UPDATE ON assets BEGIN
    UPDATE assets SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_goals_touch AFTER UPDATE ON goals BEGIN
    UPDATE goals SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_key_results_touch AFTER UPDATE ON key_results BEGIN
    UPDATE key_results SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_daily_plans_touch AFTER UPDATE ON daily_plans BEGIN
    UPDATE daily_plans SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_plan_blocks_touch AFTER UPDATE ON plan_blocks BEGIN
    UPDATE plan_blocks SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_reviews_touch AFTER UPDATE ON reviews BEGIN
    UPDATE reviews SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_habits_touch AFTER UPDATE ON habits BEGIN
    UPDATE habits SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_habit_logs_touch AFTER UPDATE ON habit_logs BEGIN
    UPDATE habit_logs SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_transactions_touch AFTER UPDATE ON transactions BEGIN
    UPDATE transactions SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_lab_results_touch AFTER UPDATE ON lab_results BEGIN
    UPDATE lab_results SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_body_metrics_touch AFTER UPDATE ON body_metrics BEGIN
    UPDATE body_metrics SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_interactions_cadence_ai AFTER INSERT ON interactions BEGIN
    UPDATE people
       SET last_contacted_at = (
            SELECT MAX(occurred_at) FROM interactions WHERE person_id = NEW.person_id)
     WHERE id = NEW.person_id;
END;
CREATE TRIGGER trg_interactions_cadence_au AFTER UPDATE ON interactions BEGIN
    UPDATE people
       SET last_contacted_at = (
            SELECT MAX(occurred_at) FROM interactions WHERE person_id = NEW.person_id)
     WHERE id = NEW.person_id;
END;
CREATE TRIGGER trg_interactions_cadence_ad AFTER DELETE ON interactions BEGIN
    UPDATE people
       SET last_contacted_at = (
            SELECT MAX(occurred_at) FROM interactions WHERE person_id = OLD.person_id)
     WHERE id = OLD.person_id;
END;
CREATE TRIGGER trg_cleanup_entry AFTER DELETE ON entries BEGIN
    DELETE FROM taggings WHERE entity_type='entry' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='entry' AND src_id=OLD.id) OR (dst_type='entry' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_person AFTER DELETE ON people BEGIN
    DELETE FROM taggings WHERE entity_type='person' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='person' AND src_id=OLD.id) OR (dst_type='person' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_org AFTER DELETE ON organizations BEGIN
    DELETE FROM taggings WHERE entity_type='organization' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='organization' AND src_id=OLD.id) OR (dst_type='organization' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_project AFTER DELETE ON projects BEGIN
    DELETE FROM taggings WHERE entity_type='project' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='project' AND src_id=OLD.id) OR (dst_type='project' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_milestone AFTER DELETE ON milestones BEGIN
    DELETE FROM taggings WHERE entity_type='milestone' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='milestone' AND src_id=OLD.id) OR (dst_type='milestone' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_task AFTER DELETE ON tasks BEGIN
    DELETE FROM taggings WHERE entity_type='task' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='task' AND src_id=OLD.id) OR (dst_type='task' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_meeting AFTER DELETE ON meetings BEGIN
    DELETE FROM taggings WHERE entity_type='meeting' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='meeting' AND src_id=OLD.id) OR (dst_type='meeting' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_interaction AFTER DELETE ON interactions BEGIN
    DELETE FROM taggings WHERE entity_type='interaction' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='interaction' AND src_id=OLD.id) OR (dst_type='interaction' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_asset AFTER DELETE ON assets BEGIN
    DELETE FROM taggings WHERE entity_type='asset' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='asset' AND src_id=OLD.id) OR (dst_type='asset' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_goal AFTER DELETE ON goals BEGIN
    DELETE FROM taggings WHERE entity_type='goal' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='goal' AND src_id=OLD.id) OR (dst_type='goal' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_habit AFTER DELETE ON habits BEGIN
    DELETE FROM taggings WHERE entity_type='habit' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='habit' AND src_id=OLD.id) OR (dst_type='habit' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_labresult AFTER DELETE ON lab_results BEGIN
    DELETE FROM taggings WHERE entity_type='lab_result' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='lab_result' AND src_id=OLD.id) OR (dst_type='lab_result' AND dst_id=OLD.id);
END;
CREATE VIEW v_followups_due AS
    SELECT p.id AS person_id, p.name, p.relationship_strength,
           p.contact_cadence_days, p.last_contacted_at,
           CAST(julianday('now') - julianday(p.last_contacted_at) AS INTEGER) AS days_since_contact
      FROM people p
     WHERE p.contact_cadence_days IS NOT NULL
       AND (p.last_contacted_at IS NULL
            OR julianday('now') - julianday(p.last_contacted_at) > p.contact_cadence_days)
     ORDER BY p.relationship_strength DESC NULLS LAST, days_since_contact DESC
/* v_followups_due(person_id,name,relationship_strength,contact_cadence_days,last_contacted_at,days_since_contact) */;
CREATE VIEW v_project_dashboard AS
    SELECT pr.id AS project_id, pr.name, pr.status,
           (SELECT COUNT(*) FROM tasks t
              WHERE t.project_id = pr.id AND t.status NOT IN ('done','cancelled')) AS open_tasks,
           (SELECT COUNT(*) FROM milestones ms
              WHERE ms.project_id = pr.id AND ms.status = 'open') AS open_milestones,
           (SELECT MIN(ms.due_date) FROM milestones ms
              WHERE ms.project_id = pr.id AND ms.status = 'open') AS next_milestone_due,
           (SELECT MAX(t.updated_at) FROM tasks t WHERE t.project_id = pr.id) AS last_task_activity
      FROM projects pr
     WHERE pr.status = 'active'
     ORDER BY open_tasks DESC
/* v_project_dashboard(project_id,name,status,open_tasks,open_milestones,next_milestone_due,last_task_activity) */;
CREATE VIEW v_next_actions AS
    SELECT t.id AS task_id, t.title, t.context, t.project_id, t.due_date
      FROM tasks t
     WHERE t.is_next_action = 1 AND t.status = 'next'
     ORDER BY t.context NULLS LAST, t.due_date NULLS LAST
/* v_next_actions(task_id,title,context,project_id,due_date) */;
CREATE VIEW v_quarter_okr_scoreboard AS
    SELECT g.id AS goal_id, g.title AS objective, g.period_start, g.period_end,
           kr.id AS kr_id, kr.description AS key_result, kr.kr_kind,
           kr.metric_type, kr.currency,
           kr.start_value, kr.current_value, kr.target_value,
           CASE
             WHEN kr.target_value IS NOT NULL AND kr.start_value IS NOT NULL
                  AND kr.target_value <> kr.start_value
               THEN ROUND( (kr.current_value - kr.start_value)
                           / (kr.target_value - kr.start_value), 3)
             ELSE kr.score
           END AS progress_fraction,
           kr.score,
           CASE kr.kr_kind WHEN 'committed' THEN 1.0 ELSE 0.7 END AS target_score
      FROM goals g
      JOIN key_results kr ON kr.goal_id = g.id
     WHERE g.horizon = 'quarter' AND g.status = 'active'
     ORDER BY g.id, kr.id
/* v_quarter_okr_scoreboard(goal_id,objective,period_start,period_end,kr_id,key_result,kr_kind,metric_type,currency,start_value,current_value,target_value,progress_fraction,score,target_score) */;
CREATE VIEW v_goal_cascade AS
    WITH RECURSIVE tree(id, title, horizon, status, parent_goal_id, depth, path) AS (
        SELECT id, title, horizon, status, parent_goal_id, 0,
               printf('%s', title)
          FROM goals WHERE parent_goal_id IS NULL
        UNION ALL
        SELECT g.id, g.title, g.horizon, g.status, g.parent_goal_id, t.depth+1,
               t.path || ' > ' || g.title
          FROM goals g JOIN tree t ON g.parent_goal_id = t.id
    )
    SELECT id AS goal_id, title, horizon, status, parent_goal_id, depth, path
      FROM tree ORDER BY path
/* v_goal_cascade(goal_id,title,horizon,status,parent_goal_id,depth,path) */;
CREATE VIEW v_person_timeline AS
    SELECT i.person_id, 'interaction' AS kind, i.id AS ref_id,
           i.occurred_at AS when_ts, i.type AS label, i.summary AS detail
      FROM interactions i
    UNION ALL
    SELECT ma.person_id, 'meeting' AS kind, m.id AS ref_id,
           m.occurred_at AS when_ts, m.title AS label, m.decisions AS detail
      FROM meeting_attendees ma JOIN meetings m ON m.id = ma.meeting_id
/* v_person_timeline(person_id,kind,ref_id,when_ts,label,detail) */;
CREATE VIEW v_backlinks AS
    SELECT dst_type AS entity_type, dst_id AS entity_id,
           src_type AS from_type, src_id AS from_id, relation, created_at
      FROM links
/* v_backlinks(entity_type,entity_id,from_type,from_id,relation,created_at) */;
CREATE TRIGGER trg_owner_health_profile_touch AFTER UPDATE ON owner_health_profile BEGIN
    UPDATE owner_health_profile SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_medications_touch AFTER UPDATE ON medications BEGIN
    UPDATE medications SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_supplements_touch AFTER UPDATE ON supplements BEGIN
    UPDATE supplements SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_family_history_touch AFTER UPDATE ON family_history BEGIN
    UPDATE family_history SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_intake_redflags_touch AFTER UPDATE ON intake_redflags BEGIN
    UPDATE intake_redflags SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_tax_profile_touch AFTER UPDATE ON tax_profile BEGIN
    UPDATE tax_profile SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_beneficiaries_touch AFTER UPDATE ON beneficiaries BEGIN
    UPDATE beneficiaries SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_investment_profile_touch AFTER UPDATE ON investment_profile BEGIN
    UPDATE investment_profile SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_professionals_touch AFTER UPDATE ON professionals BEGIN
    UPDATE professionals SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_cleanup_owner_health_profile AFTER DELETE ON owner_health_profile BEGIN
    DELETE FROM taggings WHERE entity_type='owner_health_profile' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='owner_health_profile' AND src_id=OLD.id) OR (dst_type='owner_health_profile' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_medication AFTER DELETE ON medications BEGIN
    DELETE FROM taggings WHERE entity_type='medication' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='medication' AND src_id=OLD.id) OR (dst_type='medication' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_supplement AFTER DELETE ON supplements BEGIN
    DELETE FROM taggings WHERE entity_type='supplement' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='supplement' AND src_id=OLD.id) OR (dst_type='supplement' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_family_history AFTER DELETE ON family_history BEGIN
    DELETE FROM taggings WHERE entity_type='family_history' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='family_history' AND src_id=OLD.id) OR (dst_type='family_history' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_intake_redflag AFTER DELETE ON intake_redflags BEGIN
    DELETE FROM taggings WHERE entity_type='intake_redflag' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='intake_redflag' AND src_id=OLD.id) OR (dst_type='intake_redflag' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_tax_profile AFTER DELETE ON tax_profile BEGIN
    DELETE FROM taggings WHERE entity_type='tax_profile' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='tax_profile' AND src_id=OLD.id) OR (dst_type='tax_profile' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_beneficiary AFTER DELETE ON beneficiaries BEGIN
    DELETE FROM taggings WHERE entity_type='beneficiary' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='beneficiary' AND src_id=OLD.id) OR (dst_type='beneficiary' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_investment_profile AFTER DELETE ON investment_profile BEGIN
    DELETE FROM taggings WHERE entity_type='investment_profile' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='investment_profile' AND src_id=OLD.id) OR (dst_type='investment_profile' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_professional AFTER DELETE ON professionals BEGIN
    DELETE FROM taggings WHERE entity_type='professional' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='professional' AND src_id=OLD.id) OR (dst_type='professional' AND dst_id=OLD.id);
END;
CREATE TABLE key_result_sources (
    kr_id         INTEGER PRIMARY KEY REFERENCES key_results(id) ON DELETE CASCADE,
    source_metric TEXT NOT NULL,
    note          TEXT,
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE TABLE equity_grants (
    id               INTEGER PRIMARY KEY,
    account_id       INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE, -- brokerage stock-plan account
    grant_ref_masked TEXT NOT NULL,       -- MASKED grant reference ONLY, e.g. 'RSXX****XX' (Guardrail 8)
    symbol           TEXT NOT NULL,       -- ticker, e.g. 'TICKER'
    grant_date       TEXT,                -- YYYY-MM-DD
    total_units      REAL,                -- total units granted (REAL: allows fractional)
    currency         TEXT NOT NULL,       -- ISO-4217
    notes            TEXT,
    created_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE INDEX idx_equity_grants_account ON equity_grants(account_id);
CREATE INDEX idx_equity_grants_grant_date ON equity_grants(grant_date);
CREATE TABLE vesting_events (
    id         INTEGER PRIMARY KEY,
    grant_id   INTEGER NOT NULL REFERENCES equity_grants(id) ON DELETE CASCADE,
    vest_date  TEXT NOT NULL,             -- YYYY-MM-DD
    units      REAL,                      -- units vesting in this tranche (REAL: fractional)
    est_value  REAL,                      -- estimated value at vest
    currency   TEXT NOT NULL,             -- ISO-4217 (currency est_value is expressed in)
    status     TEXT NOT NULL DEFAULT 'unvested'
                 CHECK (status IN ('distributed','unvested','cancelled')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE INDEX idx_vesting_events_grant_date ON vesting_events(grant_id, vest_date);
CREATE INDEX idx_vesting_events_vest_date ON vesting_events(vest_date);
CREATE VIEW v_habits_due_today AS
WITH today AS (
    SELECT date('now') AS d,
           CAST(strftime('%w','now') AS INTEGER) AS dow,               -- 0=Sun..6=Sat
           date('now','-'||((CAST(strftime('%w','now') AS INTEGER)+6)%7)||' days') AS week_start
),
today_code AS (
    SELECT CASE dow WHEN 0 THEN 'sun' WHEN 1 THEN 'mon' WHEN 2 THEN 'tue'
                    WHEN 3 THEN 'wed' WHEN 4 THEN 'thu' WHEN 5 THEN 'fri'
                    WHEN 6 THEN 'sat' END AS code, d, dow, week_start
      FROM today
),
base AS (
    SELECT h.id AS habit_id, h.name, h.frequency, h.frequency_target,
           h.measure_type, h.target_value, h.unit, h.area, h.linked_goal_id,
           tc.d AS today, tc.dow, tc.week_start,
           -- scheduled_today: does the schedule put this habit on today?
           CASE h.frequency
             WHEN 'daily'         THEN 1
             WHEN 'weekdays'      THEN CASE WHEN tc.dow BETWEEN 1 AND 5 THEN 1 ELSE 0 END
             WHEN 'x_per_week'    THEN 1
             WHEN 'specific_days' THEN CASE WHEN (','||replace(lower(COALESCE(h.specific_days,'')),' ','')||',')
                                              LIKE '%,'||tc.code||',%' THEN 1 ELSE 0 END
             ELSE 0 END AS scheduled_today,
           COALESCE((SELECT hl.completed FROM habit_logs hl
                      WHERE hl.habit_id=h.id AND hl.log_date=tc.d), 0) AS completed_today,
           (SELECT hl.value FROM habit_logs hl
             WHERE hl.habit_id=h.id AND hl.log_date=tc.d) AS logged_value,
           (SELECT COUNT(*) FROM habit_logs hl
             WHERE hl.habit_id=h.id AND hl.completed=1
               AND hl.log_date >= tc.week_start AND hl.log_date <= tc.d) AS done_this_week
      FROM habits h CROSS JOIN today_code tc
     WHERE h.active = 1
)
SELECT habit_id, name, frequency, frequency_target, measure_type, target_value, unit,
       area, linked_goal_id, today AS date, week_start, done_this_week,
       completed_today, logged_value, scheduled_today,
       -- is_due: still needs action today
       CASE
         WHEN scheduled_today = 0 THEN 0
         WHEN completed_today = 1 THEN 0
         WHEN frequency = 'x_per_week'
              THEN CASE WHEN done_this_week >= COALESCE(frequency_target,1) THEN 0 ELSE 1 END
         ELSE 1
       END AS is_due,
       -- relevant_today: belongs on the daily-scorecard denominator
       CASE
         WHEN scheduled_today = 0 THEN 0
         WHEN completed_today = 1 THEN 1
         WHEN frequency = 'x_per_week'
              THEN CASE WHEN done_this_week >= COALESCE(frequency_target,1) THEN 0 ELSE 1 END
         ELSE 1
       END AS relevant_today
  FROM base
/* v_habits_due_today(habit_id,name,frequency,frequency_target,measure_type,target_value,unit,area,linked_goal_id,date,week_start,done_this_week,completed_today,logged_value,scheduled_today,is_due,relevant_today) */;
CREATE VIEW v_daily_agenda AS
    SELECT 'plan'    AS kind, dp.id AS ref_id, dp.highlight AS title,
           dp.plan_date AS when_date, dp.intention AS detail
      FROM daily_plans dp WHERE dp.plan_date = date('now')
    UNION ALL
    SELECT 'meeting' AS kind, m.id, m.title, substr(m.occurred_at,1,10), m.location
      FROM meetings m WHERE substr(m.occurred_at,1,10) = date('now')
    UNION ALL
    SELECT 'task_due' AS kind, t.id, t.title, t.due_date, t.context
      FROM tasks t WHERE t.due_date = date('now') AND t.status NOT IN ('done','cancelled')
    UNION ALL
    SELECT 'task_scheduled' AS kind, t.id, t.title, t.scheduled_for, t.context
      FROM tasks t WHERE t.scheduled_for = date('now') AND t.status NOT IN ('done','cancelled')
    UNION ALL
    -- G1 FIX: all frequencies now surface via v_habits_due_today (is_due=1).
    SELECT 'habit_due' AS kind, hd.habit_id, hd.name, hd.date, hd.frequency
      FROM v_habits_due_today hd WHERE hd.is_due = 1
/* v_daily_agenda(kind,ref_id,title,when_date,detail) */;
CREATE VIEW v_today AS SELECT * FROM v_daily_agenda
/* v_today(kind,ref_id,title,when_date,detail) */;
CREATE VIEW v_open_loops AS
    SELECT
      (SELECT COUNT(*) FROM tasks WHERE status NOT IN ('done','cancelled','someday')) AS open_loops,
      (SELECT COUNT(*) FROM tasks WHERE status='inbox')                                AS inbox,
      (SELECT COUNT(*) FROM tasks WHERE status='next')                                 AS next,
      (SELECT COUNT(*) FROM tasks WHERE status='waiting')                              AS waiting,
      (SELECT COUNT(*) FROM tasks WHERE status='scheduled')                            AS scheduled,
      (SELECT COUNT(*) FROM tasks WHERE status='someday')                              AS someday,
      (SELECT COUNT(*) FROM tasks WHERE status IN ('next','scheduled'))                AS actionable
/* v_open_loops(open_loops,inbox,next,waiting,scheduled,someday,actionable) */;
CREATE VIEW v_rolled_tasks AS
    SELECT t.id AS task_id, t.title, t.context, t.status, t.is_next_action,
           t.project_id, t.milestone_id, t.goal_id,
           t.due_date, t.scheduled_for,
           CASE WHEN t.due_date IS NOT NULL AND t.due_date < date('now') THEN 1 ELSE 0 END AS overdue_by_due,
           CASE WHEN t.scheduled_for IS NOT NULL AND t.scheduled_for < date('now') THEN 1 ELSE 0 END AS rolled_by_schedule,
           MIN(COALESCE(NULLIF(t.due_date,''), '9999-12-31'),
               COALESCE(NULLIF(t.scheduled_for,''), '9999-12-31')) AS earliest_slip_date,
           CAST(julianday('now') - julianday(
               MIN(COALESCE(NULLIF(t.due_date,''), '9999-12-31'),
                   COALESCE(NULLIF(t.scheduled_for,''), '9999-12-31'))) AS INTEGER) AS days_slipped
      FROM tasks t
     WHERE t.status NOT IN ('done','cancelled')
       AND ( (t.due_date      IS NOT NULL AND t.due_date      < date('now'))
          OR (t.scheduled_for IS NOT NULL AND t.scheduled_for < date('now')) )
     ORDER BY earliest_slip_date
/* v_rolled_tasks(task_id,title,context,status,is_next_action,project_id,milestone_id,goal_id,due_date,scheduled_for,overdue_by_due,rolled_by_schedule,earliest_slip_date,days_slipped) */;
CREATE VIEW v_habit_streaks AS
WITH
-- (A) day-based frequencies: one row per completed log, with the allowed gap.
day_logs AS (
    SELECT hl.habit_id, hl.log_date, julianday(hl.log_date) AS jd,
           CASE h.frequency WHEN 'daily' THEN 1 WHEN 'weekdays' THEN 3
                            WHEN 'specific_days' THEN 7 END AS max_gap
      FROM habit_logs hl JOIN habits h ON h.id=hl.habit_id
     WHERE hl.completed=1 AND h.active=1
       AND h.frequency IN ('daily','weekdays','specific_days')
),
-- (B) week-based frequency (x_per_week): one row per ISO week that met target.
wk_counts AS (
    SELECT hl.habit_id,
           date(hl.log_date,'-'||((CAST(strftime('%w',hl.log_date) AS INTEGER)+6)%7)||' days') AS wk_start,
           COUNT(*) AS done
      FROM habit_logs hl JOIN habits h ON h.id=hl.habit_id
     WHERE hl.completed=1 AND h.active=1 AND h.frequency='x_per_week'
     GROUP BY hl.habit_id, wk_start
),
wk_met AS (
    SELECT w.habit_id, w.wk_start AS log_date, julianday(w.wk_start) AS jd, 7 AS max_gap
      FROM wk_counts w JOIN habits h ON h.id=w.habit_id
     WHERE w.done >= COALESCE(h.frequency_target,1)
),
pts AS (
    SELECT habit_id, log_date, jd, max_gap FROM day_logs
    UNION ALL
    SELECT habit_id, log_date, jd, max_gap FROM wk_met
),
marked AS (
    SELECT habit_id, log_date, jd, max_gap,
           CASE WHEN LAG(jd) OVER (PARTITION BY habit_id ORDER BY jd) IS NULL
                  OR (jd - LAG(jd) OVER (PARTITION BY habit_id ORDER BY jd)) > max_gap
                THEN 1 ELSE 0 END AS is_break
      FROM pts
),
grouped AS (
    SELECT habit_id, jd, max_gap,
           SUM(is_break) OVER (PARTITION BY habit_id ORDER BY jd ROWS UNBOUNDED PRECEDING) AS grp
      FROM marked
),
islands AS (
    SELECT habit_id, grp, COUNT(*) AS len, MAX(jd) AS last_jd, MAX(max_gap) AS max_gap
      FROM grouped GROUP BY habit_id, grp
)
SELECT h.id AS habit_id, h.name, h.frequency,
       CASE WHEN h.frequency='x_per_week' THEN 'weeks' ELSE 'days' END AS streak_unit,
       -- current streak is "alive" if the most recent qualifying point is within
       -- one allowed gap of the reference point: TODAY for day-based cadences, or
       -- THIS ISO WEEK's Monday for x_per_week (so an in-progress week never
       -- retroactively breaks last week's streak).
       COALESCE((SELECT len FROM islands i
                  WHERE i.habit_id=h.id
                    AND ( (CASE WHEN h.frequency='x_per_week'
                                THEN julianday(date('now','-'||((CAST(strftime('%w','now') AS INTEGER)+6)%7)||' days'))
                                ELSE julianday('now') END) - i.last_jd ) <= i.max_gap
                  ORDER BY i.last_jd DESC LIMIT 1), 0) AS current_streak,
       COALESCE((SELECT MAX(len) FROM islands i WHERE i.habit_id=h.id), 0) AS longest_streak
  FROM habits h WHERE h.active=1
/* v_habit_streaks(habit_id,name,frequency,streak_unit,current_streak,longest_streak) */;
CREATE VIEW v_habit_calendar AS
WITH RECURSIVE days(d) AS (
    SELECT date('now','-89 days')
    UNION ALL SELECT date(d,'+1 day') FROM days WHERE d < date('now')
)
SELECT h.id AS habit_id, h.name, days.d AS log_date,
       CASE h.frequency
         WHEN 'daily'         THEN 1
         WHEN 'x_per_week'    THEN 1
         WHEN 'weekdays'      THEN CASE WHEN CAST(strftime('%w',days.d) AS INTEGER) BETWEEN 1 AND 5 THEN 1 ELSE 0 END
         WHEN 'specific_days' THEN CASE WHEN (','||replace(lower(COALESCE(h.specific_days,'')),' ','')||',')
                LIKE '%,'||(CASE CAST(strftime('%w',days.d) AS INTEGER)
                     WHEN 0 THEN 'sun' WHEN 1 THEN 'mon' WHEN 2 THEN 'tue' WHEN 3 THEN 'wed'
                     WHEN 4 THEN 'thu' WHEN 5 THEN 'fri' WHEN 6 THEN 'sat' END)||',%' THEN 1 ELSE 0 END
         ELSE 0 END AS scheduled,
       COALESCE(hl.completed,0) AS completed,
       hl.value AS value
  FROM habits h
  CROSS JOIN days
  LEFT JOIN habit_logs hl ON hl.habit_id=h.id AND hl.log_date=days.d
 WHERE h.active=1
/* v_habit_calendar(habit_id,name,log_date,scheduled,completed,value) */;
CREATE VIEW v_objective_rollup AS
    SELECT pp.goal_id, pp.objective, pp.period_start, pp.period_end,
           MIN(pp.week_of) AS week_of, MIN(pp.total_weeks) AS total_weeks,
           MIN(pp.days_remaining) AS days_remaining,
           COUNT(*)                       AS kr_count,
           ROUND(AVG(pp.progress_fraction),3) AS mean_progress,
           ROUND(AVG(pp.attainment),3)        AS mean_attainment,
           CASE
             WHEN SUM(CASE WHEN pp.pace_signal='red'   THEN 1 ELSE 0 END) > 0 THEN 'red'
             WHEN SUM(CASE WHEN pp.pace_signal='amber' THEN 1 ELSE 0 END) > 0 THEN 'amber'
             WHEN SUM(CASE WHEN pp.pace_signal='green' THEN 1 ELSE 0 END) > 0 THEN 'green'
             ELSE 'unknown'
           END AS pace_signal
      FROM v_plan_progress pp
     GROUP BY pp.goal_id, pp.objective, pp.period_start, pp.period_end
/* v_objective_rollup(goal_id,objective,period_start,period_end,week_of,total_weeks,days_remaining,kr_count,mean_progress,mean_attainment,pace_signal) */;
CREATE VIEW v_plan_health AS
    SELECT
      (SELECT COUNT(DISTINCT goal_id) FROM v_plan_progress)                 AS active_objectives,
      (SELECT COUNT(*) FROM v_plan_progress)                                AS total_krs,
      (SELECT ROUND(AVG(attainment),3)        FROM v_plan_progress)         AS mean_attainment,
      (SELECT ROUND(AVG(progress_fraction),3) FROM v_plan_progress)         AS mean_progress,
      (SELECT ROUND(AVG(time_fraction),3)     FROM v_plan_progress)         AS mean_time_fraction,
      (SELECT COUNT(*) FROM v_plan_progress WHERE pace_signal='green')      AS krs_green,
      (SELECT COUNT(*) FROM v_plan_progress WHERE pace_signal='amber')      AS krs_amber,
      (SELECT COUNT(*) FROM v_plan_progress WHERE pace_signal='red')        AS krs_red,
      (SELECT MIN(week_of)        FROM v_plan_progress)                     AS week_of,
      (SELECT MIN(total_weeks)    FROM v_plan_progress)                     AS total_weeks,
      (SELECT MIN(days_remaining) FROM v_plan_progress)                     AS days_remaining
/* v_plan_health(active_objectives,total_krs,mean_attainment,mean_progress,mean_time_fraction,krs_green,krs_amber,krs_red,week_of,total_weeks,days_remaining) */;
CREATE VIEW v_goal_cascade_progress AS
WITH RECURSIVE tree(id, title, horizon, status, parent_goal_id, depth, path) AS (
        SELECT id, title, horizon, status, parent_goal_id, 0, printf('%s', title)
          FROM goals WHERE parent_goal_id IS NULL
        UNION ALL
        SELECT g.id, g.title, g.horizon, g.status, g.parent_goal_id, t.depth+1,
               t.path || ' > ' || g.title
          FROM goals g JOIN tree t ON g.parent_goal_id = t.id
)
SELECT tree.id AS goal_id, tree.title, tree.horizon, tree.status,
       tree.parent_goal_id, tree.depth, tree.path,
       o.kr_count, o.mean_progress, o.mean_attainment, o.pace_signal
  FROM tree
  LEFT JOIN v_objective_rollup o ON o.goal_id = tree.id
 ORDER BY tree.path
/* v_goal_cascade_progress(goal_id,title,horizon,status,parent_goal_id,depth,path,kr_count,mean_progress,mean_attainment,pace_signal) */;
CREATE VIEW v_weekly_outcomes AS
    SELECT g.id AS goal_id, g.title, g.status,
           g.period_start, g.period_end, g.parent_goal_id,
           parent.title AS parent_objective
      FROM goals g
      LEFT JOIN goals parent ON parent.id = g.parent_goal_id
     WHERE g.horizon='week'
       AND ( (g.period_start IS NOT NULL AND g.period_end IS NOT NULL
              AND date('now') BETWEEN g.period_start AND g.period_end)
          OR (g.period_start IS NULL AND g.period_end IS NULL) )   -- undated week goals still show
     ORDER BY g.id
/* v_weekly_outcomes(goal_id,title,status,period_start,period_end,parent_goal_id,parent_objective) */;
CREATE VIEW v_week_execution AS
WITH wk AS (
    SELECT date('now','-'||((CAST(strftime('%w','now') AS INTEGER)+6)%7)||' days') AS week_start,
           date('now','+'||(6-((CAST(strftime('%w','now') AS INTEGER)+6)%7))||' days') AS week_end
)
SELECT
    (SELECT week_start FROM wk) AS week_start,
    (SELECT week_end   FROM wk) AS week_end,
    (SELECT COUNT(*) FROM tasks t, wk
       WHERE t.scheduled_for BETWEEN wk.week_start AND wk.week_end
         AND t.status <> 'cancelled') AS planned,
    (SELECT COUNT(*) FROM tasks t, wk
       WHERE t.scheduled_for BETWEEN wk.week_start AND wk.week_end
         AND t.status = 'done') AS completed,
    CASE WHEN (SELECT COUNT(*) FROM tasks t, wk
                 WHERE t.scheduled_for BETWEEN wk.week_start AND wk.week_end
                   AND t.status <> 'cancelled') > 0
         THEN ROUND(1.0 *
              (SELECT COUNT(*) FROM tasks t, wk
                 WHERE t.scheduled_for BETWEEN wk.week_start AND wk.week_end
                   AND t.status='done')
              / (SELECT COUNT(*) FROM tasks t, wk
                   WHERE t.scheduled_for BETWEEN wk.week_start AND wk.week_end
                     AND t.status <> 'cancelled'), 3)
         ELSE NULL END AS execution_pct
/* v_week_execution(week_start,week_end,planned,completed,execution_pct) */;
CREATE VIEW v_daily_scorecard AS
    SELECT
      date('now') AS scorecard_date,
      (SELECT COUNT(*) FROM plan_blocks pb
         JOIN daily_plans dp ON dp.id=pb.daily_plan_id
        WHERE dp.plan_date=date('now') AND pb.is_mit=1) AS mits_planned,
      (SELECT COUNT(*) FROM plan_blocks pb
         JOIN daily_plans dp ON dp.id=pb.daily_plan_id
         JOIN tasks t ON t.id=pb.task_id
        WHERE dp.plan_date=date('now') AND pb.is_mit=1
          AND t.status='done' AND substr(t.completed_at,1,10)=date('now')) AS mits_shipped,
      (SELECT COUNT(*) FROM v_habits_due_today WHERE relevant_today=1) AS habits_due,
      (SELECT COUNT(*) FROM v_habits_due_today WHERE relevant_today=1 AND completed_today=1) AS habits_checked
/* v_daily_scorecard(scorecard_date,mits_planned,mits_shipped,habits_due,habits_checked) */;
CREATE VIEW v_monthly_review AS
    SELECT
      strftime('%Y-%m','now')                                   AS month,
      (SELECT active_objectives  FROM v_plan_health)            AS active_objectives,
      (SELECT total_krs          FROM v_plan_health)            AS total_krs,
      (SELECT mean_attainment    FROM v_plan_health)            AS plan_health,
      (SELECT mean_progress      FROM v_plan_health)            AS mean_objective_progress,
      (SELECT krs_red            FROM v_plan_health)            AS krs_red,
      (SELECT krs_amber          FROM v_plan_health)            AS krs_amber,
      (SELECT krs_green          FROM v_plan_health)            AS krs_green,
      (SELECT mean_adherence_30  FROM v_habit_adherence_rollup) AS habit_adherence_30,
      (SELECT open_loops         FROM v_open_loops)             AS open_loops,
      (SELECT week_of            FROM v_plan_health)            AS week_of,
      (SELECT total_weeks        FROM v_plan_health)            AS total_weeks,
      (SELECT days_remaining     FROM v_plan_health)            AS days_remaining
/* v_monthly_review(month,active_objectives,total_krs,plan_health,mean_objective_progress,krs_red,krs_amber,krs_green,habit_adherence_30,open_loops,week_of,total_weeks,days_remaining) */;
CREATE VIEW v_task_board AS
    SELECT t.id AS task_id, t.title, t.notes, t.status, t.is_next_action, t.context,
           t.project_id,   pr.name  AS project_title,
           t.milestone_id, ms.title AS milestone_title,
           t.goal_id,      g.title  AS goal_title,      -- soft link; may be NULL if dangling (G14)
           t.assigned_person_id, p.name AS assignee,
           t.due_date, t.scheduled_for, t.completed_at,
           CASE WHEN t.status NOT IN ('done','cancelled','someday') THEN 1 ELSE 0 END AS is_open_loop,
           CASE WHEN t.due_date IS NOT NULL AND t.due_date < date('now')
                     AND t.status NOT IN ('done','cancelled') THEN 1 ELSE 0 END AS is_overdue
      FROM tasks t
      LEFT JOIN projects   pr ON pr.id = t.project_id
      LEFT JOIN milestones ms ON ms.id = t.milestone_id
      LEFT JOIN goals      g  ON g.id  = t.goal_id
      LEFT JOIN people     p  ON p.id  = t.assigned_person_id
/* v_task_board(task_id,title,notes,status,is_next_action,context,project_id,project_title,milestone_id,milestone_title,goal_id,goal_title,assigned_person_id,assignee,due_date,scheduled_for,completed_at,is_open_loop,is_overdue) */;
CREATE VIEW v_net_worth_base AS
    -- Rolls every account to a single BASE currency. The base currency is
    -- configurable: change the 'USD' literals below to your own ISO-4217 code.
    WITH latest_bal AS (           -- most-recent balance snapshot per account
        SELECT bs.account_id, bs.balance, bs.currency, bs.snapshot_date
          FROM balance_snapshots bs
          JOIN (SELECT account_id, MAX(snapshot_date) AS md
                  FROM balance_snapshots GROUP BY account_id) mx
            ON mx.account_id = bs.account_id AND mx.md = bs.snapshot_date
    ),
    fx AS (                        -- latest rate per (base_ccy -> base currency)
        SELECT f.base_ccy, f.rate, f.rate_date
          FROM fx_rates f
          JOIN (SELECT base_ccy, MAX(rate_date) AS md FROM fx_rates
                 WHERE quote_ccy='USD' GROUP BY base_ccy) m
            ON m.base_ccy = f.base_ccy AND m.md = f.rate_date AND f.quote_ccy='USD'
    )
    SELECT a.id                AS account_id,
           a.name             AS name,
           a.institution      AS institution,
           a.type             AS type,
           a.jurisdiction     AS jurisdiction,
           a.owner            AS owner,
           a.identifier_masked AS identifier_masked,
           a.status           AS status,               -- 'open' | 'closed'
           lb.currency        AS currency,             -- native (account) currency
           lb.balance         AS native_balance,       -- native-currency balance
           lb.snapshot_date   AS as_of_date,           -- YYYY-MM-DD of that balance
           fx.rate            AS fx_rate_to_base,       -- 1 native = fx_rate_to_base base ccy (1.0 if same)
           fx.rate_date       AS fx_rate_date,          -- date of the indicative rate
           CASE WHEN lb.currency = 'USD'      THEN lb.balance
                WHEN fx.rate     IS NOT NULL  THEN ROUND(lb.balance * fx.rate, 0)
                ELSE NULL END AS balance_base           -- base-currency equivalent; NULL if no rate/no balance
      FROM accounts a
      LEFT JOIN latest_bal lb ON lb.account_id = a.id
      LEFT JOIN fx           ON fx.base_ccy = lb.currency
/* v_net_worth_base(account_id,name,institution,type,jurisdiction,owner,identifier_masked,status,currency,native_balance,as_of_date,fx_rate_to_base,fx_rate_date,balance_base) */;
CREATE TABLE career_goals (
    id           INTEGER PRIMARY KEY,
    theme        TEXT NOT NULL DEFAULT 'Career',      -- ties to the Career theme
    horizon      TEXT,                                -- free-text quarter label, e.g. 'Q3-2026'
    objective    TEXT NOT NULL,                       -- the objective statement
    track_target TEXT CHECK (track_target IS NULL OR
                    track_target IN ('IC-track','Management-track','undecided')),
    target_level TEXT,                                -- e.g. 'Staff' or 'Principal'
    status       TEXT NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','done','dropped')),
    phase        INTEGER CHECK (phase IS NULL OR phase IN (1,2,3)),  -- phase-gate (NULL = overarching)
    target_date  TEXT,                                -- YYYY-MM-DD (day-90 or per-phase)
    lead_theme   TEXT CHECK (lead_theme IS NULL OR lead_theme IN ('Career','Health')),
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE INDEX idx_career_goals_status  ON career_goals(status);
CREATE INDEX idx_career_goals_phase   ON career_goals(phase);
CREATE INDEX idx_career_goals_target  ON career_goals(target_date);
CREATE INDEX idx_career_goals_horizon ON career_goals(horizon);
CREATE TABLE promotion_evidence (
    id              INTEGER PRIMARY KEY,
    artifact        TEXT NOT NULL,                    -- what the owner did/built (genericized)
    evidence_date   TEXT,                             -- YYYY-MM-DD (house convention: prefixed date)
    blast_radius    TEXT,                             -- customer / team / org / company-wide / industry
    business_impact TEXT,                             -- measurable outcome; carry a currency label on any figure
    archetype_tag   TEXT CHECK (archetype_tag IS NULL OR
                      archetype_tag IN ('Architect','Tech-Lead','Solver','Right-Hand')),
    next_level_bar_axis     TEXT,                             -- external-authority / novel-offering / roadmap-influence /
                                                      -- mentoring-outcome / above-level-scope (open vocabulary)
    source_link     TEXT,                             -- doc/URL if any
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE INDEX idx_promotion_evidence_date      ON promotion_evidence(evidence_date);
CREATE INDEX idx_promotion_evidence_axis      ON promotion_evidence(next_level_bar_axis);
CREATE INDEX idx_promotion_evidence_archetype ON promotion_evidence(archetype_tag);
CREATE TABLE brand_artifacts (
    id            INTEGER PRIMARY KEY,
    channel       TEXT,                               -- LinkedIn / blog / conference / podcast / newsletter (open)
    title         TEXT NOT NULL,
    url           TEXT,                               -- live once published
    format        TEXT,                               -- post / article / talk / CFP-submission / doctrine (open)
    lane          TEXT,                               -- the named doctrine slug, e.g. 'your-doctrine-slug'
    status        TEXT NOT NULL DEFAULT 'drafted'
                    CHECK (status IN ('drafted','published','submitted','accepted','rejected')),
    publish_date  TEXT,                               -- YYYY-MM-DD
    engagement    TEXT,                               -- likes/comments/impressions snapshot
    is_provisional INTEGER NOT NULL DEFAULT 0 CHECK (is_provisional IN (0,1)),  -- e.g. a working doctrine name
    notes         TEXT,
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE INDEX idx_brand_artifacts_status  ON brand_artifacts(status);
CREATE INDEX idx_brand_artifacts_publish ON brand_artifacts(publish_date);
CREATE INDEX idx_brand_artifacts_lane    ON brand_artifacts(lane);
CREATE TABLE sponsors_network (
    id                INTEGER PRIMARY KEY,
    name              TEXT NOT NULL,
    role_level        TEXT,                           -- 'senior','staff','principal','director', ...
    relationship      TEXT CHECK (relationship IS NULL OR
                        relationship IN ('sponsor','mentor','candidate-sponsor','manager')),
    can_carry_next_level_case INTEGER NOT NULL DEFAULT 0 CHECK (can_carry_next_level_case IN (0,1)),  -- at/above target level?
    influence         TEXT CHECK (influence IS NULL OR influence IN ('low','med','high')),
    last_touch        TEXT,                           -- YYYY-MM-DD
    next_activation   TEXT,                           -- next value-first move planned
    person_id         INTEGER REFERENCES people(id) ON DELETE SET NULL,  -- optional CRM link (mirrors professionals)
    notes             TEXT,
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE INDEX idx_sponsors_relationship ON sponsors_network(relationship);
CREATE INDEX idx_sponsors_can_carry    ON sponsors_network(can_carry_next_level_case);
CREATE INDEX idx_sponsors_last_touch   ON sponsors_network(last_touch);
CREATE INDEX idx_sponsors_person       ON sponsors_network(person_id);
CREATE TABLE coaching_log (
    id           INTEGER PRIMARY KEY,
    session_date TEXT NOT NULL,                       -- YYYY-MM-DD (house convention: prefixed date)
    topic        TEXT,                                -- track-decision / scope-gap / sponsor-play / ...
    summary      TEXT,                                -- what was decided/advised
    framework    TEXT,                                -- Magic-Loop / observable-behavior / Larson-archetypes / ...
    action_items TEXT,                                -- handed-to-Chief of Staff items
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE INDEX idx_coaching_log_date  ON coaching_log(session_date);
CREATE INDEX idx_coaching_log_topic ON coaching_log(topic);
CREATE TRIGGER trg_career_goals_ai AFTER INSERT ON career_goals BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('career_goal', NEW.id, COALESCE(NEW.objective,''),
            COALESCE(NEW.theme,'')||' '||COALESCE(NEW.horizon,'')||' '||
            COALESCE(NEW.track_target,'')||' '||COALESCE(NEW.target_level,''));
END;
CREATE TRIGGER trg_career_goals_ad AFTER DELETE ON career_goals BEGIN
    DELETE FROM search_fts WHERE entity_type='career_goal' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_career_goals_au AFTER UPDATE ON career_goals BEGIN
    DELETE FROM search_fts WHERE entity_type='career_goal' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('career_goal', NEW.id, COALESCE(NEW.objective,''),
            COALESCE(NEW.theme,'')||' '||COALESCE(NEW.horizon,'')||' '||
            COALESCE(NEW.track_target,'')||' '||COALESCE(NEW.target_level,''));
END;
CREATE TRIGGER trg_promotion_evidence_ai AFTER INSERT ON promotion_evidence BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('promotion_evidence', NEW.id, COALESCE(NEW.artifact,''),
            COALESCE(NEW.blast_radius,'')||' '||COALESCE(NEW.business_impact,'')||' '||
            COALESCE(NEW.next_level_bar_axis,'')||' '||COALESCE(NEW.archetype_tag,''));
END;
CREATE TRIGGER trg_promotion_evidence_ad AFTER DELETE ON promotion_evidence BEGIN
    DELETE FROM search_fts WHERE entity_type='promotion_evidence' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_promotion_evidence_au AFTER UPDATE ON promotion_evidence BEGIN
    DELETE FROM search_fts WHERE entity_type='promotion_evidence' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('promotion_evidence', NEW.id, COALESCE(NEW.artifact,''),
            COALESCE(NEW.blast_radius,'')||' '||COALESCE(NEW.business_impact,'')||' '||
            COALESCE(NEW.next_level_bar_axis,'')||' '||COALESCE(NEW.archetype_tag,''));
END;
CREATE TRIGGER trg_brand_artifacts_ai AFTER INSERT ON brand_artifacts BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('brand_artifact', NEW.id, COALESCE(NEW.title,''),
            COALESCE(NEW.lane,'')||' '||COALESCE(NEW.format,'')||' '||
            COALESCE(NEW.channel,'')||' '||COALESCE(NEW.notes,''));
END;
CREATE TRIGGER trg_brand_artifacts_ad AFTER DELETE ON brand_artifacts BEGIN
    DELETE FROM search_fts WHERE entity_type='brand_artifact' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_brand_artifacts_au AFTER UPDATE ON brand_artifacts BEGIN
    DELETE FROM search_fts WHERE entity_type='brand_artifact' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('brand_artifact', NEW.id, COALESCE(NEW.title,''),
            COALESCE(NEW.lane,'')||' '||COALESCE(NEW.format,'')||' '||
            COALESCE(NEW.channel,'')||' '||COALESCE(NEW.notes,''));
END;
CREATE TRIGGER trg_sponsors_network_ai AFTER INSERT ON sponsors_network BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('sponsor', NEW.id, COALESCE(NEW.name,''),
            COALESCE(NEW.relationship,'')||' '||COALESCE(NEW.role_level,'')||' '||
            COALESCE(NEW.next_activation,'')||' '||COALESCE(NEW.notes,''));
END;
CREATE TRIGGER trg_sponsors_network_ad AFTER DELETE ON sponsors_network BEGIN
    DELETE FROM search_fts WHERE entity_type='sponsor' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_sponsors_network_au AFTER UPDATE ON sponsors_network BEGIN
    DELETE FROM search_fts WHERE entity_type='sponsor' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('sponsor', NEW.id, COALESCE(NEW.name,''),
            COALESCE(NEW.relationship,'')||' '||COALESCE(NEW.role_level,'')||' '||
            COALESCE(NEW.next_activation,'')||' '||COALESCE(NEW.notes,''));
END;
CREATE TRIGGER trg_coaching_log_ai AFTER INSERT ON coaching_log BEGIN
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('coaching_log', NEW.id, COALESCE(NEW.topic,''),
            COALESCE(NEW.summary,'')||' '||COALESCE(NEW.framework,'')||' '||COALESCE(NEW.action_items,''));
END;
CREATE TRIGGER trg_coaching_log_ad AFTER DELETE ON coaching_log BEGIN
    DELETE FROM search_fts WHERE entity_type='coaching_log' AND entity_id=OLD.id;
END;
CREATE TRIGGER trg_coaching_log_au AFTER UPDATE ON coaching_log BEGIN
    DELETE FROM search_fts WHERE entity_type='coaching_log' AND entity_id=OLD.id;
    INSERT INTO search_fts(entity_type, entity_id, title, body)
    VALUES ('coaching_log', NEW.id, COALESCE(NEW.topic,''),
            COALESCE(NEW.summary,'')||' '||COALESCE(NEW.framework,'')||' '||COALESCE(NEW.action_items,''));
END;
CREATE TRIGGER trg_career_goals_touch AFTER UPDATE ON career_goals BEGIN
    UPDATE career_goals SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_promotion_evidence_touch AFTER UPDATE ON promotion_evidence BEGIN
    UPDATE promotion_evidence SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_brand_artifacts_touch AFTER UPDATE ON brand_artifacts BEGIN
    UPDATE brand_artifacts SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_sponsors_network_touch AFTER UPDATE ON sponsors_network BEGIN
    UPDATE sponsors_network SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_coaching_log_touch AFTER UPDATE ON coaching_log BEGIN
    UPDATE coaching_log SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_cleanup_career_goal AFTER DELETE ON career_goals BEGIN
    DELETE FROM taggings WHERE entity_type='career_goal' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='career_goal' AND src_id=OLD.id) OR (dst_type='career_goal' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_promotion_evidence AFTER DELETE ON promotion_evidence BEGIN
    DELETE FROM taggings WHERE entity_type='promotion_evidence' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='promotion_evidence' AND src_id=OLD.id) OR (dst_type='promotion_evidence' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_brand_artifact AFTER DELETE ON brand_artifacts BEGIN
    DELETE FROM taggings WHERE entity_type='brand_artifact' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='brand_artifact' AND src_id=OLD.id) OR (dst_type='brand_artifact' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_sponsor AFTER DELETE ON sponsors_network BEGIN
    DELETE FROM taggings WHERE entity_type='sponsor' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='sponsor' AND src_id=OLD.id) OR (dst_type='sponsor' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_cleanup_coaching_log AFTER DELETE ON coaching_log BEGIN
    DELETE FROM taggings WHERE entity_type='coaching_log' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='coaching_log' AND src_id=OLD.id) OR (dst_type='coaching_log' AND dst_id=OLD.id);
END;
CREATE VIEW v_career_goal_phases AS
    SELECT id AS goal_id, theme, horizon, phase, objective,
           track_target, target_level, status, target_date, lead_theme
      FROM career_goals
     ORDER BY COALESCE(phase, 0), target_date
/* v_career_goal_phases(goal_id,theme,horizon,phase,objective,track_target,target_level,status,target_date,lead_theme) */;
CREATE VIEW v_promotion_evidence_by_axis AS
    SELECT COALESCE(next_level_bar_axis,'(unassigned)') AS next_level_bar_axis,
           COUNT(*) AS evidence_count,
           MAX(evidence_date) AS latest_evidence_date
      FROM promotion_evidence
     GROUP BY COALESCE(next_level_bar_axis,'(unassigned)')
     ORDER BY evidence_count DESC
/* v_promotion_evidence_by_axis(next_level_bar_axis,evidence_count,latest_evidence_date) */;
CREATE VIEW v_sponsor_map AS
    SELECT id AS sponsor_id, name, role_level, relationship,
           can_carry_next_level_case, influence, last_touch, next_activation, person_id
      FROM sponsors_network
     ORDER BY can_carry_next_level_case DESC,
              CASE influence WHEN 'high' THEN 3 WHEN 'med' THEN 2 WHEN 'low' THEN 1 ELSE 0 END DESC,
              last_touch
/* v_sponsor_map(sponsor_id,name,role_level,relationship,can_carry_next_level_case,influence,last_touch,next_activation,person_id) */;
CREATE VIEW v_promotion_evidence_log AS
    SELECT id, artifact, evidence_date, blast_radius, business_impact,
           archetype_tag, next_level_bar_axis, source_link
      FROM promotion_evidence
     ORDER BY (evidence_date IS NULL), evidence_date DESC, id
/* v_promotion_evidence_log(id,artifact,evidence_date,blast_radius,business_impact,archetype_tag,next_level_bar_axis,source_link) */;
CREATE VIEW v_coaching_log AS
    SELECT id, session_date, topic, summary, framework, action_items
      FROM coaching_log
     ORDER BY session_date DESC, id DESC
/* v_coaching_log(id,session_date,topic,summary,framework,action_items) */;
CREATE VIEW v_brand_pipeline AS
    SELECT id AS artifact_id, title, lane, channel, format, status,
           is_provisional, publish_date, engagement, url, notes
      FROM brand_artifacts
     ORDER BY (status='published') DESC, COALESCE(publish_date,'9999-12-31')
/* v_brand_pipeline(artifact_id,title,lane,channel,format,status,is_provisional,publish_date,engagement,url,notes) */;
CREATE VIEW v_health_overview AS
    SELECT ns.theme_goal_id,
           ns.north_star,
           okr.goal_id,
           okr.objective,
           okr.week_of,
           okr.total_weeks,
           okr.days_remaining
      FROM (SELECT 1 AS one) anchor
      LEFT JOIN (
            SELECT g.id AS theme_goal_id,
                   CASE WHEN instr(g.description, '[NORTH-STAR:') > 0 THEN
                        trim(substr(
                            substr(g.description, instr(g.description, '[NORTH-STAR:') + 12),
                            1,
                            instr(substr(g.description, instr(g.description, '[NORTH-STAR:') + 12) || ']', ']') - 1
                        ))
                   END AS north_star
              FROM goals g
             WHERE g.title = 'Annual Theme · Example wellness goal'
               AND g.horizon = 'annual'
             LIMIT 1
        ) ns ON 1 = 1
      LEFT JOIN (
            SELECT goal_id, objective, week_of, total_weeks, days_remaining
              FROM v_objective_rollup
             WHERE objective = 'Q3 2026 · Example health objective'
             LIMIT 1
        ) okr ON 1 = 1
/* v_health_overview(theme_goal_id,north_star,goal_id,objective,week_of,total_weeks,days_remaining) */;
CREATE VIEW v_health_kr_progress AS
    SELECT pp.goal_id, pp.objective,
           pp.kr_id, pp.key_result, pp.kr_kind, pp.metric_type, pp.source_metric,
           pp.start_value, pp.current_value, pp.target_value,
           pp.attainment, pp.pace_signal,
           pp.week_of, pp.total_weeks, pp.days_remaining,
           (pp.source_metric IS NOT NULL)                              AS live,
           (pp.current_value IS NULL AND pp.target_value IS NULL)      AS baseline_pending
      FROM v_plan_progress pp
     WHERE pp.objective = 'Q3 2026 · Example health objective'
     ORDER BY pp.kr_id
/* v_health_kr_progress(goal_id,objective,kr_id,key_result,kr_kind,metric_type,source_metric,start_value,current_value,target_value,attainment,pace_signal,week_of,total_weeks,days_remaining,live,baseline_pending) */;
CREATE VIEW v_health_habits AS
    SELECT h.id, h.name, h.identity_statement, h.cue, h.frequency,
           h.frequency_target, h.measure_type, h.unit, h.target_value, h.active,
           a.adherence_30, a.current_streak, a.streak_unit
      FROM habits h
      LEFT JOIN v_habit_adherence a ON a.habit_id = h.id
     WHERE h.area = 'health'
     ORDER BY h.active DESC, h.name
/* v_health_habits(id,name,identity_statement,cue,frequency,frequency_target,measure_type,unit,target_value,active,adherence_30,current_streak,streak_unit) */;
CREATE INDEX idx_tasks_priority_rank ON tasks(priority_rank);
CREATE VIEW v_prioritized_tasks AS
    SELECT t.id                                    AS task_id,
           t.title                                 AS title,
           t.notes                                 AS notes,
           CASE t.context
             WHEN '@health' THEN 'health'
             WHEN '@career' THEN 'career'
             ELSE REPLACE(t.context, '@', '')
           END                                     AS domain,
           g.title                                 AS goal_objective,
           t.effort                                AS effort,
           t.priority_rank                         AS priority_rank,
           t.due_date                              AS due_date,
           t.status                                AS status
      FROM tasks t
      JOIN goals g ON g.id = t.goal_id
     WHERE g.horizon = 'quarter'
       AND g.title IN (
             'Q3 2026 · Example health objective',
             'Q3 2026 · Example career objective')
       AND (t.status = 'next' OR t.is_next_action = 1)
       AND t.status NOT IN ('someday','done','cancelled')
     ORDER BY (t.priority_rank IS NULL), t.priority_rank,
              CASE t.effort
                WHEN 'quick_win' THEN 1
                WHEN 'light'     THEN 2
                WHEN 'moderate'  THEN 3
                WHEN 'deep_work' THEN 4
                ELSE 5
              END,
              (t.due_date IS NULL), t.due_date,
              t.id
/* v_prioritized_tasks(task_id,title,notes,domain,goal_objective,effort,priority_rank,due_date,status) */;
CREATE VIEW v_health_gated_actions AS
    SELECT t.id, t.title, t.notes, t.status, t.is_next_action, t.due_date,
           t.effort, t.priority_rank,
           (t.status = 'someday')                                    AS gated,
           (t.title LIKE '%[MD]%' OR t.notes LIKE '%[MD]%')          AS md
      FROM tasks t
     WHERE t.goal_id = (SELECT id FROM goals
                         WHERE title = 'Q3 2026 · Example health objective'
                           AND horizon = 'quarter')
       AND (t.status = 'someday' OR t.title LIKE '%[MD]%' OR t.notes LIKE '%[MD]%')
     ORDER BY (t.due_date IS NULL), t.due_date, t.id
/* v_health_gated_actions(id,title,notes,status,is_next_action,due_date,effort,priority_rank,gated,md) */;
CREATE VIEW v_holdings_latest AS
    WITH ranked AS (
        SELECT h.id,
               h.account_id,
               h.instrument,
               CASE WHEN instr(h.instrument, ' ') > 0
                    THEN substr(h.instrument, 1, instr(h.instrument, ' ') - 1)
                    ELSE h.instrument
               END                                       AS symbol,
               h.as_of_date,
               h.quantity,
               h.cost_basis,
               h.market_value,
               h.currency,
               h.created_at,
               h.updated_at,
               ROW_NUMBER() OVER (
                   PARTITION BY h.account_id,
                                CASE WHEN instr(h.instrument, ' ') > 0
                                     THEN substr(h.instrument, 1, instr(h.instrument, ' ') - 1)
                                     ELSE h.instrument
                                END
                   ORDER BY h.as_of_date DESC, h.id DESC
               )                                         AS rn
          FROM holdings h
    )
    SELECT id, account_id, instrument, symbol, as_of_date,
           quantity, cost_basis, market_value, currency, created_at, updated_at
      FROM ranked
     WHERE rn = 1
/* v_holdings_latest(id,account_id,instrument,symbol,as_of_date,quantity,cost_basis,market_value,currency,created_at,updated_at) */;
CREATE INDEX idx_supplements_status    ON supplements(status);
CREATE INDEX idx_supplements_gate_task ON supplements(gate_task_id);
CREATE TRIGGER trg_supplements_insert_guard
BEFORE INSERT ON supplements
WHEN NEW.is_current = 0 AND NEW.status = 'active'
BEGIN
    SELECT RAISE(ABORT,
      'supplements: is_current is DERIVED from status. Inserting is_current=0 with status=''active'' is a contradiction — set status to gated / as_needed / discontinued instead.');
END;
CREATE TRIGGER trg_supplements_derive_is_current_ins
AFTER INSERT ON supplements
WHEN NEW.is_current <> (CASE WHEN NEW.status='active' THEN 1 ELSE 0 END)
BEGIN
    UPDATE supplements
       SET is_current = CASE WHEN NEW.status='active' THEN 1 ELSE 0 END
     WHERE id = NEW.id;
END;
CREATE TRIGGER trg_supplements_is_current_guard
BEFORE UPDATE OF is_current ON supplements
-- Reads as: "you may not set is_current to anything other than what status
-- derives." The third clause is load-bearing — without it this trigger also
-- refuses the two derive triggers below, whose whole job is to write is_current
-- TO its derived value. (SQLite fires triggers on statements run from inside a
-- trigger program; recursive_triggers only stops a trigger re-firing ITSELF.)
WHEN NEW.status = OLD.status
 AND NEW.is_current <> OLD.is_current
 AND NEW.is_current <> (CASE WHEN NEW.status='active' THEN 1 ELSE 0 END)
BEGIN
    SELECT RAISE(ABORT,
      'supplements: is_current is DERIVED from status and cannot be set directly. Update status instead (active | gated | as_needed | discontinued).');
END;
CREATE TRIGGER trg_supplements_derive_is_current_upd
AFTER UPDATE OF status ON supplements
WHEN NEW.is_current <> (CASE WHEN NEW.status='active' THEN 1 ELSE 0 END)
BEGIN
    UPDATE supplements
       SET is_current = CASE WHEN NEW.status='active' THEN 1 ELSE 0 END
     WHERE id = NEW.id;
END;
CREATE TRIGGER trg_supplements_gate_required_ins
BEFORE INSERT ON supplements
WHEN NEW.status = 'gated' AND NEW.gate_reason IS NULL AND NEW.gate_task_id IS NULL
BEGIN
    SELECT RAISE(ABORT,
      'supplements: status=''gated'' requires gate_reason and/or gate_task_id — a hold with no recorded gate is an untracked waiting-for.');
END;
CREATE TRIGGER trg_supplements_gate_required_upd
BEFORE UPDATE ON supplements
WHEN NEW.status = 'gated' AND NEW.gate_reason IS NULL AND NEW.gate_task_id IS NULL
BEGIN
    SELECT RAISE(ABORT,
      'supplements: status=''gated'' requires gate_reason and/or gate_task_id — a hold with no recorded gate is an untracked waiting-for.');
END;
CREATE TABLE "accounts" (
    id                INTEGER PRIMARY KEY,
    name              TEXT NOT NULL,
    institution       TEXT,
    type              TEXT,              -- PEA | NISA | assurance_vie | iDeCo | PER | livret_a | checking | brokerage | ...
    jurisdiction      TEXT,              -- country A | country B | ...
    currency          TEXT NOT NULL,     -- ISO-4217 account base currency
    owner             TEXT,
    identifier_masked TEXT,              -- masked identifier only (Guardrail 8)
    status            TEXT NOT NULL DEFAULT 'open'
                        CHECK (status IN ('open','pending_open','blocked','closing','closed')),
    status_since      TEXT,              -- YYYY-MM-DD, the date the row entered `status`.
                                         -- Maintained by trg_accounts_status_since on every
                                         -- status change. NULL = entered the inventory in this
                                         -- state and no change has been recorded since.
    notes             TEXT,
    created_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at        TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;
CREATE INDEX idx_accounts_jurisdiction ON accounts(jurisdiction);
CREATE INDEX idx_accounts_type         ON accounts(type);
CREATE INDEX idx_accounts_status       ON accounts(status);
CREATE VIEW v_net_worth AS
    WITH latest_bal AS (
        SELECT bs.account_id, bs.balance, bs.currency, bs.snapshot_date
          FROM balance_snapshots bs
          JOIN (SELECT account_id, MAX(snapshot_date) AS md
                  FROM balance_snapshots GROUP BY account_id) mx
            ON mx.account_id = bs.account_id AND mx.md = bs.snapshot_date
    ),
    fx AS (  -- latest rate per (base_ccy -> base currency). Base is configurable:
             -- change the 'USD' literals to your own ISO-4217 code.
        SELECT f.base_ccy, f.rate
          FROM fx_rates f
          JOIN (SELECT base_ccy, MAX(rate_date) md FROM fx_rates
                 WHERE quote_ccy='USD' GROUP BY base_ccy) m
            ON m.base_ccy=f.base_ccy AND m.md=f.rate_date AND f.quote_ccy='USD'
    )
    SELECT a.id AS account_id, a.name, a.jurisdiction, a.type,
           lb.currency, lb.balance, lb.snapshot_date,
           CASE WHEN lb.currency='USD' THEN lb.balance
                WHEN fx.rate IS NOT NULL THEN ROUND(lb.balance * fx.rate, 2)
                ELSE NULL END AS balance_base
      FROM accounts a
      LEFT JOIN latest_bal lb ON lb.account_id = a.id
      LEFT JOIN fx ON fx.base_ccy = lb.currency
     WHERE a.status <> 'closed'
/* v_net_worth(account_id,name,jurisdiction,type,currency,balance,snapshot_date,balance_base) */;
CREATE VIEW v_accounts_in_flight AS
    SELECT a.id                AS account_id,
           a.name,
           a.institution,
           a.type,
           a.jurisdiction,
           a.currency,
           a.status,
           a.status_since,
           CASE WHEN a.status_since IS NOT NULL
                THEN CAST(julianday(date('now')) - julianday(a.status_since) AS INTEGER)
           END                 AS days_in_state,
           a.notes,
           (SELECT COUNT(*) FROM links l JOIN tasks t ON t.id = l.src_id
             WHERE l.src_type='task' AND l.dst_type='account' AND l.dst_id = a.id
               AND t.status NOT IN ('done','cancelled'))          AS open_followups,
           (SELECT COUNT(*) FROM links l JOIN tasks t ON t.id = l.src_id
             WHERE l.src_type='task' AND l.dst_type='account' AND l.dst_id = a.id
               AND t.status NOT IN ('done','cancelled')
               AND t.due_date IS NOT NULL AND t.due_date < date('now')) AS overdue_followups
      FROM accounts a
     WHERE a.status NOT IN ('open','closed')
/* v_accounts_in_flight(account_id,name,institution,type,jurisdiction,currency,status,status_since,days_in_state,notes,open_followups,overdue_followups) */;
CREATE VIEW v_supplement_gates AS
    SELECT s.id            AS supplement_id,
           s.name,
           s.status,
           s.dose,
           s.gate_reason,
           s.gate_task_id,
           t.title         AS gate_task_title,
           t.status        AS gate_task_status,
           t.due_date      AS gate_task_due,
           t.scheduled_for AS gate_task_scheduled,
           CASE WHEN s.gate_task_id IS NOT NULL THEN 1 ELSE 0 END        AS gate_tracked,
           CASE WHEN t.status = 'done' THEN 1 ELSE 0 END                 AS gate_cleared,
           CASE WHEN t.status = 'done' THEN 0 ELSE 1 END                 AS gate_open,
           CASE WHEN t.due_date IS NOT NULL
                 AND t.due_date < date('now')
                 AND COALESCE(t.status,'') NOT IN ('done','cancelled')
                THEN CAST(julianday(date('now')) - julianday(t.due_date) AS INTEGER)
           END                                                           AS gate_overdue_days
      FROM supplements s
      LEFT JOIN tasks t ON t.id = s.gate_task_id
     WHERE s.status = 'gated'
/* v_supplement_gates(supplement_id,name,status,dose,gate_reason,gate_task_id,gate_task_title,gate_task_status,gate_task_due,gate_task_scheduled,gate_tracked,gate_cleared,gate_open,gate_overdue_days) */;
CREATE VIEW v_weekly_review AS
    SELECT 'inbox_tasks'    AS bucket,
           (SELECT COUNT(*) FROM tasks WHERE status='inbox')     AS count
    UNION ALL SELECT 'waiting_for',
           (SELECT COUNT(*) FROM tasks WHERE status='waiting')
    UNION ALL SELECT 'someday',
           (SELECT COUNT(*) FROM tasks WHERE status='someday')
    UNION ALL SELECT 'next_actions',
           (SELECT COUNT(*) FROM tasks WHERE status='next' AND is_next_action=1)
    UNION ALL SELECT 'stale_active_projects',  -- no task activity in 14 days
           (SELECT COUNT(*) FROM projects pr WHERE pr.status='active'
              AND NOT EXISTS (SELECT 1 FROM tasks t WHERE t.project_id=pr.id
                                AND t.updated_at >= datetime('now','-14 days')))
    UNION ALL SELECT 'overdue_followups',
           (SELECT COUNT(*) FROM v_followups_due)
    -- --- added 2026-08-20 (migrate_status_columns_20260820) -------------------
    UNION ALL SELECT 'supplements_gated',           -- deliberate physician holds
           (SELECT COUNT(*) FROM supplements WHERE status='gated')
    UNION ALL SELECT 'supplements_gated_unbooked',  -- ...still waiting on an open/absent action
           (SELECT COUNT(*) FROM v_supplement_gates WHERE gate_open=1)
    UNION ALL SELECT 'accounts_in_flight',          -- pending_open | blocked | closing
           (SELECT COUNT(*) FROM v_accounts_in_flight)
/* v_weekly_review(bucket,count) */;
CREATE TRIGGER trg_accounts_touch AFTER UPDATE ON accounts BEGIN
    UPDATE accounts SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = NEW.id;
END;
CREATE TRIGGER trg_cleanup_account AFTER DELETE ON accounts BEGIN
    DELETE FROM taggings WHERE entity_type='account' AND entity_id=OLD.id;
    DELETE FROM links WHERE (src_type='account' AND src_id=OLD.id) OR (dst_type='account' AND dst_id=OLD.id);
END;
CREATE TRIGGER trg_accounts_status_since
AFTER UPDATE OF status ON accounts
WHEN NEW.status <> OLD.status
BEGIN
    UPDATE accounts SET status_since = date('now') WHERE id = NEW.id;
END;
CREATE VIEW v_habit_adherence AS
WITH
obs AS (
    -- THE OBSERVATION SET. One row per journaled day inside the 30-day window.
    -- DISTINCT because nothing stops two daily rows sharing a date; a day is
    -- observed once or not at all, never twice.
    SELECT DISTINCT e.entry_date AS d
      FROM entries e
     WHERE e.kind = 'daily'
       AND e.entry_date IS NOT NULL
       AND e.entry_date >= date('now','-29 days')
       AND e.entry_date <= date('now')
),
obs_n AS (
    SELECT
      (SELECT COUNT(*) FROM obs)                                          AS observed_30,
      (SELECT COUNT(*) FROM obs WHERE d >= date('now','-6 days'))          AS observed_7,
      (SELECT MAX(entry_date) FROM entries
        WHERE kind='daily' AND entry_date IS NOT NULL)                     AS logged_through
),
sched AS (
    SELECT h.id AS habit_id,
           o.d  AS d,
           CASE WHEN o.d >= date('now','-6 days') THEN 1 ELSE 0 END AS in_7,
           CASE h.frequency
             WHEN 'daily'         THEN 1
             WHEN 'x_per_week'    THEN 1   -- no day is pinned; count-based below
             WHEN 'weekdays'      THEN CASE WHEN CAST(strftime('%w',o.d) AS INTEGER)
                                                 BETWEEN 1 AND 5 THEN 1 ELSE 0 END
             WHEN 'specific_days' THEN CASE WHEN (','||replace(lower(COALESCE(h.specific_days,'')),' ','')||',')
                    LIKE '%,'||(CASE CAST(strftime('%w',o.d) AS INTEGER)
                         WHEN 0 THEN 'sun' WHEN 1 THEN 'mon' WHEN 2 THEN 'tue' WHEN 3 THEN 'wed'
                         WHEN 4 THEN 'thu' WHEN 5 THEN 'fri' WHEN 6 THEN 'sat' END)||',%'
                    THEN 1 ELSE 0 END
             ELSE 0 END AS scheduled
      FROM habits h
      CROSS JOIN obs o
     WHERE h.active = 1
),
agg AS (
    SELECT h.id AS habit_id,
           COALESCE(SUM(CASE WHEN s.in_7=1 THEN s.scheduled ELSE 0 END),0)          AS scheduled_7,
           COALESCE(SUM(s.scheduled),0)                                            AS scheduled_30,
           COALESCE(SUM(CASE WHEN s.in_7=1 AND COALESCE(hl.completed,0)=1
                    THEN 1 ELSE 0 END),0)                                          AS done_7,
           COALESCE(SUM(CASE WHEN COALESCE(hl.completed,0)=1 THEN 1 ELSE 0 END),0)  AS done_30,
           COALESCE(SUM(CASE WHEN s.in_7=1 AND s.scheduled=1 AND COALESCE(hl.completed,0)=1
                    THEN 1 ELSE 0 END),0)                                          AS done_7_scheduled,
           COALESCE(SUM(CASE WHEN s.scheduled=1 AND COALESCE(hl.completed,0)=1
                    THEN 1 ELSE 0 END),0)                                          AS done_30_scheduled
      FROM habits h
      -- LEFT JOIN, not the old inner JOIN: with an EMPTY observation set `sched`
      -- has no rows, and an inner join would drop every habit out of the view
      -- entirely. One row per active habit must survive at all times, carrying
      -- NULL adherence — "unknown", not "absent".
      LEFT JOIN sched s     ON s.habit_id = h.id
      LEFT JOIN habit_logs hl
             ON hl.habit_id = s.habit_id AND hl.log_date = s.d
     WHERE h.active = 1
     GROUP BY h.id
)
SELECT h.id                       AS habit_id,
       h.name                     AS name,
       h.frequency                AS frequency,
       h.frequency_target         AS frequency_target,
       a.done_7                   AS done_7,
       a.done_30                  AS done_30,
       -- adherence is now OVER OBSERVED DAYS. NULLIF(...,0) means: no observed
       -- day in the window -> NULL -> "unknown". Never 0, never a false red.
       -- CAPPED AT 1.0. Doing three times your weekly target is not 300%
       -- adherence, it is 100% adherence and some extra; and an uncapped ratio
       -- would drag the AVG() in the rollup -- and therefore the KR -- above
       -- 100%. Pro-rating the denominator to observed days makes this easy to
       -- hit (a 1x/week habit over 12 observed days expects 1.7), so the cap is
       -- load-bearing now in a way it was not before. The RAW performance stays
       -- fully visible in credited_N / expected_N, which are never capped.
       CASE h.frequency
         WHEN 'daily'         THEN MIN(ROUND(a.done_7 * 1.0 / NULLIF(a.scheduled_7 ,0), 3), 1.0)
         WHEN 'weekdays'      THEN MIN(ROUND(a.done_7_scheduled * 1.0 / NULLIF(a.scheduled_7 ,0), 3), 1.0)
         WHEN 'specific_days' THEN MIN(ROUND(a.done_7_scheduled * 1.0 / NULLIF(a.scheduled_7 ,0), 3), 1.0)
         WHEN 'x_per_week'    THEN MIN(ROUND(a.done_7 * 1.0 /
                                    NULLIF(COALESCE(h.frequency_target,7) * (SELECT observed_7 FROM obs_n) / 7.0, 0), 3), 1.0)
         ELSE NULL END           AS adherence_7,
       CASE h.frequency
         WHEN 'daily'         THEN MIN(ROUND(a.done_30 * 1.0 / NULLIF(a.scheduled_30,0), 3), 1.0)
         WHEN 'weekdays'      THEN MIN(ROUND(a.done_30_scheduled * 1.0 / NULLIF(a.scheduled_30,0), 3), 1.0)
         WHEN 'specific_days' THEN MIN(ROUND(a.done_30_scheduled * 1.0 / NULLIF(a.scheduled_30,0), 3), 1.0)
         WHEN 'x_per_week'    THEN MIN(ROUND(a.done_30 * 1.0 /
                                    NULLIF(COALESCE(h.frequency_target,7) * (SELECT observed_30 FROM obs_n) / 7.0, 0), 3), 1.0)
         ELSE NULL END           AS adherence_30,
       COALESCE(s.streak_unit,'days') AS streak_unit,
       COALESCE(s.current_streak,0)   AS current_streak,
       COALESCE(s.longest_streak,0)   AS longest_streak,
       -- credited_N / expected_N: the ACTUAL numerator and denominator used, for
       -- EVERY frequency. Render as "3 of 4". expected_N is now PRO-RATED to the
       -- observed days, so it is routinely FRACTIONAL — do not round it to an
       -- integer for display, and never re-derive it.
       CASE h.frequency
         WHEN 'daily'         THEN a.done_7
         WHEN 'weekdays'      THEN a.done_7_scheduled
         WHEN 'specific_days' THEN a.done_7_scheduled
         WHEN 'x_per_week'    THEN a.done_7
         ELSE NULL END           AS credited_7,
       CASE h.frequency
         WHEN 'daily'         THEN a.scheduled_7 * 1.0
         WHEN 'weekdays'      THEN a.scheduled_7 * 1.0
         WHEN 'specific_days' THEN a.scheduled_7 * 1.0
         WHEN 'x_per_week'    THEN ROUND(COALESCE(h.frequency_target,7) * (SELECT observed_7 FROM obs_n) / 7.0, 3)
         ELSE NULL END           AS expected_7,
       CASE h.frequency
         WHEN 'daily'         THEN a.done_30
         WHEN 'weekdays'      THEN a.done_30_scheduled
         WHEN 'specific_days' THEN a.done_30_scheduled
         WHEN 'x_per_week'    THEN a.done_30
         ELSE NULL END           AS credited_30,
       CASE h.frequency
         WHEN 'daily'         THEN a.scheduled_30 * 1.0
         WHEN 'weekdays'      THEN a.scheduled_30 * 1.0
         WHEN 'specific_days' THEN a.scheduled_30 * 1.0
         WHEN 'x_per_week'    THEN ROUND(COALESCE(h.frequency_target,7) * (SELECT observed_30 FROM obs_n) / 7.0, 3)
         ELSE NULL END           AS expected_30,
       -- --- appended 2026-08-20: the honesty columns ------------------------
       (SELECT observed_7  FROM obs_n)                                   AS observed_days_7,
       (SELECT observed_30 FROM obs_n)                                   AS observed_days_30,
       ROUND((SELECT observed_7  FROM obs_n) * 100.0 / 7.0,  1)          AS coverage_7_pct,
       ROUND((SELECT observed_30 FROM obs_n) * 100.0 / 30.0, 1)          AS coverage_30_pct,
       (SELECT logged_through FROM obs_n)                                AS logged_through,
       CASE WHEN (SELECT logged_through FROM obs_n) IS NOT NULL
            THEN CAST(julianday(date('now')) - julianday((SELECT logged_through FROM obs_n)) AS INTEGER)
       END                                                               AS log_lag_days
  FROM habits h
  JOIN agg a                  ON a.habit_id = h.id
  LEFT JOIN v_habit_streaks s ON s.habit_id = h.id
 WHERE h.active = 1
/* v_habit_adherence(habit_id,name,frequency,frequency_target,done_7,done_30,adherence_7,adherence_30,streak_unit,current_streak,longest_streak,credited_7,expected_7,credited_30,expected_30,observed_days_7,observed_days_30,coverage_7_pct,coverage_30_pct,logged_through,log_lag_days) */;
CREATE VIEW v_habit_adherence_rollup AS
    SELECT COUNT(*)                            AS active_habits,
           ROUND(AVG(adherence_7),3)           AS mean_adherence_7,
           ROUND(AVG(adherence_30),3)          AS mean_adherence_30,
           -- appended 2026-08-20
           SUM(CASE WHEN adherence_30 IS NOT NULL THEN 1 ELSE 0 END) AS habits_scored,
           MAX(observed_days_7)                AS observed_days_7,
           MAX(observed_days_30)               AS observed_days_30,
           MAX(coverage_7_pct)                 AS coverage_7_pct,
           MAX(coverage_30_pct)                AS coverage_30_pct,
           MAX(logged_through)                 AS logged_through,
           MAX(log_lag_days)                   AS log_lag_days,
           -- PROVISIONAL: below 50% coverage (Chief of Staff's threshold) the behaviour
           -- number is not yet trustworthy and must be labelled wherever shown.
           CASE WHEN COALESCE(MAX(coverage_30_pct),0) < 50.0 THEN 1 ELSE 0 END AS is_provisional
      FROM v_habit_adherence
/* v_habit_adherence_rollup(active_habits,mean_adherence_7,mean_adherence_30,habits_scored,observed_days_7,observed_days_30,coverage_7_pct,coverage_30_pct,logged_through,log_lag_days,is_provisional) */;
CREATE VIEW v_habit_adherence_by_area AS
    SELECT COALESCE(h.area,'(unassigned)')     AS area,
           COUNT(*)                            AS active_habits,
           SUM(CASE WHEN a.adherence_30 IS NOT NULL THEN 1 ELSE 0 END) AS habits_scored,
           ROUND(AVG(a.adherence_7),3)         AS mean_adherence_7,
           ROUND(AVG(a.adherence_30),3)        AS mean_adherence_30,
           MAX(a.coverage_30_pct)              AS coverage_30_pct,
           MAX(a.log_lag_days)                 AS log_lag_days
      FROM v_habit_adherence a
      JOIN habits h ON h.id = a.habit_id
     GROUP BY COALESCE(h.area,'(unassigned)')
     ORDER BY area
/* v_habit_adherence_by_area(area,active_habits,habits_scored,mean_adherence_7,mean_adherence_30,coverage_30_pct,log_lag_days) */;
CREATE VIEW v_off_pace AS
    SELECT pp.goal_id           AS goal_id,
           pp.objective         AS objective,
           pp.kr_id             AS kr_id,
           pp.key_result        AS key_result,
           pp.start_value       AS start_value,
           pp.current_value     AS current_value,     -- LIVE (source-resolved)
           pp.target_value      AS target_value,
           pp.progress_fraction AS progress_fraction,
           pp.time_fraction     AS time_fraction,
           pp.stored_current    AS stored_current,    -- raw key_results value
           pp.source_metric     AS source_metric,
           pp.target_score      AS target_score,
           pp.attainment        AS attainment,
           pp.pace_signal       AS pace_signal,
           CASE WHEN pp.stored_current IS NOT NULL
                 AND pp.current_value  IS NOT NULL
                 AND pp.stored_current <> pp.current_value
                THEN 1 ELSE 0 END AS stale_stored,
           -- appended 2026-08-20 — populated only for the habit-adherence KR,
           -- NULL/0 for every other row, so no other KR's rendering changes.
           CASE WHEN pp.source_metric = 'habit_adherence_30_pct'
                THEN (SELECT coverage_30_pct FROM v_habit_adherence_rollup)
           END                                                AS coverage_30_pct,
           CASE WHEN pp.source_metric = 'habit_adherence_30_pct'
                THEN (SELECT log_lag_days FROM v_habit_adherence_rollup)
           END                                                AS log_lag_days,
           CASE WHEN pp.source_metric = 'habit_adherence_30_pct'
                 AND (SELECT is_provisional FROM v_habit_adherence_rollup) = 1
                THEN 1 ELSE 0 END                             AS provisional_low_coverage
      FROM v_plan_progress pp
     WHERE pp.progress_fraction IS NOT NULL
       AND pp.time_fraction     IS NOT NULL
       AND pp.progress_fraction < pp.time_fraction
     ORDER BY (pp.time_fraction - pp.progress_fraction) DESC
/* v_off_pace(goal_id,objective,kr_id,key_result,start_value,current_value,target_value,progress_fraction,time_fraction,stored_current,source_metric,target_score,attainment,pace_signal,stale_stored,coverage_30_pct,log_lag_days,provisional_low_coverage) */;
CREATE VIEW v_plan_progress AS
WITH kr AS (
    SELECT g.id AS goal_id, g.title AS objective, g.period_start, g.period_end,
           k.id AS kr_id, k.description AS key_result, k.kr_kind, k.metric_type, k.currency,
           k.start_value, k.target_value, k.current_value AS stored_current, k.score,
           ks.source_metric,
           -- FIX 2: each KR's own baseline date (falls back to period_start if the
           -- KR was created at/before quarter-start or created_at is unavailable).
           date(k.created_at) AS kr_baseline_date,
           CASE ks.source_metric
             WHEN 'body_metric.weight_kg' THEN
                  -- FIX 1: latest PHASE-CLEAN weight only (is_kr_eligible = 1).
                  (SELECT bm.weight_kg FROM body_metrics bm
                    WHERE bm.weight_kg IS NOT NULL
                      AND bm.is_kr_eligible = 1
                    ORDER BY bm.metric_date DESC, bm.id DESC LIMIT 1)
             WHEN 'habit_adherence_30_pct' THEN
                  (SELECT ROUND(mean_adherence_30*100,1) FROM v_habit_adherence_rollup)
             ELSE k.current_value
           END AS current_value,
           CASE k.kr_kind WHEN 'committed' THEN 1.0 ELSE 0.7 END AS target_score
      FROM goals g
      JOIN key_results k ON k.goal_id = g.id
      LEFT JOIN key_result_sources ks ON ks.kr_id = k.id
     WHERE g.horizon='quarter' AND g.status='active'
),
calc AS (
    SELECT kr.*,
           CASE WHEN target_value IS NOT NULL AND start_value IS NOT NULL
                     AND target_value <> start_value
                THEN (current_value - start_value)*1.0 / (target_value - start_value)
                ELSE score END AS progress_fraction,
           -- FIX 2: pace window starts at the KR's baseline date, clamped into
           -- [period_start, period_end]; NULL when the goal window is degenerate.
           CASE WHEN period_start IS NOT NULL AND period_end IS NOT NULL
                     AND julianday(period_end) <> julianday(period_start)
                THEN MIN(1.0, MAX(0.0,
                       (julianday('now') - julianday(
                           CASE
                             WHEN kr_baseline_date IS NULL
                                  OR julianday(kr_baseline_date) <= julianday(period_start)
                                  OR julianday(kr_baseline_date) >= julianday(period_end)
                               THEN period_start
                             ELSE kr_baseline_date
                           END))
                     / (julianday(period_end) - julianday(
                           CASE
                             WHEN kr_baseline_date IS NULL
                                  OR julianday(kr_baseline_date) <= julianday(period_start)
                                  OR julianday(kr_baseline_date) >= julianday(period_end)
                               THEN period_start
                             ELSE kr_baseline_date
                           END))))
                ELSE NULL END AS time_fraction,
           MAX(1, CAST((julianday('now') - julianday(period_start))/7 AS INTEGER)+1) AS week_of,
           CAST((julianday(period_end) - julianday(period_start))/7 AS INTEGER)+1 AS total_weeks,
           CAST(julianday(period_end) - julianday('now') AS INTEGER) AS days_remaining
      FROM kr
)
SELECT goal_id, objective, period_start, period_end,
       kr_id, key_result, kr_kind, metric_type, currency, source_metric,
       start_value, current_value, stored_current, target_value, target_score,
       ROUND(progress_fraction,3) AS progress_fraction,
       ROUND(time_fraction,3)     AS time_fraction,
       week_of, total_weeks, days_remaining,
       ROUND(CASE WHEN target_score > 0 THEN progress_fraction/target_score END,3) AS attainment,
       -- Traffic light vs the linear-pace line, with a fixed percentage-point
       -- grace band so week-1 zeros are not alarmist (nothing is "overdue" on
       -- day 1). green = within 5pp of / ahead of pace; amber = 5-15pp behind;
       -- red = >15pp behind. (v_off_pace stays the STRICT "behind linear" list.)
       CASE
         WHEN progress_fraction IS NULL OR time_fraction IS NULL THEN 'unknown'
         WHEN progress_fraction >= time_fraction - 0.05         THEN 'green'
         WHEN progress_fraction >= time_fraction - 0.15         THEN 'amber'
         ELSE 'red'
       END AS pace_signal
  FROM calc
 ORDER BY goal_id, kr_id
/* v_plan_progress(goal_id,objective,period_start,period_end,kr_id,key_result,kr_kind,metric_type,currency,source_metric,start_value,current_value,stored_current,target_value,target_score,progress_fraction,time_fraction,week_of,total_weeks,days_remaining,attainment,pace_signal) */;
