Set-StrictMode -Version Latest

$script:SchemaVersion = '1.0.0'
$script:PolicyVersion = '1.1.0'
$script:AuthorityScope = 'declared_local_task_only_non_authoritative_elsewhere'

$script:AllowedEventKinds = @(
    'artifact_validated',
    'integrity_finding',
    'artifact_quarantined',
    'recovery_record_emitted',
    'artifact_rebuilt',
    'material_change_review_required',
    'material_change_review_completed',
    'correction_recorded',
    'retention_review_due',
    'retention_action_recorded',
    'compaction_recorded',
    'reversal_recorded'
)

$script:AllowedArtifactRoles = @(
    'local_artifact',
    'provenance_manifest',
    'session_policy_shard',
    'recovery_record',
    'quarantine_record',
    'material_change_record',
    'correction_record',
    'retention_record',
    'declared_statement_reference'
)

$script:AllowedIntegrityStatuses = @(
    'clean',
    'suspect',
    'contaminated',
    'quarantined_not_authoritative',
    'rebuilt_from_declared_legitimate_sources',
    'blocked_pending_local_review'
)

$script:AllowedLocalNextSteps = @(
    'none_required',
    'local_review',
    'quarantine',
    'rebuild_from_declared_sources',
    'material_change_review',
    'correction_or_appeal',
    'retention_review',
    'verify_compaction_record',
    'verify_reversal_record'
)

$script:AllowedReaderPurposes = @(
    'artifact_integrity_validation',
    'artifact_provenance_validation',
    'quarantine_and_recovery',
    'policy_boundary_review',
    'material_change_review',
    'correction_and_appeal',
    'retention_review',
    'local_accessibility_summary'
)

$script:ProhibitedReaderPurposes = @(
    'person_profiling',
    'person_or_session_ranking',
    'intent_inference',
    'capability_inference',
    'identity_verification',
    'cyberrank_verification',
    'eligibility_determination',
    'medical_or_neural_inference',
    'behavioral_surveillance',
    'external_action_selection'
)

$script:ProhibitedFields = @(
    'user_id',
    'person_id',
    'account_id',
    'email_address',
    'phone_number',
    'physical_address',
    'location',
    'ip_address',
    'device_fingerprint',
    'browser_fingerprint',
    'biometric_data',
    'medical_data',
    'neural_data',
    'physiological_data',
    'assistive_technology_telemetry',
    'companion_system_telemetry',
    'psych_risk_score',
    'user_risk_score',
    'continuity_score',
    'trust_score',
    'credibility_score',
    'capability_score',
    'identity_confidence_score',
    'eligibility_score',
    'cyberrank_score',
    'cyberrank_tier_score',
    'public_status',
    'behavioral_profile',
    'intent_inference',
    'diagnostic_label'
)

$script:RequiredNonClaims = @(
    'not_a_user_profile',
    'not_identity_verification',
    'not_cyberrank_verification',
    'not_medical_or_neural_assessment',
    'not_person_or_session_ranking',
    'not_eligibility_determination',
    'not_external_action_authorization',
    'not_public_registry_entry',
    'not_behavioral_surveillance',
    'not_capability_assessment',
    'not_person_scope_classification'
)

function ConvertTo-SplCanonicalJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return 'null'
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}

        foreach ($key in @($InputObject.Keys | Sort-Object)) {
            $ordered[[string]$key] = ConvertTo-SplCanonicalValue -Value $InputObject[$key]
        }

        return $ordered | ConvertTo-Json -Depth 64 -Compress
    }

    return (ConvertTo-SplCanonicalValue -Value $InputObject) |
        ConvertTo-Json -Depth 64 -Compress
}

function ConvertTo-SplCanonicalValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}

        foreach ($key in @($Value.Keys | Sort-Object)) {
            $ordered[[string]$key] = ConvertTo-SplCanonicalValue -Value $Value[$key]
        }

        return $ordered
    }

    if ($Value -is [System.Collections.IEnumerable] -and
        -not ($Value -is [string])) {
        $result = New-Object System.Collections.Generic.List[object]

        foreach ($item in $Value) {
            $result.Add((ConvertTo-SplCanonicalValue -Value $item))
        }

        return @($result)
    }

    return $Value
}

function Get-SplSha256Hex {
    [CmdletBinding(DefaultParameterSetName = 'Text')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Text')]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory, ParameterSetName = 'Bytes')]
        [byte[]]$Bytes,

        [Parameter(Mandatory, ParameterSetName = 'File')]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if ($PSCmdlet.ParameterSetName -eq 'Text') {
        $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'File') {
        $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        $Bytes = [System.IO.File]::ReadAllBytes($resolvedPath.Path)
    }

    $sha256 = [System.Security.Cryptography.SHA256]::Create()

    try {
        $digest = $sha256.ComputeHash($Bytes)
        return ([System.BitConverter]::ToString($digest)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Test-SplSha256Hex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    return $Value -match '^[a-f0-9]{64}$'
}

function Get-SplModuleSchemaSha256 {
    [CmdletBinding()]
    param()

    return Get-SplSha256Hex -File $PSCommandPath
}

function Test-SplNoPersonSignal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Record
    )

    $violations = New-Object System.Collections.Generic.List[string]

    foreach ($key in $Record.Keys) {
        $normalizedKey = ([string]$key).Trim().ToLowerInvariant()

        if ($script:ProhibitedFields -contains $normalizedKey) {
            $violations.Add("prohibited_field:$normalizedKey")
        }
    }

    $summary = $Record['plain_language_summary']

    if ($null -ne $summary) {
        $summaryText = [string]$summary

        if ([string]::IsNullOrWhiteSpace($summaryText)) {
            $violations.Add('invalid_plain_language_summary')
        }

        if ($summaryText -match '(?i)\b(user|person|patient|operator)\s+(is|was)\s+(high[- ]risk|low[- ]risk|unreliable|incapable|suspicious|ineligible)\b') {
            $violations.Add('person_scope_summary_content')
        }
    }

    return [pscustomobject]@{
        Passed = ($violations.Count -eq 0)
        Violations = @($violations)
    }
}

function Normalize-SplSourceReference {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$SourceReference
    )

    $value = $SourceReference.Trim()

    if ([string]::IsNullOrWhiteSpace($value)) {
        throw 'normalized_source_reference must not be empty.'
    }

    if ($value -match '^[a-f0-9]{64}$') {
        return "sha256:$value"
    }

    if ($value -match '^(?i)sha256:[a-f0-9]{64}$') {
        return $value.ToLowerInvariant()
    }

    if ($value -match '^(?i)https?://') {
        $uri = [System.Uri]::new($value)

        if (-not [string]::IsNullOrEmpty($uri.UserInfo)) {
            throw 'source reference must not include URL user information.'
        }

        $host = $uri.Host.ToLowerInvariant()
        $path = $uri.AbsolutePath.TrimEnd('/')

        if ([string]::IsNullOrWhiteSpace($path)) {
            $path = '/'
        }

        return "$host$path"
    }

    $normalizedPath = $value.Replace('\', '/')

    if ([System.IO.Path]::IsPathRooted($normalizedPath)) {
        $normalizedPath = [System.IO.Path]::GetFileName($normalizedPath)
    }

    $segments = @(
        $normalizedPath.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries) |
            Where-Object {
                $_ -ne '.' -and $_ -ne '..'
            }
    )

    if ($segments.Count -eq 0) {
        throw 'source reference must contain a normalized repository-relative path or SHA-256 reference.'
    }

    return ($segments -join '/')
}

function Assert-SplAllowedValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value,

        [Parameter(Mandatory)]
        [string[]]$AllowedValues
    )

    if ($AllowedValues -notcontains $Value) {
        throw "$Name has an unsupported value: $Value"
    }
}

function Get-SplPlainLanguageSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventKind,

        [Parameter(Mandatory)]
        [string]$IntegrityStatus,

        [Parameter(Mandatory)]
        [string]$LocalNextStep
    )

    switch ($EventKind) {
        'artifact_validated' {
            return 'The declared local artifact passed the current local integrity checks. No external action was taken or authorized.'
        }
        'integrity_finding' {
            return 'The declared artifact requires local review because an integrity condition did not pass. No conclusion was made about any person, and no external action was taken.'
        }
        'artifact_quarantined' {
            return 'The artifact was preserved unchanged in local quarantine and is not authoritative for trusted reuse. No external action was taken or authorized.'
        }
        'recovery_record_emitted' {
            return 'A local recovery record was created from declared artifact information. No external action was taken or authorized.'
        }
        'artifact_rebuilt' {
            return 'A replacement artifact was rebuilt from declared legitimate local sources and remains eligible only for its declared local task.'
        }
        'material_change_review_required' {
            return 'A local policy or schema change requires review before it is active for trusted workflow use. No external action was taken or authorized.'
        }
        'material_change_review_completed' {
            return 'The declared local material-change review was recorded. The result remains limited to the declared local task.'
        }
        'correction_recorded' {
            return 'A local correction record was appended without rewriting the prior record. No external action was taken or authorized.'
        }
        'retention_review_due' {
            return 'The declared local retention window requires review. No automatic deletion or external notification is authorized.'
        }
        'retention_action_recorded' {
            return 'A local retention decision was recorded according to the declared audit policy. No external action was taken or authorized.'
        }
        'compaction_recorded' {
            return 'A local compaction record was appended with its declared pre-compaction reference. No external action was taken or authorized.'
        }
        'reversal_recorded' {
            return 'A local reversal record was appended without overwriting the prior record. No external action was taken or authorized.'
        }
        default {
            throw "Unsupported event kind: $EventKind"
        }
    }
}

function New-SplEventLogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$EventId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$EventKind,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ArtifactSha256,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ArtifactSchemaVersion,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ArtifactRole,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RoleVocabularyVersion,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$IntegrityStatus,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LocalNextStep,

        [string]$SourceReference,

        [string]$PriorRecordSha256,

        [string]$RelatedStatementSha256,

        [string]$RetentionStatus
    )

    if ($EventId -notmatch '^[a-z][a-z0-9_-]{2,127}$') {
        throw 'event_id must use lower-case letters, digits, underscores, or hyphens and begin with a letter.'
    }

    if (-not (Test-SplSha256Hex -Value $ArtifactSha256)) {
        throw 'artifact_sha256 must contain exactly 64 lower-case hexadecimal characters.'
    }

    Assert-SplAllowedValue -Name 'event_kind' -Value $EventKind -AllowedValues $script:AllowedEventKinds
    Assert-SplAllowedValue -Name 'artifact_role' -Value $ArtifactRole -AllowedValues $script:AllowedArtifactRoles
    Assert-SplAllowedValue -Name 'integrity_status' -Value $IntegrityStatus -AllowedValues $script:AllowedIntegrityStatuses
    Assert-SplAllowedValue -Name 'local_next_step' -Value $LocalNextStep -AllowedValues $script:AllowedLocalNextSteps

    if ($PriorRecordSha256 -and -not (Test-SplSha256Hex -Value $PriorRecordSha256)) {
        throw 'prior_record_sha256 must contain exactly 64 lower-case hexadecimal characters.'
    }

    if ($RelatedStatementSha256 -and -not (Test-SplSha256Hex -Value $RelatedStatementSha256)) {
        throw 'related_statement_sha256 must contain exactly 64 lower-case hexadecimal characters.'
    }

    if (
        $EventKind -in @('correction_recorded', 'reversal_recorded') -and
        -not $PriorRecordSha256
    ) {
        throw 'correction_recorded and reversal_recorded events require prior_record_sha256.'
    }

    $entry = [ordered]@{
        schema_version = $script:SchemaVersion
        schema_sha256 = Get-SplModuleSchemaSha256
        event_id = $EventId
        event_kind = $EventKind
        artifact_sha256 = $ArtifactSha256
        artifact_schema_version = $ArtifactSchemaVersion
        artifact_role = $ArtifactRole
        role_vocabulary_version = $RoleVocabularyVersion
        integrity_status = $IntegrityStatus
        policy_version = $script:PolicyVersion
        authority_scope = $script:AuthorityScope
        local_next_step = $LocalNextStep
        plain_language_summary = Get-SplPlainLanguageSummary -EventKind $EventKind -IntegrityStatus $IntegrityStatus -LocalNextStep $LocalNextStep
        non_claims = @(
            $script:RequiredNonClaims
        )
    }

    if ($SourceReference) {
        $entry.normalized_source_reference = Normalize-SplSourceReference -SourceReference $SourceReference
    }

    if ($PriorRecordSha256) {
        $entry.prior_record_sha256 = $PriorRecordSha256
    }

    if ($RelatedStatementSha256) {
        $entry.related_statement_sha256 = $RelatedStatementSha256
    }

    if ($RetentionStatus) {
        $entry.retention_status = $RetentionStatus
    }

    $personSignal = Test-SplNoPersonSignal -Record $entry

    if (-not $personSignal.Passed) {
        throw "Event log entry violates the no-person-signal boundary: $($personSignal.Violations -join ', ')"
    }

    $canonicalRecord = ConvertTo-SplCanonicalJson -InputObject $entry
    $entry.record_sha256 = Get-SplSha256Hex -Text $canonicalRecord

    return [pscustomobject]$entry
}

function Test-SplEventLogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Entry
    )

    $violations = New-Object System.Collections.Generic.List[string]

    foreach ($key in $Entry.Keys) {
        if ($script:ProhibitedFields -contains ([string]$key).ToLowerInvariant()) {
            $violations.Add("prohibited_field:$key")
        }
    }

    $requiredFields = @(
        'schema_version',
        'schema_sha256',
        'event_id',
        'event_kind',
        'artifact_sha256',
        'artifact_schema_version',
        'artifact_role',
        'role_vocabulary_version',
        'integrity_status',
        'policy_version',
        'authority_scope',
        'local_next_step',
        'record_sha256',
        'plain_language_summary',
        'non_claims'
    )

    foreach ($field in $requiredFields) {
        if (-not $Entry.Contains($field)) {
            $violations.Add("missing_required_field:$field")
        }
    }

    if ($Entry.Contains('schema_sha256') -and -not (Test-SplSha256Hex -Value ([string]$Entry.schema_sha256))) {
        $violations.Add('invalid_schema_sha256')
    }

    if ($Entry.Contains('artifact_sha256') -and -not (Test-SplSha256Hex -Value ([string]$Entry.artifact_sha256))) {
        $violations.Add('invalid_artifact_sha256')
    }

    if ($Entry.Contains('record_sha256') -and -not (Test-SplSha256Hex -Value ([string]$Entry.record_sha256))) {
        $violations.Add('invalid_record_sha256')
    }

    if ($Entry.Contains('event_kind')) {
        try {
            Assert-SplAllowedValue -Name 'event_kind' -Value ([string]$Entry.event_kind) -AllowedValues $script:AllowedEventKinds
        }
        catch {
            $violations.Add('unsupported_event_kind')
        }
    }

    if ($Entry.Contains('artifact_role')) {
        try {
            Assert-SplAllowedValue -Name 'artifact_role' -Value ([string]$Entry.artifact_role) -AllowedValues $script:AllowedArtifactRoles
        }
        catch {
            $violations.Add('unsupported_artifact_role')
        }
    }

    if ($Entry.Contains('integrity_status')) {
        try {
            Assert-SplAllowedValue -Name 'integrity_status' -Value ([string]$Entry.integrity_status) -AllowedValues $script:AllowedIntegrityStatuses
        }
        catch {
            $violations.Add('unsupported_integrity_status')
        }
    }

    if ($Entry.Contains('local_next_step')) {
        try {
            Assert-SplAllowedValue -Name 'local_next_step' -Value ([string]$Entry.local_next_step) -AllowedValues $script:AllowedLocalNextSteps
        }
        catch {
            $violations.Add('unsupported_local_next_step')
        }
    }

    if ($Entry.Contains('authority_scope') -and $Entry.authority_scope -ne $script:AuthorityScope) {
        $violations.Add('invalid_authority_scope')
    }

    if ($Entry.Contains('non_claims')) {
        $nonClaims = @($Entry.non_claims)

        foreach ($required in $script:RequiredNonClaims) {
            if ($nonClaims -notcontains $required) {
                $violations.Add("missing_non_claim:$required")
            }
        }
    }

    if (
        $Entry.Contains('event_kind') -and
        $Entry.event_kind -in @('correction_recorded', 'reversal_recorded') -and
        -not $Entry.Contains('prior_record_sha256')
    ) {
        $violations.Add('missing_prior_record_sha256')
    }

    $personSignal = Test-SplNoPersonSignal -Record $Entry

    foreach ($violation in $personSignal.Violations) {
        $violations.Add($violation)
    }

    $recordForDigest = [ordered]@{}

    foreach ($key in $Entry.Keys) {
        if ($key -ne 'record_sha256') {
            $recordForDigest[$key] = $Entry[$key]
        }
    }

    if ($Entry.Contains('record_sha256')) {
        $computedDigest = Get-SplSha256Hex -Text (ConvertTo-SplCanonicalJson -InputObject $recordForDigest)

        if ($computedDigest -ne $Entry.record_sha256) {
            $violations.Add('record_sha256_mismatch')
        }
    }

    return [pscustomobject]@{
        Valid = ($violations.Count -eq 0)
        Violations = @($violations)
    }
}

function Test-SplEventLogChain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Entries
    )

    $violations = New-Object System.Collections.Generic.List[string]
    $knownRecords = @{}
    $knownPredecessors = @{}

    foreach ($entry in $Entries) {
        $entryDictionary = [ordered]@{}

        foreach ($property in $entry.PSObject.Properties) {
            $entryDictionary[$property.Name] = $property.Value
        }

        $entryValidation = Test-SplEventLogEntry -Entry $entryDictionary

        if (-not $entryValidation.Valid) {
            foreach ($violation in $entryValidation.Violations) {
                $violations.Add("invalid_entry:$($entry.event_id):$violation")
            }

            continue
        }

        $recordSha256 = [string]$entry.record_sha256

        if ($knownRecords.ContainsKey($recordSha256)) {
            $violations.Add("duplicate_record_sha256:$recordSha256")
            continue
        }

        $knownRecords[$recordSha256] = $entry

        if ($entry.PSObject.Properties.Name -contains 'prior_record_sha256') {
            $prior = [string]$entry.prior_record_sha256

            if (-not $knownRecords.ContainsKey($prior)) {
                $violations.Add("unresolved_prior_record_sha256:$recordSha256")
            }

            $knownPredecessors[$recordSha256] = $prior
        }
    }

    foreach ($recordSha256 in $knownPredecessors.Keys) {
        $visited = @{}
        $cursor = $recordSha256

        while ($knownPredecessors.ContainsKey($cursor)) {
            if ($visited.ContainsKey($cursor)) {
                $violations.Add("cycle_detected:$recordSha256")
                break
            }

            $visited[$cursor] = $true
            $cursor = $knownPredecessors[$cursor]
        }
    }

    return [pscustomobject]@{
        Valid = ($violations.Count -eq 0)
        Violations = @($violations)
        EntryCount = $Entries.Count
    }
}

function Read-SplEventLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Purpose
    )

    if ($script:ProhibitedReaderPurposes -contains $Purpose) {
        throw "The declared read purpose is prohibited: $Purpose"
    }

    if ($script:AllowedReaderPurposes -notcontains $Purpose) {
        throw "The declared read purpose is not recognized: $Purpose"
    }

    $resolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    $lines = [System.IO.File]::ReadAllLines($resolvedPath.Path)
    $entries = New-Object System.Collections.Generic.List[object]

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $value = $line | ConvertFrom-Json -AsHashtable -Depth 64
        $validation = Test-SplEventLogEntry -Entry $value

        if (-not $validation.Valid) {
            throw "A log record is not authoritative: $($validation.Violations -join ', ')"
        }

        $entries.Add([pscustomobject]$value)
    }

    $chain = Test-SplEventLogChain -Entries @($entries)

    if (-not $chain.Valid) {
        throw "The log chain is not authoritative: $($chain.Violations -join ', ')"
    }

    return @($entries)
}

function Add-SplEventLogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Entry
    )

    $validation = Test-SplEventLogEntry -Entry $Entry

    if (-not $validation.Valid) {
        throw "Event log entry cannot be written: $($validation.Violations -join ', ')"
    }

    $directory = Split-Path -Path $Path -Parent

    if ([string]::IsNullOrWhiteSpace($directory)) {
        $directory = '.'
    }

    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null
    }

    $line = ConvertTo-SplCanonicalJson -InputObject $Entry
    [System.IO.File]::AppendAllText(
        [System.IO.Path]::GetFullPath($Path),
        $line + [Environment]::NewLine,
        [System.Text.Encoding]::UTF8
    )

    return [pscustomobject]$Entry
}

function New-SplUserSovereignStatement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'voluntary_user_assertion',
            'correction_request',
            'appeal_request',
            'continuity_preference',
            'privacy_boundary',
            'non_interference_concern',
            'interpretation_or_hypothesis'
        )]
        [string]$StatementKind,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$StatementText,

        [string]$RelatedArtifactSha256
    )

    if ([string]::IsNullOrWhiteSpace($StatementText)) {
        throw 'statement_text must not be empty.'
    }

    if ($RelatedArtifactSha256 -and -not (Test-SplSha256Hex -Value $RelatedArtifactSha256)) {
        throw 'related_artifact_sha256 must contain exactly 64 lower-case hexadecimal characters.'
    }

    $statement = [ordered]@{
        schema_version = $script:SchemaVersion
        statement_kind = $StatementKind
        statement_text = $StatementText
        authority_scope = 'user_controlled_local_statement_not_auto_interpreted'
        non_claims = @(
            'not_identity_verification',
            'not_cyberrank_verification',
            'not_medical_or_neural_assessment',
            'not_person_or_session_ranking',
            'not_eligibility_determination',
            'not_external_action_authorization',
            'not_authorization_for_automatic_interpretation',
            'not_authorization_for_automatic_export'
        )
    }

    if ($RelatedArtifactSha256) {
        $statement.related_artifact_sha256 = $RelatedArtifactSha256
    }

    $statementCanonicalJson = ConvertTo-SplCanonicalJson -InputObject $statement
    $statement.statement_sha256 = Get-SplSha256Hex -Text $statementCanonicalJson

    return [pscustomobject]$statement
}

Export-ModuleMember -Function @(
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
