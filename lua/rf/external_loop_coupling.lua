local M = {}

local TWO_PI = 2.0 * math.pi

local function is_finite(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function require_positive(value, field_name)
    if not is_finite(value) or value <= 0.0 then
        return nil, field_name .. " must be finite and greater than zero"
    end

    return value
end

local function require_non_negative(value, field_name)
    if not is_finite(value) or value < 0.0 then
        return nil, field_name .. " must be finite and non-negative"
    end

    return value
end

function M.coupling_coefficient(mutual_inductance_h, inductance_tx_h, inductance_rx_h)
    local mutual, mutual_error =
        require_non_negative(mutual_inductance_h, "mutual_inductance_h")
    if mutual_error then
        return nil, mutual_error
    end

    local inductance_tx, tx_error =
        require_positive(inductance_tx_h, "inductance_tx_h")
    if tx_error then
        return nil, tx_error
    end

    local inductance_rx, rx_error =
        require_positive(inductance_rx_h, "inductance_rx_h")
    if rx_error then
        return nil, rx_error
    end

    local coupling = mutual / math.sqrt(inductance_tx * inductance_rx)

    return {
        coupling_coefficient = coupling,
        physically_plausible = coupling >= 0.0 and coupling <= 1.0,
        boundary = "external-loop calculation only; not evidence of biological coupling"
    }
end

function M.induced_voltage(input)
    if type(input) ~= "table" then
        return nil, "input must be a table"
    end

    local turns, turns_error = require_positive(input.turns, "turns")
    if turns_error then
        return nil, turns_error
    end

    local area_m2, area_error =
        require_positive(input.loop_area_m2, "loop_area_m2")
    if area_error then
        return nil, area_error
    end

    local frequency_hz, frequency_error =
        require_positive(input.frequency_hz, "frequency_hz")
    if frequency_error then
        return nil, frequency_error
    end

    local magnetic_flux_density_t, field_error =
        require_non_negative(input.magnetic_flux_density_t, "magnetic_flux_density_t")
    if field_error then
        return nil, field_error
    end

    local angle_radians = input.angle_radians
    if not is_finite(angle_radians) then
        return nil, "angle_radians must be finite"
    end

    local omega = TWO_PI * frequency_hz
    local induced_voltage_v =
        turns
        * area_m2
        * omega
        * magnetic_flux_density_t
        * math.abs(math.cos(angle_radians))

    return {
        induced_voltage_v = induced_voltage_v,
        frequency_hz = frequency_hz,
        boundary = "open-circuit external test-loop estimate only; rectification and load effects require separate measurement"
    }
end

function M.receiver_efficiency(dc_output_w, available_receiver_power_w)
    local output_power, output_error =
        require_non_negative(dc_output_w, "dc_output_w")
    if output_error then
        return nil, output_error
    end

    local available_power, available_error =
        require_positive(available_receiver_power_w, "available_receiver_power_w")
    if available_error then
        return nil, available_error
    end

    local efficiency = output_power / available_power

    return {
        receiver_efficiency = efficiency,
        bounded_efficiency = math.min(math.max(efficiency, 0.0), 1.0),
        measurement_required = "available receiver power and DC output must be externally instrumented"
    }
end

return M
