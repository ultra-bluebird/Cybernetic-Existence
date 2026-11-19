-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: basic sweat-session arithmetic and protocol review.
-- Mass is kg; volumes are L; interval bounds are epoch seconds.
-- No diagnosis, intake recommendation, persistence, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local quantities = {
    "mass_before_kg", "mass_after_kg",
    "drink_volume_l", "urine_volume_l"
}

local reviews = {
    "measurement_review",
    "interval_alignment_review",
    "clothing_moisture_review",
    "other_intake_output_review",
    "nonsweat_mass_change_review"
}

local allowed = {
    schema_version = true,
    interval_start_s = true,
    interval_end_s = true,
    protocol_reference = true
}
for _, name in ipairs(quantities) do allowed[name] = true end
for _, name in ipairs(reviews) do allowed[name] = true end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge and value < math.huge
end

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 256
end

local function zero_normalized(value)
    if value == 0 then return 0.0 end
    return value
end

function M.evaluate(input)
    local output = {
        schema_version = "sweat-session-review-v1",
        est_status = "unavailable",
        est_source_verification = "not_performed",
        est_uncertainty_status = "not_quantified",
        est_physiological_interpretation = "not_performed",
        est_findings = {}
    }

    local invalid = false
    local review_pending = false

    local function add(code, field, severity)
        output.est_findings[#output.est_findings + 1] = {
            code = code, field = field, severity = severity
        }
        if severity == "error" then invalid = true end
    end

    if not plain(input) then
        add("plain_record_required", "input", "error")
        return output
    end

    local unexpected = {}
    local invalid_key = false
    local count = 0

    for key in next, input do
        count = count + 1
        if count > 64 then
            output.est_findings = {
                {
                    code = "field_budget_exceeded",
                    field = "input",
                    severity = "error"
                }
            }
            return output
        end
        if type(key) ~= "string" or #key > 96 then
            invalid_key = true
        elseif not allowed[key] then
            unexpected[#unexpected + 1] = key
        end
    end

    if invalid_key then add("invalid_field_key", "input", "error") end
    table.sort(unexpected)
    for _, name in ipairs(unexpected) do
        add("unexpected_field", name, "error")
    end

    if rawget(input, "schema_version") ~= "sweat-session-input-v1" then
        add("unsupported_schema", "schema_version", "error")
    end

    if not text(rawget(input, "protocol_reference")) then
        add("protocol_reference_required", "protocol_reference", "error")
    end

    for _, name in ipairs(quantities) do
        local value = rawget(input, name)
        if not finite(value) or value < 0 then
            add("quantity_unavailable_or_invalid", name, "error")
        elseif (name == "mass_before_kg" or name == "mass_after_kg")
            and value == 0 then
            add("positive_body_mass_required", name, "error")
        end
    end

    local start_s = rawget(input, "interval_start_s")
    local end_s = rawget(input, "interval_end_s")
    local duration
    if finite(start_s) and finite(end_s) then
        duration = (end_s + 0.0) - (start_s + 0.0)
    end
    if not finite(duration) or duration <= 0 then
        add("positive_interval_required", "interval", "error")
    end

    for _, name in ipairs(reviews) do
        local state = rawget(input, name)
        if state == "unresolved" or state == nil then
            review_pending = true
            add("protocol_review_unresolved", name, "warning")
        elseif state ~= "supports_basic_approximation" then
            add("invalid_review_state", name, "error")
        end
    end

    if invalid then return output end

    local before = rawget(input, "mass_before_kg") + 0.0
    local after = rawget(input, "mass_after_kg") + 0.0
    local drink = rawget(input, "drink_volume_l") + 0.0
    local urine = rawget(input, "urine_volume_l") + 0.0

    local residual = (before - after) + drink - urine
    if not finite(residual) then
        add("numeric_overflow", "arithmetic", "error")
        return output
    end

    output.est_interval_duration_s = duration
    output.est_basic_mass_volume_residual_l = zero_normalized(residual)

    if residual < 0 then
        output.est_status = "negative_arithmetic_review_required"
        add("negative_basic_residual", "arithmetic", "warning")
        return output
    end

    if review_pending then
        output.est_status = "protocol_review_required"
        return output
    end

    local rate = (residual / duration) * 3600.0
    if not finite(rate) then
        add("numeric_overflow", "rate", "error")
        return output
    end

    output.est_status = "basic_approximation_available"
    output.est_basic_sweat_loss_l = zero_normalized(residual)
    output.est_basic_sweat_rate_l_per_h = zero_normalized(rate)
    return output
end

return M
