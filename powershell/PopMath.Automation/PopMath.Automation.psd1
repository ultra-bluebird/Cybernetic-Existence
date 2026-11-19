@{
    RootModule = 'PopMath.Automation.psm1'
    ModuleVersion = '1.0.0'
    GUID = '85dafaa6-2438-48a1-9e97-bc315465c29a'
    Author = 'Augmented-Hub Contributors'
    CompanyName = 'Augmented-Hub'
    Copyright = '(c) Augmented-Hub Contributors'
    Description = 'Local, deterministic Population.Math scenario validation, execution, reporting, batch processing, sensitivity analysis, comparison, logging, and reproducibility automation.'
    PowerShellVersion = '7.2'
    CompatiblePSEditions = @(
        'Core'
    )
    ProcessorArchitecture = 'None'
    RequiredModules = @()
    RequiredAssemblies = @()
    ScriptsToProcess = @()
    TypesToProcess = @()
    FormatsToProcess = @()
    NestedModules = @()
    FunctionsToExport = @(
        'ConvertTo-PopMathScenario',
        'Test-PopMathScenario',
        'Invoke-PopMathScenario',
        'Get-PopMathResultSummary',
        'Compare-PopMathReproducibility',
        'Invoke-PopMathBatch',
        'Export-PopMathReport'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    FileList = @(
        'PopMath.Automation.psd1',
        'PopMath.Automation.psm1',
        'Public/ConvertTo-PopMathScenario.ps1',
        'Public/Test-PopMathScenario.ps1',
        'Public/Invoke-PopMathScenario.ps1',
        'Public/Get-PopMathResultSummary.ps1',
        'Public/Compare-PopMathReproducibility.ps1',
        'Public/Invoke-PopMathBatch.ps1',
        'Public/Export-PopMathReport.ps1',
        'Private/Resolve-PopMathFile.ps1',
        'Private/Resolve-PopMathDirectory.ps1',
        'Private/Get-PopMathPropertyValue.ps1',
        'Private/Get-PopMathResultRecord.ps1',
        'Private/Write-PopMathLog.ps1',
        'Private/Resolve-PopMathLogPath.ps1',
        'Private/ConvertTo-PopMathLogData.ps1',
        'README.md',
        'CHANGELOG.md',
        'LICENSE',
        'en-US/about_PopMath.Automation.help.txt',
        'tests/PopMath.Automation.Tests.ps1',
        'tests/PopMath.Automation.Validation.Tests.ps1',
        'tests/PopMath.Logging.Tests.ps1'
    )
    PrivateData = @{
        PSData = @{
            Tags = @(
                'popmath',
                'population-math',
                'smart-city',
                'continuity',
                'reproducibility',
                'accessibility',
                'ecology',
                'scenario-analysis',
                'sensitivity-analysis',
                'result-comparison',
                'PSEdition_Core',
                'Windows',
                'Linux',
                'MacOS'
            )
            LicenseUri = 'https://github.com/mk-bluebird/Augmented-Hub/blob/main/LICENSE'
            ProjectUri = 'https://github.com/mk-bluebird/Augmented-Hub'
            ReleaseNotes = 'PowerShell 7.2 Core-only Population.Math automation package with schema-aware scenario validation, local CLI execution, deterministic batch aggregation, structured logging, pipeline scenario support, sensitivity analysis, result comparison, and accessible report generation.'
            RequireLicenseAcceptance = $false
        }
    }
    HelpInfoURI = 'https://github.com/mk-bluebird/Augmented-Hub'
    DefaultCommandPrefix = ''
}
