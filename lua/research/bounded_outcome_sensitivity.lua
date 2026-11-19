-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only, not identity, consent, or execution authority.
--
-- Pure analysis utility. No network, file, device, or persistence access.
-- Computes sample-completion bounds, not population confidence intervals.
-- Lua 5.1+.

local M = {}

local MAX_COUNT = 1000000
local MAX_MAGNITUDE = 1000000

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function count(value)
    return finite(value)
        and value >= 0
        and value <= MAX_COUNT
        and value % 1 == 0
end

local function reference(value)
    return type(value) == "string"
        and #value > 0
        and #value <= 128
        and value:match("%S") ~= nil
        and value:find("[%z\1-\31\127]") == nil
end

local function error_result(reason)
    return {
        status = "validation_error",
        reason = reason
    }
end

local function allowed_fields(record, allowed)
    for key in next, record do
        if not allowed[key] then
            return false
        end
    end
    return true
end

function M.arm(summary, outcome, restriction)
    if not plain(summary) or not plain(outcome) then
        return error_result("plain_records_required")
    end

    if not allowed_fields(summary, {
        total = true,
        observed = true,
        observed_sum = true
    }) or not allowed_fields(outcome, {
        lower = true,
        upper = true
    }) then
        return error_result("unknown_field")
    end

    local n = summary.total
    local observed = summary.observed
    local sum = summary.observed_sum
    local lower = outcome.lower
    local upper = outcome.upper

    if not count(n) or n == 0
        or not count(observed) or observed > n then
        return error_result("invalid_counts")
    end

    if not finite(lower) or not finite(upper)
        or math.abs(lower) > MAX_MAGNITUDE
        or math.abs(upper) > MAX_MAGNITUDE
        or lower >= upper then
        return error_result("invalid_outcome_bounds")
    end

    if not finite(sum)
        or sum < observed * lower
        or sum > observed * upper then
        return error_result("observed_sum_outside_bounds")
    end

    if observed == 0 and sum ~= 0 then
        return error_result("zero_observations_require_zero_sum")
    end

    local missing_lower = lower
    local missing_upper = upper
    local assumption = "bounded_outcome_only"

    if restriction ~= nil then
        if not plain(restriction)
            or not allowed_fields(restriction, {
                lower_mean = true,
                upper_mean = true,
                assumption_reference = true
            }) then
            return error_result("invalid_restriction_record")
        end

        missing_lower = restriction.lower_mean
        missing_upper = restriction.upper_mean

        if not finite(missing_lower)
            or not finite(missing_upper)
            or missing_lower < lower
            or missing_upper > upper
            or missing_lower > missing_upper
            or not reference(restriction.assumption_reference) then
            return error_result("invalid_missing_mean_restriction")
        end

        assumption = restriction.assumption_reference
    end

    local missing = n - observed
    local bound_lower = (sum + missing * missing_lower) / n
    local bound_upper = (sum + missing * missing_upper) / n

    return {
        status = "computed",
        scope = "sample_missing_value_completions",
        total = n,
        observed = observed,
        response_fraction = observed / n,
        lower = bound_lower,
        upper = bound_upper,
        width = bound_upper - bound_lower,
        outcome_lower = lower,
        outcome_upper = upper,
        assumption_reference = assumption
    }
end

function M.contrast(menu, automatic)
    if not plain(menu) or not plain(automatic)
        or menu.status ~= "computed"
        or automatic.status ~= "computed" then
        return error_result("computed_arm_results_required")
    end

    for _, arm in ipairs({menu, automatic}) do
        if not finite(arm.lower)
            or not finite(arm.upper)
            or arm.lower > arm.upper
            or arm.scope ~= "sample_missing_value_completions" then
            return error_result("invalid_arm_result")
        end
    end

    if menu.outcome_lower ~= automatic.outcome_lower
        or menu.outcome_upper ~= automatic.outcome_upper then
        return error_result("common_outcome_scale_required")
    end

    local lower = menu.lower - automatic.upper
    local upper = menu.upper - automatic.lower

    return {
        status = "computed",
        scope = "sample_contrast_completion_bounds",
        lower = lower,
        upper = upper,
        width = upper - lower,
        menu_assumption = menu.assumption_reference,
        automatic_assumption = automatic.assumption_reference
    }
end

function M.self_test()
    local function near(a, b)
        return math.abs(a - b) <= 1e-12
    end

    local range = {lower = 0, upper = 1}

    local menu = M.arm({
        total = 10, observed = 8, observed_sum = 2.4
    }, range)

    local automatic = M.arm({
        total = 10, observed = 5, observed_sum = 3
    }, range)

    assert(near(menu.lower, 0.24))
    assert(near(menu.upper, 0.44))

    local result = M.contrast(menu, automatic)
    assert(near(result.lower, -0.56))
    assert(near(result.upper, 0.14))
    assert(near(result.width, 0.70))

    local restricted_menu = M.arm({
        total = 10, observed = 8, observed_sum = 2.4
    }, range, {
        lower_mean = 0,
        upper_mean = 0.4,
        assumption_reference = "synthetic_menu_assumption"
    })

    local restricted_auto = M.arm({
        total = 10, observed = 5, observed_sum = 3
    }, range, {
        lower_mean = 0.4,
        upper_mean = 1,
        assumption_reference = "synthetic_auto_assumption"
    })

    local restricted = M.contrast(restricted_menu, restricted_auto)
    assert(near(restricted.width, 0.38))
    assert(restricted.lower >= result.lower)
    assert(restricted.upper <= result.upper)

    local missing = M.arm({
        total = 10, observed = 0, observed_sum = 0
    }, range)
    assert(missing.lower == 0 and missing.upper == 1)

    local complete = M.arm({
        total = 10, observed = 10, observed_sum = 4
    }, range)
    assert(near(complete.lower, 0.4))
    assert(near(complete.upper, 0.4))

    local invalid = M.arm({
        total = 10, observed = 11, observed_sum = 4
    }, range)
    assert(invalid.status == "validation_error")

    return {
        status = "self_checks_passed",
        scope = "synthetic_arithmetic_and_validation_cases"
    }
end

return M
