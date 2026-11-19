-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: first-order uncertainty for consumed mass * energy density.
-- Local calculation only; no logging, persistence, or device access.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local allowed = {
    comp_consumed_mass_g = true,
    comp_energy_density_kcal_per_g = true,
    unc_mass_sd_g = true,
    unc_density_sd_kcal_per_g = true,
    unc_mass_density_correlation = true,
    unc_independent_model_sd_kcal = true
}

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
end

local function unavailable(reason)
    return {
        est_status = "unavailable",
        est_reason = reason,
        est_method = "first_order_full_covariance"
    }
end

function M.evaluate(input)
    if type(input) ~= "table" or getmetatable(input) ~= nil then
        return unavailable("plain_input_record_required")
    end

    local count = 0
    for key in next, input do
        count = count + 1
        if count > 16 then
            return unavailable("input_field_limit_exceeded")
        end
        if not allowed[key] then
            return unavailable("unsupported_input_field")
        end
    end

    local mass = rawget(input, "comp_consumed_mass_g")
    local density = rawget(input, "comp_energy_density_kcal_per_g")
    local mass_sd = rawget(input, "unc_mass_sd_g")
    local density_sd = rawget(input, "unc_density_sd_kcal_per_g")
    local rho = rawget(input, "unc_mass_density_correlation")
    local model_sd = rawget(input, "unc_independent_model_sd_kcal")

    for _, name in ipairs({
        "comp_consumed_mass_g",
        "comp_energy_density_kcal_per_g",
        "unc_mass_sd_g",
        "unc_density_sd_kcal_per_g"
    }) do
        local value = rawget(input, name)
        if not finite(value) or value < 0 then
            return unavailable("missing_or_invalid_nonnegative_input")
        end
    end

    if not finite(rho) or rho < -1 or rho > 1 then
        return unavailable("correlation_required_within_unit_bounds")
    end

    if model_sd ~= nil and (not finite(model_sd) or model_sd < 0) then
        return unavailable("invalid_independent_model_sd")
    end

    local a = density * mass_sd
    local b = mass * density_sd
    local diagonal = a * a + b * b

    -- Algebraically equivalent to a^2 + b^2 + 2*rho*a*b,
    -- with a nonnegative form for negative correlation.
    local full
    if rho < 0 then
        full = (a - b) * (a - b) + 2 * (1 + rho) * a * b
    else
        full = diagonal + 2 * rho * a * b
    end

    local energy = mass * density
    if not finite(energy) or not finite(diagonal) or not finite(full) then
        return unavailable("numeric_overflow")
    end

    local output = {
        est_status = "calculated",
        est_method = "first_order_full_covariance",
        est_energy_at_input_means_kcal = energy,
        unc_input_variance_diagonal_kcal2 = diagonal,
        unc_input_variance_full_kcal2 = full,
        unc_input_sd_full_kcal = math.sqrt(full),
        unc_model_discrepancy = "unquantified",
        unc_prediction_interval_status = "not_constructed",
        unc_covariance_evidence_status = "supplied_not_verified"
    }

    if model_sd ~= nil then
        local total = full + model_sd * model_sd
        if not finite(total) then
            return unavailable("numeric_overflow")
        end
        output.unc_model_discrepancy =
            "supplied_independent_additive_sd"
        output.unc_combined_variance_kcal2 = total
        output.unc_combined_sd_kcal = math.sqrt(total)
    end

    return output
end

return M
