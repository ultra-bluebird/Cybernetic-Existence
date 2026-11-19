# Changelog

All notable changes to PopMath.Automation are recorded in this file.

## Unreleased

### Added

- Structured NDJSON logging through `Write-PopMathLog`.
- `-LogPath` and `-IncludeScenarioData` support for public commands.
- PowerShell 7.2 Core-only module metadata.
- Local packaging validation through `build-popmath-automation.ps1`.

### Changed

- Scenario execution records resolved local paths, result paths, exit status, and descriptive errors.
- Temporary scenario files are created in a unique local workspace and removed after execution.

## 0.1.0

### Added

- Schema-aware scenario validation.
- Single-scenario local CLI execution.
- Result-envelope summaries and reproducibility comparison.
- Parallel batch scenario execution with deterministic result aggregation.
- HTML and Markdown result-envelope reports.
- Pipeline scenario normalization.
- Sensitivity analysis and multi-scenario comparison.
