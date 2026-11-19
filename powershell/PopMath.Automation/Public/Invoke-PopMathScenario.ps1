function Invoke-PopMathScenario {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName = 'Path',
            ValueFromPipelineByPropertyName
        )]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [string]$ScenarioPath,

        [Parameter(
            Mandatory,
            ParameterSetName = 'Object',
            ValueFromPipeline
        )]
        [AllowNull()]
        [object]$Scenario,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SchemaPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PopMathCliPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [AllowNull()]
        [string]$LogPath,

        [switch]$IncludeScenarioData
    )

    process {
        $temporaryDirectory = $null
        $effectiveScenarioPath = $null
        $resolvedLogPath = Resolve-PopMathLogPath -LogPath $LogPath

        try {
            $resolvedSchema = Resolve-PopMathFile -Path $SchemaPath -Label 'Schema path'
            $resolvedCli = Resolve-PopMathFile -Path $PopMathCliPath -Label 'popmath CLI path'

            if ($PSCmdlet.ParameterSetName -eq 'Object') {
                $normalizedScenario = ConvertTo-PopMathScenario -InputObject $Scenario
                $temporaryDirectory = Join-Path `
                    ([System.IO.Path]::GetTempPath()) `
                    ('popmath-scenario-' + [System.Guid]::NewGuid().ToString('N'))

                New-Item `
                    -ItemType Directory `
                    -Path $temporaryDirectory `
                    -Force `
                    -ErrorAction Stop | Out-Null

                $effectiveScenarioPath = Write-PopMathScenarioObjectFile `
                    -Scenario $normalizedScenario `
                    -DirectoryPath $temporaryDirectory
            }
            else {
                $effectiveScenarioPath = Resolve-PopMathFile `
                    -Path $ScenarioPath `
                    -Label 'Scenario path'
            }

            $validation = Test-PopMathScenario `
                -ScenarioPath $effectiveScenarioPath `
                -SchemaPath $resolvedSchema

            if (-not $validation.IsValid) {
                $details = if ($validation.Errors.Count -gt 0) {
                    $validation.Errors -join [Environment]::NewLine
                }
                else {
                    'No additional validation details were available.'
                }

                throw "Scenario validation failed:$([Environment]::NewLine)$details"
            }

            $outputDirectory = Split-Path -Path $OutputPath -Parent

            if ([string]::IsNullOrWhiteSpace($outputDirectory)) {
                throw 'OutputPath must include a destination directory.'
            }

            Resolve-PopMathDirectory `
                -Path $outputDirectory `
                -Label 'Result output directory' `
                -Create | Out-Null

            $arguments = @(
                'run',
                '--scenario',
                $validation.ScenarioPath,
                '--output',
                $OutputPath
            )

            Write-PopMathLog `
                -Level Info `
                -Message 'Starting local Population.Math scenario execution.' `
                -Data ([pscustomobject]@{
                    ScenarioPath = $validation.ScenarioPath
                    SchemaPath = $resolvedSchema
                    CliPath = $resolvedCli
                    OutputPath = $OutputPath
                    ArgumentCount = $arguments.Count
                }) `
                -LogPath $resolvedLogPath `
                -IncludeScenarioData:$IncludeScenarioData | Out-Null

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

            $resolvedOutput = Resolve-PopMathFile `
                -Path $OutputPath `
                -Label 'Result output path'

            $scenarioId = Get-PopMathScenarioId `
                -ScenarioPath $validation.ScenarioPath

            Write-PopMathLog `
                -Level Info `
                -Message 'Population.Math scenario execution completed.' `
                -Data ([pscustomobject]@{
                    ScenarioId = $scenarioId
                    ResultPath = $resolvedOutput
                    ExitCode = $process.ExitCode
                }) `
                -LogPath $resolvedLogPath `
                -IncludeScenarioData:$IncludeScenarioData | Out-Null

            [pscustomobject]@{
                ScenarioId = $scenarioId
                ScenarioPath = $validation.ScenarioPath
                ResultPath = $resolvedOutput
                ExitCode = $process.ExitCode
                LogPath = $resolvedLogPath
            }
        }
        catch {
            Write-PopMathLog `
                -Level Error `
                -Message 'Population.Math scenario execution failed.' `
                -Data ([pscustomobject]@{
                    ScenarioPath = $effectiveScenarioPath
                    OutputPath = $OutputPath
                    ErrorMessage = $_.Exception.Message
                }) `
                -LogPath $resolvedLogPath `
                -IncludeScenarioData:$IncludeScenarioData | Out-Null

            throw
        }
        finally {
            if (
                $null -ne $temporaryDirectory -and
                (Test-Path -LiteralPath $temporaryDirectory -PathType Container)
            ) {
                Remove-Item `
                    -LiteralPath $temporaryDirectory `
                    -Recurse `
                    -Force `
                    -ErrorAction SilentlyContinue

                Write-PopMathLog `
                    -Level Debug `
                    -Message 'Temporary scenario workspace was removed.' `
                    -Data ([pscustomobject]@{
                        TemporaryDirectory = $temporaryDirectory
                    }) `
                    -LogPath $resolvedLogPath | Out-Null
            }
        }
    }
}
