# AI-Chat Environment Index

This document describes how AI-chat agents and coding assistants should interact with this workspace.

## Overview

This repository implements a **host-sovereign cybernetic augmentation system** anchored in the MT6883 (Dimensity 1000C-class) platform. The core thesis is:

> **The human host is the constitutional root of trust; all cybernetic subsystems are subordinate, evidence-bound, and reversible under explicit consent.**

## Environment Constraints

### SQLite-First Mode

This environment operates in `sqlite-first` mode:

- **`master.sql`**: Canonical schema definition
- **`master.db`**: Live authoritative index for domains, objects, files, tasks, and environment predicates

All AI-chat agents MUST:
1. Ensure `master.db` exists and matches `master.sql`
2. Query `master.db` before making structural changes
3. Use SQLite views for task discovery and object lookup

### Toolchain Restrictions

| Tool | Status | Reason |
|------|--------|--------|
| `rustup` | ❌ Forbidden | No toolchain installation allowed |
| `cargo` | ❌ Forbidden | No package management on-device |
| `sqlite3` | ✅ Required | Primary data access mechanism |
| Standard shell tools | ✅ Allowed | `ls`, `cat`, `grep`, `sed`, `awk`, `find`, `cp`, `mv`, `rm` |

### Rust Edition

- Workspace uses `edition = "2024"`
- No downgrades to older editions without explicit host authorization

## Discovery Workflow

### Step 1: Policy Acknowledgment

Before any work, read and acknowledge:
- [`AI_AGENT_POLICY.md`](../../AI_AGENT_POLICY.md)
- [`sqlite-and-tooling-contract.md`](./sqlite-and-tooling-contract.md)

### Step 2: Database Initialization

```bash
cd /workspace && sqlite3 master.db < master.sql
```

Run this only when schema or seed data changes.

### Step 3: Task Discovery

Query open tasks by priority:

```sql
SELECT t.id, o.key, t.priority, t.short_label, t.description
FROM task t
JOIN object o ON t.object_id = o.id
JOIN domain d ON o.domain_id = d.id
WHERE d.key = 'mt6883_board' AND t.status = 'open'
ORDER BY t.priority ASC;
```

Or use the convenience view:

```sql
SELECT * FROM v_mt6883_open_tasks;
```

### Step 4: Object/File Lookup

Find files associated with an object:

```sql
SELECT f.path, f.kind, of.role
FROM object_file of
JOIN file f ON of.file_id = f.id
WHERE of.object_id = ?;
```

### Step 5: Docs-Synchronized Editing

For every code change:
1. Locate corresponding docs under `docs/`
2. Update or create `.md` files to match code changes
3. If new files created, register in `master.sql` tables:
   - `file` table: path, kind, summary
   - `object_file` table: linking to parent object

## MT6883-Specific Guidance

### Host Profile Predicates

Query environment predicates for MT6883 constraints:

```sql
SELECT key, name, description
FROM env_predicate
WHERE category = 'host_toolchain';
```

Expected results:
- `mt6883_sqlite_first`: SQLite + direct file I/O required
- `mt6883_no_rustup`: Cargo/Rustup forbidden

### Energy-Budgeted Queries

The `query_class` table defines energy-budgeted query categories:

| Class | Energy (J) | Max QPM | Use Case |
|-------|-----------|---------|----------|
| `cheap_lookup` | 0.01 | 240 | Single-table SELECT |
| `moderate_join` | 0.05 | 120 | Joins across object/file/task |
| `heavy_scan` | 0.20 | 30 | Broad scans over many rows |
| `write_small` | 0.10 | 60 | Single-row INSERT/UPDATE |
| `write_bulk` | 0.50 | 10 | Bulk operations |

Budget inequality: $\sum N_i E_i \le E_{\text{host}}/60$

## Sovereignty & Neurorights

### PsychCaps Lattice

All upgrades must preserve the `PsychCaps::no_worse_than` partial order:
- Reflexive: $x \le x$
- Antisymmetric: $x \le y \land y \le x \implies x = y$
- Transitive: $x \le y \land y \le z \implies x \le z$

### Evidence Bundles

Every upgrade descriptor carries exactly 10 validated evidence tags from `BASELINE_ALLOWED_TAGS`. Validation enforces:
- Cardinality = 10
- Uniqueness
- Non-revoked status

### Audit Trails

All actions are logged in `ai_chat_envelope` table:
- Append-only semantics
- Foreign keys to task/object/domain
- Timestamped for temporal ordering

## Related Documents

- [SQLite and Tooling Contract](./sqlite-and-tooling-contract.md)
- [MT6883 Board Documentation](../mt6883-board/index.md)
- [Dev-Tunnel Behavior](../cargo-env/dev-tunnel-behavior.md)
- [Sovereignty Guarantee](../SOVEREIGNTY_GUARANTEE.md)
