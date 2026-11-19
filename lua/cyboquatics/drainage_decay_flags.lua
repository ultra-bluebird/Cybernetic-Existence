local drainage_decay_flags = {}

local analytes = {
    BOD = true,
    TSS = true,
    CEC = true
}

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function unit_interval(value)
    return finite(value) and value >= 0.0 and value <= 1.0
end

local function relative_difference(left, right)
    local denominator = math.max(math.abs(left), math.abs(right), 1e-12)
    return math.abs(left - right) / denominator
end

function drainage_decay_flags.evaluate(input, config)
    if type(input) ~= "table"
        or type(config) ~= "table"
        or not analytes[input.analyte]
        or not finite(input.value)
        or not unit_interval(input.measurement_quality)
        or type(config[input.analyte]) ~= "table" then
        return { status = "REVIEW_REQUIRED", flags = { "INVALID_INPUT" } }
    end

    local rule = config[input.analyte]
    if not finite(rule.minimum_value)
        or not finite(rule.maximum_value)
        or rule.minimum_value > rule.maximum_value
        or not unit_interval(rule.minimum_measurement_quality)
        or not unit_interval(rule.maximum_relative_trend_difference)
        or not unit_interval(rule.maximum_relative_replicate_difference) then
        return { status = "REVIEW_REQUIRED", flags = { "INVALID_CONFIG" } }
    end

    local flags = {}

    if input.value < rule.minimum_value or input.value > rule.maximum_value then
        table.insert(flags, "OUT_OF_CONFIG_RANGE")
    end

    if input.measurement_quality < rule.minimum_measurement_quality then
        table.insert(flags, "LOW_MEASUREMENT_QUALITY")
    end

    if input.previous_valid_value == nil then
        table.insert(flags, "NO_BASELINE")
    elseif not finite(input.previous_valid_value) then
        table.insert(flags, "INVALID_INPUT")
    elseif relative_difference(input.value, input.previous_valid_value) >
        rule.maximum_relative_trend_difference then
        table.insert(flags, "TREND_DIFFERENCE")
    end

    if input.replicate_value ~= nil then
        if not finite(input.replicate_value) then
            table.insert(flags, "INVALID_INPUT")
        elseif relative_difference(input.value, input.replicate_value) >
            rule.maximum_relative_replicate_difference then
            table.insert(flags, "CONFLICTING_REPLICATES")
        end
    end

    if #flags == 0 then
        return {
            status = "NO_CONFIGURED_ANOMALY",
            flags = { "NO_CONFIGURED_ANOMALY" }
        }
    end

    return {
        status = "REVIEW_REQUIRED",
        flags = flags
    }
end

return drainage_decay_flags
