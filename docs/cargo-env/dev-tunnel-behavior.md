# Dev-Tunnel Behavior Guide

This document describes expected behavior when operating in restricted dev-tunnel environments.

## Environment Characteristics

### Resource Constraints

| Resource | Typical Limit | Guidance |
|----------|--------------|----------|
| Disk space | 1-5 GB available | Avoid large downloads; prefer incremental edits |
| Network latency | Variable, may timeout | Batch requests; avoid repeated retries |
| Memory | Limited | Stream large queries; avoid loading entire tables |
| CPU | Shared, throttled | Prefer SQLite indexed lookups over full scans |

### Toolchain Availability

**Expected to be ABSENT:**
- `rustup` - No Rust toolchain installer
- `cargo` - No Rust package manager
- `npm`/`yarn` - No Node.js tooling (unless explicitly provisioned)

**Expected to be PRESENT:**
- `sqlite3` - Database CLI tool
- `bash`/`sh` - Shell execution
- Standard POSIX tools: `ls`, `cat`, `grep`, `sed`, `awk`, `find`, `cp`, `mv`, `rm`
- Text editors: `vi`, `nano` (optional)

## Failure Mode Handling

### Disk Space Exhaustion

**Symptom**: `Error: disk I/O error` or `no space left on device`

**Response Protocol:**
1. **DO NOT** retry the same operation
2. Check available space: `df -h /workspace`
3. Log the failure as a task in `master.db`:
   ```sql
   INSERT INTO task (object_id, status, priority, short_label, description, suggested_steps)
   VALUES (
     (SELECT id FROM object WHERE key = 'ai_chat_env_model'),
     'open',
     1,
     'Resolve disk space constraint',
     'Dev-tunnel environment has exhausted disk space; requires cleanup or expansion.',
     '1. Identify large files with du -sh * | sort -hr. 2. Remove temporary artifacts. 3. Request human guidance if systemic.'
   );
   ```
4. Switch to alternative strategy (e.g., edit existing files instead of creating new ones)

### Network Timeouts

**Symptom**: `curl: (28) Connection timed out` or similar

**Response Protocol:**
1. **DO NOT** retry more than 2 times
2. Document the failure in a task entry
3. Proceed with offline-first approach using existing repository content

### Missing Tools

**Symptom**: `command not found: cargo`

**Response Protocol:**
1. **DO NOT** attempt installation
2. Treat as immutable environment property
3. Adapt workflow to use allowed tools (SQLite, shell utilities, direct file editing)

## AI-Agent Workflow Adaptations

### Offline-First Discovery

When network is unreliable:

```bash
# Instead of fetching remote docs, query local SQLite
sqlite3 master.db "SELECT path, summary FROM file WHERE kind = 'doc';"

# Instead of searching GitHub, grep local codebase
grep -r "EvidenceBundle" crates/ --include "*.rs"
```

### Incremental Edits Over Replacements

When disk is constrained:

```bash
# Instead of creating backup copies, use sed for in-place edits
sed -i 's/old_pattern/new_pattern/g' target_file.rs

# Instead of generating large diff files, apply changes directly
```

### Query Optimization

When CPU/memory is limited:

```sql
-- BAD: Full table scan
SELECT * FROM task;

-- GOOD: Indexed lookup with explicit columns
SELECT id, short_label, priority 
FROM task 
WHERE status = 'open' AND object_id = 7
ORDER BY priority ASC
LIMIT 10;
```

## MT6883-Specific Considerations

### On-Device Constraints

The MT6883 (Dimensity 1000C) platform has additional constraints:

| Constraint | Value | Implication |
|------------|-------|-------------|
| APU performance | 4.5 TOPS | Inference must be quantized/pruned |
| RAM | 8-12 GB typical | Model sizes ≤ 2 GB for headroom |
| Thermal envelope | ±0.3°C delta | Duty-cycle limits on sustained compute |
| Storage | eMMC/UFS | Random I/O slower than SSD; prefer sequential access |

### SQLite Optimization for MT6883

```sql
-- Enable WAL mode for better concurrent access
PRAGMA journal_mode = WAL;

-- Set cache size appropriate for embedded memory
PRAGMA cache_size = -2000;  -- 2 MB cache

-- Use covering indexes to avoid table lookups
CREATE INDEX IF NOT EXISTS idx_task_status_priority 
ON task(status, priority, object_id);
```

## Escalation Procedures

### When to Request Human Guidance

AI agents should halt and request human input when:

1. **Environmental violation detected**: Attempted action conflicts with `env_predicate`
2. **Resource exhaustion**: Disk, memory, or network limits reached
3. **Schema mismatch**: `master.db` structure doesn't match `master.sql`
4. **Policy ambiguity**: Unclear whether an action violates `AI_AGENT_POLICY.md`
5. **Novel component creation**: New crate/module without existing doc template

### Logging Escalation Requests

```sql
INSERT INTO task (object_id, status, priority, short_label, description, suggested_steps)
VALUES (
  (SELECT id FROM object WHERE key = 'ai_chat_env_model'),
  'blocked',
  1,
  'Human guidance required: [brief reason]',
  'Detailed description of the blocking condition and attempted resolutions.',
  '1. Review env_predicate table. 2. Check AI_AGENT_POLICY.md. 3. Consult human operator.'
);
```

## Compliance Verification

### Pre-Execution Checklist

Before executing any significant operation:

- [ ] Verified no `rustup`/`cargo` installation attempts
- [ ] Confirmed `master.db` exists and is queryable
- [ ] Identified relevant domain/object/task from SQLite
- [ ] Located corresponding docs file(s)
- [ ] Classified query energy cost (if database operation)
- [ ] Prepared audit log entry for `ai_chat_envelope`

### Post-Execution Verification

After completing work:

- [ ] Updated corresponding `.md` documentation
- [ ] Registered new files in `master.sql` (if applicable)
- [ ] Regenerated `master.db` (if schema/seeds changed)
- [ ] Logged action in `ai_chat_envelope`
- [ ] Verified no prohibited commands were executed

## Related Documents

- [AI-Chat Environment Index](../ai-chat-env/index.md)
- [SQLite and Tooling Contract](../ai-chat-env/sqlite-and-tooling-contract.md)
- [AI Agent Policy](../../AI_AGENT_POLICY.md)
- [MT6883 Board Documentation](../mt6883-board/index.md)
