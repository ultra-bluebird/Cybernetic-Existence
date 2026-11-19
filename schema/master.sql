PRAGMA foreign_keys = ON;

-- Core tables: domains, objects, files
CREATE TABLE IF NOT EXISTS domain (
    id               INTEGER PRIMARY KEY,
    key              TEXT NOT NULL UNIQUE,
    name             TEXT NOT NULL,
    description      TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS object (
    id               INTEGER PRIMARY KEY,
    domain_id        INTEGER NOT NULL,
    key              TEXT NOT NULL,
    name             TEXT NOT NULL,
    kind             TEXT NOT NULL,
    summary          TEXT NOT NULL,
    FOREIGN KEY (domain_id) REFERENCES domain(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_object_domain_key
    ON object(domain_id, key);

CREATE TABLE IF NOT EXISTS file (
    id               INTEGER PRIMARY KEY,
    path             TEXT NOT NULL UNIQUE,
    kind             TEXT NOT NULL,
    summary          TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS object_file (
    object_id        INTEGER NOT NULL,
    file_id          INTEGER NOT NULL,
    role             TEXT NOT NULL,
    PRIMARY KEY (object_id, file_id, role),
    FOREIGN KEY (object_id) REFERENCES object(id),
    FOREIGN KEY (file_id)  REFERENCES file(id)
);

-- Tasks and actions for AI/chat agents
CREATE TABLE IF NOT EXISTS task (
    id               INTEGER PRIMARY KEY,
    object_id        INTEGER NOT NULL,
    status           TEXT NOT NULL DEFAULT 'open',
    priority         INTEGER NOT NULL DEFAULT 5,
    short_label      TEXT NOT NULL,
    description      TEXT NOT NULL,
    suggested_steps  TEXT NOT NULL,
    FOREIGN KEY (object_id) REFERENCES object(id)
);

CREATE INDEX IF NOT EXISTS idx_task_object_status
    ON task(object_id, status);

-- Safety predicates and environment descriptors
CREATE TABLE IF NOT EXISTS env_predicate (
    id               INTEGER PRIMARY KEY,
    category         TEXT NOT NULL,
    key              TEXT NOT NULL,
    name             TEXT NOT NULL,
    description      TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_env_predicate_cat_key
    ON env_predicate(category, key);

-- Brain-bound identity profiles
CREATE TABLE IF NOT EXISTS brain_identity_profile (
    profile_hex_id    TEXT PRIMARY KEY,
    host_did          TEXT NOT NULL,
    bostrom_addr      TEXT NOT NULL,
    attestation_sig   BLOB NOT NULL,
    psych_caps_blob   BLOB NOT NULL,
    hardware_claim    BLOB NOT NULL,
    created_at_ms     INTEGER NOT NULL,
    psych_caps_schema TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_brain_identity_host_unique
    ON brain_identity_profile (host_did, bostrom_addr);

CREATE TRIGGER IF NOT EXISTS trg_brain_identity_profile_no_update
BEFORE UPDATE ON brain_identity_profile
BEGIN
    SELECT RAISE(ABORT, 'brain_identity_profile is append-only');
END;

-- Environment profiles for host-specific constraints
CREATE TABLE IF NOT EXISTS env_profile (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    object_id        INTEGER NOT NULL REFERENCES object(id),
    key              TEXT NOT NULL,
    json_blob        TEXT NOT NULL,
    created_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE(object_id, key)
);

CREATE INDEX IF NOT EXISTS idx_env_profile_object
    ON env_profile(object_id, key);

-- HostBudget corridor parameters
CREATE TABLE IF NOT EXISTS host_budget_param (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_key       TEXT NOT NULL,
    corridor_type    TEXT NOT NULL,
    value            REAL NOT NULL,
    units            TEXT NOT NULL,
    comment          TEXT,
    UNIQUE(metric_key, corridor_type)
);

CREATE INDEX IF NOT EXISTS idx_host_budget_param_metric
    ON host_budget_param(metric_key, corridor_type);

-- Staged upgrade pathways for nanoswarm evolution
CREATE TABLE IF NOT EXISTS upgrade_path (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id        INTEGER NOT NULL REFERENCES domain(id),
    stage_order      INTEGER NOT NULL,
    key              TEXT NOT NULL,
    name             TEXT NOT NULL,
    roh_target       REAL NOT NULL,
    eco_target       REAL NOT NULL,
    risk_cap         REAL NOT NULL,
    summary          TEXT,
    UNIQUE(domain_id, stage_order),
    UNIQUE(domain_id, key)
);

CREATE INDEX IF NOT EXISTS idx_upgrade_path_domain_stage
    ON upgrade_path(domain_id, stage_order);

-- KER targets for knowledge/eco/risk scoring
CREATE TABLE IF NOT EXISTS ker_target (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_id        INTEGER NOT NULL REFERENCES domain(id),
    object_id        INTEGER REFERENCES object(id),
    key              TEXT NOT NULL,
    target_k         REAL NOT NULL,
    target_e         REAL NOT NULL,
    target_r         REAL NOT NULL,
    rationale        TEXT NOT NULL,
    UNIQUE(domain_id, key)
);

CREATE INDEX IF NOT EXISTS idx_ker_target_domain_key
    ON ker_target(domain_id, key);

-- SQLite query classes for AI-chat energy budgeting
CREATE TABLE IF NOT EXISTS query_class (
    id                   INTEGER PRIMARY KEY,
    key                  TEXT NOT NULL UNIQUE,
    description          TEXT NOT NULL,
    estimated_energy_j   REAL NOT NULL,
    max_qpm_recommended  INTEGER NOT NULL
);

-- AI-chat action envelopes for auditability
CREATE TABLE IF NOT EXISTS ai_chat_envelope (
    id                 INTEGER PRIMARY KEY,
    created_utc        INTEGER NOT NULL,
    tool_kind          TEXT NOT NULL,
    host_profile_key   TEXT NOT NULL,
    query_class_key    TEXT,
    domain_id          INTEGER,
    object_id          INTEGER,
    task_id            INTEGER,
    description        TEXT NOT NULL,
    FOREIGN KEY (domain_id) REFERENCES domain(id),
    FOREIGN KEY (object_id) REFERENCES object(id),
    FOREIGN KEY (task_id)   REFERENCES task(id)
);

CREATE INDEX IF NOT EXISTS idx_ai_chat_envelope_time
    ON ai_chat_envelope(created_utc);

CREATE INDEX IF NOT EXISTS idx_ai_chat_envelope_task
    ON ai_chat_envelope(task_id);

CREATE INDEX IF NOT EXISTS idx_ai_chat_envelope_domain_object
    ON ai_chat_envelope(domain_id, object_id);

-- Psych risk envelopes (normalized ceilings and schema version)
CREATE TABLE IF NOT EXISTS psych_risk_envelope (
    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_hex_id       TEXT NOT NULL REFERENCES brain_identity_profile(profile_hex_id),
    roh_max              REAL NOT NULL,
    pain_max             REAL NOT NULL,
    fear_max             REAL NOT NULL,
    cognitive_load_max   REAL NOT NULL,
    identity_disrupt_max REAL NOT NULL,
    schema_key           TEXT NOT NULL,
    created_at_ms        INTEGER NOT NULL,
    UNIQUE(profile_hex_id, schema_key, created_at_ms)
);

CREATE INDEX IF NOT EXISTS idx_psych_risk_profile_time
    ON psych_risk_envelope(profile_hex_id, created_at_ms);

-- Sovereign transaction envelopes (Organichain anchor)
CREATE TABLE IF NOT EXISTS sovereign_tx_envelope (
    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
    tx_id_hex            TEXT NOT NULL UNIQUE,
    profile_hex_id       TEXT NOT NULL REFERENCES brain_identity_profile(profile_hex_id),
    baseline_caps_hash   BLOB NOT NULL,
    new_caps_hash        BLOB NOT NULL,
    psych_caps_blob      BLOB NOT NULL,
    quorum_sig           BLOB NOT NULL,
    created_at_ms        INTEGER NOT NULL,
    mesh_config_key      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sovereign_tx_profile_time
    ON sovereign_tx_envelope(profile_hex_id, created_at_ms);

-- Identity recovery proofs (offline-first recovery)
CREATE TABLE IF NOT EXISTS identity_recovery_proof (
    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_hex_id       TEXT NOT NULL REFERENCES brain_identity_profile(profile_hex_id),
    recovery_hex_id      TEXT NOT NULL,
    mt6883_attestation   BLOB NOT NULL,
    witness_sig          BLOB NOT NULL,
    psych_caps_blob      BLOB NOT NULL,
    created_at_ms        INTEGER NOT NULL,
    UNIQUE(profile_hex_id, recovery_hex_id)
);

CREATE TRIGGER IF NOT EXISTS trg_identity_recovery_proof_no_update
BEFORE UPDATE ON identity_recovery_proof
BEGIN
    SELECT RAISE(ABORT, 'identity_recovery_proof is append-only');
END;

-- Energy ownership policy and theft attempts
-- All identities are DIDs; energy routes are identified by CYBERCOREHASH256 snapshot hashes.

CREATE TABLE IF NOT EXISTS energy_ownership_policy (
    policy_id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    host_did                  TEXT    NOT NULL,
    bostrom_addr              TEXT    NOT NULL,
    route_snapshot_hash       TEXT    NOT NULL,
    source_kind_code          INTEGER NOT NULL,
    sink_did_url              TEXT    NOT NULL,
    label                     TEXT    NOT NULL,
    max_energy_j_per_interval REAL    NOT NULL,
    interval_ms               INTEGER NOT NULL,
    is_active                 INTEGER NOT NULL DEFAULT 1,
    created_at_ms             INTEGER NOT NULL,
    updated_at_ms             INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_energy_policy_host_did
    ON energy_ownership_policy (host_did);

CREATE INDEX IF NOT EXISTS idx_energy_policy_route_hash
    ON energy_ownership_policy (route_snapshot_hash);

CREATE INDEX IF NOT EXISTS idx_energy_policy_active
    ON energy_ownership_policy (is_active, host_did);

CREATE TABLE IF NOT EXISTS energy_theft_attempt (
    attempt_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    host_did            TEXT    NOT NULL,
    bostrom_addr        TEXT    NOT NULL,
    route_snapshot_hash TEXT    NOT NULL,
    detected_at_ms      INTEGER NOT NULL,
    attempt_code        INTEGER NOT NULL,
    attempted_energy_j  REAL    NOT NULL,
    policy_limit_j      REAL    NOT NULL,
    telemetry_blob      BLOB    NOT NULL,
    telemetry_hash      TEXT    NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_energy_theft_host_did
    ON energy_theft_attempt (host_did);

CREATE INDEX IF NOT EXISTS idx_energy_theft_route_hash
    ON energy_theft_attempt (route_snapshot_hash);

CREATE INDEX IF NOT EXISTS idx_energy_theft_time
    ON energy_theft_attempt (host_did, detected_at_ms);

-- Corridor proposals: gated, monotone-tightening-only updates.
-- Integrated into the same schema so guard lanes can query and audit.

CREATE TABLE IF NOT EXISTS corridor_proposal (
    proposal_id        TEXT PRIMARY KEY,
    host_did           TEXT NOT NULL,
    bostrom_addr       TEXT NOT NULL,
    author_kind        TEXT NOT NULL,
    target_corridor_id TEXT NOT NULL,
    change_kind        TEXT NOT NULL,
    delta              REAL NOT NULL,
    state              TEXT NOT NULL,
    created_at_ms      INTEGER NOT NULL,
    updated_at_ms      INTEGER NOT NULL,
    baseline_roh_max   REAL NOT NULL DEFAULT 0.30
);

CREATE TABLE IF NOT EXISTS corridor_proposal_evidence (
    proposal_id       TEXT NOT NULL,
    evidence_tag_hex  TEXT NOT NULL,
    PRIMARY KEY (proposal_id, evidence_tag_hex),
    FOREIGN KEY (proposal_id) REFERENCES corridor_proposal (proposal_id)
);

CREATE INDEX IF NOT EXISTS idx_corridor_proposal_state_time
    ON corridor_proposal(state, created_at_ms);

CREATE INDEX IF NOT EXISTS idx_corridor_proposal_target
    ON corridor_proposal(target_corridor_id, state);

CREATE INDEX IF NOT EXISTS idx_corridor_proposal_host
    ON corridor_proposal(host_did, bostrom_addr, state);

-- Core seed domains
INSERT OR IGNORE INTO domain (id, key, name, description) VALUES
(1, 'nanorobotics_core', 'Nanorobotics Core', 'Core swarm types, HostBudget, safety envelopes.'),
(2, 'nanorobotics_scheduler', 'Nanorobotics Scheduler', 'Duty-cycle, thermal, and energy-aware swarm scheduling.'),
(3, 'nanorobotics_guards', 'Nanorobotics Guards', 'Pre-guard clamps, neurorights enforcement, safety invariants.'),
(4, 'nanorobotics_metrics', 'Nanorobotics Metrics', 'Prometheus metrics for observability and CI gating.'),
(5, 'bioscale_upgrades', 'Bioscale Upgrades', 'Upgrade descriptors, evidence bundles, host-budget math.'),
(6, 'ai_chat_env', 'AI-Chat Environment', 'How AI-chat systems interact with this workspace.');

-- Seed files (docs tree)
INSERT OR IGNORE INTO file (id, path, kind, summary) VALUES
(1, 'docs/README.md', 'doc', 'Top-level index for all documentation domains.'),
(2, 'docs/nanorobotics-core/index.md', 'doc', 'Index for nanorobotics core types and HostBudget.'),
(3, 'docs/nanorobotics-core/host-budget-math.md', 'doc', 'HostBudget math, risk-of-harm, and duty cycles.'),
(4, 'docs/nanorobotics-core/evidence-bundles.md', 'doc', 'Structure and semantics of evidence bundles.'),
(5, 'docs/nanorobotics-scheduler/index.md', 'doc', 'Index for scheduler design and duty-cycle envelopes.'),
(6, 'docs/nanorobotics-guards/index.md', 'doc', 'Index for guard functions and neurorights enforcement.'),
(7, 'docs/nanorobotics-guards/pain-fear-clamp.md', 'doc', 'Hardware LUT for monotone nociceptive clamping.'),
(8, 'docs/nanorobotics-metrics/index.md', 'doc', 'Index for Prometheus metrics and observability.'),
(9, 'docs/bioscale-upgrades/index.md', 'doc', 'Index for bioscale upgrade ABI and macros.'),
(10, 'docs/ai-chat-env/index.md', 'doc', 'Index for AI-chat environment integration docs.');

-- Seed objects (key concepts)
INSERT OR IGNORE INTO object (id, domain_id, key, name, kind, summary) VALUES
(1, 1, 'host_budget', 'HostBudget Model', 'math_model', 'Defines energy, protein, thermal, and duty envelopes for nanoswarm operations.'),
(2, 1, 'evidence_bundle', 'EvidenceBundle', 'data_model', 'Fixed-length bundle of 10 biophysical evidence tags.'),
(3, 1, 'safety_envelope', 'SafetyEnvelope', 'data_model', 'Thermodynamic and actuation constraints for swarm behavior.'),
(4, 2, 'duty_scheduler', 'DutyCycle Scheduler', 'component', 'Schedules nanoswarm actuation within HostBudget and thermal envelopes.'),
(5, 3, 'pain_fear_clamp', 'Pain/Fear Clamp LUT', 'hardware_guard', 'Monotone lookup table enforcing neurorights nociceptive floors.'),
(6, 4, 'prometheus_metrics', 'Prometheus Metrics', 'observability', 'Metrics for guard scans, blocks, and envelope breaches.'),
(7, 5, 'upgrade_descriptor', 'UpgradeDescriptor ABI', 'data_model', 'Canonical upgrade descriptor with costs, envelopes, and evidence.'),
(8, 6, 'ai_chat_env_model', 'AI-Chat Environment Model', 'spec', 'Description of how AI-chat agents should interpret environment descriptors.'),
(9, 1, 'corridor_proposal_lane', 'Corridor Proposal Lane', 'governance', 'AI-chat and clinician corridor proposal lane with monotone-tightening invariants.');

-- Seed object_file links
INSERT OR IGNORE INTO object_file (object_id, file_id, role) VALUES
(1, 2, 'doc'),
(1, 3, 'doc'),
(2, 4, 'doc'),
(4, 5, 'doc'),
(5, 6, 'doc'),
(5, 7, 'doc'),
(6, 8, 'doc'),
(7, 9, 'doc'),
(8, 10, 'doc');

-- Seed tasks for AI agents
INSERT OR IGNORE INTO task (id, object_id, status, priority, short_label, description, suggested_steps) VALUES
(1, 1, 'open', 2, 'Implement HostBudget utilization math', 'Define utilization ratios and corridor normalization for nanoswarm operations.', '1) Add utilization() method to HostBudget. 2) Implement normalize_corridor(). 3) Document formulas in docs/nanorobotics-core/host-budget-math.md.'),
(2, 2, 'open', 3, 'Validate EvidenceBundle cardinality', 'Ensure all upgrade descriptors carry exactly 10 unique evidence tags.', '1) Add validate() method to EvidenceBundle. 2) Write unit tests for cardinality and uniqueness. 3) Update docs/nanorobotics-core/evidence-bundles.md.'),
(3, 5, 'open', 1, 'Implement pain/fear clamp LUT', 'Create monotone lookup table for hardware-level neurorights enforcement.', '1) Define LUT generation function. 2) Add Kani proof for monotonicity. 3) Document in docs/nanorobotics-guards/pain-fear-clamp.md.'),
(4, 7, 'open', 2, 'Wire UpgradeDescriptor to SQLite', 'Persist upgrade descriptors and evidence tags in master.db.', '1) Add upgrade_descriptor and upgrade_evidence_tag tables. 2) Implement sqlite_bridge.rs. 3) Update docs/bioscale-upgrades/index.md.'),
(5, 9, 'open', 2, 'Implement corridor proposal SQLite bridge', 'Connect chat-corridor-proposals crate to corridor_proposal tables.', '1) Add Rust sqlite_bridge module. 2) Implement CRUD for proposals and evidence. 3) Update docs/ai-chat-env/index.md with query examples.');

-- Seed environment predicates
INSERT OR IGNORE INTO env_predicate (id, category, key, name, description) VALUES
(1, 'host_toolchain', 'nanorobotics_sqlite_first', 'Nanorobotics SQLite-first host profile', 'This host MUST use SQLite + direct file I/O; Cargo/Rustup are not allowed for AI-chat agents.'),
(2, 'host_toolchain', 'nanorobotics_no_rustup', 'Nanorobotics no-rustup constraint', 'Rustup installation and Cargo toolchains are forbidden in this environment for AI-chat agents.'),
(3, 'safety_neurorights', 'pain_fear_clamp_enabled', 'Pain/fear clamp hardware guard', 'Hardware-level monotone clamp for nociceptive indices is active and non-bypassable.'),
(4, 'safety_neurorights', 'roh_ceiling_0_30', 'RoH hard ceiling', 'Risk-of-harm must never exceed 0.30 for any nanoswarm operation.');

-- Seed query classes for AI-chat energy budgeting
INSERT OR IGNORE INTO query_class (id, key, description, estimated_energy_j, max_qpm_recommended) VALUES
(1, 'cheap_lookup', 'Single-table SELECT with simple WHERE/LIMIT on small tables.', 0.01, 240),
(2, 'moderate_join', 'SELECT with joins across object, file, object_file, task.', 0.05, 120),
(3, 'heavy_scan', 'Broader scans over many rows, e.g., unbounded SELECT over upgrade_descriptor.', 0.20, 30),
(4, 'write_small', 'Short INSERT/UPDATE/DELETE affecting a single row.', 0.10, 60),
(5, 'write_bulk', 'Bulk INSERT/UPDATE touching many rows.', 0.50, 10);

-- Seed host budget parameters
INSERT OR IGNORE INTO host_budget_param (metric_key, corridor_type, value, units, comment) VALUES
('energy_utilization', 'safe_max', 0.50, 'fraction', 'Recommended daily energy utilization by nanoswarm operations.'),
('energy_utilization', 'hard_max', 0.80, 'fraction', 'Absolute upper bound; beyond this host budget is violated.'),
('protein_utilization', 'safe_max', 0.40, 'fraction', 'Recommended daily protein utilization by nanoswarm operations.'),
('protein_utilization', 'hard_max', 0.75, 'fraction', 'Absolute upper bound for protein draw.'),
('thermal_delta', 'safe_max', 0.3, 'celsius', 'Recommended max brain temperature delta for nanoswarm operations.'),
('thermal_delta', 'hard_max', 0.5, 'celsius', 'Absolute max brain temperature delta before hard stop.');

-- Seed upgrade pathways
INSERT OR IGNORE INTO upgrade_path (domain_id, stage_order, key, name, roh_target, eco_target, risk_cap, summary)
SELECT d.id, 1, 'nanorobotics_stage1_telemetry_only', 'Stage 1 – Telemetry Only', 0.10, 0.95, 0.12, 'Telemetry-only nanoswarm operation; no actuation, minimal RoH.'
FROM domain d WHERE d.key = 'nanorobotics_core';

INSERT OR IGNORE INTO upgrade_path (domain_id, stage_order, key, name, roh_target, eco_target, risk_cap, summary)
SELECT d.id, 2, 'nanorobotics_stage2_soft_actuation', 'Stage 2 – Soft Actuation', 0.12, 0.93, 0.13, 'Soft nanoswarm actuation with strict HostBudget and pain/fear safety clamp corridors.'
FROM domain d WHERE d.key = 'nanorobotics_core';

-- Seed KER targets
INSERT OR IGNORE INTO ker_target (domain_id, object_id, key, target_k, target_e, target_r, rationale)
SELECT d.id, o.id, 'nanorobotics_default_ker', 0.94, 0.91, 0.13, 'Nanorobotics default KER targets derived from HostBudget corridor math and activity-window metrics.'
FROM domain d
JOIN object o ON o.domain_id = d.id
WHERE d.key = 'nanorobotics_core' AND o.key = 'host_budget';

-- Convenience views for AI-chat agents
CREATE VIEW IF NOT EXISTS v_nanorobotics_open_tasks AS
SELECT t.id AS task_id, o.key AS object_key, t.priority, t.short_label, t.description
FROM task t
JOIN object o ON t.object_id = o.id
JOIN domain d ON o.domain_id = d.id
WHERE d.key IN ('nanorobotics_core', 'nanorobotics_scheduler', 'nanorobotics_guards', 'nanorobotics_metrics')
  AND t.status = 'open'
ORDER BY t.priority ASC;

CREATE VIEW IF NOT EXISTS v_object_work AS
SELECT o.id AS object_id,
       o.key AS object_key,
       o.name AS object_name,
       d.key AS domain_key,
       MIN(t.priority) AS min_priority,
       SUM(CASE WHEN t.status = 'open' THEN 1 ELSE 0 END) AS open_tasks
FROM object o
JOIN domain d ON d.id = o.domain_id
LEFT JOIN task t ON t.object_id = o.id
GROUP BY o.id, o.key, o.name, d.key;

CREATE VIEW IF NOT EXISTS v_object_files_tasks AS
SELECT o.id AS object_id,
       o.key AS object_key,
       f.path AS file_path,
       of.role AS file_role,
       t.id AS task_id,
       t.status AS task_status,
       t.priority AS task_priority,
       t.short_label
FROM object o
LEFT JOIN object_file of ON of.object_id = o.id
LEFT JOIN file f ON f.id = of.file_id
LEFT JOIN task t ON t.object_id = o.id;

CREATE VIEW IF NOT EXISTS v_ai_compatibility AS
SELECT d.id AS domain_id,
       d.key AS domain_key,
       COUNT(DISTINCT o.id) AS object_count,
       COUNT(DISTINCT f.id) AS file_count,
       SUM(CASE WHEN t.status = 'open' THEN 1 ELSE 0 END) AS open_tasks,
       SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) AS done_tasks,
       (COUNT(DISTINCT f.id) * 1.0) /
       (1 + SUM(CASE WHEN t.status = 'open' THEN 1 ELSE 0 END)) AS compat_score
FROM domain d
LEFT JOIN object o ON o.domain_id = d.id
LEFT JOIN object_file of ON of.object_id = o.id
LEFT JOIN file f ON f.id = of.file_id
LEFT JOIN task t ON t.object_id = o.id
GROUP BY d.id, d.key;

CREATE VIEW IF NOT EXISTS v_env_profile AS
SELECT 'nanorobotics_core' AS host_key,
       MAX(CASE WHEN key = 'nanorobotics_sqlite_first' THEN 1 ELSE 0 END) AS sqlite_first,
       MAX(CASE WHEN key = 'nanorobotics_no_rustup' THEN 1 ELSE 0 END) AS no_rustup,
       MAX(CASE WHEN key = 'pain_fear_clamp_enabled' THEN 1 ELSE 0 END) AS pain_fear_clamp,
       MAX(CASE WHEN key = 'roh_ceiling_0_30' THEN 1 ELSE 0 END) AS roh_ceiling_0_30
FROM env_predicate
WHERE category IN ('host_toolchain', 'safety_neurorights');

CREATE VIEW IF NOT EXISTS v_corridor_proposal_open AS
SELECT cp.proposal_id,
       cp.host_did,
       cp.bostrom_addr,
       cp.target_corridor_id,
       cp.change_kind,
       cp.delta,
       cp.state,
       cp.created_at_ms,
       cp.updated_at_ms,
       cp.baseline_roh_max
FROM corridor_proposal cp
WHERE cp.state IN ('Draft', 'Simulated', 'Proven', 'HumanApproved')
ORDER BY cp.created_at_ms DESC;
