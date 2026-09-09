#!/usr/bin/env bash
# =============================================================================
# tests/theme-map.test.sh · keep database/theme-map.yaml honest against schema.sql
#
# The map is hand-maintained; schema.sql is regenerated from the live DB after
# every DDL migration. Without this check they diverge silently, and a map that
# quietly disagrees with the schema is worse than no map at all.
#
# Asserts: every table in schema.sql appears in exactly one theme, and every
# table named in the map exists in schema.sql. Run: tests/theme-map.test.sh
# =============================================================================
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 - "$ROOT" <<'PY'
import re, sys, collections
root = sys.argv[1]
schema = open(f"{root}/database/schema.sql").read()
mapping = open(f"{root}/database/theme-map.yaml").read()

# Quoted identifiers are real: schema.sql contains CREATE TABLE "accounts".
schema_tables = set(re.findall(
    r'^CREATE (?:VIRTUAL )?TABLE (?:IF NOT EXISTS )?"?([A-Za-z_][A-Za-z0-9_]*)"?',
    schema, re.M))

# Minimal YAML read: theme headers and their table bullets. Deliberately not a
# YAML library — this repo has no third-party dependencies.
themes, current, mapped = {}, None, collections.Counter()
for line in mapping.split("\n"):
    m = re.match(r'^  (\w[\w-]*):\s*$', line)
    if m:
        current = m.group(1)
        if current != "themes":
            themes[current] = []
        continue
    m = re.match(r'^      - (\w+)\s*$', line)
    if m and current:
        themes[current].append(m.group(1))
        mapped[m.group(1)] += 1

fails = []

missing = schema_tables - set(mapped)
if missing:
    fails.append(f"in schema.sql but not mapped to any theme: {sorted(missing)}")

phantom = set(mapped) - schema_tables
if phantom:
    fails.append(f"mapped but absent from schema.sql: {sorted(phantom)}")

dupes = [t for t, n in mapped.items() if n > 1]
if dupes:
    fails.append(f"mapped to more than one theme: {sorted(dupes)}")

empty = [t for t, v in themes.items() if not v]
if empty:
    fails.append(f"theme declares no tables: {sorted(empty)}")

print(f"== theme-map: {len(schema_tables)} tables in schema.sql, "
      f"{len(mapped)} mapped across {len(themes)} themes")
for t in sorted(themes):
    print(f"  {t:<10} {len(themes[t]):>2} tables")

if fails:
    print("== FAIL")
    for f in fails:
        print(f"  - {f}")
    sys.exit(1)
print("== PASS: every table mapped exactly once, no phantom tables")
PY
