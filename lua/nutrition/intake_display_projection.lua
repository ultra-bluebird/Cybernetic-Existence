-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: optional renderer projection over nutritional summaries.
-- No I/O, raw-event processing, model evaluation, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local nutrient_specs = {
    {
        field = "comp_iron_mg",
        label = "Iron",
        unit = "mg",
        class = "intake_token_hematinic"
    },
    {
        field = "comp_vitamin_b12_ug",
        label = "Vitamin B12",
        unit = "ug",
        class = "intake_token_hematinic"
    },
    {
        field = "comp_folate_ug",
        label = "Folate",
        unit = "ug",
        class = "intake_token_hematinic"
    },
    {
        field = "comp_folate_dfe_ug",
        label = "Folate, dietary folate equivalents",
        unit = "ug_DFE",
        class = "intake_token_hematinic"
    },
    {
        field = "comp_protein_g",
        label = "Protein",
        unit = "g",
        class = "intake_token_protein"
    },
    {
        field = "comp_total_carbohydrate_g",
        label = "Total carbohydrate",
        unit = "g",
        class = "intake_token_carbohydrate"
    },
    {
        field = "comp_free_sugars_g",
        label = "Free sugars",
        unit = "g",
        class = "intake_token_carbohydrate"
    },
    {
        field = "comp_added_sugars_g",
        label = "Added sugars",
        unit = "g",
        class = "intake_token_carbohydrate"
    },
    {
        field = "comp_fiber_g",
        label = "Fiber",
        unit = "g",
        class = "nutrient_context"
    }
}

local function plain(value, label)
    assert(type(value) == "table" and getmetatable(value) == nil,
        label .. " must be a plain table")
end

local function fields(value, allowed, label)
    plain(value, label)
    for key in pairs(value) do
        assert(allowed[key], label .. " contains an unsupported field")
    end
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
end

local function nonempty(value)
    return type(value) == "string" and #value > 0 and #value <= 512
end

local function coverage(record)
    if record.comp_coverage_state == "unavailable" then
        assert(record.comp_coverage_fraction == nil,
            "unavailable coverage cannot contain a fraction")
        return {
            state = "unavailable",
            denominator = "reported_contributing_edible_mass"
        }
    end

    assert(record.comp_coverage_state == "known",
        "coverage state must be known or unavailable")
    local fraction = record.comp_coverage_fraction
    assert(finite(fraction) and fraction >= 0 and fraction <= 1,
        "coverage fraction must be within [0, 1]")

    return {
        state = "known",
        fraction = fraction,
        denominator = "reported_contributing_edible_mass"
    }
end

local function row(spec, record)
    fields(record, {
        comp_value_state = true,
        comp_value = true,
        comp_unit = true,
        comp_provenance = true,
        comp_basis = true,
        comp_coverage_state = true,
        comp_coverage_fraction = true
    }, "nutrient record")

    assert(record.comp_unit == spec.unit, "nutrient unit mismatch")
    assert(record.comp_provenance == "reported"
        or record.comp_provenance == "derived",
        "unsupported nutrient provenance")
    assert(nonempty(record.comp_basis), "nutrient basis is required")

    local result = {
        view_class = spec.class,
        view_label = spec.label,
        view_unit = spec.unit,
        view_provenance = record.comp_provenance,
        view_basis = record.comp_basis,
        view_coverage = coverage(record)
    }

    if record.comp_value_state == "known" then
        assert(finite(record.comp_value) and record.comp_value >= 0,
            "nutrient value must be finite and nonnegative")
        result.view_value_state = "known"
        result.view_known_subtotal = record.comp_value
    else
        assert(record.comp_value_state == "unknown",
            "value state must be known or unknown")
        assert(record.comp_value == nil,
            "unknown nutrient cannot contain a numeric value")
        result.view_value_state = "unknown"
    end

    return result
end

function M.project(governance, preferences, summary)
    fields(governance, {
        gov_consent_local_processing = true,
        gov_consent_intake_display = true
    }, "governance")

    assert(type(governance.gov_consent_local_processing) == "boolean"
        and type(governance.gov_consent_intake_display) == "boolean",
        "explicit processing and display permissions are required")

    local result = {
        view_schema = "nutritional-display-v1",
        view_enabled = false,
        view_display_only = true,
        view_exchangeable = false,
        view_consumer_allowlist = { "renderer" },
        view_authority = "none",
        view_rows = {}
    }

    if not governance.gov_consent_local_processing
        or not governance.gov_consent_intake_display then
        return result
    end

    fields(preferences, {
        acc_intake_skin = true
    }, "preferences")

    local skin = preferences.acc_intake_skin or "neutral"
    assert(skin == "neutral" or skin == "resource_narrative",
        "unsupported intake presentation")

    fields(summary, {
        obs_interval_start_s = true,
        obs_interval_end_s = true,
        obs_completeness_state = true,
        comp_nutrients = true
    }, "summary")

    assert(finite(summary.obs_interval_start_s)
        and finite(summary.obs_interval_end_s)
        and summary.obs_interval_end_s > summary.obs_interval_start_s,
        "an ordered interval in epoch seconds is required")

    local completeness = summary.obs_completeness_state
    assert(completeness == "complete_day"
        or completeness == "partial_day"
        or completeness == "unknown_completeness",
        "unsupported interval completeness")

    local allowed = {}
    for _, spec in ipairs(nutrient_specs) do
        allowed[spec.field] = true
    end
    fields(summary.comp_nutrients, allowed, "nutrient collection")

    result.view_enabled = true
    result.view_skin = skin
    result.view_interval_start_s = summary.obs_interval_start_s
    result.view_interval_end_s = summary.obs_interval_end_s
    result.view_completeness_state = completeness
    result.view_scope_label =
        "Known contributions within the reported interval"
    result.view_notice =
        "Reported nutritional contributions only. "
        .. "Not a body measurement, reserve, credit, or device resource."

    for _, spec in ipairs(nutrient_specs) do
        local record = rawget(summary.comp_nutrients, spec.field)
        if record ~= nil then
            result.view_rows[#result.view_rows + 1] = row(spec, record)
        end
    end

    return result
end

return M
