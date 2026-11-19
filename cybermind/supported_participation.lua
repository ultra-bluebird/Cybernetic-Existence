-- Lua 5.4.
-- Pure procedural and mandate checks.
-- No I/O, appointments, legal-capacity findings, or external actions.
-- Import: local support = require("cybermind.supported_participation")
-- Tests: assert(support.self_test())
--
-- Timestamps use one caller-defined integer time domain.
-- Authority and review fields are supplied assertions, not authenticated facts.

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local TRI = {
    yes = true,
    no = true,
    unknown = true
}

local TYPES = {
    chosen_participation_support = true,
    uncertain_interest_advocacy = true
}

local OPERATIONS = {
    relay_approved_expression = true,
    submit_correction = true,
    request_review = true,
    request_minimal_preservation = true
}

local ADVOCACY_OPERATIONS = {
    request_review = true,
    request_minimal_preservation = true
}

local function fail(code, path, message)
    error({code = code, path = path, message = message}, 0)
end

local function fields(value, allowed, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_TABLE", path, "Expected a plain table")
    end
    for key in next, value do
        if type(key) ~= "string" or not allowed[key] then
            fail("UNKNOWN_FIELD", path, "Unexpected field")
        end
    end
end

local function integer(value, path)
    if type(value) ~= "number"
        or math.type(value) ~= "integer" or value < 0 then
        fail("INVALID_INTEGER", path, "Expected nonnegative integer")
    end
    return value
end

local function text(value, path)
    if type(value) ~= "string" or #value > 4096
        or not value:match("%S") or value:find("%c") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function choice(value, vocabulary, path)
    if type(value) ~= "string" or not vocabulary[value] then
        fail("INVALID_ENUM", path, "Unknown vocabulary value")
    end
    return value
end

local function operation_set(value)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_ARRAY", "allowed_operations", "Expected a plain array")
    end
    local count, maximum = 0, 0
    for key in next, value do
        if type(key) ~= "number" or math.type(key) ~= "integer" or key < 1 then
            fail("INVALID_ARRAY_KEY", "allowed_operations",
                "Expected consecutive positive integer keys")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum or count > 4 then
        fail("INVALID_OPERATION_LIST", "allowed_operations",
            "Expected at most four consecutive entries")
    end

    local result = {}
    for position = 1, count do
        local operation = choice(value[position],
            OPERATIONS, "allowed_operations")
        if result[operation] then
            fail("DUPLICATE_OPERATION", "allowed_operations",
                "Operation may appear only once")
        end
        result[operation] = true
    end
    return result
end

local function protect(operation)
    local ok, result = pcall(operation)
    if ok then return result end
    if type(result) == "table" and type(result.code) == "string" then
        return nil, result
    end
    return nil, {
        code = "INTERNAL_ERROR",
        path = "module",
        message = "Unexpected internal failure"
    }
end

function M.metadata()
    return {
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope =
            "Credit and workstream metadata only; not identity, consent, "
            .. "authorization, execution evidence, or authority."
    }
end

function M.response_check(record, now)
    return protect(function()
        fields(record, {
            received_at = true,
            original_due_at = true,
            response_recorded_at = true,
            accessible_delivery_confirmed = true
        }, "response")

        integer(now, "now")
        local received = integer(record.received_at, "received_at")
        local due = integer(record.original_due_at, "original_due_at")
        if due < received or received > now then
            fail("INVALID_ORDER", "response",
                "Receipt and deadline ordering is inconsistent")
        end

        local delivery = choice(record.accessible_delivery_confirmed,
            TRI, "accessible_delivery_confirmed")

        local result = M.metadata()
        result.recorded_response = "not_recorded"
        result.deadline = now >= due and "due_without_recorded_response"
            or "not_yet_due"
        result.accessible_delivery = delivery

        if record.response_recorded_at ~= nil then
            local response = integer(
                record.response_recorded_at, "response_recorded_at"
            )
            if response < received or response > now then
                fail("INVALID_ORDER", "response_recorded_at",
                    "Response must fall between receipt and assessment")
            end
            result.recorded_response = "recorded"
            result.deadline = response <= due
                and "recorded_by_deadline" or "recorded_after_deadline"
        elseif delivery == "yes" then
            fail("INCONSISTENT_DELIVERY", "accessible_delivery_confirmed",
                "Confirmed delivery requires a recorded response")
        end

        result.scope =
            "Supplied record checks only; not proof of actual delivery, "
            .. "understanding, substantive adequacy, or resolution."
        return result
    end)
end

function M.mandate_check(mandate, operation, now)
    return protect(function()
        fields(mandate, {
            type = true,
            purpose = true,
            authority_status = true,
            conflict_status = true,
            selected_support_confirmed = true,
            direct_participation_preserved = true,
            valid_from = true,
            valid_until = true,
            review_due = true,
            allowed_operations = true,
            appeal_route = true
        }, "mandate")

        integer(now, "now")
        local kind = choice(mandate.type, TYPES, "type")
        text(mandate.purpose, "purpose")
        text(mandate.appeal_route, "appeal_route")
        choice(operation, OPERATIONS, "operation")

        local authority = choice(mandate.authority_status,
            {reviewed = true, unknown = true, revoked = true},
            "authority_status")
        local conflict = choice(mandate.conflict_status,
            {cleared = true, unresolved = true}, "conflict_status")
        local selected = choice(mandate.selected_support_confirmed,
            TRI, "selected_support_confirmed")
        local direct = choice(mandate.direct_participation_preserved,
            TRI, "direct_participation_preserved")

        local first = integer(mandate.valid_from, "valid_from")
        local last = integer(mandate.valid_until, "valid_until")
        local review = integer(mandate.review_due, "review_due")
        if last <= first or review < first or review > last then
            fail("INVALID_TERM", "mandate",
                "Term and review deadline are inconsistent")
        end

        local allowed = operation_set(mandate.allowed_operations)
        local reasons = {}

        if authority ~= "reviewed" then
            reasons[#reasons + 1] = "authority_not_currently_established"
        end
        if conflict ~= "cleared" then
            reasons[#reasons + 1] = "conflict_unresolved"
        end
        if now < first or now >= last then
            reasons[#reasons + 1] = "outside_mandate_term"
        end
        if now >= review then
            reasons[#reasons + 1] = "fresh_review_required"
        end
        if not allowed[operation] then
            reasons[#reasons + 1] = "operation_outside_mandate"
        end

        if kind == "chosen_participation_support" then
            if selected ~= "yes" then
                reasons[#reasons + 1] = "chosen_support_not_confirmed"
            end
            if direct ~= "yes" then
                reasons[#reasons + 1] = "direct_participation_not_preserved"
            end
        elseif not ADVOCACY_OPERATIONS[operation] then
            reasons[#reasons + 1] =
                "uncertain_interest_advocate_cannot_attribute_expression"
        end

        local result = M.metadata()
        result.operation = operation
        result.reasons = reasons
        result.result = #reasons == 0
            and "within_supplied_mandate_checks"
            or "not_cleared_under_supplied_mandate"
        result.direct_access_instruction =
            "Do not use a support-mandate failure to remove direct participation"
        result.scope =
            "Supplied mandate assertions only; no appointment, authentication, "
            .. "legal-capacity finding, or external-action authorization."
        return result
    end)
end

function M.self_test()
    local response = assert(M.response_check({
        received_at = 0,
        original_due_at = 10,
        response_recorded_at = 8,
        accessible_delivery_confirmed = "unknown"
    }, 12))
    assert(response.deadline == "recorded_by_deadline")
    assert(response.accessible_delivery == "unknown")

    local mandate = {
        type = "chosen_participation_support",
        purpose = "Help submit a correction",
        authority_status = "reviewed",
        conflict_status = "cleared",
        selected_support_confirmed = "yes",
        direct_participation_preserved = "yes",
        valid_from = 0,
        valid_until = 100,
        review_due = 50,
        allowed_operations = {"submit_correction", "request_review"},
        appeal_route = "Independent written review"
    }

    assert(assert(M.mandate_check(
        mandate, "submit_correction", 10
    )).result == "within_supplied_mandate_checks")

    assert(assert(M.mandate_check(
        mandate, "submit_correction", 50
    )).result == "not_cleared_under_supplied_mandate")

    mandate.type = "uncertain_interest_advocacy"
    assert(assert(M.mandate_check(
        mandate, "submit_correction", 10
    )).result == "not_cleared_under_supplied_mandate")

    local value, err = M.response_check({
        received_at = 10,
        original_due_at = 5,
        accessible_delivery_confirmed = "unknown"
    }, 12)
    assert(value == nil and err.code == "INVALID_ORDER")

    return true
end

return M
