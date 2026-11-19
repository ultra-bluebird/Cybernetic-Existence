function Resolve-PopMathLogPath {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [string]$LogPath
    )

    $effectiveLogPath = $LogPath

    if ([string]::IsNullOrWhiteSpace($effectiveLogPath)) {
        $temporaryDirectory = [System.IO.Path]::GetTempPath()
        $effectiveLogPath = Join-Path $temporaryDirectory 'popmath.log.ndjson'
    }

    $directory = Split-Path -Path $effectiveLogPath -Parent

    if ([string]::IsNullOrWhiteSpace($directory)) {
        throw "LogPath must include a destination directory."
    }

    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
    }

    $resolvedDirectory = (Resolve-Path -LiteralPath $directory -ErrorAction Stop).Path
    $fileName = Split-Path -Path $effectiveLogPath -Leaf

    if ([string]::IsNullOrWhiteSpace($fileName)) {
        throw "LogPath must include a log filename."
    }

    Join-Path $resolvedDirectory $fileName
}

function ConvertTo-PopMathLogData {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Data,

        [switch]$IncludeScenarioData
    )

    if ($null -eq $Data) {
        return $null
    }

    if ($IncludeScenarioData) {
        return $Data
    }

    if ($Data -is [string] -or $Data -is [System.ValueType]) {
        return $Data
    }

    $safeData = [ordered]@{}

    foreach ($property in $Data.PSObject.Properties) {
        $propertyName = [string]$property.Name

        if (
            $propertyName -match 'scenario|payload|assumption|input|content|body|data'
        ) {
            $safeData[$propertyName] = '[omitted]'
            continue
        }

        $safeData[$propertyName] = $property.Value
    }

    [pscustomobject]$safeData
}

function Write-PopMathLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
        [string]$Level,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter()]
        [AllowNull()]
        [object]$Data,

        [Parameter()]
        [AllowNull()]
        [string]$LogPath,

        [switch]$IncludeScenarioData
    )

    $resolvedLogPath = Resolve-PopMathLogPath -LogPath $LogPath
    $safeData = ConvertTo-PopMathLogData `
        -Data $Data `
        -IncludeScenarioData:$IncludeScenarioData

    $entry = [ordered]@{
        timestamp_utc = [DateTimeOffset]::UtcNow.ToString('O')
        level = $Level
        message = $Message
        data = $safeData
    }

    $line = $entry | ConvertTo-Json -Depth 32 -Compress -ErrorAction Stop
    [System.IO.File]::AppendAllText(
        $resolvedLogPath,
        $line + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    switch ($Level) {
        'Info' {
            Write-Information -MessageData $Message -InformationAction Continue
        }
        'Warning' {
            Write-Warning -Message $Message
        }
        'Error' {
            Write-Error -Message $Message -ErrorAction Continue
        }
        'Debug' {
            Write-Debug -Message $Message
        }
    }

    [pscustomobject]@{
        TimestampUtc = $entry.timestamp_utc
        Level = $Level
        Message = $Message
        LogPath = $resolvedLogPath
    }
}
