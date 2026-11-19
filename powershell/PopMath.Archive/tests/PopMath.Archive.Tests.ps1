#requires -Version 7.2

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'PopMath.Archive.psd1'
    Import-Module $modulePath -Force

    $archiveRoot = Join-Path $TestDrive 'archive'
    $resultPath = Join-Path $TestDrive 'result.json'

    @'
{
  "scenario_id": "continuity-corridor-01",
  "validation_status": "Valid",
  "metrics": {
    "knowledge_factor": 0.92,
    "eco_impact_value": 0.81,
    "harm_risk": 0.10,
    "accessibility_impact": 0.95,
    "rights_alignment": 0.97
  },
  "reproducibility": {
    "digest": "synthetic-digest-001",
    "crate_version": "0.1.0",
    "random_seed": 42
  }
}
'@ | Set-Content -LiteralPath $resultPath -Encoding utf8 -NoNewline
}

Describe 'PopMath.Archive' {
    It 'archives a new result envelope by crate version and digest' {
        $saved = Save-PopMathResult `
            -ResultPath $resultPath `
            -ArchiveRoot $archiveRoot

        $saved.DuplicateSuppressed | Should -BeFalse
        $saved.Note | Should -Be 'archived'
        Test-Path -LiteralPath $saved.ArchivePath -PathType Leaf | Should -BeTrue

        $item = Get-Item -LiteralPath $saved.ArchivePath
        $item.IsReadOnly | Should -BeTrue
    }

    It 'suppresses a repeated digest in the same crate version' {
        $saved = Save-PopMathResult `
            -ResultPath $resultPath `
            -ArchiveRoot $archiveRoot

        $saved.DuplicateSuppressed | Should -BeTrue
        $saved.Note | Should -Be 'duplicate suppressed'
    }

    It 'maintains one archive index entry for the unique archive event' {
        $indexPath = Join-Path $archiveRoot 'index.csv'
        $indexRows = @(Import-Csv -LiteralPath $indexPath)

        $indexRows.Count | Should -Be 1
        $indexRows[0].Digest | Should -Be 'synthetic-digest-001'
        $indexRows[0].ScenarioId | Should -Be 'continuity-corridor-01'
        $indexRows[0].CrateVersion | Should -Be '0.1.0'
    }

    It 'retrieves a result envelope by digest' {
        $archived = @(
            Get-PopMathArchivedResult `
                -Digest 'synthetic-digest-001' `
                -ArchiveRoot $archiveRoot
        )

        $archived.Count | Should -Be 1
        $archived[0].ScenarioId | Should -Be 'continuity-corridor-01'
        $archived[0].ResultEnvelope.reproducibility.digest |
            Should -Be 'synthetic-digest-001'
    }
}
