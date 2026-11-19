-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only.
-- No identity, consent, legal authority, or execution authorization.
--
-- Metadata validation for preventive legal research.
-- No chemical data, operational modeling, network, file, or device actions.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"

local FIELDS = {
    source_class = true,
    source_reference = true,
    source_version = true,
    conclusion = true,
    review_status = true
}

local SOURCE_CLASSES = {
    treaty = true,
    institutional_decision = true,
    national_law = true,
    official_guidance = true,
    research_proposal = true
}

local CONCLUSIONS = {
    prohibition_established = true,
    interpretation_unresolved = true,
    implementation_deficiency_reported = true,
    applicability_unresolved = true,
    policy_proposal = true
}

local REVIEW = {
    not_reviewed = true,
    qualified_review_pending = true,
    reviewed_within_scope = true,
    disputed = true
}

local function text(value)
    return type(value) == "string"
        and #value > 0
        and #value <= 256
        and value:match("%S") ~= nil
        and value:find("[%z\1-\31\127]") == nil
end

local function invalid(reason)
    return {
        status = "validation_error",
        implementation_version = VERSION,
        reason = reason
    }
end

function M.validate(record)
    if type(record) ~= "table" or getmetatable(record) ~= nil then
        return invalid("plain_record_required")
    end

    local count = 0
    for key in next, record do
        count = count + 1
        if count > 5 or not FIELDS[key] then
            return invalid("unknown_field")
        end
    end

    for field in pairs(FIELDS) do
        if not text(record[field]) then
            return invalid("required_metadata_missing_or_invalid")
        end
    end

    if not SOURCE_CLASSES[record.source_class] then
        return invalid("unknown_source_class")
    end
    if not CONCLUSIONS[record.conclusion] then
        return invalid("unknown_conclusion")
    end
    if not REVIEW[record.review_status] then
        return invalid("unknown_review_status")
    end

    if record.source_class == "research_proposal"
        and record.conclusion == "prohibition_established" then
        return invalid("proposal_cannot_alone_establish_legal_prohibition")
    end

    return {
        status = "metadata_valid",
        implementation_version = VERSION,
        conclusion = record.conclusion,
        review_status = record.review_status
    }
end

function M.self_test()
    local record = {
        source_class = "institutional_decision",
        source_reference = "synthetic_official_decision_reference",
        source_version = "synthetic_version",
        conclusion = "interpretation_unresolved",
        review_status = "qualified_review_pending"
    }

    assert(M.validate(record).status == "metadata_valid")

    record.source_class = "research_proposal"
    record.conclusion = "prohibition_established"
    assert(M.validate(record).reason
        == "proposal_cannot_alone_establish_legal_prohibition")

    record.conclusion = "policy_proposal"
    record.unnecessary_payload = "not accepted"
    assert(M.validate(record).reason == "unknown_field")

    return {
        status = "self_checks_passed",
        scope = "preventive_research_metadata_only"
    }
end

return M
