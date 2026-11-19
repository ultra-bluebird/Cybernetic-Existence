#requires -Version 7.2

Set-StrictMode -Version Latest

function Resolve-PopMathResultFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop

    if (-not (Test-Path -LiteralPath $resolved.Path -PathType Leaf)) {
        throw "Result path must resolve to a file: $Path"
    }

    $resolved.Path
}

function Get-PopMathComparisonPropertyValue {
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

function ConvertTo-PopMathDigestPreview {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Digest,

        [ValidateRange(8, 128)]
        [int]$MaximumLength = 16
    )

    if ($null -eq $Digest) {
        return 'N/A'
    }

    $text = [string]$Digest

    if ([string]::IsNullOrWhiteSpace($text)) {
        return 'N/A'
    }

    if ($text.Length -le $MaximumLength) {
        return $text
    }

    $text.Substring(0, $MaximumLength) + '…'
}

function ConvertTo-PopMathMetricNumber {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
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

    $null
}

function Get-PopMathComparisonResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResultPath,

        [ValidateRange(8, 128)]
        [int]$DigestLength = 16
    )

    $resolvedResultPath = Resolve-PopMathResultFile -Path $ResultPath
    $resultJson = Get-Content `
        -LiteralPath $resolvedResultPath `
        -Raw `
        -Encoding utf8 `
        -ErrorAction Stop

    $result = $resultJson | ConvertFrom-Json -Depth 100 -ErrorAction Stop
    $metrics = Get-PopMathComparisonPropertyValue -Object $result -Path @('metrics')
    $reproducibility = Get-PopMathComparisonPropertyValue `
        -Object $result `
        -Path @('reproducibility')

    $continuity = Get-PopMathComparisonPropertyValue `
        -Object $result `
        -Path @('continuity')

    if ($null -eq $continuity) {
        $continuity = Get-PopMathComparisonPropertyValue `
            -Object $result `
            -Path @('result', 'continuity')
    }

    [pscustomobject]@{
        RowType = 'Scenario'
        ScenarioId = [string](Get-PopMathComparisonPropertyValue -Object $result -Path @('scenario_id'))
        ValidationStatus = [string](Get-PopMathComparisonPropertyValue -Object $result -Path @('validation_status'))
        ContinuityStatus = if ($null -eq $continuity) {
            'N/A'
        }
        else {
            [string](Get-PopMathComparisonPropertyValue -Object $continuity -Path @('overall_status'))
        }
        KnowledgeFactor = ConvertTo-PopMathMetricNumber `
            -Value (Get-PopMathComparisonPropertyValue -Object $metrics -Path @('knowledge_factor'))
        EcoImpactValue = ConvertTo-PopMathMetricNumber `
            -Value (Get-PopMathComparisonPropertyValue -Object $metrics -Path @('eco_impact_value'))
        HarmRisk = ConvertTo-PopMathMetricNumber `
            -Value (Get-PopMathComparisonPropertyValue -Object $metrics -Path @('harm_risk'))
        AccessibilityImpact = ConvertTo-PopMathMetricNumber `
            -Value (Get-PopMathComparisonPropertyValue -Object $metrics -Path @('accessibility_impact'))
        RightsAlignment = ConvertTo-PopMathMetricNumber `
            -Value (Get-PopMathComparisonPropertyValue -Object $metrics -Path @('rights_alignment'))
        SocialAcceptanceFactor = ConvertTo-PopMathMetricNumber `
            -Value (Get-PopMathComparisonPropertyValue -Object $metrics -Path @('social_acceptance_factor'))
        ReproducibilityDigest = ConvertTo-PopMathDigestPreview `
            -Digest (Get-PopMathComparisonPropertyValue -Object $reproducibility -Path @('digest')) `
            -MaximumLength $DigestLength
        ResultPath = $resolvedResultPath
        Explanation = if ($null -eq $continuity) {
            $null
        }
        else {
            Get-PopMathComparisonPropertyValue -Object $continuity -Path @('explanation')
        }
    }
}

function Get-PopMathBestScenarioIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$ScenarioRows,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$MetricName,

        [Parameter(Mandatory)]
        [ValidateSet('Minimum', 'Maximum')]
        [string]$Direction
    )

    $candidates = @(
        $ScenarioRows |
            Where-Object { $null -ne $_.$MetricName }
    )

    if ($candidates.Count -eq 0) {
        return 'N/A'
    }

    $targetValue = if ($Direction -eq 'Minimum') {
        ($candidates | Measure-Object -Property $MetricName -Minimum).Minimum
    }
    else {
        ($candidates | Measure-Object -Property $MetricName -Maximum).Maximum
    }

    $matchingScenarioIds = @(
        $candidates |
            Where-Object { $_.$MetricName -eq $targetValue } |
            Sort-Object -Property ScenarioId |
            Select-Object -ExpandProperty ScenarioId
    )

    if ($matchingScenarioIds.Count -eq 0) {
        return 'N/A'
    }

    $matchingScenarioIds -join ', '
}

function Compare-PopMathResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Path', 'FullName')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ResultPaths,

        [switch]$IncludeExplanation,

        [ValidateSet('ScenarioId', 'InputOrder')]
        [string]$SortBy = 'ScenarioId',

        [ValidateRange(8, 128)]
        [int]$DigestLength = 16
    )

    begin {
        $collectedPaths = [System.Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($resultPath in $ResultPaths) {
            $collectedPaths.Add($resultPath)
        }
    }

    end {
        if ($collectedPaths.Count -eq 0) {
            return
        }

        $rows = [System.Collections.Generic.List[object]]::new()

        foreach ($resultPath in $collectedPaths) {
            $record = Get-PopMathComparisonResult `
                -ResultPath $resultPath `
                -DigestLength $DigestLength

            if (-not $IncludeExplanation) {
                $record.PSObject.Properties.Remove('Explanation')
            }

            $rows.Add($record)
        }

        $scenarioRows = @($rows)

        if ($SortBy -eq 'ScenarioId') {
            $scenarioRows = @($scenarioRows | Sort-Object -Property ScenarioId)
        }

        foreach ($row in $scenarioRows) {
            $row
        }

        [pscustomobject]@{
            RowType = 'BestMetricSummary'
            ScenarioId = 'Best metric scenario'
            ValidationStatus = 'N/A'
            ContinuityStatus = 'N/A'
            KnowledgeFactor = Get-PopMathBestScenarioIds `
                -ScenarioRows $scenarioRows `
                -MetricName 'KnowledgeFactor' `
                -Direction Maximum
            EcoImpactValue = Get-PopMathBestScenarioIds `
                -ScenarioRows $scenarioRows `
                -MetricName 'EcoImpactValue' `
                -Direction Maximum
            HarmRisk = Get-PopMathBestScenarioIds `
                -ScenarioRows $scenarioRows `
                -MetricName 'HarmRisk' `
                -Direction Minimum
            AccessibilityImpact = Get-PopMathBestScenarioIds `
                -ScenarioRows $scenarioRows `
                -MetricName 'AccessibilityImpact' `
                -Direction Maximum
            RightsAlignment = Get-PopMathBestScenarioIds `
                -ScenarioRows $scenarioRows `
                -MetricName 'RightsAlignment' `
                -Direction Maximum
            SocialAcceptanceFactor = Get-PopMathBestScenarioIds `
                -ScenarioRows $scenarioRows `
                -MetricName 'SocialAcceptanceFactor' `
                -Direction Maximum
            ReproducibilityDigest = 'N/A'
            ResultPath = 'N/A'
            Explanation = if ($IncludeExplanation) { 'Metric values identify tied best scenario identifiers where applicable.' } else { $null }
        }
    }
}

Export-ModuleMember -Function @(
    'Compare-PopMathResults'
)
