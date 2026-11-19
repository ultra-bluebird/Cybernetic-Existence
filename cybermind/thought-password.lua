-- Lua 5.4.
-- Activation broker only: no neural acquisition, phrase storage, or decoding.
-- No I/O, external actions, or built-in cryptography.
-- Import: local thought = require("cybermind.thought-password")
-- Tests: assert(thought.self_test())
--
-- Production security depends on the injected adapters.
-- Test adapters below are deterministic fixtures, not security components.

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
local MAX_TIME = 9000000000000

local VERDICTS = {
    satisfied = true,
    not_satisfied = true,
    unknown = true
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

local function integer(value, path, minimum, maximum)
    if type(value) ~= "number" or math.type(value) ~= "integer"
        or value < minimum or value > maximum then
        fail("INVALID_INTEGER", path, "Integer outside declared range")
    end
    return value
end

local function text(value, path, maximum)
    if type(value) ~= "string" or #value > maximum
        or not value:match("%S") or value:find("%c") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function protected(operation)
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

function M.new(config, adapters)
    return protected(function()
        fields(config, {
            purpose = true,
            context = true,
            recipient = true,
            policy_revision = true,
            lifetime_ms = true,
            attempt_limit = true
        }, "config")

        fields(adapters, {
            clock_ms = true,
            issue_challenge = true,
            check_policy = true,
            verify_assertion = true,
            claim_once = true
        }, "adapters")

        local purpose = text(config.purpose, "config.purpose", 4096)
        local context = text(config.context, "config.context", 4096)
        local recipient = text(config.recipient, "config.recipient", 4096)
        local revision = integer(config.policy_revision,
            "config.policy_revision", 0, math.maxinteger)
        local lifetime = integer(config.lifetime_ms,
            "config.lifetime_ms", 1, 300000)
        local limit = integer(config.attempt_limit,
            "config.attempt_limit", 1, 100)

        local functions = {}
        for _, name in ipairs({
            "clock_ms", "issue_challenge", "check_policy",
            "verify_assertion", "claim_once"
        }) do
            if type(adapters[name]) ~= "function" then
                fail("ADAPTER_REQUIRED", "adapters." .. name,
                    "Expected an adapter function")
            end
            functions[name] = adapters[name]
        end

        local state = "idle"
        local challenge, started_at, last_time
        local attempts = 0
        local busy = false
        local api = {}

        local function binding()
            return {
                operation = "private_decoding_activation",
                purpose = purpose,
                context = context,
                recipient = recipient,
                policy_revision = revision,
                lifetime_ms = lifetime
            }
        end

        local function clear()
            challenge, started_at = nil, nil
            attempts = 0
            if state ~= "closed" then state = "idle" end
        end

        local function call(name, ...)
            local ok, value = pcall(functions[name], ...)
            if not ok then
                clear()
                fail("ADAPTER_FAILURE", "adapters." .. name,
                    "Adapter failed; activation not granted")
            end
            return value
        end

        local function now()
            local value = call("clock_ms")
            if type(value) ~= "number" or math.type(value) ~= "integer"
                or value < 0 or value > MAX_TIME then
                clear()
                fail("INVALID_CLOCK", "clock_ms",
                    "Clock must return bounded integer milliseconds")
            end
            if last_time ~= nil and value < last_time then
                clear()
                fail("CLOCK_REVERSED", "clock_ms",
                    "Clock moved backward; activation invalidated")
            end
            last_time = value
            return value
        end

        local function fresh()
            local current = now()
            if started_at == nil or current - started_at >= lifetime then
                clear()
                fail("ACTIVATION_EXPIRED", "state",
                    "A fresh activation workflow is required")
            end
            return current
        end

        local function policy()
            local result = call("check_policy", binding())
            if type(result) ~= "table" or getmetatable(result) ~= nil
                or type(result.verdict) ~= "string"
                or not VERDICTS[result.verdict]
                or type(result.revision) ~= "number"
                or math.type(result.revision) ~= "integer"
                or result.revision < 0 then
                clear()
                fail("INVALID_POLICY_RESULT", "check_policy",
                    "Policy adapter returned an invalid result")
            end
            for key in next, result do
                if key ~= "verdict" and key ~= "revision" then
                    clear()
                    fail("INVALID_POLICY_RESULT", "check_policy",
                        "Policy result contains an unexpected field")
                end
            end
            if result.verdict ~= "satisfied"
                or result.revision ~= revision then
                clear()
                fail("POLICY_NOT_CURRENTLY_PERMITTED", "check_policy",
                    "Current policy does not permit this activation")
            end
        end

        local function snapshot()
            return {
                state = state,
                attempts_used = attempts,
                attempt_limit = limit,
                policy_revision = revision,
                challenge_present = challenge ~= nil
            }
        end

        local function operation(action)
            if busy then
                return nil, {
                    code = "REENTRANT_CALL",
                    path = "module",
                    message = "Adapter reentry is not permitted"
                }
            end
            busy = true
            local result, err = protected(function()
                if state == "closed" then
                    fail("CLOSED_WORKFLOW", "state",
                        "Create a new workflow")
                end
                return action()
            end)
            busy = false
            return result, err
        end

        function api.status()
            return snapshot()
        end

        function api.begin()
            return operation(function()
                clear()
                now()
                policy()

                local issued = call("issue_challenge", binding())
                if type(issued) ~= "string"
                    or #issued ~= 64 or not issued:match("^[0-9a-f]+$") then
                    clear()
                    fail("INVALID_CHALLENGE", "issue_challenge",
                        "Expected 64 lowercase hexadecimal characters")
                end

                challenge = issued
                started_at = now()
                state = "challenge_pending"

                return {
                    challenge = challenge,
                    binding = binding(),
                    scope =
                        "Challenge for a trusted activation adapter only; "
                        .. "not permission to disclose expression"
                }
            end)
        end

        function api.submit(proof)
            return operation(function()
                if state ~= "challenge_pending" then
                    fail("NO_PENDING_CHALLENGE", "state",
                        "Begin a fresh activation workflow")
                end
                text(proof, "proof", 16384)
                fresh()
                policy()
                fresh()

                attempts = attempts + 1
                local verdict = call(
                    "verify_assertion", challenge, proof, binding()
                )
                fresh()

                if verdict == "rejected" then
                    if attempts >= limit then clear() end
                    return {
                        result = "assertion_rejected",
                        state = state,
                        further_private_disclosure_required = false
                    }
                elseif verdict == "unavailable" then
                    clear()
                    fail("VERIFIER_UNAVAILABLE", "verify_assertion",
                        "No activation granted")
                elseif verdict ~= "accepted" then
                    clear()
                    fail("INVALID_VERIFIER_RESULT", "verify_assertion",
                        "Unexpected verifier result")
                end

                policy()
                fresh()
                local claim = call("claim_once", challenge, binding())
                if claim ~= "consumed" then
                    clear()
                    fail(
                        claim == "replayed" and "REPLAY_REJECTED"
                            or "REPLAY_STORE_UNAVAILABLE",
                        "claim_once",
                        "Challenge was not freshly consumed"
                    )
                end

                fresh()
                challenge = nil
                state = "activation_accepted"
                return {
                    result = "activation_assertion_accepted",
                    state = state,
                    scope =
                        "Expression preview, publication, research reuse, "
                        .. "and external action remain separately controlled"
                }
            end)
        end

        function api.consume_activation()
            return operation(function()
                if state ~= "activation_accepted" then
                    fail("NO_ACCEPTED_ACTIVATION", "state",
                        "A fresh accepted activation is required")
                end
                fresh()
                policy()
                local consumed_at = fresh()
                local result = binding()
                result.consumed_at_ms = consumed_at
                result.scope =
                    "Single-use local activation result for the trusted host; "
                    .. "not a portable credential, identity finding, "
                    .. "expression approval, or external-action authorization"
                clear()
                return result
            end)
        end

        function api.cancel()
            return operation(function()
                clear()
                return {state = "idle", activation_granted = false}
            end)
        end

        function api.close()
            return operation(function()
                clear()
                state = "closed"
                return {state = "closed", retained_challenge = false}
            end)
        end

        return api
    end)
end

function M.self_test()
    local time = 0
    local issued = 0
    local consumed = {}

    local adapters = {
        clock_ms = function() return time end,
        issue_challenge = function()
            issued = issued + 1
            return string.format("%064x", issued)
        end,
        check_policy = function()
            return {verdict = "satisfied", revision = 1}
        end,
        verify_assertion = function(_, proof)
            return proof == "synthetic-accepted-proof"
                and "accepted" or "rejected"
        end,
        claim_once = function(challenge)
            if consumed[challenge] then return "replayed" end
            consumed[challenge] = true
            return "consumed"
        end
    }

    local function workflow()
        return assert(M.new({
            purpose = "Private communication assistance",
            context = "Synthetic test context",
            recipient = "Private preview host",
            policy_revision = 1,
            lifetime_ms = 100,
            attempt_limit = 2
        }, adapters))
    end

    local flow = workflow()
    assert(flow.begin())
    assert(flow.submit("synthetic-accepted-proof"))
    assert(flow.consume_activation())
    local value, err = flow.consume_activation()
    assert(value == nil and err.code == "NO_ACCEPTED_ACTIVATION")

    flow = workflow()
    assert(flow.begin())
    assert(flow.submit("rejected-proof").result == "assertion_rejected")
    assert(flow.submit("rejected-proof").state == "idle")

    flow = workflow()
    assert(flow.begin())
    time = 100
    value, err = flow.submit("synthetic-accepted-proof")
    assert(value == nil and err.code == "ACTIVATION_EXPIRED")

    time = 200
    flow = workflow()
    assert(flow.begin())
    time = 199
    value, err = flow.submit("synthetic-accepted-proof")
    assert(value == nil and err.code == "CLOCK_REVERSED")
    assert(flow.status().state == "idle")

    flow = workflow()
    assert(flow.begin())
    assert(flow.cancel().state == "idle")
    assert(flow.close().state == "closed")

    return true
end

return M
