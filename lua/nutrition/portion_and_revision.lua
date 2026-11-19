-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: portion bounds and composition revision planning.
-- No invented uncertainty priors, persistence, network, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local portion_bases = {
    weighed = true,
    household_measure = true,
    package_label = true,
    visual_estimate = true,
    unknown_basis = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, allowed)
    if not plain(value) then return false end
    local count = 0
    for key in next, value do
        count = count + 1
        if count > 24 or not allowed[key] then return false end
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
        schema_version = "portion-revision-result-v1",
        status = "unavailable",
        reason = reason,
        evidence_verification = "not_performed"
    }
end

local function composition(record)
    if not shape(record, {
        source = true, release = true, record_revision = true,
        food_reference = true, preparation_state = true,
        nutrient_name = true, nutrient_unit = true,
        nutrient_per_100g = true
    }) then
        return false
    end

    for _, field in ipairs({
        "source", "release", "record_revision", "food_reference",
        "preparation_state", "nutrient_name", "nutrient_unit"
    }) do
        if not text(rawget(record, field)) then return false end
    end

    local value = rawget(record, "nutrient_per_100g")
    return finite(value) and value >= 0
end

function M.contribution(input)
    if not shape(input, {
        schema_version = true,
        portion_basis = true,
        portion_source = true,
        consumed_mass_low_g = true,
        consumed_mass_high_g = true,
        composition = true
    }) then
        return unavailable("invalid_contribution_shape")
    end

    if rawget(input, "schema_version") ~= "portion-contribution-input-v1" then
        return unavailable("unsupported_schema")
    end

    local basis = rawget(input, "portion_basis")
    if type(basis) ~= "string" or not portion_bases[basis]
        or not text(rawget(input, "portion_source")) then
        return unavailable("portion_provenance_required")
    end

    local low = rawget(input, "consumed_mass_low_g")
    local high = rawget(input, "consumed_mass_high_g")
    if not finite(low) or not finite(high)
        or low < 0 or high < low then
        return unavailable("consumed_mass_bounds_required")
    end

    local record = rawget(input, "composition")
    if not composition(record) then
        return unavailable("invalid_composition_record")
    end

    local density = rawget(record, "nutrient_per_100g") + 0.0
    local amount_low = ((low + 0.0) / 100.0) * density
    local amount_high = ((high + 0.0) / 100.0) * density

    if not finite(amount_low) or not finite(amount_high) then
        return unavailable("numeric_overflow")
    end

    return {
        schema_version = "portion-revision-result-v1",
        status = "calculated",
        nutrient_name = rawget(record, "nutrient_name"),
        nutrient_unit = rawget(record, "nutrient_unit"),
        contribution_low = amount_low == 0 and 0.0 or amount_low,
        contribution_high = amount_high == 0 and 0.0 or amount_high,
        portion_basis = basis,
        uncertainty_kind = "supplied_portion_arithmetic_bounds",
        composition_uncertainty = "not_propagated",
        complete_uncertainty = "not_established",
        composition_release = rawget(record, "release"),
        composition_revision = rawget(record, "record_revision"),
        evidence_verification = "not_performed"
    }
end

function M.plan_update(old_record, new_record)
    if not composition(old_record) or not composition(new_record) then
        return unavailable("valid_composition_snapshots_required")
    end

    for _, field in ipairs({
        "source", "food_reference", "preparation_state",
        "nutrient_name", "nutrient_unit"
    }) do
        if rawget(old_record, field) ~= rawget(new_record, field) then
            return {
                schema_version = "portion-revision-result-v1",
                status = "match_review_required",
                historical_estimate_action = "preserve",
                recomputation_authorized = false
            }
        end
    end

    local same_revision =
        rawget(old_record, "record_revision") ==
        rawget(new_record, "record_revision")
    local same_value =
        rawget(old_record, "nutrient_per_100g") ==
        rawget(new_record, "nutrient_per_100g")
    local same_release =
        rawget(old_record, "release") == rawget(new_record, "release")

    local status
    if same_revision and not same_value then
        status = "revision_content_discrepancy"
    elseif same_revision and same_release then
        status = "no_nutrient_update_detected"
    else
        status = "new_snapshot_available"
    end

    return {
        schema_version = "portion-revision-result-v1",
        status = status,
        historical_estimate_action = "preserve",
        current_estimate_action = "separate_review_before_recomputation",
        recomputation_authorized = false,
        old_release = rawget(old_record, "release"),
        new_release = rawget(new_record, "release"),
        evidence_verification = "not_performed"
    }
end

return M
