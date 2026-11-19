Import-Module "$PSScriptRoot/../PopMath.Comparison/PopMath.Comparison.psd1" -Force

$repositoryRoot = (Resolve-Path "$PSScriptRoot/../..").Path
$resultDirectory = Join-Path $repositoryRoot 'artifacts/corridor-alternatives'

Get-ChildItem `
    -LiteralPath $resultDirectory `
    -Filter '*.json' `
    -File |
    Sort-Object -Property Name |
    Select-Object -ExpandProperty FullName |
    Compare-PopMathResults `
        -IncludeExplanation `
        -SortBy ScenarioId |
    Format-Table `
        RowType,
        ScenarioId,
        ValidationStatus,
        ContinuityStatus,
        KnowledgeFactor,
        EcoImpactValue,
        HarmRisk,
        AccessibilityImpact,
        RightsAlignment,
        SocialAcceptanceFactor,
        ReproducibilityDigest `
        -AutoSize
