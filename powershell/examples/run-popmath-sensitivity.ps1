Import-Module "$PSScriptRoot/../PopMath.Automation/PopMath.Automation.psd1" -Force
Import-Module "$PSScriptRoot/../PopMath.Sensitivity/PopMath.Sensitivity.psd1" -Force

$repositoryRoot = (Resolve-Path "$PSScriptRoot/../..").Path
$scenarioPath = Join-Path $repositoryRoot 'examples/scenarios/energy-continuity.json'
$schemaPath = Join-Path $repositoryRoot 'schemas/popmath-scenario.schema.json'
$cliPath = Join-Path $repositoryRoot 'target/release/popmath-cli'
$outputDirectory = Join-Path $repositoryRoot 'artifacts/sensitivity/energy-demand'

$results = Invoke-PopMathSensitivity `
    -BaseScenarioPath $scenarioPath `
    -ParameterPath 'payload.energy.demand' `
    -MinValue 10 `
    -MaxValue 100 `
    -StepCount 10 `
    -SchemaPath $schemaPath `
    -PopMathCliPath $cliPath `
    -OutputDirectory $outputDirectory `
    -KeyMetricPath 'metrics.eco_impact_value'

$results |
    Select-Object `
        ParameterValue,
        ScenarioId,
        ContinuityStatus,
        KeyMetric,
        Succeeded,
        ErrorMessage |
    Format-Table -AutoSize

$results |
    Where-Object Succeeded |
    Select-Object ParameterValue, KeyMetric, ContinuityStatus |
    Export-Csv `
        -LiteralPath (Join-Path $outputDirectory 'energy-demand-sensitivity.csv') `
        -NoTypeInformation `
        -Encoding utf8
