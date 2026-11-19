@{
    RootModule = 'PopMath.Archive.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'd7e46680-4d30-41ed-9586-3ef97d1caeb0'
    Author = 'Augmented-Hub Contributors'
    CompanyName = 'Augmented-Hub'
    Copyright = '(c) Augmented-Hub Contributors'
    Description = 'Versioned digest-addressed archive storage for Population.Math result envelopes.'
    PowerShellVersion = '7.2'
    CompatiblePSEditions = @(
        'Core'
    )
    FunctionsToExport = @(
        'Save-PopMathResult',
        'Get-PopMathArchivedResult'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @(
                'popmath',
                'archive',
                'reproducibility',
                'digest',
                'scenario-analysis',
                'auditability'
            )
            ProjectUri = 'https://github.com/mk-bluebird/Augmented-Hub'
        }
    }
}
