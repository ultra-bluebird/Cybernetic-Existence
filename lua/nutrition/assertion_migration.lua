-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: deterministic assertion-record migration.
-- No execution inference, timestamps, persistence, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local legacy_states = {
    not_run = true,
    passed = true,
    failed = true
}

local current_states = {
    not_started = true,
    in_progress = true,
    passed = true,
    failed = true,
    assertion_error = true,
    outcome_lost = true,
    unresolved_legacy = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, allowed)
    if not plain(value) then return false end
    local count = 0
    for key in next, value do
        count = count + 1
        if count > 16 or not allowed[key] then return false end
    end
    return true
end

local function local_reference(value)
    return type(value) == "string" and #value <= 128
        and value:match("^local:[A-Za-z0-9_-]+$") ~= nil
end

local function invalid(reason)
    return {
        schema_version = "assertion-migration-result-v1",
        migration_status = "unavailable",
        reason = reason,
        execution_evidence_created = false
    }
end

local function expected_state(schema, original)
    if schema == "assertion-record-v1" then
        if not legacy_states[original] then return nil end
        if original == "not_run" then return "unresolved_legacy" end
        return original
    end

    if schema == "assertion-record-v2"
        and current_states[original]
        and original ~= "unresolved_legacy" then
        return original
    end

    return nil
end

function M.migrate(input)
    if not plain(input) then
        return invalid("plain_record_required")
    end

    local version = rawget(input, "schema_version")
    local state = rawget(input, "assertion_state")
    local source = rawget(input, "source_reference")

    if not local_reference(source) then
        return invalid("local_source_reference_required")
    end

    if type(state) ~= "string" then
        return invalid("assertion_state_required")
    end

    local original_schema, original_state

    if version == "assertion-record-v1" then
        if not shape(input, {
            schema_version = true,
            assertion_state = true,
            source_reference = true
        }) then
            return invalid("invalid_legacy_shape")
        end

        if not legacy_states[state] then
            return invalid("unsupported_legacy_state")
        end

        original_schema = version
        original_state = state

    elseif version == "assertion-record-v2" then
        if not shape(input, {
            schema_version = true,
            assertion_state = true,
            source_reference = true,
            origin = true
        }) then
            return invalid("invalid_current_shape")
        end

        if not current_states[state] then
            return invalid("unsupported_current_state")
        end

        local origin = rawget(input, "origin")
        if not shape(origin, {
            schema_version = true,
            assertion_state = true
        }) then
            return invalid("origin_record_required")
        end

        original_schema = rawget(origin, "schema_version")
        original_state = rawget(origin, "assertion_state")

        if type(original_schema) ~= "string"
            or type(original_state) ~= "string" then
            return invalid("invalid_origin_fields")
        end

        if expected_state(original_schema, original_state) ~= state then
            return invalid("origin_state_inconsistent")
        end
    else
        return invalid("unsupported_schema")
    end

    local migrated = expected_state(original_schema, original_state)
    if migrated == nil then
        return invalid("unsupported_origin")
    end

    return {
        schema_version = "assertion-migration-result-v1",
        migration_status = "record_produced",
        migration_rule = "preserve_legacy_ambiguity",
        execution_evidence_created = false,
        source_verification = "not_performed",
        record = {
            schema_version = "assertion-record-v2",
            assertion_state = migrated,
            source_reference = source,
            origin = {
                schema_version = original_schema,
                assertion_state = original_state
            }
        }
    }
end

return M
