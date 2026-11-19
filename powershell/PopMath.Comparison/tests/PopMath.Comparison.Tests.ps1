#requires -Version 7.2

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'PopMath.Comparison.psd1'
    Import-Module $modulePath -Force

    $resultDirectory = Join-Path $TestDrive 'results'
    New-Item -ItemType Directory -Path $resultDirectory -Force | Out-Null

    $alphaPath = Join-Path $resultDirectory 'alpha.json'
    $betaPath = Join-Path $resultDirectory 'beta.json'

    @'
{
  "scenario_id": "alpha",
  "validation_status": "Valid",
  "continuity": {
    "overall_status": "Met",
    "explanation": "All requirements were met."
  },
  "metrics": {
    "knowledge_factor": 0.90,
    "eco_impact_value": 0.80,
    "harm_risk": 0.15,
    "accessibility_impact": 0.91,
    "rights_alignment": 0.95,
    "social_acceptance_factor": 0.84
  },
  "reproducibility": {
    "digest": "alpha-reproducibility-digest-long",
    "crate_version": "0.1.0",
    "random_seed": 7
  }
}
'@ | Set-Content -LiteralPath $alphaPath -Encoding utf8 -NoNewline

    @'
{
  "scenario_id": "beta",
  "validation_status": "Valid",
  "metrics": {
    "knowledge_factor": 0.93,
    "eco_impact_value": 0.86,
    "harm_risk": 0.10,
    "accessibility_impact": 0.96,
    "rights_alignment": 0.98,
    "social_acceptance_factor": 0.88
  },
  "reproducibility": {
    "digest": "beta-reproducibility-digest-long",
    "crate_version": "0.1.0",
    "random_seed": 8
  }
}
'@ | Set-Content -LiteralPath $betaPath -Encoding utf8 -NoNewline
}

Describe 'Compare-PopMathResults' {
    It 'compares scenarios and includes one best-metric summary row' {
        $rows = @(
            Compare-PopMathResults -ResultPaths @($betaPath, $alphaPath)
        )

        $rows.Count | Should -Be 3
        $rows[0].ScenarioId | Should -Be 'alpha'
        $rows[1].ScenarioId | Should -Be 'beta'
        $rows[2].RowType | Should -Be 'BestMetricSummary'
        $rows[1].ContinuityStatus | Should -Be 'N/A'
        $rows[2].HarmRisk | Should -Be 'beta'
        $rows[2].EcoImpactValue | Should -Be 'beta'
        $rows[0].ReproducibilityDigest | Should -Be 'alpha-reproducib…'
    }

    It 'accepts result files from the pipeline' {
        $rows = @(
            Get-ChildItem `
                -LiteralPath $resultDirectory `
                -Filter '*.json' `
                -File |
                Select-Object -ExpandProperty FullName |
                Compare-PopMathResults
        )

        @($rows | Where-Object RowType -eq 'Scenario').Count | Should -Be 2
    }
}
