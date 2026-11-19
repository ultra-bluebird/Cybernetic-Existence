-- Lua 5.4.
-- Pure local workflow. No I/O, network access, or external execution.
-- Import: local workflow = require("cybermind.expression_workflow")
-- Tests: assert(workflow.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
local SCOPE =
    "Credit and workstream metadata only; not identity, consent, "
    .. "authorization, execution evidence, or authority."

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
    if type(value) ~= "string" or not value:match("%S")
        or #value > maximum or value:find("%z") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function integer(value, path, minimum, maximum)
    if type(value) ~= "number"
        or math.type(value) ~= "integer"
        or value < minimum or value > maximum then
        fail("INVALID_INTEGER", path, "Integer outside permitted range")
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
        fields(config, {authorization_seconds = true}, "config")
        local ttl = integer(
            config.authorization_seconds,
            "config.authorization_seconds", 1, 86400
        )

        local state = "recorded"
        local revision = 0
        local expression, recipient, proposed_action, target
        local approved_at, authorized_at
        local last_time = 0
        local api = {}

        local function snapshot()
            return {
                schema_version = VERSION,
                attribution = ATTRIBUTION,
                attribution_scope = SCOPE,
                state = state,
                revision = revision,
                expression = expression,
                recipient = recipient,
                proposed_action = proposed_action,
                target = target
            }
        end

        local function clear()
            expression, recipient, proposed_action, target = nil, nil, nil, nil
            approved_at, authorized_at = nil, nil
        end

        local function require_revision(input)
            integer(input.revision, "revision", 0, math.maxinteger)
            if input.revision ~= revision then
                fail("STALE_REVISION", "revision",
                    "Approval must concern the current expression")
            end
        end

        local function require_confirmation(input)
            if input.confirmed ~= true then
                fail("CONFIRMATION_REQUIRED", "confirmed",
                    "Explicit confirmation is required")
            end
        end

        local function require_fresh(start, now)
            if start == nil or now - start >= ttl then
                fail("AUTHORIZATION_EXPIRED", "now",
                    "Fresh approval is required")
            end
        end

        local function require_state(expected)
            if state ~= expected then
                fail("INVALID_TRANSITION", "state",
                    "Operation is not valid in the current state")
            end
        end

        function api.status()
            return snapshot()
        end

        function api.transition(event, input, now)
            return protect(function()
                if type(event) ~= "string" then
                    fail("INVALID_EVENT", "event", "Expected event name")
                end
                integer(now, "now", 0, math.maxinteger)
                if now < last_time then
                    fail("CLOCK_REVERSED", "now",
                        "Workflow time must not move backward")
                end

                if event == "cancel" then
                    fields(input, {}, "input")
                    clear()
                    state = "recorded"

                elseif event == "infer" then
                    fields(input, {expression = true}, "input")
                    local next_expression = text(
                        input.expression, "expression", 65536
                    )
                    if revision == math.maxinteger then
                        fail("REVISION_EXHAUSTED", "revision",
                            "Create a new workflow")
                    end
                    clear()
                    revision = revision + 1
                    expression = next_expression
                    state = "candidate"

                elseif event == "display" then
                    fields(input, {revision = true}, "input")
                    require_revision(input)
                    require_state("candidate")
                    state = "displayed"

                elseif event == "approve" then
                    fields(input, {
                        revision = true, recipient = true, confirmed = true
                    }, "input")
                    require_revision(input)
                    require_state("displayed")
                    require_confirmation(input)
                    local next_recipient = text(
                        input.recipient, "recipient", 4096
                    )
                    recipient = next_recipient
                    approved_at = now
                    state = "approved"

                elseif event == "propose_action" then
                    fields(input, {
                        revision = true, action = true, target = true
                    }, "input")
                    require_revision(input)
                    require_state("approved")
                    require_fresh(approved_at, now)
                    local next_action = text(input.action, "action", 4096)
                    local next_target = text(input.target, "target", 4096)
                    proposed_action = next_action
                    target = next_target

                elseif event == "authorize_action" then
                    fields(input, {
                        revision = true, recipient = true,
                        action = true, target = true, confirmed = true
                    }, "input")
                    require_revision(input)
                    require_state("approved")
                    require_fresh(approved_at, now)
                    require_confirmation(input)
                    if proposed_action == nil
                        or input.recipient ~= recipient
                        or input.action ~= proposed_action
                        or input.target ~= target then
                        fail("PREVIEW_MISMATCH", "input",
                            "Authorization must match the exact preview")
                    end
                    authorized_at = now
                    state = "action_authorized"

                else
                    fail("UNKNOWN_EVENT", "event", "Unsupported transition")
                end

                last_time = now
                return snapshot()
            end)
        end

        function api.consume(kind, now)
            return protect(function()
                integer(now, "now", 0, math.maxinteger)
                if now < last_time then
                    fail("CLOCK_REVERSED", "now",
                        "Workflow time must not move backward")
                end

                if kind == "communication" then
                    require_state("approved")
                    require_fresh(approved_at, now)
                    if proposed_action ~= nil then
                        fail("ACTION_PREVIEW_PENDING", "state",
                            "Resolve the pending action before communication")
                    end
                elseif kind == "external_action" then
                    require_state("action_authorized")
                    require_fresh(approved_at, now)
                    require_fresh(authorized_at, now)
                else
                    fail("INVALID_USE", "kind", "Unsupported authorization use")
                end

                local authorization = snapshot()
                authorization.use = kind
                authorization.consumed_at = now
                authorization.scope =
                    "Single-use local authorization record; no execution "
                    .. "or identity authentication performed"

                clear()
                state = "recorded"
                last_time = now
                return authorization
            end)
        end

        return api
    end)
end

function M.self_test()
    local function approved()
        local flow = assert(M.new({authorization_seconds = 30}))
        assert(flow.transition("infer", {expression = "Please confirm"}, 0))
        assert(flow.transition("display", {revision = 1}, 1))
        assert(flow.transition("approve", {
            revision = 1, recipient = "Chosen recipient", confirmed = true
        }, 2))
        return flow
    end

    local flow = approved()
    assert(flow.transition("propose_action", {
        revision = 1, action = "Submit request", target = "Chosen service"
    }, 3))

    local value, err = flow.transition("authorize_action", {
        revision = 1, recipient = "Chosen recipient",
        action = "Submit request", target = "Different service",
        confirmed = true
    }, 4)
    assert(value == nil and err.code == "PREVIEW_MISMATCH")

    assert(flow.transition("authorize_action", {
        revision = 1, recipient = "Chosen recipient",
        action = "Submit request", target = "Chosen service",
        confirmed = true
    }, 4))
    assert(flow.consume("external_action", 5))
    value, err = flow.consume("external_action", 6)
    assert(value == nil and err.code == "INVALID_TRANSITION")

    flow = approved()
    assert(flow.transition("infer", {expression = "Revised expression"}, 3))
    value, err = flow.consume("communication", 4)
    assert(value == nil and err.code == "INVALID_TRANSITION")

    flow = approved()
    value, err = flow.consume("communication", 32)
    assert(value == nil and err.code == "AUTHORIZATION_EXPIRED")

    flow = approved()
    assert(flow.transition("cancel", {}, 3))
    assert(flow.status().expression == nil)

    flow = approved()
    local copy = flow.status()
    copy.expression = "Caller modification"
    assert(flow.status().expression == "Please confirm")

    return true
end

return M
