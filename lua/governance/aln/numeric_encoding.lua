-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: exact normalized decimal-bound encoding.
-- Supports policy decimals in [0, 1], up to six fractional digits.
-- No physiological interpretation or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local allowed = {
    enc_integer_bound = true,
    enc_scale = true,
    enc_policy_decimal = true,
    enc_direction = true,
    enc_rights_effect = true
}

local rights_effects = {
    self_report_constraint = true,
    software_only = true,
    unknown = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function integer_between(value, low, high)
    return math.type(value) == "integer"
        and value >= low and value <= high
end

local function decimal_fraction(value)
    if type(value) ~= "string" or #value > 8 then
        return nil
    end

    if value == "0" then return 0, 1 end
    if value == "1" then return 1, 1 end

    local whole, fraction = value:match("^([01])%.(%d+)$")
    if whole == nil or #fraction > 6 then
        return nil
    end

    local denominator = 1
    for _ = 1, #fraction do
        denominator = denominator * 10
    end

    local numerator =
        tonumber(whole) * denominator + tonumber(fraction)

    if numerator > denominator then
        return nil
    end

    return numerator, denominator
end

function M.evaluate(record)
    local output = {
        enc_status = "invalid_record",
        enc_consistent = false,
        enc_rights_review_required = true,
        enc_rights_effect_verification = "not_performed",
        enc_reason = "plain_encoding_record_required"
    }

    if not plain(record) then
        return output
    end

    local invalid_field = false
    local count = 0
    for key in next, record do
        count = count + 1
        if count > 16 then
            output.enc_reason = "encoding_field_limit_exceeded"
            return output
        end
        if not allowed[key] then
            invalid_field = true
        end
    end

    if invalid_field then
        output.enc_reason = "unexpected_encoding_field"
        return output
    end

    local scale = rawget(record, "enc_scale")
    local encoded = rawget(record, "enc_integer_bound")
    local direction = rawget(record, "enc_direction")
    local rights = rawget(record, "enc_rights_effect")

    if not integer_between(scale, 1, 65535) then
        output.enc_reason = "invalid_integer_scale"
        return output
    end

    if not integer_between(encoded, 0, scale) then
        output.enc_reason = "invalid_integer_bound"
        return output
    end

    if direction ~= "upper" and direction ~= "lower" then
        output.enc_reason = "invalid_bound_direction"
        return output
    end

    if type(rights) ~= "string" or not rights_effects[rights] then
        output.enc_reason = "invalid_rights_effect"
        return output
    end

    local numerator, denominator =
        decimal_fraction(rawget(record, "enc_policy_decimal"))

    if numerator == nil then
        output.enc_reason = "invalid_normalized_policy_decimal"
        return output
    end

    local product = scale * numerator
    local required

    if direction == "upper" then
        required = product // denominator
        output.enc_required_min = 0
        output.enc_required_max = required
    else
        required = (product + denominator - 1) // denominator
        output.enc_required_min = required
        output.enc_required_max = scale
    end

    output.enc_status = "evaluated"
    output.enc_required_integer_bound = required
    output.enc_consistent = encoded == required
    output.enc_rights_effect_claim = rights

    if encoded == required then
        output.enc_reason = "exact_encoding_match"
    elseif (direction == "upper" and encoded < required)
        or (direction == "lower" and encoded > required) then
        output.enc_reason = "more_restrictive_encoding"
    else
        output.enc_reason = "less_restrictive_encoding"
    end

    return output
end

return M
