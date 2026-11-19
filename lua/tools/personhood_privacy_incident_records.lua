-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/personhood_privacy_incident_records.lua
-- Destination: lua/tools/

local Records = {}

local PRIMARY_AUTHOR_ADDRESS =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local VALID_SEVERITIES = {
    low = true,
    medium = true,
    high = true,
}

local function require_table(value, name)
    assert(type(value) == "table", name .. " must be a table")
end

local function require_string(value, name)
    assert(type(value) == "string" and value ~= "", name .. " must be a non-empty string")
end

local function require_field(input, field, context)
    assert(input[field] ~= nil, context .. "." .. field .. " is required")
    return input[field]
end

local function is_iso_8601_utc(value)
    return type(value) == "string"
        and value:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.%d%d%dZ$") ~= nil
end

local function nonempty_string_array(value, name)
    require_table(value, name)
    assert(#value > 0, name .. " must contain at least one entry")

    local result = {}

    for index, item in ipairs(value) do
        require_string(item, name .. "[" .. index .. "]")
        result[index] = item
    end

    return result
end

local function copy_string_array(value)
    local result = {}

    for index, item in ipairs(value) do
        result[index] = item
    end

    return result
end

local function copy_table(value)
    local result = {}

    for key, item in pairs(value) do
        result[key] = item
    end

    return result
end

local function validate_disclosure_register(entries)
    require_table(entries, "privacy_data_map.disclosure_register")

    local validated_entries = {}

    for index, entry in ipairs(entries) do
        require_table(entry, "privacy_data_map.disclosure_register[" .. index .. "]")

        local disclosed_at = require_field(
            entry,
            "disclosed_at",
            "privacy_data_map.disclosure_register[" .. index .. "]"
        )
        local recipient = require_field(
            entry,
            "recipient",
            "privacy_data_map.disclosure_register[" .. index .. "]"
        )
        local purpose = require_field(
            entry,
            "purpose",
            "privacy_data_map.disclosure_register[" .. index .. "]"
        )
        local data_categories = require_field(
            entry,
            "data_categories",
            "privacy_data_map.disclosure_register[" .. index .. "]"
        )

        assert(
            is_iso_8601_utc(disclosed_at),
            "privacy_data_map.disclosure_register[" .. index
                .. "].disclosed_at must be ISO 8601 UTC with milliseconds"
        )
        require_string(
            recipient,
            "privacy_data_map.disclosure_register[" .. index .. "].recipient"
        )
        require_string(
            purpose,
            "privacy_data_map.disclosure_register[" .. index .. "].purpose"
        )

        validated_entries[index] = {
            disclosed_at = disclosed_at,
            recipient = recipient,
            purpose = purpose,
            data_categories = nonempty_string_array(
                data_categories,
                "privacy_data_map.disclosure_register[" .. index
                    .. "].data_categories"
            ),
        }
    end

    return validated_entries
end

--- SC-046: Validates a self-authored expression record. It records the author
--- declaration but does not verify signature ownership, establish legal identity,
--- create an entitlement, or grant authority over another person or system.
---@param record table
---@return table
function Records.personhood_expression_record(record)
    require_table(record, "personhood_expression_record")

    local statement = require_field(record, "statement", "personhood_expression_record")
    local author = require_field(record, "author", "personhood_expression_record")
    local dated = require_field(record, "dated", "personhood_expression_record")
    local signed_by = require_field(record, "signed_by", "personhood_expression_record")
    local status = require_field(record, "status", "personhood_expression_record")

    require_string(statement, "personhood_expression_record.statement")
    require_string(author, "personhood_expression_record.author")
    assert(
        is_iso_8601_utc(dated),
        "personhood_expression_record.dated must be ISO 8601 UTC with milliseconds"
    )
    require_string(signed_by, "personhood_expression_record.signed_by")
    assert(
        status == "self-asserted",
        "personhood_expression_record.status must be self-asserted"
    )

    return {
        object_id = "sc-046",
        name = "PersonhoodExpressionRecord",
        protection_class = "P1",
        valid = true,
        statement = statement,
        author = author,
        dated = dated,
        signed_by = signed_by,
        status = status,
        matches_declared_primary_author = author == PRIMARY_AUTHOR_ADDRESS,
        signature_verified = false,
        authority_effect = "none",
        interpretation =
            "Self-authored expression record only. It preserves a declared statement and "
            .. "authorship field without independently verifying the identity mechanism, signature, "
            .. "legal identity, personal status, or any claim about external systems.",
    }
end

--- SC-047: Validates a privacy data-map record. This function inventories the
--- caller-supplied metadata only; it does not inspect storage, enumerate accounts,
--- discover personal data, alter sharing, or transmit disclosure information.
---@param record table
---@return table
function Records.privacy_data_map(record)
    require_table(record, "privacy_data_map")

    local data_category = require_field(record, "data_category", "privacy_data_map")
    local storage_location = require_field(record, "storage_location", "privacy_data_map")
    local access_holders = require_field(record, "access_holders", "privacy_data_map")
    local retention_period = require_field(record, "retention_period", "privacy_data_map")
    local sharing_rules = require_field(record, "sharing_rules", "privacy_data_map")
    local disclosure_register = require_field(
        record,
        "disclosure_register",
        "privacy_data_map"
    )

    require_string(data_category, "privacy_data_map.data_category")
    require_string(storage_location, "privacy_data_map.storage_location")
    local validated_access_holders = nonempty_string_array(
        access_holders,
        "privacy_data_map.access_holders"
    )
    require_string(retention_period, "privacy_data_map.retention_period")
    require_table(sharing_rules, "privacy_data_map.sharing_rules")

    local validated_disclosures = validate_disclosure_register(disclosure_register)

    return {
        object_id = "sc-047",
        name = "PrivacyDataMap",
        protection_class = "P3",
        valid = true,
        data_category = data_category,
        storage_location = storage_location,
        access_holders = validated_access_holders,
        retention_period = retention_period,
        sharing_rules = copy_table(sharing_rules),
        disclosure_register = validated_disclosures,
        disclosure_count = #validated_disclosures,
        knowledge_factor = 0.70,
        eco_impact_value = 0.0,
        harm_risk = 0.10,
        authority_effect = "none",
        interpretation =
            "Privacy-inventory validation only. It does not verify that storage controls, "
            .. "retention behavior, access-holder lists, sharing policies, or disclosures match "
            .. "reality; confirm each item through independent access and audit evidence.",
    }
end

--- SC-048: Validates a traceable incident-response record for a safety or
--- consent concern. It does not communicate externally, contact any person,
--- delete data, lock accounts, change access, or execute containment steps.
---@param record table
---@return table
function Records.incident_response_plan(record)
    require_table(record, "incident_response_plan")

    local incident_id = require_field(record, "incident_id", "incident_response_plan")
    local reported_at = require_field(record, "reported_at", "incident_response_plan")
    local severity = require_field(record, "severity", "incident_response_plan")
    local containment_steps = require_field(
        record,
        "containment_steps",
        "incident_response_plan"
    )
    local recovery_steps = require_field(
        record,
        "recovery_steps",
        "incident_response_plan"
    )
    local authorized_by = require_field(
        record,
        "authorized_by",
        "incident_response_plan"
    )
    local reviewed_by = require_field(record, "reviewed_by", "incident_response_plan")

    require_string(incident_id, "incident_response_plan.incident_id")
    assert(
        is_iso_8601_utc(reported_at),
        "incident_response_plan.reported_at must be ISO 8601 UTC with milliseconds"
    )
    assert(
        VALID_SEVERITIES[severity],
        "incident_response_plan.severity must be low, medium, or high"
    )

    local validated_containment_steps = nonempty_string_array(
        containment_steps,
        "incident_response_plan.containment_steps"
    )
    local validated_recovery_steps = nonempty_string_array(
        recovery_steps,
        "incident_response_plan.recovery_steps"
    )

    require_string(authorized_by, "incident_response_plan.authorized_by")
    require_string(reviewed_by, "incident_response_plan.reviewed_by")

    local severity_risk = {
        low = 0.25,
        medium = 0.60,
        high = 0.90,
    }

    return {
        object_id = "sc-048",
        name = "IncidentResponsePlan",
        protection_class = "P6",
        valid = true,
        incident_id = incident_id,
        reported_at = reported_at,
        severity = severity,
        containment_steps = copy_string_array(validated_containment_steps),
        recovery_steps = copy_string_array(validated_recovery_steps),
        authorized_by = authorized_by,
        reviewed_by = reviewed_by,
        knowledge_factor = 0.75,
        eco_impact_value = 0.0,
        harm_risk = severity_risk[severity],
        authority_effect = "none",
        interpretation =
            "Incident-plan validation only. It records planned containment and recovery steps, "
            .. "but cannot execute them. Any external communication or state-changing response "
            .. "requires current, explicit authorization and an appropriate operational review.",
    }
end

return Records
