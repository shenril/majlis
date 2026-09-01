#!/usr/bin/env bash
# ============================================================================
# encrypt_db.sh  ·  Majlis — convert plaintext knowledge.db -> SQLCipher
# ----------------------------------------------------------------------------
# Owned/authored by Knowledge Engineer (Personal Knowledge Engineer). YOU (the owner)
# run this yourself. It re-keys the existing PLAINTEXT `knowledge.db` into a
# SQLCipher-ENCRYPTED database, in place, using the canonical sqlcipher_export
# migration. The passphrase is YOURS — this script NEVER generates, stores,
# logs, echoes, or hardcodes it.
#
# KEY HANDLING (read this):
#   · The passphrase is read at RUNTIME only — either from the environment
#     variable MAJLIS_DB_KEY (if you exported it), or via a silent
#     interactive prompt (read -s, no echo). It is held in a shell variable
#     for the life of this process and never written anywhere.
#   · It is passed to sqlcipher over a HERE-DOC on stdin (not as a CLI arg),
#     so it never lands in your shell history or in `ps` output.
#   · Never paste the key as an argument to this script. There is no key arg.
#
# WHAT IT DOES (safe by construction):
#   1. Verifies prerequisites (sqlcipher CLI present, plaintext DB exists).
#   2. Backs up the original plaintext DB to knowledge.plaintext.bak.
#   3. Checkpoints + removes any -wal/-shm so the copy is consistent.
#   4. Exports plaintext -> a NEW encrypted file via sqlcipher_export.
#   5. VERIFIES the encrypted file opens with the key, passes
#      PRAGMA integrity_check, and has the same table count.
#   6. ONLY THEN swaps the encrypted file into place as knowledge.db.
#   7. On ANY error it aborts and leaves your original knowledge.db untouched.
#
# IDEMPOTENT: if knowledge.db is ALREADY encrypted with your key, it detects
# that and exits cleanly without doing harm. Re-running after a successful run
# is safe.
#
# AFTER A SUCCESSFUL RUN:
#   · knowledge.plaintext.bak still exists (your safety net). Once you have
#     confirmed the encrypted DB works (e.g. `python3 db_connect.py` or the
#     sqlcipher one-liner in README.md), SECURELY DELETE the backup:
#         rm -P knowledge.plaintext.bak        # macOS: -P overwrites first
#     (or use `srm` / a secure-delete tool you trust).
#   · LOSING THE PASSPHRASE = UNRECOVERABLE DATA. There is no recovery,
#     reset, or backdoor. Store it in a password manager NOW.
# ============================================================================

set -euo pipefail

# --- resolve paths relative to this script (so it works from any CWD) -------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB="${SCRIPT_DIR}/knowledge.db"
ENC="${SCRIPT_DIR}/knowledge.encrypted.db"          # temp target during migration
BAK="${SCRIPT_DIR}/knowledge.plaintext.bak"         # safety backup of the original

# --- tiny helpers ------------------------------------------------------------
err()  { printf 'ERROR: %s\n'  "$*" >&2; }
info() { printf '==> %s\n'     "$*"; }
cleanup_enc() { rm -f "$ENC" "${ENC}-wal" "${ENC}-shm" 2>/dev/null || true; }

# --- 0. prerequisites --------------------------------------------------------
if ! command -v sqlcipher >/dev/null 2>&1; then
    err "The 'sqlcipher' CLI was not found on PATH."
    err "Install it first (Jarvis is handling this via Homebrew: 'brew install sqlcipher')."
    exit 1
fi

if [[ ! -f "$DB" ]]; then
    err "Plaintext database not found at: $DB"
    exit 1
fi

# --- 1. read the passphrase securely (env var OR silent prompt) -------------
# Never echoed, never logged, never persisted. Held only in $KEY for this run.
if [[ -n "${MAJLIS_DB_KEY:-}" ]]; then
    KEY="${MAJLIS_DB_KEY}"
    info "Using passphrase from \$MAJLIS_DB_KEY (not displayed)."
else
    # -s: no echo. Prompt on stderr so it never pollutes piped stdout.
    printf 'Enter the SQLCipher passphrase (input hidden): ' >&2
    read -rs KEY
    printf '\n' >&2
    if [[ -z "$KEY" ]]; then
        err "Empty passphrase. Aborting (refusing to create an unprotected key)."
        exit 1
    fi
    # Confirm once to catch typos, since a wrong key here would be baked in.
    printf 'Re-enter passphrase to confirm: ' >&2
    read -rs KEY_CONFIRM
    printf '\n' >&2
    if [[ "$KEY" != "$KEY_CONFIRM" ]]; then
        err "Passphrases did not match. Aborting."
        exit 1
    fi
    unset KEY_CONFIRM
fi

# SQL-escape the key for safe embedding inside single-quoted PRAGMA/ATTACH
# strings (only a single-quote needs doubling). The key is still never logged.
KEY_ESC="${KEY//\'/\'\'}"

# --- 2. idempotency check: is knowledge.db ALREADY encrypted with this key? -
# Try opening the existing DB AS plaintext. If a no-key open succeeds, it's
# still plaintext and needs migrating. If it fails, it may already be encrypted.
if sqlite3_plaintext_ok=$(sqlcipher "$DB" "PRAGMA integrity_check;" 2>/dev/null) \
   && [[ "$sqlite3_plaintext_ok" == "ok" ]]; then
    info "knowledge.db opens WITHOUT a key -> it is still plaintext. Proceeding to encrypt."
else
    # Not openable without a key. Check whether it opens WITH the supplied key.
    # Use a MARKED integrity result so the stray "ok" that this CLI prints for
    # `PRAGMA key` cannot be mistaken for a genuine integrity pass on a WRONG
    # key (which would otherwise false-positive as "already encrypted").
    if already=$(sqlcipher "$DB" <<SQL 2>/dev/null
PRAGMA key = '${KEY_ESC}';
SELECT 'IDMCHK:' || integrity_check FROM pragma_integrity_check;
SQL
    ) && [[ "$already" == *"IDMCHK:ok"* ]]; then
        info "knowledge.db is ALREADY encrypted and opens with the supplied key."
        info "Nothing to do. (Idempotent no-op.)"
        unset KEY KEY_ESC
        exit 0
    else
        err "knowledge.db cannot be opened as plaintext NOR with the supplied key."
        err "It may be encrypted with a DIFFERENT key, or corrupt. Aborting to avoid harm."
        unset KEY KEY_ESC
        exit 1
    fi
fi

# --- 3. back up the original plaintext DB (checkpoint WAL first) ------------
# Fold any -wal/-shm back into the main file so the backup/copy is consistent.
info "Checkpointing WAL and backing up the plaintext DB ..."
sqlcipher "$DB" "PRAGMA wal_checkpoint(TRUNCATE); PRAGMA journal_mode=DELETE;" >/dev/null 2>&1 || true
rm -f "${DB}-wal" "${DB}-shm" 2>/dev/null || true

cp -p "$DB" "$BAK"
info "Plaintext backup written to: $BAK"

# --- 4. export plaintext -> encrypted via sqlcipher_export ------------------
# Canonical SQLCipher migration: open plaintext, ATTACH a new encrypted DB
# under the key, copy everything with sqlcipher_export(), then DETACH.
cleanup_enc   # ensure a clean target

info "Encrypting -> $ENC (this may take a moment) ..."
if ! sqlcipher "$DB" <<SQL
ATTACH DATABASE '${ENC}' AS encrypted KEY '${KEY_ESC}';
SELECT sqlcipher_export('encrypted');
DETACH DATABASE encrypted;
SQL
then
    err "Encryption step failed. Original knowledge.db is UNTOUCHED."
    cleanup_enc
    unset KEY KEY_ESC
    exit 1
fi

if [[ ! -f "$ENC" ]]; then
    err "Encrypted file was not produced. Aborting. Original knowledge.db is UNTOUCHED."
    unset KEY KEY_ESC
    exit 1
fi

# --- 5. VERIFY the encrypted DB before swapping anything --------------------
# It must (a) open with the key, (b) pass integrity_check, and (c) have the
# same user-table count as the plaintext original. Any mismatch => abort.
#
# CLI-QUIRK NOTE: in the installed SQLCipher CLI build (reports SQLite 3.53.1 /
# SQLCipher 4.16.0) the statement `PRAGMA key = '...';` itself PRINTS "ok" on
# stdout. A naive capture of "PRAGMA key" + "SELECT COUNT(*)" therefore yields
# "ok\n60" -> "ok60", and a substring "*ok*" test on the integrity output would
# also FALSE-PASS on that stray "ok" (even with a wrong key, where the real
# integrity_check goes to stderr and only the PRAGMA-key "ok" survives).
# To be immune to that stray line, every value we care about is emitted with a
# UNIQUE, CLEARLY-DELIMITED MARKER prefix, and we extract only the marked value.
# The wrong-key case produces NO marker (the query errors out), so verification
# genuinely confirms the DB opens with the key and reports integrity 'ok'.
info "Verifying the encrypted database ..."

# Plaintext table count (marker-extracted for symmetry / robustness).
plain_count=$(sqlcipher "$DB" \
    "SELECT 'PLNCNT:' || COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null \
    | sed -n 's/.*PLNCNT:\([0-9][0-9]*\).*/\1/p')

# Encrypted integrity check + table count, each behind its own marker so the
# stray PRAGMA-key "ok" line cannot be mistaken for a real result.
enc_check=$(sqlcipher "$ENC" <<SQL 2>/dev/null
PRAGMA key = '${KEY_ESC}';
SELECT 'ENCCHK:' || integrity_check FROM pragma_integrity_check;
SQL
)
enc_count=$(sqlcipher "$ENC" <<SQL 2>/dev/null
PRAGMA key = '${KEY_ESC}';
SELECT 'ENCCNT:' || COUNT(*) FROM sqlite_master WHERE type='table';
SQL
)
enc_count="$(printf '%s' "$enc_count" | sed -n 's/.*ENCCNT:\([0-9][0-9]*\).*/\1/p')"

# Meaningful integrity gate: require the MARKED "ok" — i.e. the DB actually
# opened with the key and pragma_integrity_check returned 'ok'. A wrong key (or
# bad copy) yields no "ENCCHK:ok" marker and correctly fails here.
if [[ "$enc_check" != *"ENCCHK:ok"* ]]; then
    err "Encrypted DB failed PRAGMA integrity_check (wrong key or bad copy). Aborting."
    err "Original knowledge.db is UNTOUCHED; encrypted attempt discarded."
    cleanup_enc
    unset KEY KEY_ESC
    exit 1
fi

if [[ -z "$enc_count" || "$enc_count" != "$plain_count" ]]; then
    err "Table count mismatch (plaintext=$plain_count, encrypted=${enc_count:-?}). Aborting."
    err "Original knowledge.db is UNTOUCHED; encrypted attempt discarded."
    cleanup_enc
    unset KEY KEY_ESC
    exit 1
fi

info "Verification OK: integrity_check passed; table count matches ($enc_count tables)."

# --- 6. swap the encrypted file into place ----------------------------------
# At this point the encrypted copy is proven good. Move the original aside is
# unnecessary — knowledge.plaintext.bak already holds it. Replace atomically.
mv -f "$ENC" "$DB"
rm -f "${DB}-wal" "${DB}-shm" 2>/dev/null || true   # stale WAL/shm from plaintext era

# --- 7. done: guidance ------------------------------------------------------
unset KEY KEY_ESC   # drop the secret from this process's memory ASAP

cat >&2 <<'DONE'

============================================================================
SUCCESS — knowledge.db is now SQLCipher-ENCRYPTED.
----------------------------------------------------------------------------
NEXT STEPS (do these yourself):

  1. Verify you can open it with your passphrase, e.g.:
         python3 database/db_connect.py
     or the sqlcipher CLI one-liner (see database/README.md).

  2. The plaintext backup is still on disk as a safety net:
         database/knowledge.plaintext.bak
     Once you have CONFIRMED the encrypted DB works, SECURELY DELETE it:
         rm -P database/knowledge.plaintext.bak     # macOS overwrite-then-delete
     (Leaving it around defeats the purpose of encrypting.)

  3. Agents/teammates now connect WITH the key:
         export MAJLIS_DB_KEY='<your passphrase>'   # per shell session
     and standard sqlite3 / DB Browser (without SQLCipher) can NO LONGER open
     this file. That is expected.

  WARNING: There is NO recovery if you lose the passphrase. The data is gone.
           Store it in your password manager now.
============================================================================
DONE
