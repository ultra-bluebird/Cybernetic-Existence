-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: synthetic single-ingredient uncertainty experiment.
-- N = mass_g * component_per_100g / 100.
-- No physiological inference, personal data, random generator, or I/O.
-- No distributional coverage or scientific-validation claim.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local allowed = {
    schema_version = true,
    data_class = true,
    mass_g = true,
    component_per_100g = true,
    mass_sd_g = true,
    component_sd_per_100g = true,
    correlation = true,
    component_unit = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge and value < math.huge
end

local function unavailable(reason)
    return {
        schema_version = "synthetic-covariance-result-v1",
        status = "unavailable",
        reason = reason
    }
end

function M.evaluate(input)
    if not plain(input) then
        return unavailable("plain_input_required")
    end

    local count = 0
    for key in next, input do
        count = count + 1
        if count > 16 or not allowed[key] then
            return unavailable("unsupported_input_structure")
        end
    end

    if rawget(input, "schema_version") ~= "synthetic-covariance-input-v1"
        or rawget(input, "data_class") ~= "synthetic" then
        return unavailable("supported_synthetic_profile_required")
    end

    local unit = rawget(input, "component_unit")
    if unit ~= "g" and unit ~= "mg" and unit ~= "ug"
        and unit ~= "kcal_th" then
        return unavailable("supported_component_unit_required")
    end

    for _, name in ipairs({
        "mass_g", "component_per_100g",
        "mass_sd_g", "component_sd_per_100g"
    }) do
        local value = rawget(input, name)
        if not finite(value) or value < 0 then
            return unavailable("finite_nonnegative_inputs_required")
        end
    end

    local rho = rawget(input, "correlation")
    if not finite(rho) or rho < -1 or rho > 1 then
        return unavailable("correlation_within_unit_bounds_required")
    end

    local mass = rawget(input, "mass_g")
    local component = rawget(input, "component_per_100g")
    local mass_sd = rawget(input, "mass_sd_g")
    local component_sd = rawget(input, "component_sd_per_100g")

    local at_input_estimates = (mass / 100.0) * component
    local a = (component / 100.0) * mass_sd
    local b = (mass / 100.0) * component_sd
    local diagonal = a * a + b * b

    local full
    if rho < 0 then
        -- Nonnegative algebraic form reduces cancellation near rho = -1.
        full = (a - b) * (a - b) + 2 * (1 + rho) * a * b
    else
        full = diagonal + 2 * rho * a * b
    end

    if not finite(at_input_estimates)
        or not finite(diagonal) or not finite(full)
        or full < 0 then
        return unavailable("invalid_numeric_result")
    end

    local output = {
        schema_version = "synthetic-covariance-result-v1",
        status = "calculated",
        data_class = "synthetic",
        method = "first_order",
        component_unit = unit,
        component_at_input_estimates = at_input_estimates,
        variance_diagonal = diagonal,
        variance_full_covariance = full,
        standard_uncertainty_diagonal = math.sqrt(diagonal),
        standard_uncertainty_full = math.sqrt(full),
        correlation = rho,
        interval_status = "not_constructed",
        empirical_coverage = "not_evaluated",
        missing_contributions = "outside_this_experiment",
        model_discrepancy = "unquantified"
    }

    if diagonal > 0 then
        output.standard_uncertainty_ratio =
            math.sqrt(full / diagonal)
    else
        output.ratio_status = "unavailable_zero_diagonal_variance"
    end

    return output
end

function M.self_test()
    local input = {
        schema_version = "synthetic-covariance-input-v1",
        data_class = "synthetic",
        mass_g = 200,
        component_per_100g = 10,
        mass_sd_g = 20,
        component_sd_per_100g = 1,
        correlation = 0.5,
        component_unit = "g"
    }

    local result = M.evaluate(input)
    assert(result.component_at_input_estimates == 20)
    assert(result.variance_diagonal == 8)
    assert(result.variance_full_covariance == 12)

    input.correlation = 0
    result = M.evaluate(input)
    assert(result.variance_full_covariance == 8)

    input.correlation = -0.5
    result = M.evaluate(input)
    assert(result.variance_full_covariance == 4)

    input.correlation = -1
    result = M.evaluate(input)
    assert(result.variance_full_covariance == 0)
    assert(result.model_discrepancy == "unquantified")

    input.correlation = 2
    assert(M.evaluate(input).status == "unavailable")
    assert(M.evaluate(nil).status == "unavailable")

    return {
        status = "passed",
        scope = "embedded_synthetic_arithmetic_assertions"
    }
end

return M
