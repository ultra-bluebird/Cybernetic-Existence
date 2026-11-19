#requires -Version 7.2

BeforeAll {
    $automationModule = Join-Path $PSScriptRoot '..' '..' 'PopMath.Automation' 'PopMath.Automation.psd1'
    $sensitivityModule = Join-Path $PSScriptRoot '..' 'PopMath.Sensitivity.psd1'

    Import-Module $automationModule -Force
    Import-Module $sensitivityModule -Force

    $testRoot = Join-Path $TestDrive 'sensitivity'
    $scenarioPath = Join-Path $testRoot 'base-scenario.json'
    $schemaPath = Join-Path $testRoot 'scenario.schema.json'
    $mockCliPath = Join-Path $testRoot 'mock-popmath-cli.ps1'
    $outputDirectory = Join-Path $testRoot 'results'

    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

    @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": [
    "schema_version",
    "scenario_id",
    "purpose",
    "assumptions",
    "payload"
  ],
  "properties": {
    "schema_version": {
      "type": "string"
    },
    "scenario_id": {
      "type": "string"
    },
    "purpose": {
      "type": "object"
    },
    "assumptions": {
      "type": "array"
    },
    "payload": {
      "type": "object"
    },
    "seed": {
      "type": "integer"
    }
  }
}
'@ | Set-Content -LiteralPath $schemaPath -Encoding utf8 -NoNewline

    @'
{
  "schema_version": "1.0",
  "scenario_id": "sensitivity-base",
  "purpose": {
    "category": "EnergyResilience",
    "description": "Synthetic sensitivity fixture"
  },
  "assumptions": [
    {
      "name": "Energy demand",
      "basis": "Synthetic fixture input"
    }
  ],
  "seed": 31,
  "payload": {
    "energy": {
      "demand": 10.0
    }
  }
}
'@ | Set-Content -LiteralPath $scenarioPath -Encoding utf8 -NoNewline

    @'
param(
    [Parameter(Mandatory)]
    [string]$Command,

    [Parameter(Mandatory)]
    [string]$Scenario,

    [Parameter(Mandatory)]
    [string]$Output
)

if ($Command -ne 'run') {
    exit 64
}

$scenario = Get-Content -LiteralPath $Scenario -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
$demand = [double]$scenario.payload.energy.demand

if ($demand -eq 20.0) {
    exit 2
}

$outputDirectory = Split-Path -Path $Output -Parent
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$result = [ordered]@{
    scenario_id = $scenario.scenario_id
    validation_status = 'Valid'
    continuity = [ordered]@{
        overall_status = if ($demand -le 25.0) { 'Met' } else { 'Unmet' }
        explanation = 'Synthetic fixture'
    }
    metrics = [ordered]@{
        knowledge_factor = 0.90
        eco_impact_value = [math]::Round(1.0 - ($demand / 100.0), 4)
        harm_risk = 0.10
        accessibility_impact = 0.95
        rights_alignment = 0.97
        social_acceptance_factor = 0.90
    }
    reproducibility = [ordered]@{
        digest = "synthetic-$demand"
        crate_version = '0.1.0'
        random_seed = $scenario.seed
    }
}

$result | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Output -Encoding utf8 -NoNewline
'@ | Set-Content -LiteralPath $mockCliPath -Encoding utf8 -NoNewline
}

Describe 'Invoke-PopMathSensitivity' {
    It 'runs an ordered sweep and retains individual failure records' {
        $rows = @(
            Invoke-PopMathSensitivity `
                -BaseScenarioPath $scenarioPath `
                -ParameterPath 'payload.energy.demand' `
                -MinValue 10 `
                -MaxValue 30 `
                -StepCount 3 `
                -SchemaPath $schemaPath `
                -PopMathCliPath $mockCliPath `
                -OutputDirectory $outputDirectory `
                -KeyMetricPath 'metrics.eco_impact_value'
        )

        $rows.Count | Should -Be 3
        $rows[0].ParameterValue | Should -Be 10
        $rows[1].ParameterValue | Should -Be 20
        $rows[2].ParameterValue | Should -Be 30
        $rows[0].Succeeded | Should -BeTrue
        $rows[1].Succeeded | Should -BeFalse
        $rows[2].Succeeded | Should -BeTrue
        $rows[0].KeyMetric | Should -Be 0.9
        $rows[2].ContinuityStatus | Should -Be 'Unmet'
    }
}
