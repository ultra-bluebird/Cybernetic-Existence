-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: one-nutrient recipe subtotal and ingredient-mass coverage.
-- Inputs and source labels are supplied claims, not verified measurements.
-- No persistence, networking, physiology, gas conversion, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge and value < math.huge
end

local function nonnegative(value)
    return finite(value) and value >= 0
end

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 128
end

local function shape(value, allowed)
    if not plain(value) then return false end
    local count = 0
    for key in next, value do
        count = count + 1
        if count > 32 or not allowed[key] then return false end
    end
    return true
end

local function fail(reason)
    return {
        schema_version = "recipe-nutrient-coverage-v1",
        est_status = "unavailable",
        est_reason = reason,
        est_source_verification = "not_performed"
    }
end

local function sequence(value)
    if not plain(value) then return nil end
    local count = 0
    for key in next, value do
        if type(key) ~= "number" or key % 1 ~= 0
            or key < 1 or key > 1000 then
            return nil
        end
        count = count + 1
    end
    for index = 1, count do
        if rawget(value, index) == nil then return nil end
    end
    if count == 0 then return nil end
    return count
end

function M.evaluate(input)
    if not shape(input, {
        schema_version = true,
        nutrient_name = true,
        nutrient_unit = true,
        calculation_path = true,
        ingredients = true,
        final_yield_g = true
    }) then
        return fail("invalid_input_shape")
    end

    if rawget(input, "schema_version") ~= "recipe-nutrient-input-v1" then
        return fail("unsupported_schema")
    end

    if not text(rawget(input, "nutrient_name"))
        or not text(rawget(input, "nutrient_unit")) then
        return fail("nutrient_identity_and_unit_required")
    end

    local path = rawget(input, "calculation_path")
    if path ~= "direct_prepared" and path ~= "ingredient_retention" then
        return fail("unsupported_calculation_path")
    end

    local ingredients = rawget(input, "ingredients")
    local count = sequence(ingredients)
    if count == nil then return fail("bounded_ingredient_sequence_required") end

    local final_yield = rawget(input, "final_yield_g")
    if final_yield ~= nil and
        (not finite(final_yield) or final_yield <= 0) then
        return fail("invalid_final_yield")
    end

    local total_mass, covered_mass, subtotal = 0.0, 0.0, 0.0
    local all_mass_known = true
    local unresolved = {}
    local available_count = 0

    for index = 1, count do
        local ingredient = rawget(ingredients, index)
        if not shape(ingredient, {
            edible_mass_g = true,
            nutrient_per_100g = true,
            nutrient_state = true,
            retention_factor = true,
            retention_state = true,
            source_reference = true
        }) then
            return fail("invalid_ingredient_shape")
        end

        local mass = rawget(ingredient, "edible_mass_g")
        local state = rawget(ingredient, "nutrient_state")
        local density = rawget(ingredient, "nutrient_per_100g")
        local retention_state = rawget(ingredient, "retention_state")
        local retention = rawget(ingredient, "retention_factor")

        if not text(rawget(ingredient, "source_reference")) then
            return fail("ingredient_provenance_required")
        end

        if mass ~= nil and not nonnegative(mass) then
            return fail("invalid_edible_mass")
        end

        if state == "known" then
            if not nonnegative(density) then
                return fail("invalid_known_nutrient")
            end
        elseif state == "unknown" then
            if density ~= nil then
                return fail("unknown_nutrient_contains_value")
            end
        else
            return fail("invalid_nutrient_state")
        end

        if path == "direct_prepared" then
            if retention ~= nil or retention_state ~= nil then
                return fail("retention_not_permitted_on_prepared_path")
            end
            retention = 1.0
        else
            if retention_state == "known" then
                if not finite(retention)
                    or retention < 0 or retention > 1 then
                    return fail("invalid_retention_factor")
                end
            elseif retention_state == "unknown" then
                if retention ~= nil then
                    return fail("unknown_retention_contains_value")
                end
            else
                return fail("retention_state_required")
            end
        end

        if mass == nil then
            all_mass_known = false
        else
            total_mass = total_mass + (mass + 0.0)
        end

        if mass ~= nil and state == "known" and retention ~= nil then
            local amount = ((mass + 0.0) / 100.0) * density * retention
            subtotal = subtotal + amount
            covered_mass = covered_mass + mass
            available_count = available_count + 1
        else
            unresolved[#unresolved + 1] = index
        end

        if not finite(total_mass) or not finite(covered_mass)
            or not finite(subtotal) then
            return fail("numeric_overflow")
        end
    end

    local output = {
        schema_version = "recipe-nutrient-coverage-v1",
        est_status = "calculated",
        est_nutrient_name = rawget(input, "nutrient_name"),
        est_nutrient_unit = rawget(input, "nutrient_unit"),
        est_known_batch_subtotal = subtotal,
        est_available_contributor_count = available_count,
        est_total_contributor_count = count,
        est_unresolved_contributors = unresolved,
        est_coverage_basis = "reported_input_edible_mass",
        est_mass_coverage_status = "unavailable",
        est_complete_total_status = "unavailable",
        est_source_verification = "not_performed",
        est_uncertainty_status = "not_quantified"
    }

    if all_mass_known then
        output.est_reported_input_edible_mass_g = total_mass
        output.est_covered_input_edible_mass_g = covered_mass
        if total_mass > 0 then
            output.est_mass_coverage_status = "calculated"
            output.est_mass_coverage_fraction = covered_mass / total_mass
        end
    end

    if #unresolved == 0 then
        output.est_complete_total_status =
            "all_reported_contributors_accounted"
    end

    if final_yield ~= nil then
        local concentration = (subtotal / final_yield) * 100.0
        if not finite(concentration) then
            return fail("numeric_overflow")
        end
        output.est_final_yield_g = final_yield
        output.est_known_subtotal_per_100g_finished = concentration
    end

    return output
end

return M
