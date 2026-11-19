#requires -Version 7.2

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleDirectory = (Join-Path $PSScriptRoot '..' 'PopMath.Automation')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedModuleDirectory = (Resolve-Path -LiteralPath $ModuleDirectory).Path
$manifestPath = Join-Path $resolvedModuleDirectory 'PopMath.Automation.psd1'

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Module manifest is missing: $manifestPath"
}

$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath -ErrorAction Stop

foreach ($relativePath in @($manifest.FileList)) {
    $fullPath = Join-Path $resolvedModuleDirectory $relativePath

    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Manifest FileList entry does not exist: $relativePath"
    }
}

$moduleInfo = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop

Import-Module $manifestPath -Force -ErrorAction Stop

$missingExports = @(
    foreach ($functionName in @($manifest.FunctionsToExport)) {
        $command = Get-Command `
            -Name $functionName `
            -Module $moduleInfo.Name `
            -ErrorAction SilentlyContinue

        if ($null -eq $command) {
            $functionName
        }
    }
)

if ($missingExports.Count -gt 0) {
    throw "Manifest-declared functions were not exported: $($missingExports -join ', ')"
}

[pscustomobject]@{
    ModuleName = $moduleInfo.Name
    ModuleVersion = $moduleInfo.Version.ToString()
    PowerShellVersion = $manifest.PowerShellVersion
    CompatiblePSEditions = $manifest.CompatiblePSEditions -join ', '
    ExportedFunctionCount = @($manifest.FunctionsToExport).Count
    FileListEntryCount = @($manifest.FileList).Count
    ManifestPath = $manifestPath
    ValidationStatus = 'Valid'
}
