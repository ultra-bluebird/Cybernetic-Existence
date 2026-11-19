#requires -Version 7.2

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SourceDirectory = (Join-Path $PSScriptRoot '..' 'PopMath.Automation'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..' 'dist'),

    [switch]$SkipTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ExistingDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Label
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop

    if (-not (Test-Path -LiteralPath $resolved.Path -PathType Container)) {
        throw "$Label must resolve to a directory: $Path"
    }

    $resolved.Path
}

$resolvedSourceDirectory = Resolve-ExistingDirectory `
    -Path $SourceDirectory `
    -Label 'Source directory'

$manifestPath = Join-Path $resolvedSourceDirectory 'PopMath.Automation.psd1'

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Module manifest is missing: $manifestPath"
}

$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath -ErrorAction Stop
$moduleName = Split-Path -Path $manifestPath -LeafBase
$moduleVersion = [string]$manifest.ModuleVersion

if ([string]::IsNullOrWhiteSpace($moduleVersion)) {
    throw 'ModuleVersion must be present in the module manifest.'
}

if (-not $SkipTests) {
    $pester = Get-Module -ListAvailable -Name Pester |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1

    if ($null -eq $pester) {
        throw 'Pester is required for packaging validation unless -SkipTests is explicitly supplied.'
    }

    $testPath = Join-Path $resolvedSourceDirectory 'tests'

    if (Test-Path -LiteralPath $testPath -PathType Container) {
        Invoke-Pester -Path $testPath -Output Detailed -CI
    }
}

$resolvedOutputDirectory = $OutputDirectory

if (-not (Test-Path -LiteralPath $resolvedOutputDirectory -PathType Container)) {
    New-Item `
        -ItemType Directory `
        -Path $resolvedOutputDirectory `
        -Force `
        -ErrorAction Stop | Out-Null
}

$resolvedOutputDirectory = (Resolve-Path -LiteralPath $resolvedOutputDirectory).Path
$packageRoot = Join-Path $resolvedOutputDirectory $moduleName
$versionedPackageRoot = Join-Path $packageRoot $moduleVersion

if (Test-Path -LiteralPath $versionedPackageRoot -PathType Container) {
    Remove-Item `
        -LiteralPath $versionedPackageRoot `
        -Recurse `
        -Force `
        -ErrorAction Stop
}

New-Item `
    -ItemType Directory `
    -Path $versionedPackageRoot `
    -Force `
    -ErrorAction Stop | Out-Null

Copy-Item `
    -LiteralPath (Join-Path $resolvedSourceDirectory '*') `
    -Destination $versionedPackageRoot `
    -Recurse `
    -Force `
    -ErrorAction Stop

$packageManifestPath = Join-Path $versionedPackageRoot 'PopMath.Automation.psd1'

Test-ModuleManifest `
    -Path $packageManifestPath `
    -ErrorAction Stop | Out-Null

$packageArchivePath = Join-Path `
    $resolvedOutputDirectory `
    ("{0}.{1}.zip" -f $moduleName, $moduleVersion)

if (Test-Path -LiteralPath $packageArchivePath -PathType Leaf) {
    Remove-Item -LiteralPath $packageArchivePath -Force -ErrorAction Stop
}

Compress-Archive `
    -LiteralPath $versionedPackageRoot `
    -DestinationPath $packageArchivePath `
    -CompressionLevel Optimal `
    -ErrorAction Stop

[pscustomobject]@{
    ModuleName = $moduleName
    ModuleVersion = $moduleVersion
    PackageDirectory = $versionedPackageRoot
    PackageArchive = $packageArchivePath
    Manifest = $packageManifestPath
}
