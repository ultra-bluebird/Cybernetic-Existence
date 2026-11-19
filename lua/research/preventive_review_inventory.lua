-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only, not identity, consent, or legal authority.
--
-- Documentation inventory only.
-- No chemical specifications, operational modeling, source retrieval,
-- network, file, device, persistence, or cryptographic operations.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"

local CATEGORIES = {
    "source_capture",
    "source_authenticity_review",
    "applicability_analysis",
    "national_implementation_analysis",
    "contrary_positions",
    "reviewer_qualifications",
    "conflict_of_interest",
    "review_independence",
    "rights_and_remedies",
    "reasoned_conclusion"
}

local RECORD_STATUS = {
    proposal = true,
    preliminary_analysis = true,
    completed_review = true,
    disputed = true
}

local PRESENCE = {
    present = true,
    unresolved = true,
    missing = true
}

local ADEQUACY = {
    adequate = true,
    inadequate = true,
    not_assessed = true
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

    for key in next, record do
        if key ~= "record_status"
            and key ~= "scope_reference"
            and key ~= "entries" then
            return invalid("unknown_record_field")
        end
    end

    if type(record.record_status) ~= "string"
        or not RECORD_STATUS[record.record_status]
        or not text(record.scope_reference)
        or not plain(record.entries) then
        return invalid("invalid_record_metadata")
    end

    local allowed = {}
    for i = 1, #CATEGORIES do allowed[CATEGORIES[i]] = true end
    for key in next, record.entries do
        if not allowed[key] then
            return invalid("unknown_documentation_category")
        end
    end

    local missing, unresolved, inadequate, unassessed = {}, {}, {}, {}

    for i = 1, #CATEGORIES do
        local name = CATEGORIES[i]
        local entry = record.entries[name]

        if entry == nil then
            missing[name] = true
            unassessed[name] = true
        else
            if not plain(entry) then
                return invalid("invalid_entry")
            end

            for key in next, entry do
                if key ~= "presence"
                    and key ~= "adequacy"
                    and key ~= "basis_reference"
                    and key ~= "review_reference" then
                    return invalid("unknown_entry_field")
                end
            end

            if not PRESENCE[entry.presence]
                or not ADEQUACY[entry.adequacy]
                or not text(entry.basis_reference) then
                return invalid("invalid_entry_metadata")
            end

            if entry.presence ~= "present"
                and entry.adequacy ~= "not_assessed" then
                return invalid("adequacy_requires_present_material")
            end

            if entry.adequacy ~= "not_assessed"
                and not text(entry.review_reference) then
                return invalid("adequacy_review_reference_required")
            end

            if entry.presence == "missing" then missing[name] = true end
            if entry.presence == "unresolved" then unresolved[name] = true end
            if entry.adequacy == "inadequate" then inadequate[name] = true end
            if entry.adequacy == "not_assessed" then unassessed[name] = true end
        end
    end

    local presence_status =
        next(missing) and "incomplete"
        or next(unresolved) and "availability_unresolved"
        or "reported_present"

    local adequacy_status =
        next(inadequate) and "reported_inadequate"
        or next(unassessed) and "assessment_incomplete"
        or "reported_adequate_within_declared_scope"

    return {
        status = "inventory_assessed",
        implementation_version = VERSION,
        record_status = record.record_status,
        scope_reference = record.scope_reference,
        presence_status = presence_status,
        adequacy_status = adequacy_status,
        findings = {
            missing = missing,
            unresolved = unresolved,
            inadequate = inadequate,
            unassessed = unassessed
        }
    }
end

function M.self_test()
    local record = {
        record_status = "preliminary_analysis",
        scope_reference = "synthetic_preventive_review_scope",
        entries = {}
    }

    for i = 1, #CATEGORIES do
        record.entries[CATEGORIES[i]] = {
            presence = "present",
            adequacy = "not_assessed",
            basis_reference = "synthetic_document_reference"
        }
    end

    local present = M.inspect(record)
    assert(present.presence_status == "reported_present")
    assert(present.adequacy_status == "assessment_incomplete")

    record.entries.source_capture.adequacy = "inadequate"
    record.entries.source_capture.review_reference =
        "synthetic_capture_review"

    local inadequate = M.inspect(record)
    assert(inadequate.adequacy_status == "reported_inadequate")

    record.entries.source_capture.presence = "missing"
    assert(M.inspect(record).reason
        == "adequacy_requires_present_material")

    return {
        status = "self_checks_passed",
        scope = "synthetic_presence_and_adequacy_inventory"
    }
end

return M
