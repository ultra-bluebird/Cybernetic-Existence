#requires -Version 7.2

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'PopMath.Automation.psd1'
    Import-Module $modulePath -Force

    $testRoot = Join-Path $TestDrive 'continuity-schema'
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

    $schemaPath = Join-Path $testRoot 'popmath-continuity-scenario.schema.json'
    $invalidScenarioPath = Join-Path $testRoot 'invalid-continuity-scenario.json'

    Copy-Item `
        -LiteralPath (
            Join-Path $PSScriptRoot '..' '..' '..' '..' 'schemas' 'popmath-continuity-scenario.schema.json'
        ) `
        -Destination $schemaPath `
        -Force

    @'
{
  "schema_version": "1.0",
  "scenario_id": "invalid-continuity-01",
  "purpose": {
    "category": "ContinuityPlanning",
    "description": "Synthetic invalid continuity scenario."
  },
  "assumptions": [
    {
      "name": "Synthetic fixture",
      "basis": "Local validation test."
    }
  ],
  "payload": {
    "continuity": {
      "requested_window": {
        "start_seconds_since_epoch": 0,
        "end_seconds_since_epoch": 3600
      },
      "requirements": {
        "requirement": {
          "kind": "ChargingAvailability",
          "minimum_availability": 0.99,
          "maximum_gap_seconds": 60,
          "required_evidence": "Verified"
        }
      },
      "capability_windows": [
        {
          "kind": "LowNoiseEnvironment",
          "window": {
            "start_seconds_since_epoch": 0,
            "end_seconds_since_epoch": 3600
          },
          "evidence": "Verified",
          "available": true
        }
      ]
    }
  }
}
'@ | Set-Content -LiteralPath $invalidScenarioPath -Encoding utf8 -NoNewline
}

Describe 'Population.Math continuity scenario validation' {
    It 'rejects capability windows that do not match a declared requirement kind' {
        $validation = Test-PopMathScenario `
            -ScenarioPath $invalidScenarioPath `
            -SchemaPath $schemaPath `
            -Detailed

        $validation.IsValid | Should -BeFalse
        ($validation.Errors -join "`n") |
            Should -Match 'has no matching requirement kind'
    }
}
