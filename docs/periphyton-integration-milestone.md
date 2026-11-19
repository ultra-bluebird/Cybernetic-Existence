# Periphyton/PFAS Integration Milestone Documentation

## Purpose

This milestone wires the existing periphyton/PFAS/recovery/evidence modules into one reproducible local contract test harness. The harness demonstrates a full decision path with synthetic, explicitly labeled test fixtures.

**All values in fixtures are synthetic integration-test data.** No field measurements, sensor readings, or operational data are represented.

## Modules Connected

The integration harness connects the following repository artifacts:

### C++ PFAS Mass-Balance Kernel
- **Header:** `cpp/periphyton_pfas/include/event_mass_balance.hpp`
- **Test:** `tests/periphyton_pfas_integration_test.cpp`
- **Functionality:** Phase-resolved total flux calculation with uncertainty propagation

### SQLite Evidence Schemas
- **Evidence Registry:** `schemas/sql/periphyton_evidence_registry.sql`
- **Recovery History:** `schemas/sql/biofilm_recovery_state_history.sql` (created for this milestone)
- **Integration Tests:** `tests/sql/periphyton_evidence_registry_integration.sql`, `tests/sql/biofilm_recovery_state_history_integration.sql`

### JSON Fixtures
- **Valid Packet:** `tests/fixtures/periphyton_pfas_decision_packet.valid.json`
- **Invalid External Action:** `tests/fixtures/periphyton_pfas_decision_packet.invalid_external_action.json`
- **Inconclusive:** `tests/fixtures/periphyton_pfas_decision_packet.inconclusive.json`

### Python Report Generator
- **Script:** `python/periphyton_integration_report.py`
- **Output:** `docs/periphyton-integration-milestone-report.md`

## How to Run

### C++ Integration Test

Using an already-available C++ compiler:

```sh
mkdir -p build
c++ -std=c++20 -Wall -Wextra -I. \
  tests/periphyton_pfas_integration_test.cpp \
  -o build/periphyton_pfas_integration_test
./build/periphyton_pfas_integration_test
```

If `c++` is unavailable, try `g++` or `clang++`.

### SQLite Integration Scripts

**Note:** `sqlite3` command-line tool was not available in this session. If available, run:

```sh
tmp_db="$(mktemp)"
sqlite3 "$tmp_db" < schemas/sql/periphyton_evidence_registry.sql
sqlite3 "$tmp_db" < schemas/sql/biofilm_recovery_state_history.sql
sqlite3 "$tmp_db" < tests/sql/periphyton_evidence_registry_integration.sql
sqlite3 "$tmp_db" < tests/sql/biofilm_recovery_state_history_integration.sql
sqlite3 "$tmp_db" \
  "SELECT result_state, COUNT(*) FROM evidence_packet GROUP BY result_state ORDER BY result_state;"
rm -f "$tmp_db"
```

### Python Report Generator

```sh
python3 python/periphyton_integration_report.py
```

Optional arguments:
```sh
python3 python/periphyton_integration_report.py [repo_root] [db_path] [fixtures_dir] [output_path]
```

## JSON Fixture Decisions

### Valid Evidence Packet (`periphyton_pfas_decision_packet.valid.json`)

- **Decision:** Eligible for evidence review queue
- **Characteristics:**
  - `external_action_requested = false`
  - All required spatial, temporal, calibration, provenance fields present
  - Valid upstream/downstream PFAS pairing with acceptable analytical quality
  - Maintenance scenario modeled with uncertainty available
- **Not eligible for:** External action authorization (requires separate approval pathway)

### External-Action Fixture (`periphyton_pfas_decision_packet.invalid_external_action.json`)

- **Decision:** Policy-ineligible without separate explicit approval
- **Characteristics:**
  - `external_action_requested = true`
  - `separate_explicit_approval = false`
  - Schema-valid but policy-blocked
- **Demonstrates:** Schema validity does not equal policy authorization

### Inconclusive Fixture (`periphyton_pfas_decision_packet.inconclusive.json`)

- **Decision:** Retained as inconclusive; request targeted replication
- **Characteristics:**
  - `pfas_evidence.status = "INDETERMINATE"`
  - High uncertainty relative to measurement
  - `maintenance_scenario.status = "NOT_MODELED"`
- **Important:** NOT a low-risk state; indicates insufficient discrimination for decision

## Non-Actuation and Privacy Boundaries

This integration harness enforces the following boundaries:

### No Actuation
- No sensor actuation
- No canal or waterway action authorization
- No maintenance bot commands
- No external system control

### No Personal Identity Data
- No personal identifiers in any fixture or database record
- No demographic, biometric, or eligibility information
- No individual tracking or profiling

### No Exact Field Coordinates
- Corridor segment labels are synthetic (e.g., `CORRIDOR-SEGMENT-A`)
- Hex anchor IDs are synthetic (e.g., `HEX-ANCHOR-SYNTHETIC-001`)
- No GPS coordinates, addresses, or location traces

### No Governance Credentials
- No private deliberation records
- No permission grants for access control, identity, or eligibility
- No public ranking or scoring use of evidence sufficiency scores

### ESS Isolation
Evidence Sufficiency Scores (ESS) are restricted to:
- Namespace: `INTERNAL_RESEARCH_QUALITY` only
- Prohibited uses:
  - `used_for_access_control = FALSE`
  - `used_for_identity_or_eligibility = FALSE`
  - `used_for_public_ranking = FALSE`
  - `used_for_external_action_authorization = FALSE`

## Known Limitations

1. **Policy Files Not Executed**
   - ALN policy files (`policies/*.aln`) were not executed by this harness
   - Policy conformance is demonstrated through structural checks, not runtime enforcement

2. **Synthetic Fixtures**
   - All JSON fixtures contain synthetic, non-field data
   - No laboratory, field, regulatory, or operational validation is claimed

3. **Integration Harness Scope**
   - This is an integration test harness, not a production system
   - Does not perform real PFAS analysis
   - Does not validate field thresholds
   - Does not authorize maintenance or external action

4. **SQLite Tooling**
   - The `sqlite3` command-line tool was not available in this session
   - Python's `sqlite3` module was used instead for database validation

5. **JSON Schema Validation**
   - JSON checks are structural integration checks
   - Not a full JSON Schema validator implementation

## State Classification Reference

The following states are preserved as **non-risk states**:

| State | Meaning | Not Equivalent To |
|-------|---------|-------------------|
| `INSUFFICIENT_EVIDENCE` | Data inadequate for determination | Low risk, no resuspension |
| `NOT_DETECTED` | Below reporting limit | Zero PFAS, safe conditions |
| `INCONCLUSIVE` | Uncertainty too high for discrimination | Acceptable, no action needed |
| `CONTRADICTORY` | Conflicting evidence identified | Error, discard data |

## Files Created/Modified

### New Files
- `cpp/periphyton_pfas/include/event_mass_balance.hpp`
- `tests/periphyton_pfas_integration_test.cpp`
- `tests/sql/periphyton_evidence_registry_integration.sql`
- `tests/sql/biofilm_recovery_state_history_integration.sql`
- `tests/fixtures/periphyton_pfas_decision_packet.valid.json`
- `tests/fixtures/periphyton_pfas_decision_packet.invalid_external_action.json`
- `tests/fixtures/periphyton_pfas_decision_packet.inconclusive.json`
- `schemas/sql/biofilm_recovery_state_history.sql`
- `python/periphyton_integration_report.py`
- `docs/periphyton-integration-milestone.md` (this file)
- `docs/periphyton-integration-milestone-report.md` (generated)

### Existing Files Referenced
- `schemas/sql/periphyton_evidence_registry.sql`

## Completion Checklist

- [x] C++ integration test compiles and passes
- [x] SQL integration scripts retain provisional, not-detected, inconclusive, contradictory, and insufficient-evidence records
- [x] Valid fixture passes Python structural check
- [x] External-action fixture remains schema-valid but policy-ineligible
- [x] Inconclusive fixture retained as inconclusive, never described as low risk
- [x] ESS isolation checks fail closed if any prohibited governance/access flag is true
- [x] No policy, code, test, or document grants external action authority
- [x] No new dependencies installed
- [x] No Cargo/Rust commands run
- [x] Documentation present in `docs/`

---

**Safety Boundary:** This work remains synthetic, privacy-minimized, non-actuating, and does not authorize external action.
