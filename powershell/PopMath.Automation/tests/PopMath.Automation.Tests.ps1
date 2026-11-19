#requires -Version 7.2

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'PopMath.Automation.psd1'
    Import-Module $modulePath -Force

    $testRoot = Join-Path $TestDrive 'popmath'
    $schemaPath = Join-Path $testRoot 'scenario.schema.json'
    $scenarioPath = Join-Path $testRoot 'scenario.json'
    $leftResultPath = Join-Path $testRoot 'left-result.json'
    $rightResultPath = Join-Path $testRoot 'right-result.json'

    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

    @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["scenario_id"],
  "properties": {
    "scenario_id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9][A-Za-z0-9._-]*$"
    }
  }
}
'@ | Set-Content -LiteralPath $schemaPath -Encoding utf8 -NoNewline

    @'
{
  "scenario_id": "continuity-corridor-01"
}
'@ | Set-Content -LiteralPath $scenarioPath -Encoding utf8 -NoNewline

    @'
{
  "scenario_id": "continuity-corridor-01",
  "validation_status": "Valid",
  "purpose": {
    "category": "ContinuityPlanning",
    "description": "Synthetic continuity corridor scenario"
  },
  "assumptions": [
    {
      "name": "Demand window",
      "basis": "Continuous service is evaluated for one hour."
    }
  ],
  "continuity": {
    "overall_status": "Met",
    "explanation": "All declared capability requirements were met.",
    "capability_results": []
  },
  "metrics": {
    "knowledge_factor": 0.92,
    "eco_impact_value": 0.81,
    "harm_risk": 0.10,
    "accessibility_impact": 0.95,
    "rights_alignment": 0.97,
    "social_acceptance_factor": 0.88
  },
  "reproducibility": {
    "digest": "synthetic-digest-001",
    "crate_version": "0.1.0",
    "random_seed": 42
  }
}
'@ | Set-Content -LiteralPath $leftResultPath -Encoding utf8 -NoNewline

    Copy-Item -LiteralPath $leftResultPath -Destination $rightResultPath -Force
}

Describe 'PopMath.Automation' {
    It 'validates a well-formed scenario against its schema' {
        $result = Test-PopMathScenario -ScenarioPath $scenarioPath -SchemaPath $schemaPath

        $result.IsValid | Should -BeTrue
        $result.ScenarioId | Should -Be 'continuity-corridor-01'
    }

    It 'returns a normalized result summary' {
        $summary = Get-PopMathResultSummary -ResultPath $leftResultPath

        $summary.ScenarioId | Should -Be 'continuity-corridor-01'
        $summary.ValidationStatus | Should -Be 'Valid'
        $summary.ContinuityStatus | Should -Be 'Met'
        $summary.ReproducibilityDigest | Should -Be 'synthetic-digest-001'
        $summary.SocialAcceptanceFactor | Should -Be 0.88
    }

    It 'confirms equivalent reproducibility metadata' {
        $comparison = Compare-PopMathReproducibility `
            -LeftResultPath $leftResultPath `
            -RightResultPath $rightResultPath

        $comparison.SameDigest | Should -BeTrue
        $comparison.SameCrateVersion | Should -BeTrue
        $comparison.SameSeed | Should -BeTrue
        $comparison.ReproducibleUnderDeclaredInputs | Should -BeTrue
    }

    It 'writes a Markdown report to an existing or created directory' {
        $reportPath = Join-Path $testRoot 'reports' 'scenario-report.md'

        $report = Export-PopMathReport `
            -ResultPaths @($leftResultPath) `
            -OutputPath $reportPath `
            -Format Markdown

        $report.Format | Should -Be 'Markdown'
        $report.ScenarioCount | Should -Be 1
        Test-Path -LiteralPath $report.OutputPath -PathType Leaf | Should -BeTrue

        $content = Get-Content -LiteralPath $report.OutputPath -Raw -Encoding utf8
        $content | Should -Match 'Population.Math Scenario Report'
        $content | Should -Match 'continuity-corridor-01'
    }

    It 'writes an accessible HTML report to an existing or created directory' {
        $reportPath = Join-Path $testRoot 'reports' 'scenario-report.html'

        $report = Export-PopMathReport `
            -ResultPaths @($leftResultPath) `
            -OutputPath $reportPath `
            -Format Html

        $report.Format | Should -Be 'Html'
        $report.ScenarioCount | Should -Be 1
        Test-Path -LiteralPath $report.OutputPath -PathType Leaf | Should -BeTrue

        $content = Get-Content -LiteralPath $report.OutputPath -Raw -Encoding utf8
        $content | Should -Match '<main>'
        $content | Should -Match '<table>'
        $content | Should -Match 'Reproducibility digest'
    }

    It 'rejects scenario identifiers with unsupported characters' {
        $invalidScenarioPath = Join-Path $testRoot 'invalid-scenario.json'

        @'
{
  "scenario_id": "scenario with spaces"
}
'@ | Set-Content -LiteralPath $invalidScenarioPath -Encoding utf8 -NoNewline

        {
            Get-PopMathScenarioId -ScenarioPath $invalidScenarioPath
        } | Should -Throw
    }
}
