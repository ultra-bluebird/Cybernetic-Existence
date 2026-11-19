-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: dietary-energy units and missing-aware subtotals.
-- kcal means thermochemical kilocalorie throughout this module.
-- No requirement estimation, physiology, gas conversion, or device access.
-- No filesystem, network, clock, persistence, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local joules_per_unit = {
    kcal = 4184.0,
    kJ = 1000.0,
    J = 1.0
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function supported_unit(value)
    return type(value) == "string" and joules_per_unit[value] ~= nil
end

local function finite_nonnegative(value)
    return type(value) == "number"
        and value == value
        and value >= 0
        and value < math.huge
end

local function unavailable(reason)
    return {
        schema_version = "dietary-energy-result-v1",
        status = "unavailable",
        reason = reason
    }
end

local function quantity_valid(quantity)
    if not plain(quantity) then return false, "plain_quantity_required" end

    local count = 0
    for key in next, quantity do
        count = count + 1
        if count > 3 or
            (key ~= "value" and key ~= "unit" and key ~= "state") then
            return false, "unsupported_quantity_field"
        end
    end

    if not supported_unit(rawget(quantity, "unit")) then
        return false, "unsupported_unit"
    end

    local state = rawget(quantity, "state")
    local value = rawget(quantity, "value")

    if state == "unknown" then
        if value ~= nil then return false, "unknown_contains_value" end
    elseif state == "known" then
        if not finite_nonnegative(value) then
            return false, "finite_nonnegative_value_required"
        end
    else
        return false, "explicit_known_or_unknown_state_required"
    end

    return true
end

function M.convert(quantity, target_unit)
    if not supported_unit(target_unit) then
        return unavailable("unsupported_target_unit")
    end

    local valid, reason = quantity_valid(quantity)
    if not valid then return unavailable(reason) end

    local source_unit = rawget(quantity, "unit")
    if rawget(quantity, "state") == "unknown" then
        return {
            schema_version = "dietary-energy-result-v1",
            status = "unknown",
            state = "unknown",
            unit = target_unit,
            source_unit = source_unit,
            convention = "thermochemical"
        }
    end

    local input_value = rawget(quantity, "value")
    local value = input_value

    if source_unit ~= target_unit then
        local factor =
            joules_per_unit[source_unit] / joules_per_unit[target_unit]
        value = input_value * factor
    end

    if not finite_nonnegative(value) then
        return unavailable("numeric_overflow")
    end

    if input_value > 0 and value == 0 then
        return unavailable("numeric_underflow")
    end

    if value == 0 then value = 0.0 end

    return {
        schema_version = "dietary-energy-result-v1",
        status = "converted",
        state = "known",
        value = value,
        unit = target_unit,
        source_value = input_value,
        source_unit = source_unit,
        convention = "thermochemical",
        interpretation = "unit_conversion_only"
    }
end

function M.sum(quantities, target_unit)
    if not supported_unit(target_unit) then
        return unavailable("unsupported_target_unit")
    end
    if not plain(quantities) then
        return unavailable("plain_quantity_sequence_required")
    end

    local count = 0
    for key in next, quantities do
        if type(key) ~= "number" or key % 1 ~= 0
            or key < 1 or key > 1000 then
            return unavailable("bounded_integer_sequence_required")
        end
        count = count + 1
    end

    for index = 1, count do
        if rawget(quantities, index) == nil then
            return unavailable("contiguous_sequence_required")
        end
    end

    local subtotal = 0.0
    local known_count, unknown_count = 0, 0

    -- Fixed input order; no claim of cross-build bitwise reproducibility.
    for index = 1, count do
        local converted = M.convert(rawget(quantities, index), target_unit)

        if converted.status == "unavailable" then
            converted.invalid_contributor_index = index
            return converted
        elseif converted.state == "unknown" then
            unknown_count = unknown_count + 1
        else
            subtotal = subtotal + converted.value
            if not finite_nonnegative(subtotal) then
                return unavailable("subtotal_overflow")
            end
            known_count = known_count + 1
        end
    end

    local completeness = "all_submitted_values_known"
    if count == 0 then
        completeness = "no_submitted_values"
    elseif known_count == 0 then
        completeness = "no_known_values"
    elseif unknown_count > 0 then
        completeness = "partial_known_subtotal"
    end

    return {
        schema_version = "dietary-energy-subtotal-v1",
        status = "accounted",
        known_subtotal = subtotal,
        unit = target_unit,
        known_count = known_count,
        unknown_count = unknown_count,
        submitted_count = count,
        completeness = completeness,
        scope = "submitted_quantities_only",
        convention = "thermochemical",
        physiological_interpretation = "not_performed"
    }
end

function M.self_test()
    local one = M.convert(
        { state = "known", value = 1, unit = "kcal" }, "J")
    assert(one.value == 4184)

    local zero = M.convert(
        { state = "known", value = 0, unit = "kcal" }, "kJ")
    assert(zero.value == 0)

    local missing = M.convert(
        { state = "unknown", unit = "kcal" }, "J")
    assert(missing.state == "unknown")
    assert(missing.value == nil)

    local total = M.sum({
        { state = "known", value = 100, unit = "kcal" },
        { state = "known", value = 4184, unit = "J" },
        { state = "unknown", unit = "kJ" }
    }, "kcal")

    assert(total.known_subtotal == 101)
    assert(total.unknown_count == 1)
    assert(total.completeness == "partial_known_subtotal")

    assert(M.convert(
        { state = "known", value = -1, unit = "kcal" }, "J"
    ).status == "unavailable")

    assert(M.convert(
        { state = "known", value = 1, unit = "kcal" }, "gas"
    ).status == "unavailable")

    return { status = "passed", scope = "embedded_synthetic_assertions" }
end

return M
