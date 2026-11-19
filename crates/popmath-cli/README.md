# popmath-cli

`popmath-cli` is the local command-line wrapper for `popmath`.

It reads a scenario JSON file, validates the scenario contract, builds a deterministic advisory result envelope, and writes that envelope to a caller-selected local path.

The CLI is designed for PowerShell, Lua, shell scripts, local development tools, and offline reproducible scenario workflows.

## Design

The crate provides one command:

```text
popmath-cli run --scenario <scenario.json> --output <result.json>
```

The command:

- Reads local UTF-8 JSON input
- Validates `schema_version`, `scenario_id`, purpose, assumptions, and payload structure
- Preserves the scenario seed when one is declared
- Computes a SHA-256 reproducibility digest from canonical scenario content and crate version
- Writes a JSON result envelope
- Creates the requested output directory when needed
- Does not use network access, device access, service credentials, or external APIs

## Build

From the repository root:

```powershell
cargo build --release -p popmath-cli
```

The executable is created at:

```text
target/release/popmath-cli
```

On Windows, the executable name includes `.exe`.

## Run

```powershell
./target/release/popmath-cli `
    run `
    --scenario ./examples/scenarios/continuity-corridor.json `
    --output ./artifacts/continuity-corridor.json
```

## Scenario contract

A minimal scenario has the following shape:

```json
{
  "schema_version": "1.0",
  "scenario_id": "continuity-corridor-01",
  "purpose": {
    "category": "ContinuityPlanning",
    "description": "Synthetic local continuity scenario."
  },
  "assumptions": [
    {
      "name": "Support duration",
      "basis": "Synthetic deterministic fixture."
    }
  ],
  "seed": 42,
  "payload": {
    "continuity": {
      "overall_status": "Met",
      "explanation": "All requested conditions were met.",
      "capability_results": []
    },
    "metrics": {
      "knowledge_factor": 0.92,
      "eco_impact_value": 0.81,
      "harm_risk": 0.10,
      "accessibility_impact": 0.95,
      "rights_alignment": 0.97,
      "social_acceptance_factor": 0.88
    }
  }
}
```

Accepted purpose categories are:

- `WaterResilience`
- `EnergyResilience`
- `EcologicalRestoration`
- `MobilityPlanning`
- `InfrastructureMaintenance`
- `PublicServiceCapacity`
- `ContinuityPlanning`

## Result envelope

Each successful run writes an envelope containing:

- `scenario_id`
- `purpose`
- `assumptions`
- `validation_status`
- Optional `continuity` summary
- Bounded result metrics
- A reproducibility digest and crate version
- An advisory payload summary

A continuity status of `Unmet` or `InsufficientEvidence` produces `validation_status: "ReviewRequired"` while retaining the calculation output for transparent local review.

## PowerShell integration

The PowerShell automation module can invoke this CLI directly:

```powershell
Invoke-PopMathScenario `
    -ScenarioPath ./examples/scenarios/continuity-corridor.json `
    -SchemaPath ./schemas/popmath-scenario.schema.json `
    -PopMathCliPath ./target/release/popmath-cli `
    -OutputPath ./artifacts/continuity-corridor.json
```

The CLI return contract is:

- Exit code `0`: result envelope created successfully
- Exit code `2`: command argument, input, validation, or local output error
- Result JSON: written only on a successful run

## Tests

Run the crate tests locally:

```powershell
cargo test -p popmath-cli
```

Run formatting and lints:

```powershell
cargo fmt --check
cargo clippy -p popmath-cli --all-targets -- -D warnings
```

## Integration direction

The initial CLI validates scenario structure and produces a deterministic envelope suitable for the existing PowerShell automation, sensitivity analysis, comparison, reporting, and archival modules.

As `popmath` domain modules are enabled, the `build_result_envelope` function can dispatch validated typed payloads to:

- Water-balance calculations
- Energy-storage and critical-load continuity calculations
- Mobility and capability-route calculations
- Corridor calibration models
- Queue and maintenance capacity calculations
- Ecological mass-balance and emissions calculations
- Solver-neutral optimization validation
- Seeded simulation summaries

The command-line interface remains stable: domain expansion enriches the JSON result envelope without replacing the local scenario-to-result workflow.
