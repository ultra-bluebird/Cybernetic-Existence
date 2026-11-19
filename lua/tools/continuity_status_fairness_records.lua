-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/continuity_status_fairness_records.lua
-- Destination: lua/tools/

local Records = {}

local VALID_ARCHIVE_CATEGORIES = {
    ["research"] = true,
    ["notes"] = true,
    ["settings"] = true,
    ["prompts"] = true,
    ["code"] = true,
    ["documents"] = true,
}

local CYBERRANK_TIER2 = {
    name = "CyberRank-tier2",
    status_type = "self-governed-project-status",
    verification = "self-asserted",
    limitation =
        "Not an external certification, legal status, medical determination, or entitlement.",
    authority = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7",
    protection_classes = {
        "P1",
        "P4",
        "P5",
    },
}

local function require_table(value, name)
    assert(type(value) == "table", name .. " must be a table")
end

local function require_string(value, name)
    assert(type(value) == "string" and value ~= "", name .. " must be a non-empty string")
end

local function require_boolean(value, name)
    assert(type(value) == "boolean", name .. " must be a boolean")
end

local function require_field(input, field, context)
    assert(input[field] ~= nil, context .. "." .. field .. " is required")
    return input[field]
end

local function is_iso_8601_utc(value)
    return type(value) == "string"
        and value:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.%d%d%dZ$") ~= nil
end

local function copy_array(source)
    local result = {}

    for index, value in ipairs(source) do
        result[index] = value
    end

    return result
end

local function copy_table(source)
    local result = {}

    for key, value in pairs(source) do
        if type(value) == "table" then
            result[key] = copy_array(value)
        else
            result[key] = value
        end
    end

    return result
end

local function is_encrypted_uri(value)
    if type(value) ~= "string" or value == "" then
        return false
    end

    return value:match("^encrypted%+") ~= nil
        or value:match("^vault://") ~= nil
        or value:match("^cyberfs%+encrypted://") ~= nil
end

local function validate_archive_categories(categories)
    require_table(categories, "content_categories")
    assert(#categories > 0, "content_categories must not be empty")

    local seen = {}
    local normalized = {}

    for index, category in ipairs(categories) do
        require_string(category, "content_categories[" .. index .. "]")
        assert(
            VALID_ARCHIVE_CATEGORIES[category],
            "unsupported archive content category: " .. category
        )
        assert(not seen[category], "duplicate archive content category: " .. category)

        seen[category] = true
        table.insert(normalized, category)
    end

    table.sort(normalized)
    return normalized
end

--- SC-043: Validates a versioned continuity-archive export record. It records
--- archive metadata only and does not read, export, decrypt, upload, alter, or
--- restore files.
---@param record table
---@return table
function Records.continuity_archive_record(record)
    require_table(record, "continuity_archive_record")

    local archive_id = require_field(record, "archive_id", "continuity_archive_record")
    local created_date = require_field(
        record,
        "created_date",
        "continuity_archive_record"
    )
    local content_categories = require_field(
        record,
        "content_categories",
        "continuity_archive_record"
    )
    local storage_location = require_field(
        record,
        "storage_location",
        "continuity_archive_record"
    )
    local restoration_tested = require_field(
        record,
        "restoration_tested",
        "continuity_archive_record"
    )

    require_string(archive_id, "continuity_archive_record.archive_id")
    assert(
        is_iso_8601_utc(created_date),
        "continuity_archive_record.created_date must be ISO 8601 UTC with milliseconds"
    )
    local validated_categories = validate_archive_categories(content_categories)
    require_string(
        storage_location,
        "continuity_archive_record.storage_location"
    )
    assert(
        is_encrypted_uri(storage_location),
        "continuity_archive_record.storage_location must use an encrypted URI scheme"
    )
    require_boolean(
        restoration_tested,
        "continuity_archive_record.restoration_tested"
    )

    return {
        object_id = "sc-043",
        name = "ContinuityArchiveRecord",
        valid = true,
        archive_id = archive_id,
        created_date = created_date,
        content_categories = validated_categories,
        storage_location = storage_location,
        restoration_tested = restoration_tested,
        knowledge_factor = restoration_tested and 0.85 or 0.45,
        eco_impact_value = 0.0,
        harm_risk = restoration_tested and 0.10 or 0.65,
        authority_effect = "none",
        interpretation =
            "Archive-metadata validation only. This record does not prove archive contents, "
            .. "encryption strength, recoverability, ownership, or integrity without separate "
            .. "export, restoration, and verification evidence.",
    }
end

--- SC-044: Returns the declared CyberRank-tier2 self-governed project-status
--- record. It is intentionally a declaration, not an independently verified
--- credential, authorization, entitlement, legal status, or medical conclusion.
---@return table
function Records.cyberrank_tier2_status()
    return {
        object_id = "sc-044",
        name = "CyberRankTier2Status",
        status = copy_table(CYBERRANK_TIER2),
        protection_classes = copy_array(CYBERRANK_TIER2.protection_classes),
        self_governed = true,
        externally_verified = false,
        authority_effect = "none",
        interpretation =
            "Self-governed project-status declaration. It documents a chosen status label "
            .. "and protection focus but does not create access rights, privileges, certification, "
            .. "legal identity, medical status, or a claim against third parties.",
    }
end

--- SC-045: Evaluates whether a supplied service record meets a stated equality
--- policy for an identity claim that has already been accepted by the caller's
--- applicable service process. It cannot establish identity, override access
--- rules, adjudicate law, or grant services.
---@param identity_exists boolean
---@param service_equal boolean
---@return table
function Records.fairness_validation_rule(identity_exists, service_equal)
    require_boolean(identity_exists, "identity_exists")
    require_boolean(service_equal, "service_equal")

    local policy_satisfied = not identity_exists or service_equal
    local review_required = identity_exists and not service_equal

    return {
        object_id = "sc-045",
        name = "FairnessValidationRule",
        identity_exists = identity_exists,
        service_equal = service_equal,
        policy_satisfied = policy_satisfied,
        review_required = review_required,
        rule =
            "For a service process that recognizes an identity claim, comparable services must be evaluated under equal, documented criteria.",
        knowledge_factor = 0.50,
        eco_impact_value = 0.0,
        harm_risk = review_required and 0.80 or 0.05,
        authority_effect = "none",
        interpretation =
            "Fairness-policy check only. It does not determine whether an identity exists, "
            .. "establish eligibility, interpret law, approve access, or replace independent "
            .. "anti-discrimination, accessibility, and service-governance review.",
    }
end

return Records
