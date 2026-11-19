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

function Get-PopMathScenarioId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ScenarioPath
    )

    $resolvedScenario = Resolve-PopMathFile -Path $ScenarioPath -Label "Scenario path"
    $scenarioJson = Get-Content -LiteralPath $resolvedScenario -Raw -Encoding utf8 -ErrorAction Stop
    $scenario = $scenarioJson | ConvertFrom-Json -Depth 64 -ErrorAction Stop

    if ($null -eq $scenario.scenario_id) {
        throw "Scenario file does not contain a scenario_id: $resolvedScenario"
    }

    $scenarioId = [string]$scenario.scenario_id

    if ([string]::IsNullOrWhiteSpace($scenarioId)) {
        throw "Scenario file contains an empty scenario_id: $resolvedScenario"
    }

    if ($scenarioId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "Scenario scenario_id contains unsupported characters: $scenarioId"
    }

    $scenarioId
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

function ConvertTo-PopMathSafeHtml {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ""
    }

    [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function ConvertTo-PopMathSafeMarkdown {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ""
    }

    ([string]$Value).
        Replace('\', '\\').
        Replace('|', '\|').
        Replace("`r", ' ').
        Replace("`n", ' ')
}

function ConvertTo-PopMathCommandLineArgument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.Append('"')

    $backslashCount = 0

    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') {
            $backslashCount++
            continue
        }

        if ($character -eq '"') {
            [void]$builder.Append(('\' * (($backslashCount * 2) + 1)))
            [void]$builder.Append('"')
            $backslashCount = 0
            continue
        }

        if ($backslashCount -gt 0) {
            [void]$builder.Append(('\' * $backslashCount))
            $backslashCount = 0
        }

        [void]$builder.Append($character)
    }

    if ($backslashCount -gt 0) {
        [void]$builder.Append(('\' * ($backslashCount * 2)))
    }

    [void]$builder.Append('"')
    $builder.ToString()
}

function Invoke-PopMathCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PopMathCliPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ScenarioPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $resolvedCli = Resolve-PopMathFile -Path $PopMathCliPath -Label "popmath CLI path"
    $resolvedScenario = Resolve-PopMathFile -Path $ScenarioPath -Label "Scenario path"

    $outputDirectory = Split-Path -Path $OutputPath -Parent

    if ([string]::IsNullOrWhiteSpace($outputDirectory)) {
        throw "OutputPath must include a destination directory."
    }

    $resolvedOutputDirectory = Resolve-PopMathDirectory `
        -Path $outputDirectory `
        -Label "Result output directory" `
        -Create

    $outputLeaf = Split-Path -Path $OutputPath -Leaf

    if ([string]::IsNullOrWhiteSpace($outputLeaf)) {
        throw "OutputPath must include a result filename."
    }

    $resolvedOutputPath = Join-Path $resolvedOutputDirectory $outputLeaf

    $arguments = @(
        'run',
        '--scenario',
        (ConvertTo-PopMathCommandLineArgument -Value $resolvedScenario),
        '--output',
        (ConvertTo-PopMathCommandLineArgument -Value $resolvedOutputPath)
    ) -join ' '

    $process = Start-Process `
        -FilePath $resolvedCli `
        -ArgumentList $arguments `
        -NoNewWindow `
        -PassThru `
        -Wait `
        -ErrorAction Stop

    if ($process.ExitCode -ne 0) {
        throw "popmath CLI returned a non-zero exit code: $($process.ExitCode)"
    }

    if (-not (Test-Path -LiteralPath $resolvedOutputPath -PathType Leaf)) {
        throw "popmath CLI completed without creating a result envelope: $resolvedOutputPath"
    }

    Resolve-PopMathFile -Path $resolvedOutputPath -Label "Result output path"
}

function Get-PopMathResultRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResultPath
    )

    $resolvedResult = Resolve-PopMathFile -Path $ResultPath -Label "Result path"
    $resultJson = Get-Content -LiteralPath $resolvedResult -Raw -Encoding utf8 -ErrorAction Stop
    $result = $resultJson | ConvertFrom-Json -Depth 64 -ErrorAction Stop

    $continuity = Get-PopMathPropertyValue -Object $result -Path @('continuity')

    if ($null -eq $continuity) {
        $continuity = Get-PopMathPropertyValue -Object $result -Path @('result', 'continuity')
    }

    $metrics = Get-PopMathPropertyValue -Object $result -Path @('metrics')
    $reproducibility = Get-PopMathPropertyValue -Object $result -Path @('reproducibility')

    [pscustomobject]@{
        ScenarioId = Get-PopMathPropertyValue -Object $result -Path @('scenario_id')
        Purpose = Get-PopMathPropertyValue -Object $result -Path @('purpose', 'description')
        PurposeCategory = Get-PopMathPropertyValue -Object $result -Path @('purpose', 'category')
        ValidationStatus = Get-PopMathPropertyValue -Object $result -Path @('validation_status')
        Continuity = $continuity
        ContinuityStatus = Get-PopMathPropertyValue -Object $continuity -Path @('overall_status')
        ContinuityExplanation = Get-PopMathPropertyValue -Object $continuity -Path @('explanation')
        Metrics = $metrics
        Reproducibility = $reproducibility
        KnowledgeFactor = Get-PopMathPropertyValue -Object $metrics -Path @('knowledge_factor')
        EcoImpactValue = Get-PopMathPropertyValue -Object $metrics -Path @('eco_impact_value')
        HarmRisk = Get-PopMathPropertyValue -Object $metrics -Path @('harm_risk')
        AccessibilityImpact = Get-PopMathPropertyValue -Object $metrics -Path @('accessibility_impact')
        RightsAlignment = Get-PopMathPropertyValue -Object $metrics -Path @('rights_alignment')
        SocialAcceptanceFactor = Get-PopMathPropertyValue -Object $metrics -Path @('social_acceptance_factor')
        ReproducibilityDigest = Get-PopMathPropertyValue -Object $reproducibility -Path @('digest')
        CrateVersion = Get-PopMathPropertyValue -Object $reproducibility -Path @('crate_version')
        ScenarioSeed = Get-PopMathPropertyValue -Object $reproducibility -Path @('random_seed')
        ResultPath = $resolvedResult
    }
}

function Test-PopMathScenario {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ScenarioPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SchemaPath
    )

    $resolvedScenario = Resolve-PopMathFile -Path $ScenarioPath -Label "Scenario path"
    $resolvedSchema = Resolve-PopMathFile -Path $SchemaPath -Label "Schema path"
    $scenarioJson = Get-Content -LiteralPath $resolvedScenario -Raw -Encoding utf8 -ErrorAction Stop
    $isValid = Test-Json -Json $scenarioJson -SchemaFile $resolvedSchema -ErrorAction Stop

    [pscustomobject]@{
        ScenarioPath = $resolvedScenario
        SchemaPath = $resolvedSchema
        ScenarioId = Get-PopMathScenarioId -ScenarioPath $resolvedScenario
        IsValid = [bool]$isValid
    }
}

function Invoke-PopMathScenario {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ScenarioPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SchemaPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PopMathCliPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $validation = Test-PopMathScenario -ScenarioPath $ScenarioPath -SchemaPath $SchemaPath

    if (-not $validation.IsValid) {
        throw "Scenario JSON does not conform to the provided schema: $($validation.ScenarioPath)"
    }

    $resolvedOutput = Invoke-PopMathCli `
        -PopMathCliPath $PopMathCliPath `
        -ScenarioPath $validation.ScenarioPath `
        -OutputPath $OutputPath

    [pscustomobject]@{
        ScenarioId = $validation.ScenarioId
        ScenarioPath = $validation.ScenarioPath
        ResultPath = $resolvedOutput
        ExitCode = 0
    }
}

function Get-PopMathResultSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResultPath
    )

    $record = Get-PopMathResultRecord -ResultPath $ResultPath

    [pscustomobject]@{
        ScenarioId = $record.ScenarioId
        ValidationStatus = $record.ValidationStatus
        ContinuityStatus = $record.ContinuityStatus
        KnowledgeFactor = $record.KnowledgeFactor
        EcoImpactValue = $record.EcoImpactValue
        HarmRisk = $record.HarmRisk
        AccessibilityImpact = $record.AccessibilityImpact
        RightsAlignment = $record.RightsAlignment
        SocialAcceptanceFactor = $record.SocialAcceptanceFactor
        ReproducibilityDigest = $record.ReproducibilityDigest
        CrateVersion = $record.CrateVersion
        ScenarioSeed = $record.ScenarioSeed
        ResultPath = $record.ResultPath
    }
}

function Compare-PopMathReproducibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LeftResultPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RightResultPath
    )

    $left = Get-PopMathResultSummary -ResultPath $LeftResultPath
    $right = Get-PopMathResultSummary -ResultPath $RightResultPath

    $sameDigest = $left.ReproducibilityDigest -eq $right.ReproducibilityDigest
    $sameCrateVersion = $left.CrateVersion -eq $right.CrateVersion
    $sameSeed = $left.ScenarioSeed -eq $right.ScenarioSeed

    [pscustomobject]@{
        LeftScenarioId = $left.ScenarioId
        RightScenarioId = $right.ScenarioId
        LeftResultPath = $left.ResultPath
        RightResultPath = $right.ResultPath
        SameDigest = $sameDigest
        SameCrateVersion = $sameCrateVersion
        SameSeed = $sameSeed
        ReproducibleUnderDeclaredInputs = (
            $sameDigest -and
            $sameCrateVersion -and
            $sameSeed
        )
    }
}

function Invoke-PopMathBatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ScenarioPaths,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SchemaPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PopMathCliPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputDirectory,

        [ValidateRange(1, 128)]
        [int]$ThrottleLimit = 4
    )

    $resolvedSchema = Resolve-PopMathFile -Path $SchemaPath -Label "Schema path"
    $resolvedCli = Resolve-PopMathFile -Path $PopMathCliPath -Label "popmath CLI path"
    $resolvedOutputDirectory = Resolve-PopMathDirectory `
        -Path $OutputDirectory `
        -Label "Batch output directory" `
        -Create

    $scenarioRecords = @(
        foreach ($scenarioPath in $ScenarioPaths) {
            $resolvedScenarioPath = Resolve-PopMathFile -Path $scenarioPath -Label "Scenario path"

            [pscustomobject]@{
                ScenarioId = Get-PopMathScenarioId -ScenarioPath $resolvedScenarioPath
                ScenarioPath = $resolvedScenarioPath
            }
        }
    )

    $duplicateScenarioIds = @(
        $scenarioRecords |
            Group-Object -Property ScenarioId |
            Where-Object { $_.Count -gt 1 }
    )

    if ($duplicateScenarioIds.Count -gt 0) {
        $duplicateList = ($duplicateScenarioIds | ForEach-Object Name) -join ', '
        throw "Scenario identifiers must be unique within a batch: $duplicateList"
    }

    $temporaryRoot = Join-Path `
        ([System.IO.Path]::GetTempPath()) `
        ('popmath-batch-' + [System.Guid]::NewGuid().ToString('N'))

    New-Item -ItemType Directory -Path $temporaryRoot -Force -ErrorAction Stop | Out-Null

    try {
        $parallelResults = @(
            $scenarioRecords |
                ForEach-Object -Parallel {
                    $record = $_
                    $schema = $using:resolvedSchema
                    $cli = $using:resolvedCli
                    $outputDirectory = $using:resolvedOutputDirectory
                    $temporaryRoot = $using:temporaryRoot

                    $jobDirectory = Join-Path $temporaryRoot $record.ScenarioId
                    $temporaryResult = Join-Path $jobDirectory 'result.json'
                    $finalResult = Join-Path $outputDirectory ($record.ScenarioId + '.json')

                    try {
                        New-Item -ItemType Directory -Path $jobDirectory -Force -ErrorAction Stop | Out-Null

                        $scenarioJson = Get-Content `
                            -LiteralPath $record.ScenarioPath `
                            -Raw `
                            -Encoding utf8 `
                            -ErrorAction Stop

                        if (-not (Test-Json -Json $scenarioJson -SchemaFile $schema -ErrorAction Stop)) {
                            throw 'Scenario JSON does not conform to the provided schema.'
                        }

                        if (Test-Path -LiteralPath $finalResult -PathType Leaf) {
                            throw "Batch result path already exists: $finalResult"
                        }

                        $quote = {
                            param([string]$Value)

                            if ($Value -notmatch '[\s"]') {
                                return $Value
                            }

                            $builder = [System.Text.StringBuilder]::new()
                            [void]$builder.Append('"')
                            $backslashCount = 0

                            foreach ($character in $Value.ToCharArray()) {
                                if ($character -eq '\') {
                                    $backslashCount++
                                    continue
                                }

                                if ($character -eq '"') {
                                    [void]$builder.Append(('\' * (($backslashCount * 2) + 1)))
                                    [void]$builder.Append('"')
                                    $backslashCount = 0
                                    continue
                                }

                                if ($backslashCount -gt 0) {
                                    [void]$builder.Append(('\' * $backslashCount))
                                    $backslashCount = 0
                                }

                                [void]$builder.Append($character)
                            }

                            if ($backslashCount -gt 0) {
                                [void]$builder.Append(('\' * ($backslashCount * 2)))
                            }

                            [void]$builder.Append('"')
                            $builder.ToString()
                        }

                        $arguments = @(
                            'run',
                            '--scenario',
                            (& $quote $record.ScenarioPath),
                            '--output',
                            (& $quote $temporaryResult)
                        ) -join ' '

                        $process = Start-Process `
                            -FilePath $cli `
                            -ArgumentList $arguments `
                            -NoNewWindow `
                            -PassThru `
                            -Wait `
                            -ErrorAction Stop

                        if ($process.ExitCode -ne 0) {
                            throw "popmath CLI returned a non-zero exit code: $($process.ExitCode)"
                        }

                        if (-not (Test-Path -LiteralPath $temporaryResult -PathType Leaf)) {
                            throw 'popmath CLI completed without creating a result envelope.'
                        }

                        Move-Item `
                            -LiteralPath $temporaryResult `
                            -Destination $finalResult `
                            -ErrorAction Stop

                        [pscustomobject]@{
                            ScenarioId = $record.ScenarioId
                            ScenarioPath = $record.ScenarioPath
                            ResultPath = $finalResult
                            Succeeded = $true
                            ErrorMessage = $null
                        }
                    }
                    catch {
                        [pscustomobject]@{
                            ScenarioId = $record.ScenarioId
                            ScenarioPath = $record.ScenarioPath
                            ResultPath = $null
                            Succeeded = $false
                            ErrorMessage = $_.Exception.Message
                        }
                    }
                    finally {
                        if (Test-Path -LiteralPath $jobDirectory -PathType Container) {
                            Remove-Item `
                                -LiteralPath $jobDirectory `
                                -Recurse `
                                -Force `
                                -ErrorAction SilentlyContinue
                        }
                    }
                } -ThrottleLimit $ThrottleLimit
        )

        $rows = foreach ($parallelResult in $parallelResults) {
            if (-not $parallelResult.Succeeded) {
                [pscustomobject]@{
                    ScenarioId = $parallelResult.ScenarioId
                    ScenarioPath = $parallelResult.ScenarioPath
                    ResultPath = $null
                    Succeeded = $false
                    ErrorMessage = $parallelResult.ErrorMessage
                    ValidationStatus = $null
                    ContinuityStatus = $null
                    KnowledgeFactor = $null
                    EcoImpactValue = $null
                    HarmRisk = $null
                    AccessibilityImpact = $null
                    RightsAlignment = $null
                    SocialAcceptanceFactor = $null
                    ReproducibilityDigest = $null
                    CrateVersion = $null
                    ScenarioSeed = $null
                    ResultEnvelopeReadable = $false
                }

                continue
            }

            try {
                $resultJson = Get-Content `
                    -LiteralPath $parallelResult.ResultPath `
                    -Raw `
                    -Encoding utf8 `
                    -ErrorAction Stop

                $result = $resultJson | ConvertFrom-Json -Depth 64 -ErrorAction Stop
                $continuity = $result.continuity

                if ($null -eq $continuity) {
                    $continuity = $result.result.continuity
                }

                $metrics = $result.metrics
                $reproducibility = $result.reproducibility

                [pscustomobject]@{
                    ScenarioId = $parallelResult.ScenarioId
                    ScenarioPath = $parallelResult.ScenarioPath
                    ResultPath = $parallelResult.ResultPath
                    Succeeded = $true
                    ErrorMessage = $null
                    ValidationStatus = $result.validation_status
                    ContinuityStatus = $continuity.overall_status
                    KnowledgeFactor = $metrics.knowledge_factor
                    EcoImpactValue = $metrics.eco_impact_value
                    HarmRisk = $metrics.harm_risk
                    AccessibilityImpact = $metrics.accessibility_impact
                    RightsAlignment = $metrics.rights_alignment
                    SocialAcceptanceFactor = $metrics.social_acceptance_factor
                    ReproducibilityDigest = $reproducibility.digest
                    CrateVersion = $reproducibility.crate_version
                    ScenarioSeed = $reproducibility.random_seed
                    ResultEnvelopeReadable = $true
                }
            }
            catch {
                [pscustomobject]@{
                    ScenarioId = $parallelResult.ScenarioId
                    ScenarioPath = $parallelResult.ScenarioPath
                    ResultPath = $parallelResult.ResultPath
                    Succeeded = $false
                    ErrorMessage = "Result-envelope aggregation failed: $($_.Exception.Message)"
                    ValidationStatus = $null
                    ContinuityStatus = $null
                    KnowledgeFactor = $null
                    EcoImpactValue = $null
                    HarmRisk = $null
                    AccessibilityImpact = $null
                    RightsAlignment = $null
                    SocialAcceptanceFactor = $null
                    ReproducibilityDigest = $null
                    CrateVersion = $null
                    ScenarioSeed = $null
                    ResultEnvelopeReadable = $false
                }
            }
        }

        $orderedRows = @($rows | Sort-Object -Property ScenarioId)

        [pscustomobject]@{
            OutputDirectory = $resolvedOutputDirectory
            ThrottleLimit = $ThrottleLimit
            ScenarioCount = $orderedRows.Count
            SucceededCount = @($orderedRows | Where-Object Succeeded).Count
            FailedCount = @($orderedRows | Where-Object { -not $_.Succeeded }).Count
            Results = $orderedRows
            Errors = @(
                $orderedRows |
                    Where-Object { -not $_.Succeeded } |
                    Select-Object ScenarioId, ScenarioPath, ErrorMessage
            )
        }
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

function Export-PopMathReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ResultPaths,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [ValidateSet('Html', 'Markdown')]
        [string]$Format
    )

    $outputDirectory = Split-Path -Path $OutputPath -Parent

    if ([string]::IsNullOrWhiteSpace($outputDirectory)) {
        throw "OutputPath must include a destination directory."
    }

    $resolvedOutputDirectory = Resolve-PopMathDirectory `
        -Path $outputDirectory `
        -Label "Report output directory" `
        -Create

    $outputLeaf = Split-Path -Path $OutputPath -Leaf

    if ([string]::IsNullOrWhiteSpace($outputLeaf)) {
        throw "OutputPath must include a report filename."
    }

    $resolvedOutputPath = Join-Path $resolvedOutputDirectory $outputLeaf

    $reportEntries = @(
        foreach ($resultPath in $ResultPaths) {
            $record = Get-PopMathResultRecord -ResultPath $resultPath
            $capabilityResults = Get-PopMathPropertyValue `
                -Object $record.Continuity `
                -Path @('capability_results')

            $failedCapabilities = @(
                foreach ($capability in @($capabilityResults)) {
                    if (
                        $capability.status -eq 'Unmet' -or
                        $capability.status -eq 'InsufficientEvidence'
                    ) {
                        if ($null -ne $capability.kind) {
                            [string]$capability.kind
                        }
                    }
                }
            )

            [pscustomobject]@{
                ScenarioId = $record.ScenarioId
                Purpose = $record.Purpose
                PurposeCategory = $record.PurposeCategory
                ValidationStatus = $record.ValidationStatus
                ContinuityStatus = $record.ContinuityStatus
                ContinuityExplanation = $record.ContinuityExplanation
                FailedCapabilities = @($failedCapabilities | Sort-Object -Unique)
                AccessibilityImpact = $record.AccessibilityImpact
                RightsAlignment = $record.RightsAlignment
                EcoImpactValue = $record.EcoImpactValue
                HarmRisk = $record.HarmRisk
                SocialAcceptanceFactor = $record.SocialAcceptanceFactor
                ReproducibilityDigest = $record.ReproducibilityDigest
                CrateVersion = $record.CrateVersion
                Assumptions = Get-PopMathPropertyValue `
                    -Object $record `
                    -Path @('Result', 'assumptions')
                ResultPath = $record.ResultPath
            }
        }
    )

    $orderedEntries = @($reportEntries | Sort-Object -Property ScenarioId)

    if ($Format -eq 'Markdown') {
        $lines = [System.Collections.Generic.List[string]]::new()

        $lines.Add('# Population.Math Scenario Report')
        $lines.Add('')
        $lines.Add('This report summarizes deterministic scenario result envelopes.')
        $lines.Add('')
        $lines.Add('| Scenario | Validation | Continuity | Accessibility | Rights alignment | Eco impact | Harm risk | Digest |')
        $lines.Add('|---|---|---:|---:|---:|---:|---:|---|')

        foreach ($entry in $orderedEntries) {
            $lines.Add((
                '| {0} | {1} | {2} | {3} | {4} | {5} | {6} | `{7}` |' -f `
                    (ConvertTo-PopMathSafeMarkdown $entry.ScenarioId),
                    (ConvertTo-PopMathSafeMarkdown $entry.ValidationStatus),
                    (ConvertTo-PopMathSafeMarkdown $entry.ContinuityStatus),
                    (ConvertTo-PopMathSafeMarkdown $entry.AccessibilityImpact),
                    (ConvertTo-PopMathSafeMarkdown $entry.RightsAlignment),
                    (ConvertTo-PopMathSafeMarkdown $entry.EcoImpactValue),
                    (ConvertTo-PopMathSafeMarkdown $entry.HarmRisk),
                    (ConvertTo-PopMathSafeMarkdown $entry.ReproducibilityDigest)
            ))

            $lines.Add('')
            $lines.Add("## $(ConvertTo-PopMathSafeMarkdown $entry.ScenarioId)")
            $lines.Add('')
            $lines.Add("**Purpose:** $(ConvertTo-PopMathSafeMarkdown $entry.Purpose)")
            $lines.Add('')
            $lines.Add("**Purpose category:** $(ConvertTo-PopMathSafeMarkdown $entry.PurposeCategory)")
            $lines.Add('')
            $lines.Add(
                "**Continuity explanation:** $(ConvertTo-PopMathSafeMarkdown $entry.ContinuityExplanation)"
            )
            $lines.Add('')

            if ($entry.FailedCapabilities.Count -gt 0) {
                $capabilities = (
                    $entry.FailedCapabilities |
                        ForEach-Object { ConvertTo-PopMathSafeMarkdown $_ }
                ) -join ', '

                $lines.Add("**Capability requirements needing attention:** $capabilities")
                $lines.Add('')
            }

            $lines.Add('### Assumptions')
            $lines.Add('')

            $assumptions = @($entry.Assumptions)

            if ($assumptions.Count -eq 0) {
                $lines.Add('- No assumptions were included in the result envelope.')
            }
            else {
                foreach ($assumption in $assumptions) {
                    $name = ConvertTo-PopMathSafeMarkdown $assumption.name
                    $basis = ConvertTo-PopMathSafeMarkdown $assumption.basis
                    $lines.Add("- **$name:** $basis")
                }
            }

            $lines.Add('')
            $lines.Add(
                "**Reproducibility:** crate $(ConvertTo-PopMathSafeMarkdown $entry.CrateVersion), digest `$(ConvertTo-PopMathSafeMarkdown $entry.ReproducibilityDigest)`"
            )
            $lines.Add('')
        }

        Set-Content `
            -LiteralPath $resolvedOutputPath `
            -Value $lines `
            -Encoding utf8 `
            -NoNewline `
            -ErrorAction Stop

        return [pscustomobject]@{
            Format = 'Markdown'
            OutputPath = Resolve-PopMathFile `
                -Path $resolvedOutputPath `
                -Label "Report output path"
            ScenarioCount = $orderedEntries.Count
        }
    }

    $style = @'
:root {
    color-scheme: light;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    line-height: 1.5;
}
body {
    margin: 0 auto;
    max-width: 72rem;
    padding: 1.5rem;
    color: #18212f;
    background: #ffffff;
}
h1,
h2,
h3 {
    color: #0b3d66;
}
table {
    border-collapse: collapse;
    width: 100%;
    margin: 1rem 0 2rem;
}
th,
td {
    border: 1px solid #4a5568;
    padding: 0.65rem;
    text-align: left;
    vertical-align: top;
}
th {
    background: #e8f1f8;
}
.status {
    font-weight: 700;
}
details {
    border: 1px solid #4a5568;
    border-radius: 0.25rem;
    margin: 1rem 0;
    padding: 0.75rem;
}
summary {
    cursor: pointer;
    font-weight: 700;
}
footer {
    border-top: 2px solid #4a5568;
    margin-top: 2rem;
    padding-top: 1rem;
}
code {
    overflow-wrap: anywhere;
}
'@

    $rows = foreach ($entry in $orderedEntries) {
@"
<tr>
<td>$(ConvertTo-PopMathSafeHtml $entry.ScenarioId)</td>
<td class="status">$(ConvertTo-PopMathSafeHtml $entry.ValidationStatus)</td>
<td class="status">$(ConvertTo-PopMathSafeHtml $entry.ContinuityStatus)</td>
<td>$(ConvertTo-PopMathSafeHtml $entry.AccessibilityImpact)</td>
<td>$(ConvertTo-PopMathSafeHtml $entry.RightsAlignment)</td>
<td>$(ConvertTo-PopMathSafeHtml $entry.EcoImpactValue)</td>
<td>$(ConvertTo-PopMathSafeHtml $entry.HarmRisk)</td>
<td><code>$(ConvertTo-PopMathSafeHtml $entry.ReproducibilityDigest)</code></td>
</tr>
"@
    }

    $details = foreach ($entry in $orderedEntries) {
        $assumptions = @($entry.Assumptions)

        $assumptionItems = if ($assumptions.Count -eq 0) {
            '<li>No assumptions were included in the result envelope.</li>'
        }
        else {
            foreach ($assumption in $assumptions) {
                "<li><strong>$(ConvertTo-PopMathSafeHtml $assumption.name):</strong> $(ConvertTo-PopMathSafeHtml $assumption.basis)</li>"
            }
        }

        $failedCapabilityText = if ($entry.FailedCapabilities.Count -gt 0) {
            ($entry.FailedCapabilities | ForEach-Object {
                ConvertTo-PopMathSafeHtml $_
            }) -join ', '
        }
        else {
            'None reported'
        }

@"
<details>
<summary>$(ConvertTo-PopMathSafeHtml $entry.ScenarioId): scenario explanation and assumptions</summary>
<p><strong>Purpose:</strong> $(ConvertTo-PopMathSafeHtml $entry.Purpose)</p>
<p><strong>Purpose category:</strong> $(ConvertTo-PopMathSafeHtml $entry.PurposeCategory)</p>
<p><strong>Continuity explanation:</strong> $(ConvertTo-PopMathSafeHtml $entry.ContinuityExplanation)</p>
<p><strong>Capability requirements needing attention:</strong> $failedCapabilityText</p>
<p><strong>Social acceptance factor:</strong> $(ConvertTo-PopMathSafeHtml $entry.SocialAcceptanceFactor)</p>
<h3>Assumptions</h3>
<ul>
$($assumptionItems -join "`n")
</ul>
<p><strong>Reproducibility:</strong> crate $(ConvertTo-PopMathSafeHtml $entry.CrateVersion), digest <code>$(ConvertTo-PopMathSafeHtml $entry.ReproducibilityDigest)</code></p>
</details>
"@
    }

    $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Population.Math Scenario Report</title>
<style>
$style
</style>
</head>
<body>
<main>
<h1>Population.Math Scenario Report</h1>
<p>This report summarizes deterministic scenario result envelopes in plain language.</p>
<table>
<thead>
<tr>
<th scope="col">Scenario</th>
<th scope="col">Validation</th>
<th scope="col">Continuity</th>
<th scope="col">Accessibility</th>
<th scope="col">Rights alignment</th>
<th scope="col">Eco impact</th>
<th scope="col">Harm risk</th>
<th scope="col">Reproducibility digest</th>
</tr>
</thead>
<tbody>
$($rows -join "`n")
</tbody>
</table>
$($details -join "`n")
</main>
<footer>
<p>Generated locally from $($orderedEntries.Count) Population.Math result envelope(s).</p>
</footer>
</body>
</html>
"@

    Set-Content `
        -LiteralPath $resolvedOutputPath `
        -Value $html `
        -Encoding utf8 `
        -NoNewline `
        -ErrorAction Stop

    [pscustomobject]@{
        Format = 'Html'
        OutputPath = Resolve-PopMathFile `
            -Path $resolvedOutputPath `
            -Label "Report output path"
        ScenarioCount = $orderedEntries.Count
    }
}

Export-ModuleMember -Function @(
    'Test-PopMathScenario',
    'Invoke-PopMathScenario',
    'Get-PopMathResultSummary',
    'Compare-PopMathReproducibility',
    'Invoke-PopMathBatch',
    'Export-PopMathReport'
)
