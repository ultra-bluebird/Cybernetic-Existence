-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: aligned reported-intake / estimated-expenditure accounting.
-- All energy amounts are interval totals in thermochemical kcal.
-- No storage-change inference, clinical label, recommendation, or action.
-- No filesystem, network, clock, persistence, or device access.
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

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 160
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

local function bounds(record)
    local low = rawget(record, "low_kcal")
    local high = rawget(record, "high_kcal")
    if not finite(low) or not finite(high) or low < 0 or high < low then
        return nil
    end
    return low, high
end

local function normalized_zero(value)
    if value == 0 then return 0.0 end
    return value
end

function M.evaluate(input)
    local output = {
        schema_version = "energy-residual-review-v1",
        status = "unavailable",
        findings = {},
        evidence_verification = "not_performed",
        physiological_interpretation = "not_performed",
        discrepancy_flag = "not_evaluated"
    }

    local function add(code, field)
        output.findings[#output.findings + 1] = {
            code = code, field = field, severity = "error"
        }
    end

    if not shape(input, {
        schema_version = true,
        intake = true,
        expenditure = true,
        added_activity_kcal = true,
        added_tef_kcal = true
    }) then
        add("invalid_input_shape", "input")
        return output
    end

    if rawget(input, "schema_version") ~= "energy-residual-input-v1" then
        add("unsupported_schema", "schema_version")
    end

    local intake = rawget(input, "intake")
    local expenditure = rawget(input, "expenditure")

    local intake_ok = shape(intake, {
        low_kcal = true, high_kcal = true,
        interval_start_s = true, interval_end_s = true,
        completeness = true, source_reference = true
    })
    local expenditure_ok = shape(expenditure, {
        low_kcal = true, high_kcal = true,
        interval_start_s = true, interval_end_s = true,
        model_reference = true, applicability = true,
        includes_activity = true, includes_tef = true,
        output_target = true
    })

    if not intake_ok then add("invalid_intake_record", "intake") end
    if not expenditure_ok then
        add("invalid_expenditure_record", "expenditure")
    end
    if not intake_ok or not expenditure_ok then return output end

    local intake_low, intake_high = bounds(intake)
    local expenditure_low, expenditure_high = bounds(expenditure)
    if intake_low == nil then add("invalid_bounds", "intake") end
    if expenditure_low == nil then add("invalid_bounds", "expenditure") end

    local start_s = rawget(intake, "interval_start_s")
    local end_s = rawget(intake, "interval_end_s")
    local exp_start = rawget(expenditure, "interval_start_s")
    local exp_end = rawget(expenditure, "interval_end_s")

    if not finite(start_s) or not finite(end_s) or end_s <= start_s then
        add("invalid_interval", "intake")
    end
    if not finite(exp_start) or not finite(exp_end) or exp_end <= exp_start then
        add("invalid_interval", "expenditure")
    end
    if start_s ~= exp_start or end_s ~= exp_end then
        add("interval_mismatch", "interval")
    end

    local completeness = rawget(intake, "completeness")
    if completeness ~= "complete_report"
        and completeness ~= "partial_report"
        and completeness ~= "unknown_completeness" then
        add("completeness_required", "intake.completeness")
    end

    if not text(rawget(intake, "source_reference")) then
        add("source_reference_required", "intake.source_reference")
    end
    if not text(rawget(expenditure, "model_reference")) then
        add("model_reference_required", "expenditure.model_reference")
    end
    if rawget(expenditure, "applicability") ~= "applicable" then
        add("applicable_model_required", "expenditure.applicability")
    end
    if rawget(expenditure, "output_target") ~= "total_expenditure" then
        add("total_expenditure_required", "expenditure.output_target")
    end
    if rawget(expenditure, "includes_activity") ~= true then
        add("activity_inclusion_unresolved", "expenditure.includes_activity")
    end
    if rawget(expenditure, "includes_tef") ~= true then
        add("tef_inclusion_unresolved", "expenditure.includes_tef")
    end

    for _, field in ipairs({ "added_activity_kcal", "added_tef_kcal" }) do
        local value = rawget(input, field)
        if value ~= nil then
            if not finite(value) or value < 0 then
                add("invalid_added_component", field)
            elseif value ~= 0 then
                add("component_already_included", field)
            end
        end
    end

    if #output.findings > 0 then return output end

    local low = (intake_low + 0.0) - (expenditure_high + 0.0)
    local high = (intake_high + 0.0) - (expenditure_low + 0.0)

    if not finite(low) or not finite(high) or high < low then
        add("invalid_arithmetic_result", "residual")
        return output
    end

    output.status = "accounting_residual_calculated"
    output.interval_start_s = start_s
    output.interval_end_s = end_s
    output.energy_unit = "kcal"
    output.calorie_convention = "thermochemical"
    output.intake_completeness = completeness
    output.intake_source_reference = rawget(intake, "source_reference")
    output.expenditure_model_reference =
        rawget(expenditure, "model_reference")
    output.residual_low_kcal = normalized_zero(low)
    output.residual_high_kcal = normalized_zero(high)
    output.uncertainty_kind = "supplied_arithmetic_bounds"
    output.complete_uncertainty = "not_established"
    output.interpretation =
        "reported_intake_minus_estimated_expenditure_only"

    return output
end

function M.self_test()
    local input = {
        schema_version = "energy-residual-input-v1",
        intake = {
            low_kcal = 1800, high_kcal = 2000,
            interval_start_s = 0, interval_end_s = 86400,
            completeness = "partial_report",
            source_reference = "synthetic-intake"
        },
        expenditure = {
            low_kcal = 2100, high_kcal = 2400,
            interval_start_s = 0, interval_end_s = 86400,
            model_reference = "synthetic-model",
            applicability = "applicable",
            includes_activity = true,
            includes_tef = true,
            output_target = "total_expenditure"
        }
    }

    local result = M.evaluate(input)
    assert(result.residual_low_kcal == -600)
    assert(result.residual_high_kcal == -100)
    assert(result.intake_completeness == "partial_report")
    assert(result.physiological_interpretation == "not_performed")

    input.added_activity_kcal = 100
    assert(M.evaluate(input).status == "unavailable")
    input.added_activity_kcal = nil

    input.expenditure.interval_end_s = 90000
    assert(M.evaluate(input).status == "unavailable")
    assert(M.evaluate(nil).status == "unavailable")

    return { status = "passed", scope = "synthetic_assertions" }
end

return M
