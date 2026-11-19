Import-Module "$PSScriptRoot/../PopMath.Automation/PopMath.Automation.psm1" -Force

$repositoryRoot = Resolve-Path "$PSScriptRoot/../.."
$schemaPath = Join-Path $repositoryRoot "schemas/popmath-scenario.schema.json"
$cliPath = Join-Path $repositoryRoot "target/release/popmath-cli"
$outputDirectory = Join-Path $repositoryRoot "artifacts/pipeline"

$scenarioObjects = @(
    [pscustomobject]@{
        SchemaVersion = "1.0"
        ScenarioId = "continuity-corridor-a"
        Purpose = [pscustomobject]@{
            Category = "ContinuityPlanning"
            Description = "Synthetic continuity scenario A"
        }
        Assumptions = @(
            [pscustomobject]@{
                Name = "Support duration"
                Basis = "Synthetic local fixture for deterministic evaluation."
            }
        )
        Seed = 41
        Payload = [pscustomobject]@{
            required_continuity_ratio = 0.99
        }
    },
    [pscustomobject]@{
        SchemaVersion = "1.0"
        ScenarioId = "continuity-corridor-b"
        Purpose = [pscustomobject]@{
            Category = "ContinuityPlanning"
            Description = "Synthetic continuity scenario B"
        }
        Assumptions = @(
            [pscustomobject]@{
                Name = "Support duration"
                Basis = "Synthetic local fixture for deterministic evaluation."
            }
        )
        Seed = 42
        Payload = [pscustomobject]@{
            required_continuity_ratio = 0.995
        }
    }
)

$scenarioObjects |
    ConvertTo-PopMathScenario |
    ForEach-Object {
        $resultName = "$($_.scenario_id).json"

        Invoke-PopMathScenario `
            -Scenario $_ `
            -SchemaPath $schemaPath `
            -PopMathCliPath $cliPath `
            -OutputPath (Join-Path $outputDirectory $resultName)
    } |
    Format-Table ScenarioId, ExitCode, ResultPath -AutoSize
