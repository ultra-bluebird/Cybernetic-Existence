-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/consent_attribution_recovery_records.lua
-- Destination: lua/tools/

local Records = {}

local DEFAULT_CONSENT_MODE = "read-only"
local RECOVERY_TEST_CADENCE_DAYS = 90
local DAY_SECONDS = 24 * 60 * 60

local VALID_ACTION_TYPES = {
    ["read-only"] = true,
    ["analyze"] = true,
    ["summarize"] = true,
    ["draft"] = true,
    ["publish"] = true,
    ["transmit"] = true,
}

local VALID_RECOVERY_METHODS = {
    ["passkey"] = true,
    ["offline-code"] = true,
    ["recovery-contact"] = true,
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

local function parse_iso_8601_utc(value)
    assert(is_iso_8601_utc(value), "timestamp must be ISO 8601 UTC with milliseconds")

    local year, month, day, hour, minute, second = value:match(
        "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)%.%d%d%dZ$"
    )

    local timestamp = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(minute),
        sec = tonumber(second),
        isdst = false,
    })

    assert(timestamp ~= nil, "timestamp could not be parsed")
    return timestamp
end

local function copy_array(source)
    local result = {}

    for index, value in ipairs(source) do
        result[index] = value
    end

    return result
end

local function valid_scope(scope)
    if type(scope) == "string" then
        return scope ~= ""
    end

    if type(scope) ~= "table" or #scope == 0 then
        return false
    end

    for index, category in ipairs(scope) do
        if type(category) ~= "string" or category == "" then
            return false, "scope[" .. index .. "] must be a non-empty string"
        end
    end

    return true
end

local function uri_like(value)
    if type(value) ~= "string" or value == "" then
        return false
    end

    return value:match("^[%a][%w+.-]*:") ~= nil
        or value:match("^[%./][%w%-%._/~]+") ~= nil
end

--- SC-040: Validates a consent or disclosure record. The default mode is
--- read-only. This record does not execute, publish, transmit, or otherwise
--- perform an action; callers must obtain a separately verified approval before
--- attempting any external side effect.
---@param record table
---@return table
function Records.consent_boundary_register(record)
    require_table(record, "consent_register")

    local action_type = record.action_type or DEFAULT_CONSENT_MODE
    local scope = require_field(record, "scope", "consent_register")
    local granted_by = require_field(record, "granted_by", "consent_register")
    local valid_from = require_field(record, "valid_from", "consent_register")
    local valid_until = require_field(record, "valid_until", "consent_register")
    local revocable = require_field(record, "revocable", "consent_register")

    assert(
        VALID_ACTION_TYPES[action_type],
        "consent_register.action_type is unsupported"
    )
    assert(valid_scope(scope), "consent_register.scope must contain data categories")
    require_string(granted_by, "consent_register.granted_by")
    assert(
        is_iso_8601_utc(valid_from),
        "consent_register.valid_from must be ISO 8601 UTC with milliseconds"
    )
    assert(
        is_iso_8601_utc(valid_until),
        "consent_register.valid_until must be ISO 8601 UTC with milliseconds"
    )
    require_boolean(revocable, "consent_register.revocable")

    local valid_from_epoch = parse_iso_8601_utc(valid_from)
    local valid_until_epoch = parse_iso_8601_utc(valid_until)

    assert(
        valid_until_epoch > valid_from_epoch,
        "consent_register.valid_until must be later than valid_from"
    )

    return {
        object_id = "sc-040",
        name = "ConsentBoundaryRegisters",
        valid = true,
        action_type = action_type,
        scope = type(scope) == "table" and copy_array(scope) or scope,
        granted_by = granted_by,
        valid_from = valid_from,
        valid_until = valid_until,
        revocable = revocable,
        default_mode = DEFAULT_CONSENT_MODE,
        authority_effect = "none",
        interpretation =
            "Consent-record validation only. This result does not itself authorize an action. "
            .. "External actions require a fresh, explicit approval check at execution time.",
    }
end

--- SC-041: Validates a dated authorship-provenance entry. The function records
--- the declared address verbatim and does not claim that address ownership,
--- signature validity, authorship, identity, copyright, or legal rights have
--- been cryptographically or legally verified.
---@param entry table
---@return table
function Records.authorship_ledger_entry(entry)
    require_table(entry, "authorship_ledger_entry")

    local work_id = require_field(entry, "work_id", "authorship_ledger_entry")
    local author_did = require_field(entry, "author_did", "authorship_ledger_entry")
    local author_address = require_field(
        entry,
        "author_address",
        "authorship_ledger_entry"
    )
    local created_at = require_field(entry, "created_at", "authorship_ledger_entry")
    local source_location = require_field(
        entry,
        "source_location",
        "authorship_ledger_entry"
    )
    local license = require_field(entry, "license", "authorship_ledger_entry")
    local signature = require_field(entry, "signature", "authorship_ledger_entry")

    require_string(work_id, "authorship_ledger_entry.work_id")
    require_string(author_did, "authorship_ledger_entry.author_did")
    require_string(author_address, "authorship_ledger_entry.author_address")
    assert(
        is_iso_8601_utc(created_at),
        "authorship_ledger_entry.created_at must be ISO 8601 UTC with milliseconds"
    )
    assert(
        uri_like(source_location),
        "authorship_ledger_entry.source_location must be a URI or repository-relative path"
    )
    require_string(license, "authorship_ledger_entry.license")
    require_string(signature, "authorship_ledger_entry.signature")

    return {
        object_id = "sc-041",
        name = "AuthorshipLedgerEntry",
        valid = true,
        entry = {
            work_id = work_id,
            author_did = author_did,
            author_address = author_address,
            created_at = created_at,
            source_location = source_location,
            license = license,
            signature = signature,
        },
        declared_attribution = true,
        cryptographic_signature_verified = false,
        address_ownership_verified = false,
        legal_authorship_verified = false,
        authority_effect = "none",
        interpretation =
            "Structured provenance record only. Verify signatures with an approved verification "
            .. "tool and establish rights or identity through the appropriate independent process.",
    }
end

--- SC-042: Validates a recovery-access test record and calculates its cadence
--- status relative to a caller-supplied current UTC timestamp. It does not
--- access accounts, credentials, passkeys, recovery codes, contacts, or systems.
---@param record table
---@param current_time_utc string
---@return table
function Records.recovery_access_test_record(record, current_time_utc)
    require_table(record, "recovery_access_test_record")
    require_string(current_time_utc, "current_time_utc")

    local test_date = require_field(record, "test_date", "recovery_access_test_record")
    local method = require_field(record, "method", "recovery_access_test_record")
    local passed = require_field(record, "passed", "recovery_access_test_record")
    local notes = require_field(record, "notes", "recovery_access_test_record")

    assert(
        is_iso_8601_utc(test_date),
        "recovery_access_test_record.test_date must be ISO 8601 UTC with milliseconds"
    )
    assert(
        is_iso_8601_utc(current_time_utc),
        "current_time_utc must be ISO 8601 UTC with milliseconds"
    )
    assert(
        VALID_RECOVERY_METHODS[method],
        "recovery_access_test_record.method is unsupported"
    )
    require_boolean(passed, "recovery_access_test_record.passed")
    require_string(notes, "recovery_access_test_record.notes")

    local test_epoch = parse_iso_8601_utc(test_date)
    local current_epoch = parse_iso_8601_utc(current_time_utc)

    assert(
        current_epoch >= test_epoch,
        "current_time_utc cannot be earlier than test_date"
    )

    local days_since_test = (current_epoch - test_epoch) / DAY_SECONDS
    local cadence_due = days_since_test >= RECOVERY_TEST_CADENCE_DAYS
    local next_review_epoch =
        test_epoch + RECOVERY_TEST_CADENCE_DAYS * DAY_SECONDS

    return {
        object_id = "sc-042",
        name = "RecoveryAccessTestRecord",
        valid = true,
        test_date = test_date,
        method = method,
        passed = passed,
        notes = notes,
        days_since_test = days_since_test,
        required_cadence_days = RECOVERY_TEST_CADENCE_DAYS,
        cadence_due = cadence_due,
        next_review_epoch_utc = next_review_epoch,
        knowledge_factor = passed and 0.80 or 0.20,
        eco_impact_value = 0.0,
        harm_risk = (not passed or cadence_due) and 0.70 or 0.10,
        authority_effect = "none",
        interpretation =
            "Recovery-test record validation only. It does not perform recovery, expose credentials, "
            .. "contact a recovery delegate, or verify account ownership.",
    }
end

return Records
