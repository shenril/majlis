# Majlis — Unified Knowledge Base (`knowledge.db`)

One normalized, cross-linked **SQLite** store serving **every team domain** — no silos.
Owned and engineered by the data-management specialist (**Knowledge Engineer** in the example
roster). Other teammates **read and write rows**; they request schema changes from the
data owner and never run DDL themselves.

- **Database:** `database/knowledge.db`
- **Schema (source of truth):** `database/schema.sql` (well-commented, sectioned; DDL-only)
- **Theme map:** [`THEMES.md`](THEMES.md) — which tables serve which life theme, and who owns
  them (machine-readable twin: [`theme-map.yaml`](theme-map.yaml))
- **SQLite:** FTS5 required · STRICT tables · **Encryption: SQLCipher** (see *Encryption (SQLCipher)*)

> *Captured, normalized, cross-linked, searchable — every item in its place, nothing
> trapped in prose, nothing lost in a folder.*

---

## How to connect

Once you have run the re-key (see *Encryption (SQLCipher)* below) the database is
**SQLCipher-encrypted**: you must open it **with the passphrase**, and plain `sqlite3`
can no longer open it. Until then it is a normal plaintext SQLite file.

```bash
# SQLCipher CLI (the key is the FIRST statement after opening).
sqlcipher database/knowledge.db
sqlite> PRAGMA key = 'your-passphrase-here';
sqlite> PRAGMA foreign_keys = ON;
sqlite> SELECT COUNT(*) FROM people;   -- verifies the key

# Or from Python (agents): supply the key for your session, then run the
# helper with the DEDICATED VENV interpreter (NOT bare python3 — see below):
export MAJLIS_DB_KEY='your-passphrase'
./.venv/bin/python database/db_connect.py   # uses $MAJLIS_DB_KEY or a secure prompt
```

> **Which Python?** Use a dedicated venv at `database/.venv` with a source-built
> `sqlcipher3` binding. A stock system Python usually has **no** compatible SQLCipher
> binding, so bare `python3 db_connect.py` will fail to import the driver. Always run
> `./.venv/bin/python database/db_connect.py`.
>
> **Supplying the key.** Teammates writing/reading the encrypted DB provide the
> passphrase at runtime — either `export MAJLIS_DB_KEY='…'` for the session
> (never hardcoded or committed), or, with the CLI, `PRAGMA key='…'` as the first
> statement. The key lives only in the owner's head / password manager. (The env var
> name is defined once in `db_connect.py`/`encrypt_db.sh` — rename it there if you like.)

**Every connection MUST set foreign keys on** — it is per-connection and does **not**
persist:

```sql
PRAGMA foreign_keys = ON;
```

`journal_mode = WAL` is **persisted on the DB file**, so concurrent read/write is enabled
without per-connection setup. Wrap multi-row writes in a **transaction** (`BEGIN; … COMMIT;`).

**Temporal spine (one format everywhere):** timestamps are TEXT **ISO-8601 UTC**
`YYYY-MM-DDTHH:MM:SSZ`; plain calendar dates are `YYYY-MM-DD`. Never mix or use local
time in stored values.

**Currency:** store an ISO-4217 TEXT currency code on **every** monetary row (the schema
is multi-currency by design — never assume a single currency).

---

## What's inside

See the header of `schema.sql` for the exact object counts (tables / views / triggers /
indexes) — it is regenerated from the live DB after every migration and is authoritative.
The store ships empty apart from the canonical `entity_types` vocabulary seed.

### Domain sections (see `schema.sql` for the full, commented DDL)

> For the table-by-table breakdown of which domain each table belongs to, see
> [`THEMES.md`](THEMES.md).

1. **Knowledge base & document index** — `entries` (journal/notes, Zettelkasten kinds),
   `meetings` + `meeting_attendees`, personal CRM (`people`, `organizations`,
   `interactions`), GTD `projects` / `milestones` / `tasks`, and the **asset catalog**
   `assets` (sha256 UNIQUE dedup, `perceptual_hash` for near-dups, path-vs-blob storage,
   promoted EXIF/IPTC/Dublin-Core columns + OCR `extracted_text`) with `asset_metadata`
   (EAV long tail).
2. **Planning** — `goals` (horizon theme/annual/quarter/month/week/day + `parent_goal_id`
   cascade + framework), `key_results` (OKRs, `kr_kind`, score 0–1), `daily_plans` +
   `plan_blocks` (MITs), `reviews` (daily/weekly/monthly/quarterly).
3. **Habits** — `habits` (binary/quantitative, frequency targets, identity statement,
   stack anchor, `linked_goal_id`) + `habit_logs` (UNIQUE per habit/day).
4. **Health & fitness** **[SENSITIVE]** — `meal_plans` / `meals` / `meal_items` / `foods` /
   `nutrition_logs`; `lab_results` (**reference range stored WITH each value**, `source` =
   issuing lab — thresholds are never hardcoded), `body_metrics`, `wearable_rollups`;
   `exercises` / `training_programs` / `mesocycles` / `workouts` / `workout_sets`.
5. **Finance** **[SENSITIVE]** — `accounts` (institution, account type, jurisdiction,
   currency, owner, **masked identifier only**), `balance_snapshots`, `holdings`,
   `transactions`, `asset_items` / `liabilities`, `net_worth_snapshots`,
   `investment_plans` (IPS), `financial_goals` (linked into the planning cascade),
   `fx_rates` (reference).

### Cross-cutting layers — the backbone that makes this ONE brain

- **Universal tags** — `tags` + `taggings(tag_id, entity_type, entity_id)`, indexed on
  `(entity_type, entity_id)`. Never comma-strings.
- **Universal links / relations graph** — `links(src_type, src_id, dst_type, dst_id,
  relation)`, indexed on both ends. This is the **backlinks / Obsidian-style graph**.
  **Attachments are `links` rows with `relation='attachment'`** (asset → entity).
  Other relations: `mentions`, `relates_to`, `advances` (project→goal), `blocks`, etc.
- **Unified FTS5 search** — one `search_fts` table over all textual content (entries,
  meetings, people/org notes, project/goal/task text, reviews, interaction summaries,
  asset OCR/description). `tokenize='porter unicode61'`; rank with `bm25()`; preview with
  `snippet()`/`highlight()`. Kept in sync by AFTER INSERT/UPDATE/DELETE triggers on each
  source table. Each row carries `entity_type` + `entity_id` to map a hit back to its row.
- **Shared temporal spine** — the one date format above, so journaling, meetings,
  interactions, habit logs, snapshots, and workouts all sort/filter on one timeline.

### Canonical `entity_type` vocabulary

The strings in `entity_types` are the single vocabulary used by `taggings`, `links`, and
`search_fts`. `taggings`/`links` FK-validate their `*_type` columns against it, so a typo'd
type is rejected at write time. Add new types there (with a `domain`) before using them.

---

## Searching (FTS5)

```sql
SELECT entity_type, entity_id, bm25(search_fts) AS rank,
       snippet(search_fts, 2, '[', ']', '…', 8) AS preview
FROM search_fts
WHERE search_fts MATCH 'roadmap OR planning'
ORDER BY rank;        -- bm25: lower is more relevant
```

Resolve a hit back to its row by joining `entity_id` against the table named by
`entity_type` (e.g. `entity_type='entry'` → `entries.id`).

### Backfilling / repairing the FTS index (the gotcha)

`search_fts` is a **standalone** (not external-content) FTS5 table maintained by triggers.
The `'rebuild'` command applies **only to external-content tables** and is **not** valid
here. To repair drift or after a bulk load **with triggers temporarily disabled**:

```sql
BEGIN;
DELETE FROM search_fts;
-- re-INSERT one block per source table, e.g.:
INSERT INTO search_fts(entity_type, entity_id, title, body)
  SELECT 'entry', id, COALESCE(title,''),
         COALESCE(body,'')||' '||COALESCE(highlight,'')||' '||COALESCE(mood,'')
  FROM entries;
-- … (people, organizations, projects, tasks, meetings, interactions, goals,
--     reviews, assets) …
COMMIT;
INSERT INTO search_fts(search_fts) VALUES('optimize');   -- valid here
```

During normal row-by-row writes the triggers keep it in sync automatically — no rebuild
needed.

---

## Views (the recurring questions, encoded)

See `schema.sql` for the full, current list. Representative views:

| View | Answers |
|------|---------|
| `v_today` / `v_daily_agenda` | Today's plan + meetings + tasks due/scheduled + due habits (one feed, `kind` discriminator) |
| `v_followups_due` | CRM contacts past their `contact_cadence_days`, ranked by relationship strength |
| `v_project_dashboard` | Open tasks/milestones, next milestone due, last activity per active project |
| `v_next_actions` | GTD next actions (`is_next_action=1`, `status='next'`) by `@context` |
| `v_quarter_okr_scoreboard` | Current-quarter KRs: current vs target, progress fraction, score, target score |
| `v_off_pace` | KRs whose progress fraction trails the elapsed-time fraction of their period |
| `v_habit_adherence` | Adherence % vs frequency target over 7- and 30-day windows, **scored over observed (journaled) days only** — plus coverage %, `logged_through`, `log_lag_days` |
| `v_habit_adherence_by_area` | The same rollup split by PARA area, so a "health" KR stops averaging in career habits |
| `v_goal_cascade` | Recursive parent→child goal tree with depth + path |
| `v_net_worth` | Latest account balances rolled to a base currency via latest `fx_rates` |
| `v_weekly_review` | GTD weekly-review scoreboard (inbox, waiting-for, someday, next actions, stale projects, overdue follow-ups, gated items, accounts in flight) |
| `v_accounts_in_flight` | Accounts that are neither plainly open nor confirmed closed — mid-application, blocked, or mid-cancellation — with `days_in_state` and open linked follow-ups |
| `v_supplement_gates` | Each clinically-gated supplement joined to the task that clears it: `gate_tracked` / `gate_cleared` / `gate_open` / `gate_overdue_days` |
| `v_person_timeline` | A person's interactions + meetings chronologically (filter by `person_id`) |
| `v_backlinks` | Everything that links **to** an entity (reverse graph; filter by `entity_type`+`entity_id`) |

Notes: "today" views use `date('now')` (UTC); pass `date('now','localtime')` in your own
queries for local-day semantics. `v_net_worth` rolls to a single base currency — supply
`fx_rates` rows for each held currency (same-currency rows pass 1:1).

---

## Adherence is scored over OBSERVED days (not calendar days)

**The system of record for habits may be an offline source (e.g. a paper bullet
journal).** If so, the database is a periodic transcription of it. A missing `habit_logs`
row then does **not** mean "the owner missed it" — it means "that day has not been
transcribed yet".

**A day is OBSERVED if it has an `entries` row with `kind='daily'`.** That is the same row
that carries `mood` and `highlight`: one row, two jobs, no parallel table. Adherence is
computed over observed days only.

- Inside an observed day, an absent tick **is** a miss — on a journaled day the page is a
  complete record.
- Outside the observed set, absence means **nothing at all**.

This splits one misleading number into two honest ones:

| | |
|---|---|
| **coverage %** | observed days / calendar days — a **tooling** metric (is the transcription ritual running?) |
| **adherence %** | credited / expected over observed days — a **behaviour** metric |

**Zero observed days ⇒ `adherence_* IS NULL`** — "unknown", never `0`. Nothing may render a
NULL adherence as a zero or as a red. `v_habit_adherence_rollup.is_provisional` is `1`
below 50% coverage; `v_off_pace` carries `provisional_low_coverage` so a weak signal is
*labelled* rather than hidden, while a genuinely absent signal drops out of `v_off_pace`
by itself (NULL progress fraction).

`adherence_*` is **capped at 1.0**: beating a weekly target three times over is 100%
adherence plus extra, not 300%. The uncapped truth stays visible in `credited_*` /
`expected_*`, which are pro-rated to observed days and are therefore routinely
**fractional** — render them, never re-derive them.

---

## Status vocabularies (and one derived compatibility column)

Some columns carry a *state machine*, not a boolean — because the system was acting on a
fact the database could not store, so the fact lived in a `notes` string and the UI had to
infer it from prose. The fix: promote the state to a real enum.

### `accounts.status`

| value | means | note |
|---|---|---|
| `open` | operative and usable | the default |
| `pending_open` | application submitted/accepted, **not yet usable** | record it as a real row in this state rather than leaving it out of the inventory or lying that it is open |
| `blocked` | the account exists but is **unusable pending an action by the institution** | e.g. blocked at identity verification with a support case open |
| `closing` | closure/cancellation **requested**, awaiting the institution's confirmation | **not closed** — still live, can still hold money and still bill fees |
| `closed` | no account of record exists — closed by the institution, **or an application deleted before it ever opened** | a one-week transient does not earn its own vocabulary value |

`accounts.status_since` (`YYYY-MM-DD`) is maintained automatically by a trigger on every
status change, so "how long has this been blocked?" is a query, not an archaeology
exercise. `NULL` means the row has never changed state since it entered the inventory.

**Reading rule for anything that sums money:** the set of accounts that are *on the books*
is `status <> 'closed'` — **not** `status = 'open'`. A `closing` or `blocked` account still
holds a balance. `v_net_worth` follows this rule.

### `supplements.status`

| value | means |
|---|---|
| `active` | being taken now |
| `gated` | **deliberately not being taken**, pending a named clinical result. A decision on the record — not a gap and not a lapse |
| `as_needed` | an ungated tool, used when convenient |
| `discontinued` | stopped |

A `gated` row must carry its gate: `gate_reason` (what result clears it, in words) and/or
`gate_task_id` (FK → `tasks`, the one action that clears it). Triggers refuse a hold with
no gate — an untracked hold is a `waiting-for` wearing a safety label, and it is exactly
what this system exists not to drop. `v_supplement_gates` joins the two, and
`v_weekly_review` counts the ones whose clearing action is still open.

### `supplements.is_current` is DERIVED — do not write it

`is_current` is kept only so existing readers keep working. It is maintained by trigger as
`status = 'active'`. **Set `status`; never set `is_current`.** A write that moves
`is_current` to anything other than what `status` derives is refused with a message telling
you so, rather than silently accepted — because the dangerous direction (a clinical hold
flipped to "taking it" by a stale one-line UPDATE) must never pass quietly.

The same pattern is available whenever a boolean has grown a third meaning: promote the
state to a real enum, keep the boolean as a trigger-derived compatibility column, and
guard it.

---

## Encryption (SQLCipher)

**Design decision:** the whole DB is protected with **SQLCipher full-database
encryption-at-rest**. This covers everything, including the **[SENSITIVE]** health and
finance tables — not just selected columns.

**The OWNER owns the passphrase.** The tooling never generates, stores, hardcodes, logs,
or echoes it. It exists only in the owner's head / password manager, and is supplied
**at runtime** (a secure prompt, or the `MAJLIS_DB_KEY` env var the owner sets).
None of the tooling here writes the key anywhere.

> ⚠️ **No recovery.** If the passphrase is lost, the data is **unrecoverable** — there is
> no reset or backdoor. Store it in a password manager now.

**Prerequisites** (installed separately):
- The **`sqlcipher` CLI** (e.g. `brew install sqlcipher`).
- A **Python binding** for `db_connect.py`: `pip install sqlcipher3-binary` (preferred) or
  `pysqlcipher3`.
- **Standard `sqlite3` / DB Browser without the SQLCipher build can NO LONGER open the DB**
  once it's encrypted. That is expected.

### Re-keying (one time, run by the OWNER)

`database/encrypt_db.sh` converts the plaintext `knowledge.db` into an encrypted one via
the canonical `sqlcipher_export` migration. It is **idempotent** and **fail-safe** (it
never destroys the original on error). Run it yourself:

```bash
cd database
./encrypt_db.sh            # prompts for the passphrase (hidden, entered twice)
# — or, if you prefer the env var:
#   export MAJLIS_DB_KEY='your-passphrase'; ./encrypt_db.sh
```

What it does: backs up the plaintext to `knowledge.plaintext.bak`, checkpoints/removes WAL,
exports plaintext → encrypted, **verifies** the encrypted copy (opens with the key,
`PRAGMA integrity_check`, matching table count), and only then swaps it into place.

### Verify, then SECURELY DELETE the plaintext backup

After a successful run the plaintext copy still exists as a safety net. Confirm the
encrypted DB works, **then destroy the backup** (it is unencrypted data):

```bash
export MAJLIS_DB_KEY='your-passphrase'
./.venv/bin/python db_connect.py   # should print "OK: opened knowledge.db — N tables"
rm -P knowledge.plaintext.bak      # macOS: -P overwrites before unlinking (or use srm)
```

### Connecting afterward

```bash
# SQLCipher CLI — key MUST be the first statement:
sqlcipher knowledge.db
sqlite> PRAGMA key = 'your-passphrase';
sqlite> PRAGMA foreign_keys = ON;
sqlite> SELECT COUNT(*) FROM people;   -- a wrong key errors here
```

```python
# Agents in Python — run with database/.venv/bin/python (has the sqlcipher3 binding):
from db_connect import get_connection      # reads $MAJLIS_DB_KEY or prompts
conn = get_connection()                    # applies PRAGMA key + foreign_keys, verifies
```

Under the hood the key is applied as a **SQL-escaped string literal**
(`PRAGMA key = '<escaped>';`, single-quotes doubled), not a bound parameter — PRAGMA
statements reject bound parameters (`near "?": syntax error`) in the `sqlcipher3` binding,
which is why the CLI's `PRAGMA key='…'` and `db_connect.py` match exactly.

**Never committed:** the passphrase (in any form), `knowledge.plaintext.bak`, `.env`, and
the `*-wal`/`*-shm` sidecars are excluded via `database/.gitignore`. Decide per repo
whether to commit `knowledge.db` at all — for a personal store, most people do **not**.

---

## Inbox ingestion → asset catalog (how `assets` gets populated)

When the owner drops a file/image in `Team's Inbox/`, the data specialist's pipeline:

1. **Intake** the new file(s) from `Team's Inbox/`.
2. **Identify** the true type by **magic bytes** (not extension) → `mime_type`.
3. **Extract metadata** — EXIF/IPTC/Dublin-Core for images/docs (into the promoted `assets`
   columns; rare keys into `asset_metadata`), OCR/document text into `extracted_text`.
4. **Hash + dedup** — compute **SHA-256**; `assets.sha256` is **UNIQUE**, so an exact
   duplicate is detected and not re-stored. For images, compute `perceptual_hash` to
   surface near-duplicates.
5. **Catalog** — insert into `assets` (`storage='path'` for large media, `'blob'` for small
   items) with all extracted metadata.
6. **Link** — add `links` rows (`relation='attachment'`, asset → the relevant
   entry/person/project/meeting/…) plus topical relations, and `taggings`.
7. **Index** — the asset's text lands in `search_fts` automatically via the assets FTS
   triggers.

Deliverables for the owner are written to `Owner's Inbox/`; the inbox folders are kept
clean (no marker/README files inside them).

---

## Export path (data is never trapped)

Entries/notes → Markdown + YAML frontmatter; tables → CSV (`.mode csv` / `.output`);
people → vCard. The store is the working layer, not a prison.

---

## Conventions cheat-sheet for teammates writing rows

- `PRAGMA foreign_keys = ON;` every connection. Wrap multi-row writes in a transaction.
- Timestamps `YYYY-MM-DDTHH:MM:SSZ` (UTC); dates `YYYY-MM-DD`. One spine.
- Currency (ISO-4217) on every monetary row.
- Don't run DDL — request schema changes (table/column/index/view, with the exact query it
  must serve) from the data specialist.
- Use the canonical `entity_type` strings for any `taggings` / `links` row.
- Store each lab value **with its issuing lab's own reference range** — never hardcode a
  threshold.
- Need to see what the database actually says? **`.read database/inspect.sql`** — read-only,
  key-free, safe on any schema version.
- `accounts.status` / `supplements.status` are **state machines, not booleans** — see
  "Status vocabularies" above. Never write `supplements.is_current` (derived), and never
  sum money over `accounts.status = 'open'` (use `<> 'closed'`).
```
