-- =============================================================================
-- FIXTURE: a BROKEN staged file — deliberately non-idempotent.
-- The INSERT is unguarded, so every run appends another row. Used by
-- tests/validate-staged.test.sh to assert the gate reports FAIL / exit 1.
-- Before the fix in #6 this file passed the gate with exit 0.
-- =============================================================================
PRAGMA foreign_keys = ON;

BEGIN;

-- No OR IGNORE, no guard: re-running writes a second, third, nth entry.
INSERT INTO entries (entry_date, kind, title, body)
VALUES ('2026-01-01', 'note', 'fixture non-idempotent', 'appends on every run');

COMMIT;
