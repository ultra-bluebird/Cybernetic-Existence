#requires -Version 7.2

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'PopMath.Automation.psm1'
    Import-Module $modulePath -Force

    $testRoot = Join-Path $TestDrive 'popmath-validation'
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

    $schemaPath = Join-Path $testRoot 'scenario.schema.json'
    $validScenarioPath = Join-Path $testRoot 'valid.json'
    $invalidScenarioPath = Join-Path $testRoot 'invalid.json'

    @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schema_version",
    "scenario_id",
    "purpose",
    "assumptions",
    "payload"
  ],
  "properties": {
    "schema_version": {
      "type": "string",
      "const": "1.0"
    },
    "scenario_id": {
      "type": "string",
      "pattern": "^[A-Za-z0-9][A-Za-z0-9._-]*$"
    },
    "purpose": {
      "type": "object",
      "additionalProperties": false,
      "required": ["category", "description"],
      "properties": {
        "category": {
          "type": "string",
          "enum": [
            "WaterResilience",
            "EnergyResilience",
            "EcologicalRestoration",
            "MobilityPlanning",
            "InfrastructureMaintenance",
            "PublicServiceCapacity",
            "ContinuityPlanning"
          ]
        },
        "description": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "assumptions": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["name", "basis"],
        "properties": {
          "name": {
            "type": "string",
            "minLength": 1
          },
          "basis": {
            "type": "string",
            "minLength": 1
          }
        }
      }
    },
    "seed": {
      "type": "integer",
      "minimum": 0,
      "maximum": 4294967295
    },
    "payload": {
      "type": "object"
    }
  }
}
'@ | Set-Content -LiteralPath $schemaPath -Encoding utf8 -NoNewline

    @'
{
  "schema_version": "1.0",
  "scenario_id": "valid-scenario-01",
  "purpose": {
    "category": "ContinuityPlanning",
    "description": "Synthetic validation fixture"
  },
  "assumptions": [
    {
      "name": "Synthetic input",
      "basis": "Local test fixture"
    }
  ],
  "seed": 17,
  "payload": {}
}
'@ | Set-Content -LiteralPath $validScenarioPath -Encoding utf8 -NoNewline

    @'
{
  "scenario_id": "invalid scenario",
  "purpose": {
    "category": "UnsupportedCategory",
    "description": ""
  },
  "assumptions": [],
  "payload": []
}
'@ | Set-Content -LiteralPath $invalidScenarioPath -Encoding utf8 -NoNewline
}

Describe 'Test-PopMathScenario' {
    It 'returns a valid result for a schema-conforming local scenario' {
        $validation = Test-PopMathScenario `
            -ScenarioPath $validScenarioPath `
            -SchemaPath $schemaPath

        $validation.IsValid | Should -BeTrue
        $validation.Errors.Count | Should -Be 0
        $validation.ScenarioPath | Should -Be $validScenarioPath
    }

    It 'returns contextual messages for an invalid local scenario' {
        $validation = Test-PopMathScenario `
            -ScenarioPath $invalidScenarioPath `
            -SchemaPath $schemaPath `
            -Detailed

        $validation.IsValid | Should -BeFalse
        $validation.Errors.Count | Should -BeGreaterThan 0
        ($validation.Errors -join "`n") | Should -Match "schema_version"
        ($validation.Errors -join "`n") | Should -Match "scenario_id"
        ($validation.Errors -join "`n") | Should -Match "purpose.category"
    }
}

Describe 'ConvertTo-PopMathScenario' {
    It 'normalizes PascalCase scenario objects into schema-compatible properties' {
        $scenario = [pscustomobject]@{
            SchemaVersion = "1.0"
            ScenarioId = "pipeline-scenario-01"
            Purpose = [pscustomobject]@{
                Category = "ContinuityPlanning"
                Description = "Synthetic pipeline fixture"
            }
            Assumptions = @(
                [pscustomobject]@{
                    Name = "Scenario source"
                    Basis = "Local test fixture"
                }
            )
            Seed = 31
            Payload = [pscustomobject]@{
                service_window_seconds = 3600
            }
        }

        $normalized = $scenario | ConvertTo-PopMathScenario

        $normalized.schema_version | Should -Be "1.0"
        $normalized.scenario_id | Should -Be "pipeline-scenario-01"
        $normalized.purpose.category | Should -Be "ContinuityPlanning"
        $normalized.assumptions[0].name | Should -Be "Scenario source"
        $normalized.seed | Should -Be 31
        $normalized.payload.service_window_seconds | Should -Be 3600
    }

    It 'rejects scenario objects with missing required properties' {
        {
            [pscustomobject]@{
                ScenarioId = "missing-fields"
            } | ConvertTo-PopMathScenario
        } | Should -Throw
    }
}
