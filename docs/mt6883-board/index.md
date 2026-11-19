# MT6883 Board Documentation Index

This document provides an index for MT6883 (Dimensity 1000C-class) platform integration.

## Platform Overview

The MT6883 is a MediaTek Dimensity 1000C-class SoC serving as the host processor for the cybernetic augmentation system.

### Key Specifications

| Component | Specification | Relevance |
|-----------|--------------|-----------|
| CPU | Octa-core Cortex-A77/A55 | General computation, sovereignty kernel |
| APU | 3.0 (4.5 TOPS) | Neural inference for BCI/EEG processing |
| Memory | 8-12 GB LPDDR4X | Model storage, SQLite cache |
| Storage | eMMC/UFS | Persistent database, evidence bundles |
| Thermal | ±0.3°C delta ceiling | Nanoswarm duty-cycle limits |

## Host Profile

### MT6883HostProfile Object

The `MT6883HostProfile` defines platform-specific constraints:

```rust
/// Host profile for MT6883 (Dimensity 1000C-class) platforms
#[derive(Debug, Clone)]
pub struct Mt6883HostProfile {
    /// Maximum SQLite queries per second
    pub max_sql_qps: u32,
    /// Maximum concurrent AI agents
    pub max_concurrent_agents: u32,
    /// Whether Cargo is allowed (always false for MT6883)
    pub allow_cargo: bool,
    /// Whether Rustup is allowed (always false for MT6883)
    pub allow_rustup: bool,
    /// Whether network tooling is allowed
    pub allow_tool_net: bool,
}

impl Default for Mt6883HostProfile {
    fn default() -> Self {
        Self {
            max_sql_qps: 100,
            max_concurrent_agents: 3,
            allow_cargo: false,
            allow_rustup: false,
            allow_tool_net: false,
        }
    }
}
```

### Hardware-to-Policy Mapping

| Hardware Feature | Policy Predicate | Enforcement |
|-----------------|------------------|-------------|
| eMMC storage | `mt6883_sqlite_first` | Sequential I/O optimization |
| Limited thermal headroom | `roh_ceiling_0_30` | Duty-cycle throttling |
| APU availability | `apu_inference_enabled` | Quantized model requirement |
| No hardware RNG | `deterministic_crypto_required` | Seed management protocol |

## SQLite Indexing Strategy

### Query Class Model

The `query_class` table enables energy-budgeted query planning:

**Energy Budget Inequality:**
$$\sum_{i} N_i \cdot E_i \le \frac{E_{\text{host}}}{60}$$

Where:
- $N_i$ = count of queries in class $i$
- $E_i$ = energy cost per query (Joules)
- $E_{\text{host}}$ = host's allocated energy budget per minute

### Recommended Indexes for MT6883

```sql
-- Covering index for task discovery
CREATE INDEX IF NOT EXISTS idx_task_open_priority
ON task(status, priority, object_id)
WHERE status = 'open';

-- Composite index for object-file lookups
CREATE INDEX IF NOT EXISTS idx_object_file_role
ON object_file(object_id, role);

-- Temporal index for audit trails
CREATE INDEX IF NOT EXISTS idx_ai_chat_envelope_time_desc
ON ai_chat_envelope(created_utc DESC);

-- Domain-scoped object lookup
CREATE INDEX IF NOT EXISTS idx_object_domain_key
ON object(domain_id, key);
```

### Agent Workflow

```bash
# 1. Open database
sqlite3 master.db

# 2. Check environment predicates
SELECT key, description FROM env_predicate 
WHERE category = 'host_toolchain';

# 3. Query open tasks (uses idx_task_open_priority)
SELECT t.id, o.key, t.priority, t.short_label
FROM task t
JOIN object o ON t.object_id = o.id
WHERE t.status = 'open'
ORDER BY t.priority ASC
LIMIT 5;

# 4. Find files for selected object
SELECT f.path, of.role
FROM file f
JOIN object_file of ON f.id = of.file_id
WHERE of.object_id = ?;
```

## Environment Predicates

### Seed Data for MT6883

The following predicates should be present in `env_predicate`:

```sql
INSERT OR IGNORE INTO env_predicate (category, key, name, description) VALUES
('host_toolchain', 'mt6883_sqlite_first', 'MT6883 SQLite-first policy', 
 'This host MUST use SQLite + direct file I/O; Cargo/Rustup are not allowed.'),
('host_toolchain', 'mt6883_no_rustup', 'MT6883 no-rustup constraint', 
 'Rustup installation and Cargo toolchains are forbidden on MT6883.'),
('host_capacity', 'mt6883_max_qps_100', 'MT6883 SQLite QPS limit',
 'Maximum 100 SQLite queries per second to preserve battery and thermal envelope.'),
('safety_neurorights', 'mt6883_roh_ceiling_0_30', 'MT6883 RoH hard ceiling',
 'Risk-of-harm must never exceed 0.30 for any nanoswarm operation on MT6883.');
```

## Host Budget Parameters

### Utilization Ratios

Define utilization metrics for resource tracking:

$$u_E = \frac{E_{\text{upgrade}}}{E_{\max}}$$
$$u_P = \frac{P_{\text{upgrade}}}{P_{\max}}$$
$$u_T = \frac{\Delta T_{\text{upgrade}}}{\Delta T_{\max}}$$

### Corridor Normalization

Normalize metrics to safe/hard corridor:

$$r(x) = \begin{cases}
0 & \text{if } x \le \text{safe\_max} \\
\frac{x - \text{safe\_max}}{\text{hard\_max} - \text{safe\_max}} & \text{if } \text{safe\_max} < x < \text{hard\_max} \\
1 & \text{if } x \ge \text{hard\_max}
\end{cases}$$

### Residual Risk Computation

$$V_t = \sum_{j} w_j \cdot r_j^2$$

Admissibility check: $V_{t+1} \le V_t$ and $\forall j: r_j \le 1.0$

## AI-Chat Compatibility Crate

### mt6883-ai-chat-compat

The `crates/mt6883-ai-chat-compat` crate provides:

- `is_mt6883_sqlite_only()` - Predicate check
- `allowed_query_class()` - Budget checker
- `Mt6883HostBudget` - Budget math implementation
- Kani harnesses for monotonicity proofs

### Usage Example

```rust
use mt6883_ai_chat_compat::{is_mt6883_sqlite_only, allowed_query_class};

let db = rusqlite::Connection::open("master.db")?;

if is_mt6883_sqlite_only(&db)? {
    // Enforce SQLite-only workflow
    println!("MT6883 detected: using sqlite-first mode");
}

// Check if query is within budget
let remaining_budget = 0.5; // Joules
if allowed_query_class(&db, "moderate_join", remaining_budget)? {
    // Proceed with query
} else {
    // Defer or simplify query
}
```

## Related Documents

- [AI-Chat Environment Index](../ai-chat-env/index.md)
- [SQLite and Tooling Contract](../ai-chat-env/sqlite-and-tooling-contract.md)
- [Dev-Tunnel Behavior](../cargo-env/dev-tunnel-behavior.md)
- [Host Budget Math](../nanorobotics-core/host-budget-math.md)
