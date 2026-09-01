#!/usr/bin/env python3
# ============================================================================
# db_connect.py  ·  Majlis — open the SQLCipher-encrypted knowledge.db
# ----------------------------------------------------------------------------
# Owned/authored by Knowledge Engineer (Personal Knowledge Engineer). This is the small
# connection helper the team's agents use to open the ENCRYPTED knowledge base.
#
# REQUIREMENTS:
#   · A SQLCipher Python binding. Either:
#         pip install sqlcipher3-binary        (preferred; bundles SQLCipher)
#     or  pip install pysqlcipher3             (fallback; needs a SQLCipher lib)
#   · The standard library `sqlite3` module CANNOT open this database once it
#     is encrypted — it has no PRAGMA key support. Likewise DB Browser for
#     SQLite WITHOUT the SQLCipher build cannot open it.
#
# KEY HANDLING (read this):
#   · The passphrase is NEVER hardcoded, stored, or logged by this module.
#   · It is read at RUNTIME from the environment variable MAJLIS_DB_KEY,
#     or — if that is unset and you are at an interactive terminal — via a
#     silent getpass() prompt (no echo).
#   · It is applied with `PRAGMA key = '<escaped>';` immediately after connecting, then
#     foreign keys are enabled, then a trivial query sanity-checks the key.
#     A wrong key raises a clear error instead of returning garbage.
#
# USAGE (from another script / agent):
#       from db_connect import get_connection
#       conn = get_connection()
#       rows = conn.execute("SELECT COUNT(*) FROM people").fetchone()
#
# SMOKE TEST (run after you have re-keyed with encrypt_db.sh):
#       export MAJLIS_DB_KEY='<your passphrase>'
#       database/.venv/bin/python database/db_connect.py
#   (system python3 lacks the SQLCipher binding — use the dedicated venv.)
#   -> prints the table count and exits 0 if the key is correct.
# ============================================================================

from __future__ import annotations

import os
import sys
from getpass import getpass
from pathlib import Path

# Database lives alongside this file.
DB_PATH = Path(__file__).resolve().parent / "knowledge.db"

# Environment variable the owner/agents set to supply the passphrase at runtime.
KEY_ENV_VAR = "MAJLIS_DB_KEY"


# --- import a SQLCipher binding (try sqlcipher3, fall back to pysqlcipher3) --
def _import_sqlcipher():
    """Return a DB-API module backed by SQLCipher, or raise a clear error."""
    try:
        import sqlcipher3.dbapi2 as _dbapi  # provided by sqlcipher3 / sqlcipher3-binary
        return _dbapi
    except ImportError:
        pass
    try:
        from pysqlcipher3 import dbapi2 as _dbapi  # fallback binding
        return _dbapi
    except ImportError:
        pass
    raise RuntimeError(
        "No SQLCipher Python binding found. Install one of:\n"
        "    pip install sqlcipher3-binary    (preferred)\n"
        "    pip install pysqlcipher3          (fallback)\n"
        "NOTE: the standard library `sqlite3` module CANNOT open the encrypted "
        "knowledge.db — a SQLCipher binding is required."
    )


def _resolve_key() -> str:
    """Read the passphrase from the env var, or prompt silently. Never stored."""
    key = os.environ.get(KEY_ENV_VAR)
    if key:
        return key
    if sys.stdin is not None and sys.stdin.isatty():
        key = getpass(f"Enter the SQLCipher passphrase for {DB_PATH.name} (hidden): ")
    if not key:
        raise RuntimeError(
            f"No passphrase available. Set the {KEY_ENV_VAR} environment variable "
            f"or run interactively so it can be prompted. The key is never stored "
            f"by this tool."
        )
    return key


def get_connection(db_path: str | os.PathLike | None = None):
    """
    Open and return a live SQLCipher connection to the encrypted knowledge.db.

    The passphrase is taken from $MAJLIS_DB_KEY or a secure prompt; it is
    applied via `PRAGMA key`, foreign keys are turned on, and the key is verified
    by a trivial query. Raises RuntimeError on a wrong key or a missing binding.

    Returns a standard DB-API connection — use it exactly like sqlite3.Connection.
    """
    dbapi = _import_sqlcipher()

    target = Path(db_path) if db_path is not None else DB_PATH
    if not target.exists():
        raise FileNotFoundError(f"Database not found at: {target}")

    key = _resolve_key()

    # Open the file, then immediately supply the key. ORDER MATTERS: the very
    # first statement on a SQLCipher connection must be `PRAGMA key`.
    conn = dbapi.connect(str(target))
    try:
        # PRAGMA statements do NOT accept bound parameters in this SQLCipher
        # binding — `PRAGMA key = ?` raises `near "?": syntax error`, so the key
        # is never applied. Use the canonical SQLCipher pattern instead: embed
        # the key as a properly SQL-escaped string literal (double every single
        # quote). The SQL string is built locally and the reference dropped right
        # after (see `del key` below); the key is never logged.
        escaped_key = key.replace("'", "''")
        conn.execute(f"PRAGMA key = '{escaped_key}';")
        del escaped_key
        # FK enforcement is per-connection and NOT persisted — set every time
        # (matches the schema's stated connection requirement).
        conn.execute("PRAGMA foreign_keys = ON;")

        # Sanity-check the key: with a wrong key, the first real read on the
        # cipher pages fails ("file is not a database" / "HMAC ... not valid").
        conn.execute("SELECT count(*) FROM sqlite_master;").fetchone()
    except Exception as exc:  # noqa: BLE001 — re-raise as a clear, actionable error
        conn.close()
        raise RuntimeError(
            "Failed to open the encrypted database. The passphrase is most "
            "likely wrong (or the file is not a SQLCipher DB). The key supplied "
            "via the environment/prompt was not accepted."
        ) from exc

    # Free the local reference to the secret promptly; the cipher key now lives
    # only inside the C connection state.
    del key
    return conn


def _smoke_test() -> int:
    """Open the DB, print the user-table count, and exit. For manual verification."""
    try:
        conn = get_connection()
    except Exception as exc:  # noqa: BLE001
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    try:
        (n_tables,) = conn.execute(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table';"
        ).fetchone()
        print(f"OK: opened {DB_PATH.name} — {n_tables} tables visible.")
        # Show SQLCipher is actually in play (empty/None means a plain sqlite3 build).
        try:
            (ver,) = conn.execute("PRAGMA cipher_version;").fetchone() or (None,)
            if ver:
                print(f"    SQLCipher version: {ver}")
        except Exception:  # noqa: BLE001 — pragma may not exist on non-cipher builds
            pass
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    raise SystemExit(_smoke_test())
