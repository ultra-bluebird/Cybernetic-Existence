Import-Module "$PSScriptRoot/../PopMath.Automation/PopMath.Automation.psm1" -Force

$repositoryRoot = Resolve-Path "$PSScriptRoot/../.."
$schemaPath = Join-Path $repositoryRoot "schemas/popmath-scenario.schema.json"
$scenarioPath = Join-Path $repositoryRoot "examples/continuity-corridor.json"
$cliPath = Join-Path $repositoryRoot "target/release/popmath-cli"
$outputDirectory = Join-Path $repositoryRoot "artifacts"
$firstOutputPath = Join-Path $outputDirectory "continuity-corridor.first.json"
$secondOutputPath = Join-Path $outputDirectory "continuity-corridor.second.json"

$validation = Test-PopMathScenario `
    -ScenarioPath $scenarioPath `
    -SchemaPath $schemaPath

if (-not $validation.IsValid) {
    throw "The scenario is not valid and will not be executed."
}

Invoke-PopMathScenario `
    -ScenarioPath $scenarioPath `
    -SchemaPath $schemaPath `
    -PopMathCliPath $cliPath `
    -OutputPath $firstOutputPath | Out-Null

Invoke-PopMathScenario `
    -ScenarioPath $scenarioPath `
    -SchemaPath $schemaPath `
    -PopMathCliPath $cliPath `
    -OutputPath $secondOutputPath | Out-Null

Get-PopMathResultSummary -ResultPath $firstOutputPath | Format-List

Compare-PopMathReproducibility `
    -LeftResultPath $firstOutputPath `
    -RightResultPath $secondOutputPath | Format-List
