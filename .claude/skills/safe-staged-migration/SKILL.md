---
name: safe-staged-migration
description: The mandatory write protocol for the knowledge base (database/knowledge.db). Use this whenever any team member needs to change data in the DB — insert, update, or correct rows. Produces a key-free, guard-gated, idempotent, single-transaction staged .sql file, validated against schema.sql with validate_staged.sh before the owner applies it. Covers the DDL exception (schema changes are the data specialist's lane) and the apply-and-verify handoff. Invoke before writing any SQL that touches the knowledge base.
---

# Safe Staged Migration — the DB write protocol

Every change to the knowledge base goes through a **staged `.sql` file** that the OWNER
applies in a keyed session. Agents never open the encrypted DB directly. This protocol
exists so a write is **reviewable, replayable, and impossible to half-apply**.

> Captured, normalized, cross-linked, searchable — and never a mystery mutation. A staged
> file is a change you could hand to a stranger and they'd know exactly what it does and
> that it's safe to run twice.

## When to use

Use this **any time you change data in `database/knowledge.db`** — adding entries, tasks,
people, interactions, meetings, snapshots; correcting a value; re-linking or re-tagging.
If it writes a row, it goes through a staged file.

Do **not** use it for read-only questions — for those, `.read database/inspect.sql` (or an
ad-hoc SELECT) is enough and touches nothing.

## The rules (non-negotiable)

1. **Check `schema.sql` FIRST.** `database/schema.sql` is the canonical structure — the
   real table, column, and view names. **Never guess a column.** Open it, confirm every
   name and type you reference, note NOT NULL / CHECK / UNIQUE / FK constraints, and honour
   the conventions (timestamps `YYYY-MM-DDTHH:MM:SSZ` UTC, dates `YYYY-MM-DD`, ISO-4217
   currency on monetary rows, canonical `entity_type` strings for `taggings`/`links`).
2. **Key-free.** The file contains **no passphrase, no `PRAGMA key`, no secret** — ever.
   The owner supplies the key at apply time; the staged file assumes an already-open
   connection.
3. **Guard-gated pre-flight.** Before mutating anything, verify the preconditions the
   change depends on (the target row exists, the value is what you expect, the FK target is
   present). If a precondition is unmet, **abort cleanly with a readable message** — do not
   partially apply. Use `RAISE(ABORT, '…')` inside a `SELECT` guard (see the skeleton).
4. **Single `BEGIN; … COMMIT;`.** All writes in one transaction. If anything inside fails,
   the whole change rolls back — no half-applied state.
5. **Idempotent — safe to re-run, a no-op the second time.** Use `INSERT OR IGNORE` /
   `INSERT … ON CONFLICT … DO NOTHING/UPDATE`, `UPDATE … WHERE <not-already-done>`, and
   guards that detect "already applied". Re-running a correct file changes nothing. The
   validator enforces this.
6. **No DDL and no DELETE in a normal staged file.** No `CREATE`/`ALTER`/`DROP` and no
   `DELETE`. Structure changes are the DDL exception below; destructive removals need a
   deliberate, separately-reviewed file, not a routine data write.
7. **Descriptive filename in `database/`.** Name it for what it does, e.g.
   `database/add_meeting_followups_20260901.sql`. A reader should know the intent from the
   filename alone.

## The DDL exception (schema changes)

New tables, columns, indexes, or views are **the data specialist's lane** (Knowledge Engineer in
the example roster). She runs the DDL and then **regenerates `schema.sql` from the live DB**
(schema-only dump) so it always mirrors the real structure. If your change needs a column
that doesn't exist, do not invent it in a data file — request the schema change.

DDL files follow the same key-free / single-transaction / guarded discipline, with one
difference: **SQLite DDL can't be diff-idempotent** (a second `CREATE TABLE` errors rather
than no-ops, and `.dump` differs). So DDL files use a **re-run guard** instead — either
`CREATE TABLE IF NOT EXISTS` / `CREATE VIEW IF NOT EXISTS` / `CREATE INDEX IF NOT EXISTS`,
or a pre-flight that detects the object/column already exists (`pragma_table_info(...)`) and
aborts with "already applied". `ALTER TABLE ADD COLUMN` has no `IF NOT EXISTS`, so guard it
with a `pragma_table_info` check.

## The gate — `validate_staged.sh` must PASS

Before a file goes anywhere near the owner, run:

```bash
database/validate_staged.sh database/<your_file>.sql
# optional 2nd arg: a fixture .sql that seeds minimal rows so a guarded
# UPDATE/INSERT path is actually exercised:
database/validate_staged.sh database/<your_file>.sql database/<fixture>.sql
```

It builds a **throwaway plaintext DB from `schema.sql`**, `.read`s your file under
`.bail on`, and reports the exact parse error / missing column / phantom object. Then it
applies the file a **second time** and diffs the full `.dump` to confirm **idempotency**
(a correct file's 2nd run changes nothing). It never touches the real `knowledge.db`.

**Running this is the last step of writing a staged file — not an optional check you
remember to do.** You wrote the file; you run the gate before you mention it to anyone.

**The exit code is the verdict.** `0` means PASS and nothing else. A file that parses and
applies but is **not idempotent exits non-zero** — re-applying it would double-write the
owner's knowledge base, and the owner may not remember whether a file already ran. Fix
the guards (`INSERT OR IGNORE`, `ON CONFLICT`, `UPDATE … WHERE <not-already-done>`) until
the re-run is a clean no-op. **A file that isn't green does not get handed off.**

The gate also pre-checks the toolchain, so a missing `sqlite3` or an sqlite3 built without
FTS5 is reported as itself rather than surfacing as a confusing `schema.sql` parse error.

## Apply + verify (the handoff)

1. Deliver the validated `.sql` file and tell the owner what it does.
2. The **OWNER** applies it in a **keyed SQLCipher session** (agents never open the
   encrypted DB):
   ```bash
   sqlcipher database/knowledge.db
   sqlite> PRAGMA key = '<passphrase>';
   sqlite> PRAGMA foreign_keys = ON;
   sqlite> .read database/<your_file>.sql
   ```
3. **Verify afterward** with `.read database/inspect.sql` (read-only, key-free) — confirm
   the rows you expected are present with the values you intended, and that
   `foreign_key_check violations : 0`.

## Copy-pasteable template migration skeleton

Start every data migration from this. Replace the guard and the write; keep the shape.

```sql
-- =============================================================================
-- <describe the change in one line> — <author>, <YYYY-MM-DD>
-- WHAT: <the rows this adds/corrects, and why>
-- SAFE: key-free · single transaction · idempotent (re-run = no-op) · no DDL/DELETE
-- CHECKED schema.sql: <tables/columns this touches, confirmed to exist>
-- APPLY: owner runs in a keyed SQLCipher session; verify with inspect.sql
-- =============================================================================
PRAGMA foreign_keys = ON;

-- --- 1) GUARD PRE-FLIGHT: verify preconditions; abort cleanly if unmet --------
-- Example: refuse to run if the target person row is missing. RAISE(ABORT,…)
-- prints a readable message and stops the file before any write happens.
SELECT CASE
  WHEN (SELECT COUNT(*) FROM people WHERE id = 42) = 0
    THEN RAISE(ABORT, 'PRECONDITION FAILED: people.id=42 not found — nothing applied')
END;

-- --- 2) THE CHANGE: one transaction, idempotent writes ------------------------
BEGIN;

-- INSERT that no-ops on re-run (UNIQUE/PK conflict is ignored):
INSERT OR IGNORE INTO tags (name) VALUES ('example-tag');

-- UPDATE scoped so a second run matches nothing (already-done rows excluded):
UPDATE people
   SET relationship_strength = 4
 WHERE id = 42
   AND (relationship_strength IS NULL OR relationship_strength <> 4);

-- Cross-link, idempotent (relies on a UNIQUE constraint or a NOT EXISTS guard):
INSERT INTO links (src_type, src_id, dst_type, dst_id, relation)
SELECT 'entry', 100, 'person', 42, 'mentions'
 WHERE NOT EXISTS (
   SELECT 1 FROM links
    WHERE src_type='entry' AND src_id=100
      AND dst_type='person' AND dst_id=42 AND relation='mentions');

COMMIT;
-- Re-running this whole file is a clean no-op. Validate with validate_staged.sh.
```

### DDL re-run-guard variant (data specialist only)

```sql
-- ADD COLUMN has no IF NOT EXISTS — guard it so a re-run is a clean no-op.
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM pragma_table_info('people') WHERE name='timezone')
    THEN RAISE(ABORT, 'ALREADY APPLIED: people.timezone exists — nothing to do')
END;
ALTER TABLE people ADD COLUMN timezone TEXT;
-- Then regenerate schema.sql from the live DB (schema-only dump).
```
