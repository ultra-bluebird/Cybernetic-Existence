-- Lua 5.4.
-- Local private-expression workflow; no neural acquisition or external action.
-- Import: local consent = require("cybermind.inner_expression_consent")
-- Tests: assert(consent.self_test())
--
-- The trusted host must authenticate controls and supply monotonic time.
-- This module does not establish identity, voluntariness, or legal consent.

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
local MAX_TIME = 9000000000000

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

local function text(value, path, maximum)
    if type(value) ~= "string" or #value > maximum
        or not value:match("%S") or value:find("%z") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function integer(value, path, minimum, maximum)
    if type(value) ~= "number" or math.type(value) ~= "integer"
        or value < minimum or value > maximum then
        fail("INVALID_INTEGER", path, "Integer outside declared range")
    end
    return value
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

function M.new(config)
    return protect(function()
        fields(config, {
            purpose = true,
            context = true,
            recipient = true,
            ttl_ms = true,
            max_draft_bytes = true
        }, "config")

        local purpose = text(config.purpose, "config.purpose", 4096)
        local context = text(config.context, "config.context", 4096)
        local recipient = text(config.recipient, "config.recipient", 4096)
        local ttl = integer(config.ttl_ms, "config.ttl_ms", 1, 86400000)
        local maximum = integer(config.max_draft_bytes,
            "config.max_draft_bytes", 1, 65536)

        local state = "paused"
        local revision = 0
        local draft
        local activated_at, approved_at, last_time
        local api = {}

        local function check_time(now)
            integer(now, "now", 0, MAX_TIME)
            if last_time ~= nil and now < last_time then
                fail("CLOCK_REVERSED", "now", "Monotonic time moved backward")
            end
        end

        local function clear()
            draft, activated_at, approved_at = nil, nil, nil
            state = "paused"
        end

        local function require_fresh(start, now)
            if start == nil or now - start >= ttl then
                fail("AUTHORIZATION_EXPIRED", "now",
                    "Fresh activation and approval are required")
            end
        end

        local function require_revision(value)
            integer(value, "revision", 0, math.maxinteger)
            if value ~= revision then
                fail("STALE_REVISION", "revision",
                    "Approval must bind the current candidate")
            end
        end

        local function require_binding(input)
            if input.purpose ~= purpose
                or input.context ~= context
                or input.recipient ~= recipient then
                fail("BINDING_MISMATCH", "input",
                    "Purpose, context, and recipient must match")
            end
        end

        function api.status()
            return {
                schema_version = VERSION,
                attribution = ATTRIBUTION,
                attribution_scope =
                    "Credit and workstream metadata only; not identity, consent, "
                    .. "authorization, execution evidence, or authority.",
                state = state,
                revision = revision,
                candidate_present = draft ~= nil
            }
        end

        function api.activate(input, now)
            return protect(function()
                fields(input, {
                    purpose = true, context = true, recipient = true,
                    inference_gate = true, activation_verified = true
                }, "activation")
                check_time(now)
                require_binding(input)

                if input.inference_gate ~= "satisfied"
                    or input.activation_verified ~= true then
                    fail("ACTIVATION_NOT_ACCEPTED", "activation",
                        "A satisfied inference gate and trusted activation "
                        .. "assertion are required")
                end

                clear()
                activated_at = now
                state = "armed"
                last_time = now
                return api.status()
            end)
        end

        function api.candidate(value, now)
            return protect(function()
                check_time(now)
                if state ~= "armed" and state ~= "candidate"
                    and state ~= "previewed" and state ~= "approved" then
                    fail("NOT_ARMED", "state", "Activation is required")
                end
                require_fresh(activated_at, now)
                local checked = text(value, "candidate", maximum)
                if revision == math.maxinteger then
                    fail("REVISION_EXHAUSTED", "revision",
                        "Create a new workflow")
                end

                revision = revision + 1
                draft = checked
                approved_at = nil
                state = "candidate"
                last_time = now
                return api.status()
            end)
        end

        function api.private_preview(now)
            return protect(function()
                check_time(now)
                if state ~= "candidate" and state ~= "previewed" then
                    fail("NO_PREVIEWABLE_CANDIDATE", "state",
                        "A current candidate is required")
                end
                require_fresh(activated_at, now)
                state = "previewed"
                last_time = now
                return {
                    revision = revision,
                    private_expression = draft,
                    purpose = purpose,
                    context = context,
                    recipient = recipient,
                    scope = "Private preview only; not approved expression"
                }
            end)
        end

        function api.approve(input, now)
            return protect(function()
                fields(input, {
                    revision = true, purpose = true,
                    context = true, recipient = true, confirmed = true
                }, "approval")
                check_time(now)
                require_revision(input.revision)
                require_binding(input)
                if state ~= "previewed" or input.confirmed ~= true then
                    fail("APPROVAL_REQUIRED", "approval",
                        "Current preview and explicit confirmation are required")
                end
                require_fresh(activated_at, now)
                approved_at = now
                state = "approved"
                last_time = now
                return api.status()
            end)
        end

        function api.release(input, now)
            return protect(function()
                fields(input, {
                    revision = true, purpose = true,
                    context = true, recipient = true
                }, "release")
                check_time(now)
                require_revision(input.revision)
                require_binding(input)
                if state ~= "approved" then
                    fail("NOT_APPROVED", "state",
                        "Current expression approval is required")
                end
                require_fresh(activated_at, now)
                require_fresh(approved_at, now)

                local payload = {
                    revision = revision,
                    expression = draft,
                    purpose = purpose,
                    context = context,
                    recipient = recipient,
                    scope =
                        "Single-use release to the trusted host; not proof of "
                        .. "identity, legal admissibility, or action authorization"
                }

                clear()
                last_time = now
                return payload
            end)
        end

        function api.pause(now)
            return protect(function()
                check_time(now)
                clear()
                last_time = now
                return api.status()
            end)
        end

        return api
    end)
end

local function fixture()
    return assert(M.new({
        purpose = "Chosen communication",
        context = "Private session",
        recipient = "Chosen recipient",
        ttl_ms = 100,
        max_draft_bytes = 1024
    }))
end

local function binding(revision)
    return {
        revision = revision,
        purpose = "Chosen communication",
        context = "Private session",
        recipient = "Chosen recipient",
        confirmed = true
    }
end

function M.self_test()
    local flow = fixture()
    local activation = {
        purpose = "Chosen communication",
        context = "Private session",
        recipient = "Chosen recipient",
        inference_gate = "satisfied",
        activation_verified = true
    }
    assert(flow.activate(activation, 0))
    assert(flow.candidate("Synthetic private expression", 1))
    assert(flow.status().expression == nil)

    local value, err = flow.approve(binding(1), 2)
    assert(value == nil and err.code == "APPROVAL_REQUIRED")

    assert(flow.private_preview(2))
    assert(flow.approve(binding(1), 3))

    local release = binding(1)
    release.confirmed = nil
    assert(flow.release(release, 4))
    value, err = flow.release(release, 5)
    assert(value == nil and err.code == "NOT_APPROVED")

    flow = fixture()
    assert(flow.activate(activation, 0))
    assert(flow.candidate("First candidate", 1))
    assert(flow.private_preview(2))
    assert(flow.approve(binding(1), 3))
    assert(flow.candidate("Changed candidate", 4))
    release = binding(1)
    release.confirmed = nil
    value, err = flow.release(release, 5)
    assert(value == nil and err.code == "STALE_REVISION")

    assert(flow.pause(6))
    assert(not flow.status().candidate_present)

    flow = fixture()
    assert(flow.activate(activation, 0))
    value, err = flow.candidate("Late candidate", 100)
    assert(value == nil and err.code == "AUTHORIZATION_EXPIRED")

    return true
end

return M
