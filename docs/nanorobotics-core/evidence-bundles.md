# EvidenceBundle Specification

## Structure
Every `EvidenceBundle` must contain exactly 10 `EvidenceTag` entries. Each tag consists of:
- `hex`: 8–16 character lowercase hexadecimal string
- `description`: Human-readable biophysical domain mapping

## Validation Rules
1. **Cardinality**: Exactly 10 tags.
2. **Uniqueness**: No duplicate `hex` values within a bundle.
3. **Allowlist**: All `hex` values must exist in the `BASELINE_ALLOWED_TAGS` registry.
4. **Immutability**: Bundles are append-only; modifications require a new bundle ID and version.

## Purpose Mapping
Tags anchor upgrades to empirical biophysical domains:
- ATP turnover & resting metabolic rate
- Oxidative phosphorylation efficiency
- Protein synthesis cost & turnover kinetics
- Thermoregulatory brain/core limits
- Peripheral circulation & neurovascular coupling
- EEG/BCI duty cycle safety
- Neuromorphic ML energy profiles
- Inflammation & pain thresholds

## Failure Handling
Invalid bundles must trigger immediate `EvidenceError` and block scheduling. No partial validation or fallback is permitted.
