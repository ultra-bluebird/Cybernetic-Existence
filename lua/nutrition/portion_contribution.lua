-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Bounds must represent consumed edible mass, not purchased or served mass.

local C = require("lua.nutrition.portion_constants").get()
local V = require("lua.nutrition.composition_record")
local M = {}

function M.contribution(input)
    local findings = {}
    local fields = {
        "schema_version", "portion_basis", "portion_source",
        "consumed_mass_low_g", "consumed_mass_high_g", "composition"
    }

    if not V.shape(input, fields, findings, "input") then
        return V.unavailable("contribution", findings)
    end

    if rawget(input, "schema_version") ~=
        C.SCHEMA_VERSIONS.contribution_input then
        V.add(findings, "unsupported_contribution_schema",
            "input.schema_version")
    end

    local basis = rawget(input, "portion_basis")
    if basis ~= nil then
        if type(basis) ~= "string" or not C.PORTION_BASES[basis] then
            V.add(findings, "unsupported_portion_basis", "input.portion_basis")
        elseif basis == "unknown_basis" then
            V.add(findings, "portion_basis_unknown", "input.portion_basis")
        end
    end

    local source = rawget(input, "portion_source")
    if source ~= nil and not V.text(source) then
        V.add(findings, "invalid_portion_source", "input.portion_source")
    end

    local low = rawget(input, "consumed_mass_low_g")
    local high = rawget(input, "consumed_mass_high_g")

    for _, field in ipairs({ "consumed_mass_low_g", "consumed_mass_high_g" }) do
        local value = rawget(input, field)
        if value ~= nil then
            if not V.finite(value) then
                V.add(findings, "consumed_mass_nonfinite", "input." .. field)
            elseif value < 0 then
                V.add(findings, "consumed_mass_negative", "input." .. field)
            elseif value > C.MAX_PORTION_MASS_G then
                V.add(findings, "consumed_mass_outside_profile", "input." .. field)
            end
        end
    end

    if V.finite(low) and V.finite(high) and high < low then
        V.add(findings, "consumed_mass_inverted", "input.consumed_mass_bounds")
    end

    local record = V.validate(
        rawget(input, "composition"), findings, "input.composition")

    if #findings > 0 then
        return V.unavailable("contribution", findings)
    end

    local nutrient_per_100g = record.nutrient_per_100g
    local amount_low = (low / 100.0) * nutrient_per_100g
    local amount_high = (high / 100.0) * nutrient_per_100g

    if not V.finite(amount_low) or not V.finite(amount_high) then
        V.add(findings, "numeric_overflow", "output.contribution")
        return V.unavailable("contribution", findings)
    end

    local bounds_kind = "interval"
    if low == high then bounds_kind = "point" end

    return {
        kind = "contribution",
        schema_version = C.SCHEMA_VERSIONS.contribution_output,
        status = "calculated",
        findings = {},
        contribution_low = V.normalize_zero(amount_low),
        contribution_high = V.normalize_zero(amount_high),
        bounds_kind = bounds_kind,
        portion_basis = basis,
        portion_source = source,
        consumed_mass_low_g = V.normalize_zero(low),
        consumed_mass_high_g = V.normalize_zero(high),
        composition_snapshot = record,
        uncertainty_kind = "supplied_portion_arithmetic_bounds",
        composition_uncertainty = "not_propagated",
        complete_uncertainty = "not_established",
        evidence_verification = "not_performed"
    }
end

return M
