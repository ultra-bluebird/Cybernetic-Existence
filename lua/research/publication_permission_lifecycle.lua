-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only.
-- No identity verification, consent authentication, or execution authority.
--
-- Research-only permission lifecycle.
-- No network, file, device, persistence, or publication operations.
-- Evidence references are caller assertions, not authenticated evidence.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"
local MAX_TIME = 1000000000

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function text(value)
    return type(value) == "string"
        and #value > 0
        and #value <= 256
        and value:match("%S") ~= nil
        and value:find("[%z\1-\31\127]") == nil
end

local function time_value(value)
    return type(value) == "number"
        and value == value
        and value >= 0
        and value <= MAX_TIME
        and value % 1 == 0
end

local function binding(value)
    if not plain(value) then return nil end

    local allowed = {package = true, audience = true, policy = true}
    for key in next, value do
        if not allowed[key] then return nil end
    end

    if not text(value.package)
        or not text(value.audience)
        or not text(value.policy) then
        return nil
    end

    return {
        package = value.package,
        audience = value.audience,
        policy = value.policy
    }
end

local function validation(reason)
    return {status = "validation_error", reason = reason}
end

function M.new(bound_scope, initial_time)
    local scope = binding(bound_scope)
    assert(scope, "programmer error: valid lifecycle binding required")
    assert(time_value(initial_time),
        "programmer error: valid initial time required")

    local state = "unissued"
    local last_time = initial_time
    local granted_at, expires_at
    local grant_reference, withdrawal_reference
    local api = {}

    local function prepare(now)
        if not time_value(now) then
            return validation("invalid_time")
        end
        if now < last_time then
            return validation("regressed_time")
        end

        last_time = now

        if state == "active" and now >= expires_at then
            state = "expired"
        end

        return nil
    end

    local function snapshot()
        local result = {
            implementation_version = VERSION,
            state = state,
            last_time = last_time,
            binding = {
                package = scope.package,
                audience = scope.audience,
                policy = scope.policy
            }
        }

        if granted_at ~= nil then
            result.granted_at = granted_at
            result.expires_at = expires_at
            result.grant_reference = grant_reference
        end

        if withdrawal_reference ~= nil then
            result.withdrawal_reference = withdrawal_reference
        end

        return result
    end

    function api.snapshot()
        return snapshot()
    end

    function api.grant(now, expiry, evidence_reference)
        if not time_value(expiry)
            or not text(evidence_reference) then
            return validation("invalid_grant_arguments")
        end

        local problem = prepare(now)
        if problem then return problem end

        if state ~= "unissued" then
            return {
                status = "transition_rejected",
                reason = "grant_already_issued",
                state = state
            }
        end

        if expiry <= now then
            return validation("expiry_must_follow_grant")
        end

        state = "active"
        granted_at = now
        expires_at = expiry
        grant_reference = evidence_reference

        return {status = "grant_recorded", state = state}
    end

    function api.withdraw(now, evidence_reference)
        if not text(evidence_reference) then
            return validation("withdrawal_reference_required")
        end

        local problem = prepare(now)
        if problem then return problem end

        if state == "unissued" then
            return {
                status = "transition_rejected",
                reason = "no_issued_grant",
                state = state
            }
        end

        if state == "withdrawn" then
            return {
                status = "withdrawal_already_recorded",
                state = state
            }
        end

        state = "withdrawn"
        withdrawal_reference = evidence_reference

        return {status = "withdrawal_recorded", state = state}
    end

    function api.advance(now)
        local problem = prepare(now)
        if problem then return problem end

        return {status = "clock_advanced", state = state}
    end

    function api.check(now, requested_scope)
        local requested = binding(requested_scope)
        if not requested then
            return validation("invalid_request_binding")
        end

        local problem = prepare(now)
        if problem then return problem end

        local findings = {}
        if state == "unissued" then
            findings.permission_unissued = true
        elseif state == "withdrawn" then
            findings.permission_withdrawn = true
        elseif state == "expired" then
            findings.permission_expired = true
        end

        for _, field in ipairs({"package", "audience", "policy"}) do
            if requested[field] ~= scope[field] then
                findings[field .. "_mismatch"] = true
            end
        end

        local passed = next(findings) == nil

        return {
            status = "permission_assessed",
            implementation_version = VERSION,
            checked_at = now,
            state = state,
            permission_result = passed and "pass" or "refuse",
            findings = findings
        }
    end

    return api
end

function M.self_test()
    local checks = 0

    local function expect(condition)
        assert(condition, "lifecycle conformance check failed")
        checks = checks + 1
    end

    local function scope()
        return {
            package = "synthetic_exact_package",
            audience = "synthetic_public_forum",
            policy = "synthetic_policy"
        }
    end

    local machine = M.new(scope(), 0)
    expect(machine.check(0, scope()).permission_result == "refuse")
    expect(machine.grant(0, 2, "synthetic_grant").status == "grant_recorded")
    expect(machine.check(1, scope()).permission_result == "pass")
    expect(machine.check(2, scope()).findings.permission_expired == true)

    local withdrawn = M.new(scope(), 0)
    withdrawn.grant(0, 10, "synthetic_grant")
    withdrawn.withdraw(1, "synthetic_withdrawal")

    local changed = scope()
    changed.audience = "different_audience"

    local composite = withdrawn.check(1, changed)
    expect(composite.permission_result == "refuse")
    expect(composite.findings.permission_withdrawn == true)
    expect(composite.findings.audience_mismatch == true)
    expect(withdrawn.grant(2, 20, "new_claim").status
        == "transition_rejected")

    local snapshot = withdrawn.snapshot()
    snapshot.state = "active"
    snapshot.binding.audience = "different_audience"
    expect(withdrawn.snapshot().state == "withdrawn")
    expect(withdrawn.snapshot().binding.audience == scope().audience)
    expect(withdrawn.advance(0).reason == "regressed_time")

    -- Generated sequences over three event types and five time steps.
    local generated = 0
    local function sequence(prefix, depth)
        if depth == 5 then
            generated = generated + 1
            local instance = M.new(scope(), 0)
            instance.grant(0, 3, "synthetic_grant")
            local withdrawal_seen = false

            for step = 1, #prefix do
                local event = prefix[step]

                if event == "withdraw" then
                    instance.withdraw(step, "synthetic_withdrawal")
                    withdrawal_seen = true
                elseif event == "advance" then
                    instance.advance(step)
                else
                    local result = instance.check(step, scope())
                    if withdrawal_seen or step >= 3 then
                        expect(result.permission_result == "refuse")
                    end
                end

                local current = instance.snapshot()
                if withdrawal_seen then
                    expect(current.state == "withdrawn")
                end
                expect(current.last_time == step)
            end
            return
        end

        for _, event in ipairs({"withdraw", "advance", "check"}) do
            prefix[#prefix + 1] = event
            sequence(prefix, depth + 1)
            prefix[#prefix] = nil
        end
    end

    sequence({}, 0)

    return {
        status = "self_checks_passed",
        checks = checks,
        generated_sequences = generated,
        scope = "bounded_synthetic_permission_lifecycles"
    }
end

return M
