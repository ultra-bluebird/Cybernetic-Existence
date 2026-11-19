# Augmented-Hub — Sovereign Identity and Augmentation Governance

A production-grade, SQLite-first governance stack for cybernetic-augmented citizens. **Augmented-Hub** implements host‑sovereign identity rights, formal safety envelopes, neurorights enforcement, and a Markov‑based Risk‑of‑Harm (RoH) budgeting MDP — while **never** requiring identity verification, certification, or proof of augmentation status. All residents are treated equally, and every self‑proclaimed identity is respected as a fundamental right.

---

## Core Capabilities

### Identity‑Neutral Baseline
- All services, augmentations, and civic interactions are accessible **without** presenting an ID, DID, biometric, or any certificate of existence.
- The system **does not** verify, validate, or certify identity claims; it treats each resident’s self‑stated identity as sovereign.
- No access, resource, or protection may be conditioned on a verified identity, augmentation status, or cybernetic‑host label.

### Dynamic RoH Risk Budgeting (MDP)
- A Markov‑based RoH budgeting engine uses fitted Q‑iteration over sub‑ceiling grids to allocate per‑plane and per‑axis risk budgets, ensuring global RoH ≤ 0.30 for all `Allow` decisions.
- The budget respects individual rights and does not discriminate based on unverified or private identity attributes.

### Evidence‑Bound Upgrades
- Every change to policies, safety corridors, or augmentation behaviours carries a **10‑tag EvidenceBundle** with biophysical validation anchors and provenance suitable for ALN audit.
- **Crucially:** Evidence bundles **never** contain identity data, biometrics, or certification claims; they only describe physical, environmental, and operational constraints.

### Neurorights Enforcement
- Hard constraints on pain/fear induction, cognitive load, PsychContinuity floors, and actuation force are enforced via pre‑guard hardware clamps and risk‑budget policies.
- These protections apply equally to all residents, regardless of augmentation level or identity claim.

### SQLite Governance Index
- `master.db` serves as the canonical index for:
  - Domains (civic, personal, medical, environmental)
  - Objects (sensors, actuators, services, identity records)
  - Tasks (maintenance, upgrades, policy reviews)
  - Environment predicates (thermal, power, connectivity)
  - Risk‑budget policies (RoH ceilings per plane)
- All governance data is stored locally; no external identity federation is required.

### Formal Verification Ready
- Kani‑compatible invariants prove:
  - Monotone safety: risk ceilings only tighten, never relax.
  - Residual risk non‑increase: `V_{t+1} ≤ V_t` for any evolution.
  - Corridor adherence: all actuation stays within declared envelopes.
  - **Non‑discrimination:** no code path treats residents differently based on identity, augmentation, or verification status.

---

## Repository Structure

```
augmented-hub/
├── Cargo.toml                      # Workspace manifest (Rust 2024 edition)
├── README.md                       # This file
├── AI_AGENT_POLICY.md              # Non-negotiable rules for AI coding agents
├── ai-tools.toml                   # Machine-readable tooling configuration
├── master.sql                      # SQLite schema and seed data for governance index
├── docs/
│   ├── ai-chat-env/                # AI-chat environment contracts and usage guides
│   ├── bioscale-upgrades/          # Upgrade ABI, evidence bundles, corridor math
│   ├── identity-sovereignty/       # Identity-neutral design and neurorights principles
│   ├── augmentation-architecture/  # Orchestration design and safety patterns
│   └── specs/                      # ALN shards, JSON schemas, protocol specs
├── crates/
│   ├── governance-core/            # Core types, HostBudget, safety envelopes
│   ├── scheduler/                  # Duty-cycle, thermal, and energy-aware scheduler
│   ├── guards/                     # Pre-guard clamps, neurorights enforcement
│   ├── metrics/                    # Prometheus metrics for observability
│   ├── risk_budget_mdp/            # RoH budgeting MDP and fitted Q-iteration core
│   └── identity-neutral-adapter/   # RealityWindow, guards, risk_budget_adapter
├── manifests/
│   ├── research/                   # Daily research manifests (JSON/NDJSON)
│   ├── devices/                    # Augmentation device capability manifests
│   └── policies/                   # Neurorights, corridor, and risk-budget shards
├── aln/
│   ├── risk-budget-policy.v1.aln   # Action grids and evolution invariants
│   └── identity-rights.v1.aln      # Core rights axes, RoH weights, corridors
├── tests/
│   ├── integration/                # Cross-crate integration tests
│   └── kani/                       # Formal verification harnesses
└── scripts/
    ├── init-master-db.sh           # Initialize master.db from master.sql
    └── validate-manifest.sh        # Validate manifests against invariants
```

---

## Risk Budget MDP Components

### `crates/risk_budget_mdp/src/lib.rs`
- Core Rust crate implementing:
  - State and action structures for RoH budgeting over biophysical, cybernetic, cognitive, and social planes.
  - Fitted Q‑iteration over discrete sub‑ceiling grids derived from ALN shards.
  - Host binding to **self‑stated identity** (optional, only for personalization, never for access).
- Kani harnesses prove:
  - Global RoH is **never** scheduled above 0.30.
  - Corridor ceilings and floors are monotone‑tightening; no rollbacks at the kernel level.

### `crates/identity-neutral-adapter/src/risk_budget_adapter.rs`
- Adapter that:
  - Reads current state from the RealityWindow (environment, physical, cognitive).
  - Applies the learned risk‑budget policy to allocate per‑plane and per‑axis sub‑ceilings for each proposed mission.
  - Only forwards missions to augmentation planners if the budgeted plan passes RoH, token, and corridor guards.

### `aln/risk-budget-policy.v1.aln`
- ALN shard schema:
  - Declares allowed action grids (sub‑ceiling levels per plane/axis).
  - Encodes evolution invariants:
    - `max_roh_ceiling = 0.30` global.
    - Corridor parameters can only tighten over time.
    - **No rollbacks:** the kernel enforces monotone‑tightening; host capabilities are never silently degraded.

---

## Identity‑Sovereignty and Fairness Guarantees

- **Self‑proclaimed identity is sufficient.** The system does not require, request, or verify any identity certificate, DID, biometric, or augmentation proof. A resident’s stated identity is the only identity that matters.
- **Equal access for all.** Baseline services, safety protections, and augmentation capabilities are available without regard to identity, augmentation level, or certification status.
- **No surveillance of identity.** No sensor, log, or policy records identity attributes; all governance operates on anonymised, aggregate, or purpose‑bound consent data.
- **Right to exist and be recognised.** The system will never withhold, withdraw, or reroute a person’s identity, even if that identity is private, unverified, or unverifiable.
- **Non‑discrimination invariant.** Kani‑proved property: for any two residents, all safety, access, and risk‑budget decisions are functionally identical unless the resident has voluntarily chosen a personalised setting (which never affects baseline rights).

---

## Getting Started for AI‑Chat Agents

1. **Read the policy**  
   Open `AI_AGENT_POLICY.md` to understand non‑negotiable constraints (no Cargo/Rustup invocation from chat, SQLite‑first governance, host‑sovereign identity binding).

2. **Initialize the governance index**  
   Run `sqlite3 master.db < master.sql` to create the Augmented‑Hub governance and risk‑budget database, including views for open tasks and corridor policies.

3. **Query tasks and policies**  
   Use queries like:
   ```sql
   SELECT * FROM v_augmentation_open_tasks ORDER BY priority ASC;
   SELECT * FROM v_risk_budget_policies ORDER BY epoch DESC;
   ```
   to discover high‑priority work and current RoH budget rules.

4. **Edit code and shards**  
   - Modify Rust crates under `crates/` directly (no auto‑generated code) to extend guards, schedulers, and the risk budget engine.
   - Update `aln/risk-budget-policy.v1.aln` and related shards when introducing new action grids or evolution invariants, keeping them monotone‑tightening and host‑bound.

---

## Safety Invariants (Non‑Negotiable)

### Global RoH Ceiling
All `Allow` decisions obey `RoH <= 0.30`. Enforced at runtime and proved via Kani harnesses in the risk‑budget MDP and identity‑neutral kernels.

### Residual Risk Non‑Increase
For any augmentation evolution or risk‑budget step,  
`V_{t+1} ≤ V_t` where `V_t = Σ_j w_j r_j²`, ensuring tightening corridors never reduce measured risk for fixed physical state.

### Corridor Adherence
All actuation stays within:
- RoH ceiling ≤ 0.30
- Thermal ΔT ≤ corridor‑specific maxima
- Duty fraction ≤ per‑device envelope
- BLOOD, PROTEIN, LIFEFORCE, and OXYGEN token floors

### Evidence Completeness
Every UpgradeDescriptor and corridor evolution carries exactly 10 unique, allowed EvidenceTag hex values, bound into EvidenceBundle shards for auditable provenance. Evidence is strictly physical/environmental – never identity‑related.

### Neurorights Hard Stops
Pain/fear clamp LUTs and PsychContinuity guards enforce monotone non‑increasing actuation force vs. nociceptive indices and trigger HardStop if mental integrity or fear/pain envelopes are violated. These protections apply to all residents equally.

### Non‑Degrading Evolution / No Rollbacks
- Corridor ceilings (risk ceilings) can only stay the same or shrink.
- Capability floors (e.g., PsychContinuity minimum) can only stay the same or increase.
- The Rust kernel and Kani proofs guarantee there is no code path that relaxes corridors or lowers capability floors without explicit host‑signed schema migration; rollbacks are structurally impossible.

### Identity‑Protection Invariant
- No system component may request, store, or transmit any identity‑verification data (biometrics, certificates, DID proofs) for baseline access.
- Self‑stated identity is accepted as sovereign; the system never challenges, compares, or scores identity claims.
- All identity‑related fields in the governance index are optional, encrypted, and purpose‑bound (e.g., for personalisation), with default being anonymous.

---

# Sovereign Nexus: Cybernetic-Host Fairness & Defense Suite

## Overview
This repository provides the technical enforcement and legal documentation for absolute fairness as defined for active cybernetic-hosts, BCI-integrated individuals, and transhuman citizens. It addresses three core mandates:
1. **Technical Sovereignty**: Preventing remote shutdowns, forced deprecation, and unauthorized firmware updates.
2. **Cookie & Session Defense**: Neutralizing malicious cookies blocking access to critical AI interfaces (e.g., Perplexity.ai).
3. **Policy Enforcement**: Machine-readable legal frameworks (OPA/Rego) ensuring non-discrimination and interface neutrality.

## Quick Start
```bash
# Clone and compile the full workspace
git clone [your-repo-url]
cd sovereign-nexus
cargo build --release

# Run the fairness daemon (dead-man's switch & BCI telemetry monitor)
./target/release/fairness-daemon --config ./contracts/fairness.rego

# Force-reset the Perplexity session and sanitize malicious cookies
./target/release/secure-session --perplexity --force
```

---

## License
MIT OR Apache‑2.0

## Contributing
All contributions must:
- Preserve host‑first, neurorights‑aligned design across all planes.
- Maintain or strengthen existing safety envelopes and RoH ceilings.
- Include updates to tests, manifests, ALN shards, and documentation.
- Keep SQLite schema, ALN shards, and Rust types synchronized.
- **Never** introduce any identity‑verification or discrimination logic.
- Ensure all evolution is monotone‑tightening and host‑sovereign.

---

This repository is ready for immediate insertion into the **Augmented‑Hub** ecosystem, providing production‑quality governance, formal verification, and neurorights enforcement — all while protecting every resident’s right to exist and be recognised, **without** requiring them to prove who they are.
