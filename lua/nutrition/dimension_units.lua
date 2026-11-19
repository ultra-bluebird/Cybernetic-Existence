-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: explicit mass, volume, and thermochemical energy conversion.
-- Density is a supplied food-specific claim, not verified evidence.
-- No physiology, nutrition requirement, gas, persistence, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local units = {
    g = { dimension = "mass", factor = 1.0 },
    kg = { dimension = "mass", factor = 1000.0 },
    mg = { dimension = "mass", factor = 0.001 },

    mL = { dimension = "volume", factor = 1.0 },
    L = { dimension = "volume", factor = 1000.0 },
    fl_oz_us = { dimension = "volume", factor = 29.5735295625 },
    fl_oz_imperial = { dimension = "volume", factor = 28.4130625 },

    J = { dimension = "energy", factor = 1.0 },
    kJ = { dimension = "energy", factor = 1000.0 },
    kcal_th = { dimension = "energy", factor = 4184.0 }
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, allowed)
    if not plain(value) then return false end
    local count = 0
    for key in next, value do
        count = count + 1
        if count > 16 or not allowed[key] then return false end
    end
    return true
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge and value < math.huge
end

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 160
end

local function unavailable(reason)
    return {
        schema_version = "dimension-conversion-v1",
        status = "unavailable",
        reason = reason,
        evidence_verification = "not_performed"
    }
end

function M.convert(quantity, target_unit, density)
    if not shape(quantity, {
        value = true, unit = true,
        food_reference = true, preparation_state = true
    }) then
        return unavailable("invalid_quantity_shape")
    end

    local value = rawget(quantity, "value")
    local source_unit = rawget(quantity, "unit")

    if not finite(value) or value < 0 then
        return unavailable("finite_nonnegative_quantity_required")
    end
    if type(source_unit) ~= "string" or not units[source_unit]
        or type(target_unit) ~= "string" or not units[target_unit] then
        return unavailable("explicit_supported_units_required")
    end

    local source = units[source_unit]
    local target = units[target_unit]
    local converted
    local density_source
    local density_value
    local food_reference
    local preparation_state

    if source.dimension == target.dimension then
        if density ~= nil then
            return unavailable("density_not_applicable_to_same_dimension")
        end

        if source_unit == target_unit then
            converted = value
        else
            converted = value * (source.factor / target.factor)
        end
    else
        local mass_volume =
            (source.dimension == "mass" and target.dimension == "volume")
            or
            (source.dimension == "volume" and target.dimension == "mass")

        if not mass_volume then
            return unavailable("dimension_conversion_prohibited")
        end

        if not shape(density, {
            value_g_per_mL = true,
            food_reference = true,
            preparation_state = true,
            source_reference = true
        }) then
            return unavailable("explicit_density_record_required")
        end

        density_value = rawget(density, "value_g_per_mL")
        food_reference = rawget(quantity, "food_reference")
        preparation_state = rawget(quantity, "preparation_state")
        density_source = rawget(density, "source_reference")

        if not finite(density_value) or density_value <= 0 then
            return unavailable("positive_finite_density_required")
        end

        if not text(food_reference) or not text(preparation_state)
            or not text(density_source) then
            return unavailable("food_preparation_and_density_source_required")
        end

        if food_reference ~= rawget(density, "food_reference")
            or preparation_state ~= rawget(density, "preparation_state") then
            return unavailable("density_context_mismatch")
        end

        -- Order avoids constructing a large intermediate base quantity.
        if source.dimension == "volume" then
            converted =
                (value * (source.factor / target.factor)) * density_value
        else
            converted =
                (value * (source.factor / target.factor)) / density_value
        end
    end

    if not finite(converted) then
        return unavailable("numeric_overflow")
    end
    if value > 0 and converted == 0 then
        return unavailable("numeric_underflow")
    end
    if converted == 0 then converted = 0.0 end

    local output = {
        schema_version = "dimension-conversion-v1",
        status = "converted",
        value = converted,
        unit = target_unit,
        dimension = target.dimension,
        source_value = value,
        source_unit = source_unit,
        evidence_verification = "not_performed",
        uncertainty_status = "not_propagated"
    }

    if density_source ~= nil then
        output.density_source_reference = density_source
        output.density_g_per_mL = density_value
        output.food_reference = food_reference
        output.preparation_state = preparation_state
    end

    return output
end

function M.self_test()
    assert(M.convert({ value = 1, unit = "kcal_th" }, "J").value == 4184)
    assert(M.convert({ value = 1, unit = "kg" }, "g").value == 1000)

    assert(M.convert({ value = 1, unit = "oz" }, "mL").status
        == "unavailable")
    assert(M.convert({ value = 1, unit = "g" }, "J").status
        == "unavailable")
    assert(M.convert({ value = 100, unit = "mL" }, "g").status
        == "unavailable")

    local quantity = {
        value = 100, unit = "mL",
        food_reference = "synthetic-food",
        preparation_state = "cooked"
    }
    local density = {
        value_g_per_mL = 0.8,
        food_reference = "synthetic-food",
        preparation_state = "cooked",
        source_reference = "synthetic-density"
    }

    assert(M.convert(quantity, "g", density).value == 80)

    density.preparation_state = "raw"
    assert(M.convert(quantity, "g", density).reason
        == "density_context_mismatch")

    assert(M.convert({ value = 0, unit = "g" }, "kg").value == 0)

    return {
        status = "passed",
        scope = "embedded_synthetic_assertions"
    }
end

return M
