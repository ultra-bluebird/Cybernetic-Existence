#requires -Version 7.2

BeforeAll {
    $moduleManifest = Join-Path $PSScriptRoot '..' 'PopMath.Automation.psd1'
    Import-Module $moduleManifest -Force
}

Describe 'PopMath structured logging' {
    It 'writes an NDJSON log entry with a UTC timestamp and requested level' {
        $logPath = Join-Path $TestDrive 'logs' 'popmath.log.ndjson'

        $entry = Write-PopMathLog `
            -Level Info `
            -Message 'Synthetic local log entry.' `
            -Data ([pscustomobject]@{
                ScenarioPath = 'synthetic-scenario.json'
                ResultPath = 'synthetic-result.json'
            }) `
            -LogPath $logPath

        $entry.Level | Should -Be 'Info'
        Test-Path -LiteralPath $entry.LogPath -PathType Leaf | Should -BeTrue

        $record = Get-Content `
            -LiteralPath $entry.LogPath `
            -Raw `
            -Encoding utf8 |
            ConvertFrom-Json

        $record.timestamp_utc | Should -Not -BeNullOrEmpty
        $record.level | Should -Be 'Info'
        $record.message | Should -Be 'Synthetic local log entry.'
        $record.data.ScenarioPath | Should -Be '[omitted]'
        $record.data.ResultPath | Should -Be 'synthetic-result.json'
    }

    It 'includes scenario data only when explicitly requested' {
        $logPath = Join-Path $TestDrive 'logs' 'scenario-data.log.ndjson'

        Write-PopMathLog `
            -Level Debug `
            -Message 'Synthetic scenario data inclusion.' `
            -Data ([pscustomobject]@{
                Scenario = [pscustomobject]@{
                    scenario_id = 'synthetic-01'
                }
            }) `
            -LogPath $logPath `
            -IncludeScenarioData | Out-Null

        $record = Get-Content `
            -LiteralPath $logPath `
            -Raw `
            -Encoding utf8 |
            ConvertFrom-Json

        $record.data.Scenario.scenario_id | Should -Be 'synthetic-01'
    }
}
