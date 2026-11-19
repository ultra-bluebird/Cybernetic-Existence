@{
    RootModule = 'PopMath.Sensitivity.psm1'
    ModuleVersion = '1.0.0'
    GUID = '3bdc9c61-f8d0-4f18-91e5-ec77d7d22a0a'
    Author = 'Augmented-Hub'
    CompanyName = 'Augmented-Hub'
    Copyright = '(c) Augmented-Hub'
    Description = 'Deterministic single-parameter sensitivity analysis for Population.Math scenarios.'
    PowerShellVersion = '7.2'
    RequiredModules = @(
        @{
            ModuleName = 'PopMath.Automation'
            ModuleVersion = '1.0.0'
        }
    )
    FunctionsToExport = @(
        'Invoke-PopMathSensitivity'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
