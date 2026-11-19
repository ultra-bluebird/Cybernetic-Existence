#requires -Version 7.2

Set-StrictMode -Version Latest

function Resolve-PopMathFile {
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

function Resolve-PopMathDirectory {
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

function Get-PopMathPropertyValue {
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

function ConvertTo-PopMathPathSegments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterPath
    )

    $segments = @(
        $ParameterPath.Split('.') |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    if ($segments.Count -lt 2) {
        throw "ParameterPath must contain at least two dot-separated segments, such as 'payload.energy.demand'."
    }

    foreach ($segment in $segments) {
        if ($segment -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            throw "ParameterPath segment '$segment' is not supported. Use letters, numbers, and underscores, beginning with a letter or underscore."
        }
    }

    $segments
}

function ConvertTo-PopMathNumericValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Value,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Label
    )

    $number = 0.0

    if (
        -not [double]::TryParse(
            [string]$Value,
            [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$number
        )
    ) {
        throw "$Label must be numeric."
    }

    if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) {
        throw "$Label must be finite."
    }

    $number
}

function Set-PopMathNestedNumericProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Object,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Path,

        [Parameter(Mandatory)]
        [double]$Value
    )

    if ($Path.Count -lt 1) {
        throw "Path must contain at least one property name."
    }

    $current = $Object

    for ($index = 0; $index -lt ($Path.Count - 1); $index++) {
        $segment = $Path[$index]
        $property = $current.PSObject.Properties[$segment]

        if ($null -eq $property) {
            throw "ParameterPath does not resolve to an existing property: $($Path -join '.')"
        }

        if ($null -eq $property.Value) {
            throw "ParameterPath includes a null container at '$segment': $($Path -join '.')"
        }

        if ($property.Value -is [string] -or $property.Value -isnot [pscustomobject]) {
            throw "ParameterPath segment '$segment' must resolve to an object container."
        }

        $current = $property.Value
    }

    $leafName = $Path[$Path.Count - 1]
    $leafProperty = $current.PSObject.Properties[$leafName]

    if ($null -eq $leafProperty) {
        throw "ParameterPath does not resolve to an existing numeric property: $($Path -join '.')"
    }

    $existingValue = $leafProperty.Value

    if ($existingValue -is [string] -or $existingValue -isnot [System.ValueType]) {
        throw "ParameterPath leaf '$leafName' must be numeric."
    }

    $null = ConvertTo-PopMathNumericValue -Value $existingValue -Label "ParameterPath leaf '$leafName'"
    $leafProperty.Value = $Value
}

function ConvertTo-PopMathResultValue {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return $null
    }

    $number = 0.0

    if (
        [double]::TryParse(
            [string]$Value,
            [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$number
        )
    ) {
        return $number
    }

    [string]$Value
}

function Get-PopMathSensitivityMetric {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ResultEnvelope,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$KeyMetricPath
    )

    $segments = ConvertTo-PopMathPathSegments -ParameterPath $KeyMetricPath
    $value = Get-PopMathPropertyValue -Object $ResultEnvelope -Path $segments

    if ($null -eq $value -and $segments[0] -eq 'result') {
        $value = Get-PopMathPropertyValue -Object $ResultEnvelope -Path $segments[1..($segments.Count - 1)]
    }

    ConvertTo-PopMathResultValue -Value $value
}

function Invoke-PopMathSensitivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseScenarioPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterPath,

        [Parameter(Mandatory)]
        [double]$MinValue,

        [Parameter(Mandatory)]
        [double]$MaxValue,

        [Parameter(Mandatory)]
        [ValidateRange(2, 10000)]
        [int]$StepCount,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SchemaPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PopMathCliPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDirectory,

        [ValidateNotNullOrEmpty()]
        [string]$KeyMetricPath = 'metrics.eco_impact_value'
    )

    if ([double]::IsNaN($MinValue) -or [double]::IsInfinity($MinValue)) {
        throw "MinValue must be finite."
    }

    if ([double]::IsNaN($MaxValue) -or [double]::IsInfinity($MaxValue)) {
        throw "MaxValue must be finite."
    }

    if ($MinValue -gt $MaxValue) {
        throw "MinValue must be less than or equal to MaxValue."
    }

    $resolvedBaseScenario = Resolve-PopMathFile `
        -Path $BaseScenarioPath `
        -Label "Base scenario path"

    $resolvedSchema = Resolve-PopMathFile `
        -Path $SchemaPath `
        -Label "Schema path"

    $resolvedCli = Resolve-PopMathFile `
        -Path $PopMathCliPath `
        -Label "popmath CLI path"

    $resolvedOutputDirectory = Resolve-PopMathDirectory `
        -Path $OutputDirectory `
        -Label "Sensitivity output directory" `
        -Create

    $pathSegments = ConvertTo-PopMathPathSegments -ParameterPath $ParameterPath
    $metricSegments = ConvertTo-PopMathPathSegments -ParameterPath $KeyMetricPath
    $baseScenarioJson = Get-Content `
        -LiteralPath $resolvedBaseScenario `
        -Raw `
        -Encoding utf8 `
        -ErrorAction Stop

    $baseScenario = $baseScenarioJson | ConvertFrom-Json -Depth 100 -ErrorAction Stop
    $baseScenarioId = [string](Get-PopMathPropertyValue -Object $baseScenario -Path @('scenario_id'))

    if ([string]::IsNullOrWhiteSpace($baseScenarioId)) {
        throw "Base scenario must contain a non-empty scenario_id."
    }

    $temporaryRoot = Join-Path `
        ([System.IO.Path]::GetTempPath()) `
        ('popmath-sensitivity-' + [System.Guid]::NewGuid().ToString('N'))

    New-Item -ItemType Directory -Path $temporaryRoot -Force -ErrorAction Stop | Out-Null

    try {
        $stepSize = if ($StepCount -eq 1) {
            0.0
        }
        else {
            ($MaxValue - $MinValue) / ($StepCount - 1)
        }

        $rows = [System.Collections.Generic.List[object]]::new()

        for ($index = 0; $index -lt $StepCount; $index++) {
            $parameterValue = if ($index -eq ($StepCount - 1)) {
                $MaxValue
            }
            else {
                $MinValue + ($index * $stepSize)
            }

            $stepDirectory = Join-Path $temporaryRoot ('step-' + $index.ToString('D5'))
            $stepScenarioPath = Join-Path $stepDirectory 'scenario.json'
            $stepResultPath = Join-Path `
                $resolvedOutputDirectory `
                ('{0}--{1:D5}.json' -f $baseScenarioId, $index)

            try {
                New-Item -ItemType Directory -Path $stepDirectory -Force -ErrorAction Stop | Out-Null

                $stepScenario = $baseScenarioJson | ConvertFrom-Json -Depth 100 -ErrorAction Stop

                Set-PopMathNestedNumericProperty `
                    -Object $stepScenario `
                    -Path $pathSegments `
                    -Value $parameterValue

                $stepScenarioJson = $stepScenario | ConvertTo-Json `
                    -Depth 100 `
                    -Compress `
                    -ErrorAction Stop

                [System.IO.File]::WriteAllText(
                    $stepScenarioPath,
                    $stepScenarioJson,
                    [System.Text.UTF8Encoding]::new($false)
                )

                $execution = Invoke-PopMathScenario `
                    -ScenarioPath $stepScenarioPath `
                    -SchemaPath $resolvedSchema `
                    -PopMathCliPath $resolvedCli `
                    -OutputPath $stepResultPath

                $resultJson = Get-Content `
                    -LiteralPath $execution.ResultPath `
                    -Raw `
                    -Encoding utf8 `
                    -ErrorAction Stop

                $resultEnvelope = $resultJson | ConvertFrom-Json -Depth 100 -ErrorAction Stop
                $continuityStatus = Get-PopMathPropertyValue `
                    -Object $resultEnvelope `
                    -Path @('continuity', 'overall_status')

                if ($null -eq $continuityStatus) {
                    $continuityStatus = Get-PopMathPropertyValue `
                        -Object $resultEnvelope `
                        -Path @('result', 'continuity', 'overall_status')
                }

                $keyMetric = Get-PopMathSensitivityMetric `
                    -ResultEnvelope $resultEnvelope `
                    -KeyMetricPath ($metricSegments -join '.')

                $rows.Add([pscustomobject]@{
                    ParameterPath = $ParameterPath
                    ParameterValue = $parameterValue
                    ScenarioId = $execution.ScenarioId
                    ContinuityStatus = if ($null -eq $continuityStatus) { 'N/A' } else { [string]$continuityStatus }
                    KeyMetricPath = $KeyMetricPath
                    KeyMetric = $keyMetric
                    ResultPath = $execution.ResultPath
                    Succeeded = $true
                    ErrorMessage = $null
                })
            }
            catch {
                $rows.Add([pscustomobject]@{
                    ParameterPath = $ParameterPath
                    ParameterValue = $parameterValue
                    ScenarioId = $baseScenarioId
                    ContinuityStatus = 'N/A'
                    KeyMetricPath = $KeyMetricPath
                    KeyMetric = $null
                    ResultPath = $null
                    Succeeded = $false
                    ErrorMessage = $_.Exception.Message
                })
            }
            finally {
                if (Test-Path -LiteralPath $stepDirectory -PathType Container) {
                    Remove-Item `
                        -LiteralPath $stepDirectory `
                        -Recurse `
                        -Force `
                        -ErrorAction SilentlyContinue
                }
            }
        }

        @($rows | Sort-Object -Property ParameterValue)
    }
    finally {
        if (Test-Path -LiteralPath $temporaryRoot -PathType Container) {
            Remove-Item `
                -LiteralPath $temporaryRoot `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

Export-ModuleMember -Function @(
    'Invoke-PopMathSensitivity'
)
