# SQLite and Tooling Contract

This document formalizes the contract between AI-chat agents and the SQLite-based governance kernel.

## Schema Authority

### Canonical Sources

| File | Purpose | Mutability |
|------|---------|------------|
| `schema/master.sql` | Authoritative schema + seed data | Editable (with docs sync) |
| `master.db` | Live database instance | Generated from `master.sql` |
| `ai-tools.toml` | Machine-readable config | Editable (with docs sync) |

### Initialization Contract

AI agents MUST ensure database consistency before operations:

```bash
# Check if database exists and has expected tables
sqlite3 master.db "SELECT COUNT(*) FROM domain;" 2>/dev/null || \
  sqlite3 master.db < schema/master.sql
```

**Idempotency**: Running `master.sql` against an existing database is safe due to:
- `CREATE TABLE IF NOT EXISTS` clauses
- `INSERT OR IGNORE` for seed data
- Trigger re-creation is idempotent

## Query Classes and Energy Budgets

### Formal Model

Let $Q$ be a query issued by an agent, classified into class $c \in C$ where:
- $C = \{\text{cheap\_lookup}, \text{moderate\_join}, \text{heavy\_scan}, \text{write\_small}, \text{write\_bulk}\}$

Each class $c$ has associated energy cost $E_c$ (Joules) and max QPM $M_c$:

| $c$ | $E_c$ | $M_c$ |
|-----|-------|-------|
| cheap_lookup | 0.01 | 240 |
| moderate_join | 0.05 | 120 |
| heavy_scan | 0.20 | 30 |
| write_small | 0.10 | 60 |
| write_bulk | 0.50 | 10 |

**Budget Inequality**: Over any 60-second window, an agent's queries must satisfy:

$$\sum_{c \in C} N_c \cdot E_c \le \frac{E_{\text{host}}}{60}$$

where $N_c$ is the count of queries in class $c$, and $E_{\text{host}}$ is the host's allocated energy budget for AI operations.

### Query Classification Helper

Agents should classify queries before execution:

```rust
/// Query class enumeration matching query_class table
#[derive(Debug, Clone, Copy)]
pub enum QueryClass {
    CheapLookup,    // Single-table SELECT with simple WHERE/LIMIT
    ModerateJoin,   // Joins across object/file/object_file/task
    HeavyScan,      // Broad scans over many rows
    WriteSmall,     // Single-row INSERT/UPDATE/DELETE
    WriteBulk,      // Multi-row writes
}

impl QueryClass {
    pub fn estimated_energy_j(&self) -> f64 {
        match self {
            QueryClass::CheapLookup => 0.01,
            QueryClass::ModerateJoin => 0.05,
            QueryClass::HeavyScan => 0.20,
            QueryClass::WriteSmall => 0.10,
            QueryClass::WriteBulk => 0.50,
        }
    }
    
    pub fn max_qpm(&self) -> u32 {
        match self {
            QueryClass::CheapLookup => 240,
            QueryClass::ModerateJoin => 120,
            QueryClass::HeavyScan => 30,
            QueryClass::WriteSmall => 60,
            QueryClass::WriteBulk => 10,
        }
    }
}
```

## Environment Predicates

### Predicate Discovery

Agents MUST query `env_predicate` table before assuming capabilities:

```sql
-- Get all active predicates for this environment
SELECT category, key, name, description
FROM env_predicate
ORDER BY category, key;
```

### MT6883-Specific Predicates

| Category | Key | Meaning |
|----------|-----|---------|
| `host_toolchain` | `mt6883_sqlite_first` | SQLite + direct file I/O only |
| `host_toolchain` | `mt6883_no_rustup` | No Cargo/Rustup installation |
| `safety_neurorights` | `pain_fear_clamp_enabled` | Hardware nociceptive clamp active |
| `safety_neurorights` | `roh_ceiling_0_30` | Risk-of-harm ≤ 0.30 hard ceiling |

### Predicate Enforcement

Rust code should expose predicate checks:

```rust
/// Check if running in MT6883 SQLite-only mode
pub fn is_mt6883_sqlite_only(db: &rusqlite::Connection) -> bool {
    let predicate = db.query_row(
        "SELECT 1 FROM env_predicate 
         WHERE category = 'host_toolchain' AND key = 'mt6883_sqlite_first'",
        [],
        |_| Ok(())
    );
    predicate.is_ok()
}

/// Check if a query class is allowed under current budget
pub fn allowed_query_class(
    db: &rusqlite::Connection,
    class: &str,
    remaining_budget: f64
) -> bool {
    let required_energy: f64 = db.query_row(
        "SELECT estimated_energy_j FROM query_class WHERE key = ?",
        [class],
        |row| row.get(0)
    ).unwrap_or(f64::INFINITY);
    
    required_energy <= remaining_budget
}
```

## Audit Envelope Requirements

### Action Logging

Every AI-agent action MUST be logged in `ai_chat_envelope`:

```sql
INSERT INTO ai_chat_envelope (
    created_utc, tool_kind, host_profile_key,
    query_class_key, domain_id, object_id, task_id, description
) VALUES (
    (strftime('%s', 'now')),
    'file_edit',           -- tool_kind
    'mt6883_host_001',     -- host_profile_key (from env or config)
    'write_small',         -- query_class_key
    1,                     -- domain_id (nanorobotics_core)
    7,                     -- object_id (upgrade_descriptor)
    4,                     -- task_id
    'Added EvidenceBundle validation to upgrade_descriptor.rs'
);
```

### Required Fields

| Field | Constraint | Source |
|-------|------------|--------|
| `created_utc` | Unix timestamp | `strftime('%s', 'now')` |
| `tool_kind` | Enum: `file_edit`, `db_query`, `doc_update`, `task_create` | Agent decision |
| `host_profile_key` | Non-empty string | From `brain_identity_profile` or config |
| `query_class_key` | FK to `query_class.key` | Query classification |
| `domain_id` | FK to `domain.id` (nullable) | From task/object context |
| `object_id` | FK to `object.id` (nullable) | From task context |
| `task_id` | FK to `task.id` (nullable) | Current task being worked |
| `description` | Non-empty text | Human-readable summary |

## Docs Synchronization Contract

### File Registration Protocol

When creating new files, agents MUST:

1. **Create the file** at the appropriate path under `/workspace/`
2. **Insert into `file` table**:
   ```sql
   INSERT INTO file (path, kind, summary)
   VALUES ('crates/mt6883-ai-chat-compat/src/lib.rs', 'rust_src', 'MT6883 AI-chat compatibility layer');
   ```
3. **Link to parent object** in `object_file`:
   ```sql
   INSERT INTO object_file (object_id, file_id, role)
   VALUES (8, last_insert_rowid(), 'implementation');
   ```
4. **Regenerate `master.db`**:
   ```bash
   sqlite3 master.db < schema/master.sql
   ```

### Doc Update Checklist

Before committing code changes:

- [ ] Located corresponding `.md` file under `docs/`
- [ ] Updated documentation to reflect code changes
- [ ] If new component created, created new `.md` doc
- [ ] Registered new files in `master.sql` seed data
- [ ] Regenerated `master.db`

## Kani Verification Harness

For the `mt6883-ai-chat-compat` crate, verify monotonicity of safety checks:

```rust
// crates/mt6883-ai-chat-compat/src/kani_harness.rs

#[cfg(kani)]
mod kani_proofs {
    use super::*;
    
    #[kani::proof]
    fn prove_query_energy_monotonicity() {
        let classes = [
            QueryClass::CheapLookup,
            QueryClass::ModerateJoin,
            QueryClass::HeavyScan,
            QueryClass::WriteSmall,
            QueryClass::WriteBulk,
        ];
        
        // Prove energy estimates are positive
        for class in classes.iter() {
            let energy = class.estimated_energy_j();
            kani::assert(energy > 0.0, "Energy must be positive");
            kani::assert(energy <= 1.0, "Energy must be bounded");
        }
    }
    
    #[kani::proof]
    fn prove_qpm_bounds() {
        let classes = [/* ... */];
        
        for class in classes.iter() {
            let qpm = class.max_qpm();
            kani::assert(qpm > 0, "QPM must be positive");
            kani::assert(qpm <= 1000, "QPM must be reasonable");
        }
    }
}
```

## Related Documents

- [AI-Chat Environment Index](./index.md)
- [MT6883 Board Documentation](../mt6883-board/index.md)
- [AI Agent Policy](../../AI_AGENT_POLICY.md)
