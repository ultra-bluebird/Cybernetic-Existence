-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only.
-- No identity verification, consent, or execution authority.
--
-- Bounded inspection-record checker, not a legal or institutional verifier.
-- No network, file, device, persistence, or cryptographic operations.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"

local CRITERIA = {
    "authority",
    "source_fidelity",
    "scope_and_applicability",
    "evidence_quality",
    "reasoning_and_alternatives",
    "conflict_and_uncertainty",
    "equal_standing",
    "accessibility_and_participation",
    "privacy_and_authorization",
    "necessity_of_restrictions",
    "continuity_and_remedy",
    "accountability_and_change_control"
}

local STATES = {
    compliant = true,
    noncompliant = true,
    unresolved = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function text(value)
    return type(value) == "string"
        and #value > 0
        and #value <= 256
        and value:match("%S") ~= nil
        and value:find("[%z\1-\31\127]") == nil
end

local function exact(record, allowed)
    if not plain(record) then return false end

    for key in next, record do
        if not allowed[key] then return false end
    end

    for key in next, allowed do
        if rawget(record, key) == nil then return false end
    end

    return true
end

local function invalid(reason)
    return {
        disposition = "validation_error",
        implementation_version = VERSION,
        reason = reason
    }
end

function M.inspect(record)
    if not exact(record, {
        standard_version = true,
        interpretation_version = true,
        scope = true,
        reviewer_role = true,
        review_reference = true,
        findings = true
    }) then
        return invalid("invalid_record_shape")
    end

    if record.standard_version ~= VERSION then
        return invalid("standard_version_mismatch")
    end

    for _, field in ipairs({
        "interpretation_version",
        "scope",
        "reviewer_role",
        "review_reference"
    }) do
        if not text(record[field]) then
            return invalid("invalid_review_metadata")
        end
    end

    local allowed = {}
    for i = 1, #CRITERIA do
        allowed[CRITERIA[i]] = true
    end

    if not exact(record.findings, allowed) then
        return invalid("required_findings_missing_or_unknown")
    end

    local noncompliant, unresolved, compliant = {}, {}, {}

    for i = 1, #CRITERIA do
        local name = CRITERIA[i]
        local finding = record.findings[name]

        if not exact(finding, {
            state = true,
            basis_reference = true
        }) then
            return invalid("invalid_finding_shape")
        end

        if type(finding.state) ~= "string"
            or not STATES[finding.state]
            or not text(finding.basis_reference) then
            return invalid("invalid_finding")
        end

        if finding.state == "noncompliant" then
            noncompliant[name] = finding.basis_reference
        elseif finding.state == "unresolved" then
            unresolved[name] = finding.basis_reference
        else
            compliant[name] = finding.basis_reference
        end
    end

    local disposition
    if next(noncompliant) ~= nil then
        disposition = "reported_nonconformity"
    elseif next(unresolved) ~= nil then
        disposition = "supported_review_required"
    else
        disposition = "documented_criteria_met"
    end

    return {
        disposition = disposition,
        implementation_version = VERSION,
        interpretation_version = record.interpretation_version,
        scope = record.scope,
        review_reference = record.review_reference,
        findings = {
            compliant = compliant,
            noncompliant = noncompliant,
            unresolved = unresolved
        },
        assessment_type = "supplied_inspection_record"
    }
end

function M.self_test()
    local function fixture()
        local findings = {}
        for i = 1, #CRITERIA do
            findings[CRITERIA[i]] = {
                state = "compliant",
                basis_reference = "synthetic_review_basis"
            }
        end

        return {
            standard_version = VERSION,
            interpretation_version = "synthetic-interpretation",
            scope = "synthetic-operation-review",
            reviewer_role = "synthetic-reviewer",
            review_reference = "synthetic-review-record",
            findings = findings
        }
    end

    local complete = fixture()
    assert(M.inspect(complete).disposition == "documented_criteria_met")

    local pending = fixture()
    pending.findings.authority.state = "unresolved"
    assert(M.inspect(pending).disposition == "supported_review_required")

    local mixed = fixture()
    mixed.findings.equal_standing.state = "noncompliant"
    mixed.findings.source_fidelity.state = "unresolved"

    local result = M.inspect(mixed)
    assert(result.disposition == "reported_nonconformity")
    assert(result.findings.noncompliant.equal_standing ~= nil)
    assert(result.findings.unresolved.source_fidelity ~= nil)

    local missing = fixture()
    missing.findings.accessibility_and_participation = nil
    assert(M.inspect(missing).disposition == "validation_error")

    local malformed = fixture()
    malformed.findings.authority.state = "probably_fine"
    assert(M.inspect(malformed).disposition == "validation_error")

    local unsupported_version = fixture()
    unsupported_version.standard_version = "other"
    assert(M.inspect(unsupported_version).reason
        == "standard_version_mismatch")

    return {
        status = "self_checks_passed",
        scope = "synthetic_record_validation_and_finding_preservation"
    }
end

return M
