$repositoryRoot = (Resolve-Path "$PSScriptRoot/../..").Path

Import-Module `
    (Join-Path $repositoryRoot 'powershell/PopMath.Automation/PopMath.Automation.psd1') `
    -Force

Import-Module `
    (Join-Path $repositoryRoot 'powershell/PopMath.Sensitivity/PopMath.Sensitivity.psd1') `
    -Force

Import-Module `
    (Join-Path $repositoryRoot 'powershell/PopMath.Comparison/PopMath.Comparison.psd1') `
    -Force

Get-Command -Module PopMath.Automation, PopMath.Sensitivity, PopMath.Comparison |
    Sort-Object -Property ModuleName, Name |
    Format-Table ModuleName, Name -AutoSize
