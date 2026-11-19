# Sovereignty-Preserving Log PowerShell Module

This module creates and validates local, artifact-scoped event records. It does
not use network access, external services, connectors, repository operations,
account authentication, identity verification, scoring, ranking, profiling, or
external action.

## Import

```powershell
Import-Module ./powershell/SovereigntyPreservingLog.psd1 -Force
```

## Create an event record

```powershell
$artifactSha256 = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'

$entry = New-SplEventLogEntry `
  -EventId 'artifact-validation-local' `
  -EventKind 'artifact_validated' `
  -ArtifactSha256 $artifactSha256 `
  -ArtifactSchemaVersion '1.0.0' `
  -ArtifactRole 'local_artifact' `
  -RoleVocabularyVersion '1.0.0' `
  -IntegrityStatus 'clean' `
  -LocalNextStep 'none_required' `
  -SourceReference 'policies/sovereignty_preserving_log_policy.aln'
```

## Append locally

```powershell
Add-SplEventLogEntry `
  -Path ./local-audit/artifact-events.jsonl `
  -Entry $entry
```

## Validate and read for an allowed purpose

```powershell
$entries = Read-SplEventLog `
  -Path ./local-audit/artifact-events.jsonl `
  -Purpose 'artifact_integrity_validation'
```

## Create a separate user-sovereign statement

```powershell
$statement = New-SplUserSovereignStatement `
  -StatementKind 'correction_request' `
  -StatementText 'A local correction review is requested.' `
  -RelatedArtifactSha256 $artifactSha256
```

A user-sovereign statement is separate from the event log. Its content is not
automatically summarized, classified, exported, or used for identity
verification, scoring, ranking, eligibility, diagnosis, or external action.

## Run tests

```powershell
Invoke-Pester ./tests/SovereigntyPreservingLog.Tests.ps1
```

The test suite requires Pester only if it is already available in the local
PowerShell environment. Do not install it automatically.
