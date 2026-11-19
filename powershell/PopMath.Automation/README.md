# PopMath.Automation

## Requirements

- PowerShell 7.2 or later
- A local `popmath-cli` executable for scenario execution
- Pester for running the test suite and build validation

## Import from source

```powershell
Import-Module ./powershell/PopMath.Automation/PopMath.Automation.psd1 -Force
Get-Command -Module PopMath.Automation
```

## Run local tests

```powershell
Invoke-Pester ./powershell/PopMath.Automation/tests -Output Detailed
```

## Build a local package

```powershell
./powershell/build/build-popmath-automation.ps1
```

## Install for the current user

```powershell
$moduleSource = Resolve-Path ./powershell/dist/PopMath.Automation/0.1.0
$moduleDestination = Join-Path $HOME '.local/share/powershell/Modules/PopMath.Automation/0.1.0'

New-Item -ItemType Directory -Path $moduleDestination -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $moduleSource '*') -Destination $moduleDestination -Recurse -Force

Import-Module PopMath.Automation -RequiredVersion 0.1.0 -Force
```

## Windows current-user installation

```powershell
$moduleSource = Resolve-Path ./powershell/dist/PopMath.Automation/0.1.0
$moduleDestination = Join-Path $HOME 'Documents/PowerShell/Modules/PopMath.Automation/0.1.0'

New-Item -ItemType Directory -Path $moduleDestination -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $moduleSource '*') -Destination $moduleDestination -Recurse -Force

Import-Module PopMath.Automation -RequiredVersion 0.1.0 -Force
```

## Run a logged scenario

```powershell
Invoke-PopMathScenario `
    -ScenarioPath ./examples/scenarios/continuity-corridor.json `
    -SchemaPath ./schemas/popmath-scenario.schema.json `
    -PopMathCliPath ./target/release/popmath-cli `
    -OutputPath ./artifacts/continuity-corridor.json `
    -LogPath ./artifacts/logs/popmath.log.ndjson
```

## Read local logs

```powershell
Get-Content ./artifacts/logs/popmath.log.ndjson |
    ConvertFrom-Json |
    Format-Table timestamp_utc, level, message -AutoSize
```
