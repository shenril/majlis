-- =============================================================================
-- inspect.sql · EXAMPLE read-only diagnostic for knowledge.db
-- -----------------------------------------------------------------------------
-- This is an EXAMPLE health-check you can `.read` in one session to answer the
-- standing "what does the database actually say?" questions without hand-typing
-- a query at a time. Adapt the sections to your own domain tables.
--
-- IT IS READ-ONLY. No INSERT, no UPDATE, no DELETE, no DDL, no transaction — it
-- cannot change anything. KEY-FREE: it contains no passphrase or key. If the DB
-- is SQLCipher-encrypted, supply the key yourself first, then `.read` this file.
--
-- RUN IT (encrypted DB):
--   sqlcipher database/knowledge.db
--   sqlite> PRAGMA key = '<your passphrase>';
--   sqlite> .read database/inspect.sql
--
-- RUN IT (plaintext DB):
--   sqlite3 database/knowledge.db ".read database/inspect.sql"
--
-- SAFE ON ANY SCHEMA VERSION. `.bail off` (set below, restored at the end) means
-- a statement referencing a column or view your schema does not have prints an
-- error and the run CONTINUES — nothing can abort the file. So a section that
-- targets a table you have not created yet simply errors harmlessly and the rest
-- still runs.
--
-- WHAT IT COVERS: 1 schema version/counts · 2 knowledge entries · 3 GTD tasks ·
-- 4 projects & milestones · 5 people / CRM cadence · 6 meetings · 7 the links
-- (backlinks) graph · 8 tags · 9 full-text search index health · 10 integrity.
-- =============================================================================

.bail off
.mode list
.headers off

SELECT '';
SELECT '###############################################################';
SELECT '#  knowledge.db inspection — ' || datetime('now') || ' UTC';
SELECT '###############################################################';

-- =============================================================================
-- 1) SCHEMA SHAPE — object counts, so you know what you are looking at.
-- =============================================================================
SELECT '';
SELECT '== 1. SCHEMA SHAPE ============================================';
SELECT '  tables / views / triggers / indexes : ' ||
       (SELECT COUNT(*) FROM sqlite_master WHERE type='table')   || ' / ' ||
       (SELECT COUNT(*) FROM sqlite_master WHERE type='view')    || ' / ' ||
       (SELECT COUNT(*) FROM sqlite_master WHERE type='trigger') || ' / ' ||
       (SELECT COUNT(*) FROM sqlite_master WHERE type='index');
SELECT '  entity_type vocabulary rows : ' || (SELECT COUNT(*) FROM entity_types);

-- =============================================================================
-- 2) KNOWLEDGE ENTRIES — journal / notes by kind, and the observation spine.
-- =============================================================================
SELECT '';
SELECT '== 2. ENTRIES ================================================';
SELECT '  ' || printf('%-12s', kind) || ' : ' || COUNT(*) || ' rows'
  FROM entries GROUP BY kind ORDER BY COUNT(*) DESC;
SELECT '  -- total entries : ' || (SELECT COUNT(*) FROM entries)
       || '   ·  latest daily : '
       || COALESCE((SELECT MAX(entry_date) FROM entries WHERE kind='daily'),'(never)');

-- =============================================================================
-- 3) TASKS (GTD) — open loops by status, and what is overdue.
-- =============================================================================
SELECT '';
SELECT '== 3. TASKS ==================================================';
SELECT '  ' || printf('%-10s', status) || ' : ' || COUNT(*)
  FROM tasks GROUP BY status ORDER BY COUNT(*) DESC;
SELECT '  -- overdue open tasks (due < today, not done/cancelled):';
SELECT '     due ' || due_date || ' | ' || printf('%-9s', status) || ' | ' || substr(title,1,60)
  FROM tasks
 WHERE status NOT IN ('done','cancelled')
   AND due_date IS NOT NULL AND due_date < date('now')
 ORDER BY due_date, id LIMIT 20;
SELECT '  -- next actions ready to do (is_next_action=1, status=''next''):';
SELECT '     ' || COALESCE('@'||context,'(no context)') || ' | ' || substr(title,1,64)
  FROM tasks WHERE is_next_action=1 AND status='next' ORDER BY context, id LIMIT 20;

-- =============================================================================
-- 4) PROJECTS & MILESTONES — what is active and what is due next.
-- =============================================================================
SELECT '';
SELECT '== 4. PROJECTS ===============================================';
SELECT '  ' || printf('%-10s', status) || ' : ' || COUNT(*)
  FROM projects GROUP BY status ORDER BY COUNT(*) DESC;
SELECT '  -- next open milestones by due date:';
SELECT '     due ' || COALESCE(due_date,'(none)') || ' | ' || printf('%-9s', status)
       || ' | ' || substr(title,1,60)
  FROM milestones WHERE status <> 'done' ORDER BY due_date IS NULL, due_date LIMIT 15;

-- =============================================================================
-- 5) PEOPLE / CRM — the roster and who is overdue for contact (cadence engine).
-- =============================================================================
SELECT '';
SELECT '== 5. PEOPLE / CRM ===========================================';
SELECT '  people : ' || (SELECT COUNT(*) FROM people)
       || '   ·  organizations : ' || (SELECT COUNT(*) FROM organizations)
       || '   ·  interactions : ' || (SELECT COUNT(*) FROM interactions);
SELECT '  -- follow-ups due (last_contacted_at + cadence is past), strongest first:';
SELECT '     strength ' || COALESCE(CAST(relationship_strength AS TEXT),'-')
       || ' | last ' || COALESCE(last_contacted_at,'(never)')
       || ' | ' || substr(name,1,40)
  FROM people
 WHERE contact_cadence_days IS NOT NULL
   AND (last_contacted_at IS NULL
        OR date(last_contacted_at, '+' || contact_cadence_days || ' days') < date('now'))
 ORDER BY relationship_strength DESC NULLS LAST, last_contacted_at LIMIT 20;

-- =============================================================================
-- 6) MEETINGS — recent records (decisions are stored distinctly from discussion).
-- =============================================================================
SELECT '';
SELECT '== 6. MEETINGS ===============================================';
SELECT '  total meetings : ' || (SELECT COUNT(*) FROM meetings);
SELECT '     ' || COALESCE(occurred_at,'(no date)') || ' | ' || substr(title,1,64)
  FROM meetings ORDER BY occurred_at DESC LIMIT 10;

-- =============================================================================
-- 7) LINKS GRAPH — the relations that make backlinks resolve both directions.
-- =============================================================================
SELECT '';
SELECT '== 7. LINKS (backlinks graph) ================================';
SELECT '  total links : ' || (SELECT COUNT(*) FROM links);
SELECT '  ' || printf('%-14s', relation) || ' : ' || COUNT(*)
  FROM links GROUP BY relation ORDER BY COUNT(*) DESC LIMIT 15;

-- =============================================================================
-- 8) TAGS — the universal tagging layer (never comma-strings in a column).
-- =============================================================================
SELECT '';
SELECT '== 8. TAGS ===================================================';
SELECT '  tags : ' || (SELECT COUNT(*) FROM tags)
       || '   ·  taggings : ' || (SELECT COUNT(*) FROM taggings);
SELECT '  -- most-used tags:';
SELECT '     ' || printf('%-20s', t.name) || ' : ' || COUNT(tg.tag_id)
  FROM tags t LEFT JOIN taggings tg ON tg.tag_id = t.id
 GROUP BY t.id ORDER BY COUNT(tg.tag_id) DESC LIMIT 15;

-- =============================================================================
-- 9) FULL-TEXT SEARCH — is the FTS5 index populated and in sync?
-- =============================================================================
SELECT '';
SELECT '== 9. SEARCH (FTS5) ==========================================';
SELECT '  search_fts rows : ' || (SELECT COUNT(*) FROM search_fts);
SELECT '  -- rows per entity_type in the index:';
SELECT '     ' || printf('%-16s', entity_type) || ' : ' || COUNT(*)
  FROM search_fts GROUP BY entity_type ORDER BY COUNT(*) DESC;

-- =============================================================================
-- 10) INTEGRITY — foreign keys must be clean (prints the count, so a silent
--     pass is not mistaken for "did not run").
-- =============================================================================
SELECT '';
SELECT '== 10. INTEGRITY =============================================';
SELECT '  foreign_key_check violations : ' || (SELECT COUNT(*) FROM pragma_foreign_key_check)
    || '   (must be 0)';

SELECT '';
SELECT '###############################################################';
SELECT '#  end of inspection — nothing was modified.';
SELECT '###############################################################';

.bail on
