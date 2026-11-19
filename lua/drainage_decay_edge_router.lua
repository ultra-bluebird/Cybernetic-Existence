local Router = {}

local MAX_MESSAGE_BYTES = 16384

local expected_units = {
    BOD = "mg/L",
    TSS = "mg/L",
    CEC = "cmolc/kg",
}

local expected_matrix = {
    BOD = "water",
    TSS = "water",
    CEC = "sediment",
}

local function finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function valid_nonempty_string(value, maximum)
    return type(value) == "string"
        and #value > 0
        and #value <= maximum
        and value:match("%S") ~= nil
end

local function utc_second_precision(value)
    return type(value) == "string"
        and value:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$") ~= nil
end

function Router.validate_measurement(message)
    if type(message) ~= "table" then
        return nil, "measurement must be an object"
    end

    local encoded_size = #(
        tostring(message.source_id or "")
        .. tostring(message.canal_node_id or "")
        .. tostring(message.anchor_id or "")
        .. tostring(message.measure_code or "")
        .. tostring(message.observed_utc or "")
    )

    if encoded_size > MAX_MESSAGE_BYTES then
        return nil, "measurement metadata exceeds edge-router size limit"
    end

    if not valid_nonempty_string(message.source_id, 128) then
        return nil, "source_id must be a non-empty string of at most 128 bytes"
    end

    if not valid_nonempty_string(message.canal_node_id, 128) then
        return nil, "canal_node_id must be a non-empty string of at most 128 bytes"
    end

    if not valid_nonempty_string(message.anchor_id, 128) then
        return nil, "anchor_id must be a non-empty string of at most 128 bytes"
    end

    local unit = expected_units[message.measure_code]
    local matrix = expected_matrix[message.measure_code]

    if unit == nil or matrix == nil then
        return nil, "measure_code must be BOD, TSS, or CEC"
    end

    if message.unit_code ~= unit then
        return nil, "unit_code is incompatible with measure_code"
    end

    if message.matrix_kind ~= matrix then
        return nil, "matrix_kind is incompatible with measure_code"
    end

    if not finite_number(message.value_numeric) or message.value_numeric < 0.0 then
        return nil, "value_numeric must be finite and non-negative"
    end

    if not finite_number(message.uncertainty_stddev) or message.uncertainty_stddev <= 0.0 then
        return nil, "uncertainty_stddev must be finite and greater than zero"
    end

    if not utc_second_precision(message.observed_utc) then
        return nil, "observed_utc must use UTC RFC 3339 second precision"
    end

    return {
        accepted = true,
        route = "drainage-normalization",
        measurement = {
            source_id = message.source_id,
            canal_node_id = message.canal_node_id,
            anchor_id = message.anchor_id,
            measure_code = message.measure_code,
            matrix_kind = message.matrix_kind,
            value_numeric = message.value_numeric,
            unit_code = message.unit_code,
            uncertainty_stddev = message.uncertainty_stddev,
            observed_utc = message.observed_utc,
            quality_status = "provisional",
        },
    }
end

return Router
