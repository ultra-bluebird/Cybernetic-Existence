-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only.
-- No identity, consent, legal authority, or execution authorization.
--
-- Documentation-completeness checker for preventive legal review.
-- No chemical specifications or operational functionality.
-- No network, file, device, persistence, or cryptographic actions.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"

local REQUIRED = {
    "question_reference",
    "normative_source_bundle",
    "source_binding_review",
    "jurisdiction_scope",
    "applicability_analysis",
    "national_implementation_analysis",
    "contrary_positions_analysis",
    "reviewer_qualification_record",
    "conflict_of_interest_record",
    "independence_record",
    "rights_and_remedy_analysis",
    "reasoned_conclusion"
}

local STATES = {
    present = true,
    unresolved = true,
    missing = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function text(value)
    return type(value) == "string"
        and #value > 0 and #value <= 256
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

function M.inspect(record)
    if not plain(record) then
        return invalid("plain_record_required")
    end

    local allowed = {}
    for i = 1, #REQUIRED do allowed[REQUIRED[i]] = true end

    local count = 0
    for key in next, record do
        count = count + 1
        if count > #REQUIRED or not allowed[key] then
            return invalid("unknown_documentation_category")
        end
    end

    local present, unresolved, missing = {}, {}, {}

    for i = 1, #REQUIRED do
        local name = REQUIRED[i]
        local item = record[name]

        if item == nil then
            missing[name] = "not_supplied"
        else
            if not plain(item) then
                return invalid("invalid_documentation_entry")
            end

            for key in next, item do
                if key ~= "state" and key ~= "reference" then
                    return invalid("unknown_entry_field")
                end
            end

            if type(item.state) ~= "string"
                or not STATES[item.state]
                or not text(item.reference) then
                return invalid("invalid_entry_state_or_reference")
            end

            if item.state == "present" then
                present[name] = item.reference
            elseif item.state == "unresolved" then
                unresolved[name] = item.reference
            else
                missing[name] = item.reference
            end
        end
    end

    local status
    if next(missing) then
        status = "documentation_incomplete"
    elseif next(unresolved) then
        status = "documentation_review_pending"
    else
        status = "documentation_reported_present"
    end

    return {
        status = status,
        implementation_version = VERSION,
        findings = {
            present = present,
            unresolved = unresolved,
            missing = missing
        },
        scope = "supplied_documentation_inventory"
    }
end

function M.self_test()
    local record = {}
    for i = 1, #REQUIRED do
        record[REQUIRED[i]] = {
            state = "present",
            reference = "synthetic_document_reference"
        }
    end

    assert(M.inspect(record).status == "documentation_reported_present")

    record.source_binding_review.state = "unresolved"
    assert(M.inspect(record).status == "documentation_review_pending")

    record.contrary_positions_analysis = nil
    local incomplete = M.inspect(record)
    assert(incomplete.status == "documentation_incomplete")
    assert(incomplete.findings.unresolved.source_binding_review ~= nil)
    assert(incomplete.findings.missing.contrary_positions_analysis ~= nil)

    record.extra_payload = "not accepted"
    assert(M.inspect(record).reason == "unknown_documentation_category")

    return {
        status = "self_checks_passed",
        scope = "synthetic_documentation_inventory_cases"
    }
end

return M
