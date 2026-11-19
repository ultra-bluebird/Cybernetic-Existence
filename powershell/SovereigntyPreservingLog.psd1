@{
    RootModule = 'SovereigntyPreservingLog.psm1'
    ModuleVersion = '1.0.0'
    GUID = '4f2b1e8b-2ad7-4c58-91e4-706a8d1135d7'
    Author = 'Augmented-Hub'
    CompanyName = 'mk-bluebird'
    Copyright = '(c) Augmented-Hub'
    Description = 'Local artifact-scoped event logging with SHA-256 integrity, purpose-limited reads, no-person-signal validation, and separate user-sovereign statements.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Add-SplEventLogEntry',
        'ConvertTo-SplCanonicalJson',
        'Get-SplModuleSchemaSha256',
        'Get-SplPlainLanguageSummary',
        'Get-SplSha256Hex',
        'New-SplEventLogEntry',
        'New-SplUserSovereignStatement',
        'Normalize-SplSourceReference',
        'Read-SplEventLog',
        'Test-SplEventLogChain',
        'Test-SplEventLogEntry',
        'Test-SplNoPersonSignal',
        'Test-SplSha256Hex'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @(
                'local-only',
                'sha256',
                'provenance',
                'artifact-integrity',
                'privacy',
                'non-interference',
                'offline'
            )
            ProjectUri = 'https://github.com/mk-bluebird/Augmented-Hub'
            LicenseUri = 'https://opensource.org/licenses/MIT'
            RequireLicenseAcceptance = $false
        }
    }
}
