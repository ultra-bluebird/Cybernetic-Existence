# Nanorobotics Core Documentation

This directory contains the authoritative specifications for the core nanorobotics control stack, including biophysical budget modeling, evidence-bundle validation, and safety envelope definitions.

## Contents
- `host-budget-math.md`: Formulas, corridor normalization, and residual risk calculations.
- `evidence-bundles.md`: Structure, validation rules, and allowed biophysical tag sequences.

## Agent & Developer Guidelines
- All core types must compile under `edition = "2024"` and align with the workspace `Cargo.toml`.
- Mathematical invariants defined here are binding. Do not weaken risk ceilings or evidence cardinality rules.
- Updates to Rust structs in `crates/nanorobotics-core` must be mirrored in these docs.
