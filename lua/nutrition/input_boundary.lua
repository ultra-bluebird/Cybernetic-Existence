-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: narrow nutritional-input projection.
-- Optional self-description and access preferences are not read.
-- No identity inference, model selection, scoring, persistence, or action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local allowed_nutrition_fields = {
    schema_version = true,
    consumed_edible_mass_g = true,
    nutrient_per_100g = true,
    nutrient_unit = true,
    nutrient_name = true,
    preparation_state = true,
    composition_reference = true,
    composition_revision = true
}

local preparation_states = {
    raw = true,
    cooked = true,
    processed = true,
    mixed_recipe = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function finite_nonnegative(value)
    return type(value) == "number"
        and value == value
        and value >= 0 and value < math.huge
end

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 128
end

local function local_reference(value)
    return type(value) == "string" and #value <= 128
        and value:match("^local:[A-Za-z0-9_-]+$") ~= nil
end

local function unavailable(reason)
    return {
        schema_version = "nutrition-input-projection-v1",
        status = "unavailable",
        reason = reason,
        source_verification = "not_performed"
    }
end

function M.project(envelope)
    if not plain(envelope) then
        return unavailable("plain_envelope_required")
    end

    -- No enumeration of the envelope and no access to other compartments.
    if rawget(envelope, "consent_local_nutrition_processing") ~= true then
        return unavailable("processing_permission_absent")
    end

    local nutrition = rawget(envelope, "nutrition_input")
    if not plain(nutrition) then
        return unavailable("plain_nutrition_record_required")
    end

    local count = 0
    for key in next, nutrition do
        count = count + 1
        if count > 16 then
            return unavailable("nutrition_field_budget_exceeded")
        end
        if not allowed_nutrition_fields[key] then
            return unavailable("unsupported_nutrition_field")
        end
    end

    if rawget(nutrition, "schema_version") ~= "composition-input-v1" then
        return unavailable("unsupported_nutrition_schema")
    end

    local mass = rawget(nutrition, "consumed_edible_mass_g")
    local density = rawget(nutrition, "nutrient_per_100g")
    if not finite_nonnegative(mass)
        or not finite_nonnegative(density) then
        return unavailable("finite_nonnegative_quantities_required")
    end

    local name = rawget(nutrition, "nutrient_name")
    local unit = rawget(nutrition, "nutrient_unit")
    local preparation = rawget(nutrition, "preparation_state")
    local source = rawget(nutrition, "composition_reference")
    local revision = rawget(nutrition, "composition_revision")

    if not text(name) or not text(unit) or not text(revision)
        or not local_reference(source)
        or type(preparation) ~= "string"
        or not preparation_states[preparation] then
        return unavailable("composition_metadata_required")
    end

    return {
        schema_version = "nutrition-input-projection-v1",
        status = "projected",
        source_verification = "not_performed",
        calculation_input = {
            schema_version = "composition-input-v1",
            consumed_edible_mass_g = mass == 0 and 0.0 or mass,
            nutrient_per_100g = density == 0 and 0.0 or density,
            nutrient_name = name,
            nutrient_unit = unit,
            preparation_state = preparation,
            composition_reference = source,
            composition_revision = revision
        }
    }
end

return M
