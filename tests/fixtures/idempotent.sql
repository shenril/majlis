-- =============================================================================
-- FIXTURE: a correct staged file — re-running it is a clean no-op.
-- Used by tests/validate-staged.test.sh to assert the gate reports PASS / exit 0.
-- SAFE: key-free · single transaction · idempotent · no DDL/DELETE
-- =============================================================================
PRAGMA foreign_keys = ON;

BEGIN;

-- Conflict on the UNIQUE name is ignored, so a second run inserts nothing.
INSERT OR IGNORE INTO tags (name) VALUES ('fixture-idempotent');

COMMIT;
