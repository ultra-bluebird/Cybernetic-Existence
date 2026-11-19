-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4. Amounts are grams of nitrogen over the declared interval.
-- Sources, bases, and attestations are supplied claims, not verification.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local VERSION = "nitrogen-accounting-v2"
local FIELD_BUDGET = 64

local LOSSES = {
    "urinary_total", "fecal", "integumentary", "other_applicable"
}

local STATES = { "available", "unknown", "not_applicable" }
local BASES = { "measured", "estimated" }
local URINARY_KINDS = { "total", "urea_only", "urea_plus_allowance" }
local NA_PERMITTED = { other_applicable = true }

local REASONS = {
    "invalid_input", "record_required", "field_budget_exceeded",
    "invalid_field_key", "unexpected_field", "missing_field",
    "version_mismatch", "invalid_interval", "invalid_text",
    "invalid_boolean", "overlap_not_attested", "invalid_state",
    "invalid_basis", "invalid_bounds", "interval_mismatch",
    "intake_unknown", "intake_not_applicable", "loss_unavailable",
    "loss_not_applicable", "invalid_urinary_kind",
    "urinary_total_not_covered", "allowance_requires_estimated_basis",
    "numeric_overflow", "internal_invariant_violated",
    "complete_balance_unavailable", "protocol_scoped_estimate"
}

local function copy_array(values)
    local result = {}
    for index, value in ipairs(values) do
        result[index] = value
    end
    return result
end

local function field_set(names)
    local result = {}
    for _, name in ipairs(names) do
        result[name] = true
    end
    return result
end

local REASON_SET = field_set(REASONS)

local TOP_FIELDS = {
    "schema_version", "interval_start_s", "interval_end_s",
    "protocol_source", "protocol_overlap_attestation", "intake", "losses"
}

local AVAILABLE_FIELDS = {
    "state", "basis", "source", "low_g_n", "high_g_n",
    "interval_start_s", "interval_end_s"
}

local URINARY_FIELDS = copy_array(AVAILABLE_FIELDS)
URINARY_FIELDS[#URINARY_FIELDS + 1] = "urinary_measurement_kind"

local URINARY_ALLOWED = copy_array(URINARY_FIELDS)
URINARY_ALLOWED[#URINARY_ALLOWED + 1] = "allowance_source"

local UNAVAILABLE_FIELDS = { "state", "unavailable_reason" }

local TOP_SET = field_set(TOP_FIELDS)
local LOSS_SET = field_set(LOSSES)
local AVAILABLE_SET = field_set(AVAILABLE_FIELDS)
local URINARY_SET = field_set(URINARY_ALLOWED)
local UNAVAILABLE_SET = field_set(UNAVAILABLE_FIELDS)

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
end

local function text(value)
    return type(value) == "string"
        and #value >= 1
        and #value <= 512
        and value:find("%S") ~= nil
        and value:find("[%z\1-\8\11\12\14-\31\127]") == nil
end

local function normalized(value)
    if value == 0 then
        return 0.0
    end
    return value + 0.0
end

local function add(output, code, field, severity)
    assert(REASON_SET[code], "internal reason registry mismatch")
    output.est_findings[#output.est_findings + 1] = {
        code = code,
        field = field,
        severity = severity
    }
end

local function required_text(output, record, name, path)
    local value = rawget(record, name)
    if value ~= nil and not text(value) then
        add(output, "invalid_text", path .. "." .. name, "error")
    end
end

local function shape(output, record, allowed, required, path)
    if not plain(record) then
        add(output, "record_required", path, "error")
        return false
    end

    local count = 0
    for _ in next, record do
        count = count + 1
        if count > FIELD_BUDGET then
            add(output, "field_budget_exceeded", path, "error")
            return false
        end
    end

    local unexpected = {}
    local invalid_key = false

    for key in next, record do
        if type(key) ~= "string"
            or #key == 0
            or #key > 96
            or key:match("^[A-Za-z_][A-Za-z0-9_]*$") == nil then
            invalid_key = true
        elseif not allowed[key] then
            unexpected[#unexpected + 1] = key
        end
    end

    if invalid_key then
        add(output, "invalid_field_key", path, "error")
    end

    table.sort(unexpected)
    for _, name in ipairs(unexpected) do
        add(output, "unexpected_field", path .. "." .. name, "error")
    end

    local missing = {}
    for _, name in ipairs(required) do
        if rawget(record, name) == nil then
            missing[#missing + 1] = name
        end
    end

    table.sort(missing)
    for _, name in ipairs(missing) do
        add(output, "missing_field", path .. "." .. name, "error")
    end

    return true
end

local function interval_valid(start_s, end_s)
    if not finite(start_s) or not finite(end_s) or end_s <= start_s then
        return false
    end

    local duration = normalized(end_s) - normalized(start_s)
    if not finite(duration) or duration <= 0 then
        return false
    end

    return true, duration
end

local function validate_term(output, record, path, category, start_s, end_s)
    if not plain(record) then
        add(output, "record_required", path, "error")
        return nil
    end

    local state = rawget(record, "state")

    if state == "unknown" or state == "not_applicable" then
        if not shape(output, record, UNAVAILABLE_SET,
            UNAVAILABLE_FIELDS, path) then
            return nil
        end

        required_text(output, record, "unavailable_reason", path)

        if category == "intake" then
            local code = "intake_unknown"
            if state == "not_applicable" then
                code = "intake_not_applicable"
            end
            add(output, code, path .. ".state", "error")
        elseif state == "not_applicable" then
            if not NA_PERMITTED[category] then
                add(output, "loss_not_applicable",
                    path .. ".state", "error")
            end
        else
            add(output, "loss_unavailable", path .. ".state", "warning")
        end

        return { state = state }
    end

    if state ~= "available" then
        if state == nil then
            add(output, "missing_field", path .. ".state", "error")
        else
            add(output, "invalid_state", path .. ".state", "error")
        end
        return nil
    end

    local allowed = AVAILABLE_SET
    local required = AVAILABLE_FIELDS
    if category == "urinary_total" then
        allowed = URINARY_SET
        required = URINARY_FIELDS
    end

    if not shape(output, record, allowed, required, path) then
        return nil
    end

    local basis = rawget(record, "basis")
    if basis ~= nil and basis ~= "measured" and basis ~= "estimated" then
        add(output, "invalid_basis", path .. ".basis", "error")
    end

    required_text(output, record, "source", path)

    local term_start = rawget(record, "interval_start_s")
    local term_end = rawget(record, "interval_end_s")
    if term_start ~= nil and term_end ~= nil then
        if not interval_valid(term_start, term_end) then
            add(output, "invalid_interval", path .. ".interval", "error")
        elseif term_start ~= start_s or term_end ~= end_s then
            add(output, "interval_mismatch", path .. ".interval", "error")
        end
    end

    local low = rawget(record, "low_g_n")
    local high = rawget(record, "high_g_n")
    if low ~= nil and high ~= nil then
        if not finite(low) or not finite(high)
            or low < 0 or high < low then
            add(output, "invalid_bounds", path .. ".bounds", "error")
        end
    end

    if category == "urinary_total" then
        local kind = rawget(record, "urinary_measurement_kind")
        local allowance = rawget(record, "allowance_source")

        if kind == "urea_only" then
            add(output, "urinary_total_not_covered",
                path .. ".urinary_measurement_kind", "error")
        elseif kind == "urea_plus_allowance" then
            if basis ~= "estimated" then
                add(output, "allowance_requires_estimated_basis",
                    path .. ".basis", "error")
            end

            if allowance == nil then
                add(output, "missing_field",
                    path .. ".allowance_source", "error")
            else
                required_text(output, record, "allowance_source", path)
            end
        elseif kind ~= nil and kind ~= "total" then
            add(output, "invalid_urinary_kind",
                path .. ".urinary_measurement_kind", "error")
        end

        if kind ~= "urea_plus_allowance" and allowance ~= nil then
            add(output, "unexpected_field",
                path .. ".allowance_source", "error")
        end
    end

    return {
        state = state,
        basis = basis,
        low = low,
        high = high
    }
end

local function finish_errors(output)
    for _, finding in ipairs(output.est_findings) do
        if finding.severity == "error" then
            output.est_reason = finding.code
            output.est_error_field = finding.field

            local loss = finding.field:match(
                "^input%.losses%.([A-Za-z_][A-Za-z0-9_]*)")
            if loss and LOSS_SET[loss] then
                output.est_invalid_loss = loss
            end

            return true
        end
    end
    return false
end

function M.contract()
    return {
        schema_version = VERSION,
        runtime_profile = "Lua 5.4",
        amount_unit = "g_N",
        interval_unit = "s",
        loss_categories = copy_array(LOSSES),
        term_states = copy_array(STATES),
        term_bases = copy_array(BASES),
        urinary_measurement_kinds = copy_array(URINARY_KINDS),
        reasons = copy_array(REASONS),
        na_permitted_categories = { "other_applicable" },
        structural_field_budget = FIELD_BUDGET,
        unavailable_terms_inherit_parent_interval = true,
        sources_and_attestations_are_unverified = true
    }
end

function M.evaluate(input)
    local output = {
        schema_version = VERSION,
        est_status = "unavailable",
        est_reason = "invalid_input",
        est_uncertainty_kind = "unavailable",
        est_source_verification = "not_performed",
        est_overlap_verification = "not_performed",
        est_tissue_maintenance_assessed = false,
        est_findings = {},
        est_missing_losses = {},
        est_estimated_terms = {},
        est_estimated_losses = {},
        est_not_applicable_losses = {}
    }

    if not shape(output, input, TOP_SET, TOP_FIELDS, "input") then
        finish_errors(output)
        return output
    end

    local version = rawget(input, "schema_version")
    if version ~= nil and version ~= VERSION then
        add(output, "version_mismatch", "input.schema_version", "error")
    end

    required_text(output, input, "protocol_source", "input")

    local attestation = rawget(input, "protocol_overlap_attestation")
    if attestation ~= nil then
        if type(attestation) ~= "boolean" then
            add(output, "invalid_boolean",
                "input.protocol_overlap_attestation", "error")
        elseif not attestation then
            add(output, "overlap_not_attested",
                "input.protocol_overlap_attestation", "error")
        end
    end

    local start_s = rawget(input, "interval_start_s")
    local end_s = rawget(input, "interval_end_s")
    local interval_ok, duration = interval_valid(start_s, end_s)

    if start_s ~= nil and end_s ~= nil and not interval_ok then
        add(output, "invalid_interval", "input.interval", "error")
    end

    local intake_record = rawget(input, "intake")
    local intake
    if intake_record ~= nil then
        intake = validate_term(output, intake_record,
            "input.intake", "intake", start_s, end_s)
    end

    local losses = rawget(input, "losses")
    local parsed = {}

    if losses ~= nil and shape(output, losses, LOSS_SET, {},
        "input.losses") then
        for _, name in ipairs(LOSSES) do
            local record = rawget(losses, name)
            if record == nil then
                add(output, "loss_unavailable",
                    "input.losses." .. name, "warning")
                output.est_missing_losses[
                    #output.est_missing_losses + 1] = name
            else
                local value = validate_term(output, record,
                    "input.losses." .. name, name, start_s, end_s)
                parsed[name] = value
                if value and value.state == "unknown" then
                    output.est_missing_losses[
                        #output.est_missing_losses + 1] = name
                end
            end
        end
    end

    if finish_errors(output) then
        return output
    end

    if not intake or intake.state ~= "available" or not interval_ok then
        add(output, "internal_invariant_violated", "input", "error")
        finish_errors(output)
        return output
    end

    local loss_low, loss_high = 0.0, 0.0
    local accounted = 0

    if intake.basis == "estimated" then
        output.est_estimated_terms[
            #output.est_estimated_terms + 1] = "intake"
    end

    for _, name in ipairs(LOSSES) do
        local value = parsed[name]
        if value and value.state == "available" then
            loss_low = loss_low + normalized(value.low)
            loss_high = loss_high + normalized(value.high)

            if not finite(loss_low) or not finite(loss_high) then
                add(output, "numeric_overflow",
                    "input.losses." .. name, "error")
                finish_errors(output)
                return output
            end

            accounted = accounted + 1
            if value.basis == "estimated" then
                output.est_estimated_terms[
                    #output.est_estimated_terms + 1] = name
                output.est_estimated_losses[
                    #output.est_estimated_losses + 1] = name
            end
        elseif value and value.state == "not_applicable" then
            output.est_not_applicable_losses[
                #output.est_not_applicable_losses + 1] = name
        end
    end

    local low = normalized(intake.low) - loss_high
    local high = normalized(intake.high) - loss_low

    if not finite(low) or not finite(high) then
        add(output, "numeric_overflow", "output.residual", "error")
        finish_errors(output)
        return output
    end

    if high < low or loss_high < loss_low then
        add(output, "internal_invariant_violated",
            "output.residual", "error")
        finish_errors(output)
        return output
    end

    low, high = normalized(low), normalized(high)

    output.est_interval_start_s = normalized(start_s)
    output.est_interval_end_s = normalized(end_s)
    output.est_interval_duration_s = duration
    output.est_intake_basis = intake.basis
    output.est_intake_estimated = intake.basis == "estimated"
    output.est_intake_low_g_n = normalized(intake.low)
    output.est_intake_high_g_n = normalized(intake.high)
    output.est_accounted_losses_low_g_n = normalized(loss_low)
    output.est_accounted_losses_high_g_n = normalized(loss_high)
    output.est_accounted_loss_count = accounted
    output.est_estimated_terms_present =
        #output.est_estimated_terms > 0
    output.est_not_applicable_categories_present =
        #output.est_not_applicable_losses > 0
    output.est_overlap_attestation = true
    output.est_uncertainty_kind = "supplied_arithmetic_bounds"

    if #output.est_missing_losses > 0 then
        output.est_status = "partial_accounting"
        output.est_reason = "complete_balance_unavailable"
        output.est_partial_residual_low_g_n = low
        output.est_partial_residual_high_g_n = high
        output.est_intake_minus_accounted_losses_low_g_n = low
        output.est_intake_minus_accounted_losses_high_g_n = high
    else
        output.est_status = "all_declared_loss_categories_accounted"
        output.est_reason = "protocol_scoped_estimate"
        output.est_balance_low_g_n = low
        output.est_balance_high_g_n = high
    end

    return output
end

return M
