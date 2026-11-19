-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only, not identity, consent, or execution authority.
--
-- Conditional theorem-formula evaluation, not a DP mechanism or manager.
-- No network, file, device, persistence, or personal-data operations.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function invalid(reason)
    return {
        status = "validation_error",
        implementation_version = VERSION,
        reason = reason
    }
end

local function exp_minus_one(x)
    if x < 0.00001 then
        local term, total = x, x
        for n = 2, 8 do
            term = term * x / n
            total = total + term
        end
        return total
    end
    return math.exp(x) - 1
end

local function bound(epsilon, delta)
    return {
        epsilon = epsilon,
        delta = delta,
        status = delta < 1
            and "conditional_bound_computed"
            or "delta_bound_vacuous"
    }
end

function M.compute(parameters)
    if not plain(parameters) then
        return invalid("plain_parameter_record_required")
    end

    local allowed = {
        releases = true,
        epsilon = true,
        delta = true,
        slack_delta = true
    }

    for key in next, parameters do
        if not allowed[key] then
            return invalid("unknown_parameter")
        end
    end

    local k = parameters.releases
    local epsilon = parameters.epsilon
    local delta = parameters.delta
    local slack = parameters.slack_delta

    if not finite(k)
        or k < 1 or k > 1000000
        or k % 1 ~= 0 then
        return invalid("invalid_release_count")
    end

    if not finite(epsilon) or epsilon < 0 or epsilon > 1 then
        return invalid("epsilon_outside_supported_range")
    end

    if not finite(delta) or delta < 0 or delta >= 1 then
        return invalid("invalid_per_release_delta")
    end

    if not finite(slack) or slack <= 0 or slack >= 1 then
        return invalid("invalid_slack_delta")
    end

    local basic_epsilon = k * epsilon
    local basic_delta = k * delta

    local advanced_epsilon =
        math.sqrt(2 * k * math.log(1 / slack)) * epsilon
        + k * epsilon * exp_minus_one(epsilon)

    local advanced_delta = basic_delta + slack

    local result = {
        status = "formula_evaluated",
        implementation_version = VERSION,
        basic = bound(basic_epsilon, basic_delta),
        advanced = bound(advanced_epsilon, advanced_delta),
        scope = "homogeneous_conditional_composition",
        premises = {
            adjacency = "must_be_defined_and_compatible",
            per_release_guarantees = "not_verified",
            adaptive_conditions = "not_verified",
            mechanism_implementation = "not_verified"
        }
    }

    if advanced_delta < 1 then
        result.at_advanced_delta = {
            epsilon = math.min(basic_epsilon, advanced_epsilon),
            delta = advanced_delta
        }
    end

    return result
end

function M.self_test()
    local function near(a, b)
        return math.abs(a - b)
            <= 1e-12 * math.max(1, math.abs(a), math.abs(b))
    end

    local result = M.compute({
        releases = 100,
        epsilon = 0.01,
        delta = 0.00000001,
        slack_delta = 0.000001
    })

    assert(result.status == "formula_evaluated")
    assert(near(result.basic.epsilon, 1))
    assert(near(result.advanced.epsilon, 0.5357023440598613))
    assert(result.advanced.epsilon < result.basic.epsilon)

    local small = M.compute({
        releases = 1,
        epsilon = 0.01,
        delta = 0,
        slack_delta = 0.000001
    })
    assert(small.advanced.epsilon > small.basic.epsilon)

    local zero = M.compute({
        releases = 10,
        epsilon = 0,
        delta = 0,
        slack_delta = 0.000001
    })
    assert(zero.basic.epsilon == 0)
    assert(zero.advanced.epsilon == 0)

    local vacuous = M.compute({
        releases = 10,
        epsilon = 0.01,
        delta = 0.2,
        slack_delta = 0.01
    })
    assert(vacuous.advanced.status == "delta_bound_vacuous")
    assert(vacuous.at_advanced_delta == nil)

    assert(M.compute({
        releases = 0,
        epsilon = 0.01,
        delta = 0,
        slack_delta = 0.01
    }).reason == "invalid_release_count")

    return {
        status = "self_checks_passed",
        scope = "synthetic_composition_arithmetic"
    }
end

return M
