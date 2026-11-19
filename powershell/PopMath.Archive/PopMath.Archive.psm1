#requires -Version 7.2

Set-StrictMode -Version Latest

function Resolve-PopMathArchiveFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Label
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop

    if (-not (Test-Path -LiteralPath $resolved.Path -PathType Leaf)) {
        throw "$Label must resolve to a file: $Path"
    }

    $resolved.Path
}

function Resolve-PopMathArchiveDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Label,

        [switch]$Create
    )

    if ($Create -and -not (Test-Path -LiteralPath $Path -PathType Container)) {
        New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
    }

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop

    if (-not (Test-Path -LiteralPath $resolved.Path -PathType Container)) {
        throw "$Label must resolve to a directory: $Path"
    }

    $resolved.Path
}

function Get-PopMathArchiveProperty {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Object,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Path
    )

    $current = $Object

    foreach ($segment in $Path) {
        if ($null -eq $current) {
            return $null
        }

        $property = $current.PSObject.Properties[$segment]

        if ($null -eq $property) {
            return $null
        }

        $current = $property.Value
    }

    $current
}

function Test-PopMathArchivePathSegment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Value,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Label
    )

    if ($Value -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]*$') {
        throw "$Label contains unsupported characters: $Value"
    }

    $Value
}

function Get-PopMathArchiveResultMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResultPath
    )

    $resolvedResult = Resolve-PopMathArchiveFile -Path $ResultPath -Label 'Result path'
    $resultJson = Get-Content -LiteralPath $resolvedResult -Raw -Encoding utf8 -ErrorAction Stop
    $result = $resultJson | ConvertFrom-Json -Depth 100 -ErrorAction Stop

    $digest = Get-PopMathArchiveProperty `
        -Object $result `
        -Path @('reproducibility', 'digest')

    $scenarioId = Get-PopMathArchiveProperty `
        -Object $result `
        -Path @('scenario_id')

    $embeddedCrateVersion = Get-PopMathArchiveProperty `
        -Object $result `
        -Path @('reproducibility', 'crate_version')

    if ($null -eq $digest -or [string]::IsNullOrWhiteSpace([string]$digest)) {
        throw "Result envelope does not contain reproducibility.digest: $resolvedResult"
    }

    if ($null -eq $scenarioId -or [string]::IsNullOrWhiteSpace([string]$scenarioId)) {
        throw "Result envelope does not contain scenario_id: $resolvedResult"
    }

    [pscustomobject]@{
        ResultPath = $resolvedResult
        Digest = [string]$digest
        ScenarioId = [string]$scenarioId
        EmbeddedCrateVersion = if ($null -eq $embeddedCrateVersion) {
            $null
        }
        else {
            [string]$embeddedCrateVersion
        }
    }
}

function Write-PopMathArchiveIndex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$IndexPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Digest,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ScenarioId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OriginalPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ArchivePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CrateVersion
    )

    $entry = [pscustomobject]@{
        Digest = $Digest
        ScenarioId = $ScenarioId
        TimestampUtc = [DateTimeOffset]::UtcNow.ToString('O')
        OriginalPath = $OriginalPath
        ArchivePath = $ArchivePath
        CrateVersion = $CrateVersion
    }

    if (Test-Path -LiteralPath $IndexPath -PathType Leaf) {
        $entry | Export-Csv `
            -LiteralPath $IndexPath `
            -NoTypeInformation `
            -Append `
            -Encoding utf8 `
            -ErrorAction Stop
    }
    else {
        $entry | Export-Csv `
            -LiteralPath $IndexPath `
            -NoTypeInformation `
            -Encoding utf8 `
            -ErrorAction Stop
    }
}

function Save-PopMathResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Path', 'FullName')]
        [ValidateNotNullOrEmpty()]
        [string]$ResultPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ArchiveRoot = './artifacts/archive',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CrateVersion
    )

    process {
        $metadata = Get-PopMathArchiveResultMetadata -ResultPath $ResultPath
        $effectiveCrateVersion = $CrateVersion

        if ([string]::IsNullOrWhiteSpace($effectiveCrateVersion)) {
            $effectiveCrateVersion = $metadata.EmbeddedCrateVersion
        }

        if ([string]::IsNullOrWhiteSpace($effectiveCrateVersion)) {
            throw 'CrateVersion must be supplied when the result envelope does not contain reproducibility.crate_version.'
        }

        $validatedDigest = Test-PopMathArchivePathSegment `
            -Value $metadata.Digest `
            -Label 'Reproducibility digest'

        $validatedCrateVersion = Test-PopMathArchivePathSegment `
            -Value $effectiveCrateVersion `
            -Label 'Crate version'

        $validatedScenarioId = Test-PopMathArchivePathSegment `
            -Value $metadata.ScenarioId `
            -Label 'Scenario identifier'

        $resolvedArchiveRoot = Resolve-PopMathArchiveDirectory `
            -Path $ArchiveRoot `
            -Label 'Archive root' `
            -Create

        $versionDirectory = Join-Path $resolvedArchiveRoot $validatedCrateVersion
        $resolvedVersionDirectory = Resolve-PopMathArchiveDirectory `
            -Path $versionDirectory `
            -Label 'Version archive directory' `
            -Create

        $archivePath = Join-Path $resolvedVersionDirectory ($validatedDigest + '.json')
        $indexPath = Join-Path $resolvedArchiveRoot 'index.csv'

        if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
            [pscustomobject]@{
                Digest = $validatedDigest
                ScenarioId = $validatedScenarioId
                CrateVersion = $validatedCrateVersion
                OriginalPath = $metadata.ResultPath
                ArchivePath = $archivePath
                DuplicateSuppressed = $true
                Note = 'duplicate suppressed'
            }

            return
        }

        Copy-Item `
            -LiteralPath $metadata.ResultPath `
            -Destination $archivePath `
            -ErrorAction Stop

        Set-ItemProperty `
            -LiteralPath $archivePath `
            -Name IsReadOnly `
            -Value $true `
            -ErrorAction Stop

        Write-PopMathArchiveIndex `
            -IndexPath $indexPath `
            -Digest $validatedDigest `
            -ScenarioId $validatedScenarioId `
            -OriginalPath $metadata.ResultPath `
            -ArchivePath $archivePath `
            -CrateVersion $validatedCrateVersion

        [pscustomobject]@{
            Digest = $validatedDigest
            ScenarioId = $validatedScenarioId
            CrateVersion = $validatedCrateVersion
            OriginalPath = $metadata.ResultPath
            ArchivePath = $archivePath
            DuplicateSuppressed = $false
            Note = 'archived'
        }
    }
}

function Get-PopMathArchivedResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Digest,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ArchiveRoot = './artifacts/archive',

        [Parameter()]
        [AllowNull()]
        [string]$CrateVersion
    )

    $validatedDigest = Test-PopMathArchivePathSegment `
        -Value $Digest `
        -Label 'Reproducibility digest'

    $resolvedArchiveRoot = Resolve-PopMathArchiveDirectory `
        -Path $ArchiveRoot `
        -Label 'Archive root'

    $candidatePaths = if ([string]::IsNullOrWhiteSpace($CrateVersion)) {
        @(
            Get-ChildItem `
                -LiteralPath $resolvedArchiveRoot `
                -Directory `
                -ErrorAction Stop |
                Sort-Object -Property Name |
                ForEach-Object {
                    Join-Path $_.FullName ($validatedDigest + '.json')
                }
        )
    }
    else {
        $validatedCrateVersion = Test-PopMathArchivePathSegment `
            -Value $CrateVersion `
            -Label 'Crate version'

        @(
            Join-Path `
                (Join-Path $resolvedArchiveRoot $validatedCrateVersion) `
                ($validatedDigest + '.json')
        )
    }

    $matches = @(
        $candidatePaths |
            Where-Object {
                Test-Path -LiteralPath $_ -PathType Leaf
            } |
            Sort-Object
    )

    if ($matches.Count -eq 0) {
        return $null
    }

    foreach ($match in $matches) {
        $metadata = Get-PopMathArchiveResultMetadata -ResultPath $match

        [pscustomobject]@{
            Digest = $metadata.Digest
            ScenarioId = $metadata.ScenarioId
            CrateVersion = $metadata.EmbeddedCrateVersion
            ArchivePath = $metadata.ResultPath
            ResultEnvelope = (
                Get-Content `
                    -LiteralPath $metadata.ResultPath `
                    -Raw `
                    -Encoding utf8 `
                    -ErrorAction Stop |
                    ConvertFrom-Json `
                    -Depth 100 `
                    -ErrorAction Stop
            )
        }
    }
}

Export-ModuleMember -Function @(
    'Save-PopMathResult',
    'Get-PopMathArchivedResult'
)
