local AdaptivePolling = {}

local function finite_number(value, label)
    if type(value) ~= "number" or value ~= value or
        value == math.huge or value == -math.huge then
        error((label or "value") .. " must be a finite number")
    end
    return value
end

local function nonnegative(value, label)
    finite_number(value, label)
    if value < 0 then
        error((label or "value") .. " must be nonnegative")
    end
    return value
end

local function positive(value, label)
    finite_number(value, label)
    if value <= 0 then
        error((label or "value") .. " must be positive")
    end
    return value
end

local function clamp(value, lower, upper)
    if value < lower then
        return lower
    end
    if value > upper then
        return upper
    end
    return value
end

local function median(values)
    if type(values) ~= "table" or #values == 0 then
        error("values must be a non-empty table")
    end

    local sorted = {}
    for index, value in ipairs(values) do
        sorted[index] = finite_number(value, "change rate")
    end

    table.sort(sorted)

    local midpoint = math.floor(#sorted / 2)
    if #sorted % 2 == 1 then
        return sorted[midpoint + 1]
    end

    return (sorted[midpoint] + sorted[midpoint + 1]) / 2
end

function AdaptivePolling.relative_change(current_value, previous_value, scale, epsilon)
    finite_number(current_value, "current_value")
    finite_number(previous_value, "previous_value")
    positive(scale, "scale")
    positive(epsilon, "epsilon")

    return math.abs(current_value - previous_value) /
        math.max(math.abs(previous_value), scale, epsilon)
end

function AdaptivePolling.robust_change_rate(recent_change_rates)
    return median(recent_change_rates)
end

function AdaptivePolling.poll_interval(config, recent_change_rates)
    if type(config) ~= "table" then
        error("config must be a table")
    end

    positive(config.base_interval_s, "base_interval_s")
    positive(config.minimum_interval_s, "minimum_interval_s")
    positive(config.maximum_interval_s, "maximum_interval_s")
    positive(config.required_maximum_interval_s, "required_maximum_interval_s")
    nonnegative(config.alpha, "alpha")

    if config.minimum_interval_s > config.maximum_interval_s then
        error("minimum_interval_s must not exceed maximum_interval_s")
    end

    local change_rate = AdaptivePolling.robust_change_rate(recent_change_rates)
    local adaptive_interval =
        config.base_interval_s / (1.0 + config.alpha * change_rate)

    local bounded_interval = clamp(
        adaptive_interval,
        config.minimum_interval_s,
        config.maximum_interval_s
    )

    return math.min(
        bounded_interval,
        config.required_maximum_interval_s
    )
end

function AdaptivePolling.should_wake_early(event, config)
    if type(event) ~= "table" or type(config) ~= "table" then
        error("event and config must be tables")
    end

    nonnegative(event.absolute_change, "absolute_change")
    nonnegative(event.relative_change, "relative_change")
    nonnegative(config.critical_absolute_change, "critical_absolute_change")
    nonnegative(config.critical_relative_change, "critical_relative_change")

    return event.absolute_change > config.critical_absolute_change or
        event.relative_change > config.critical_relative_change or
        event.safety_corridor_breach == true or
        event.calibration_review_needed == true
end

function AdaptivePolling.cycle_energy_joules(config)
    if type(config) ~= "table" then
        error("config must be a table")
    end

    positive(config.voltage_v, "voltage_v")

    local stages = {
        { current_a = config.sleep_current_a, duration_s = config.sleep_duration_s },
        { current_a = config.wake_current_a, duration_s = config.wake_duration_s },
        { current_a = config.sense_current_a, duration_s = config.sense_duration_s },
        { current_a = config.compute_current_a, duration_s = config.compute_duration_s },
        { current_a = config.store_current_a, duration_s = config.store_duration_s },
        { current_a = config.transmit_current_a, duration_s = config.transmit_duration_s }
    }

    local coulombs = 0.0
    for _, stage in ipairs(stages) do
        nonnegative(stage.current_a or 0.0, "stage current")
        nonnegative(stage.duration_s or 0.0, "stage duration")
        coulombs = coulombs + stage.current_a * stage.duration_s
    end

    return config.voltage_v * coulombs
end

function AdaptivePolling.sleep_current_within_target(sleep_current_a, target_microamps)
    nonnegative(sleep_current_a, "sleep_current_a")
    positive(target_microamps, "target_microamps")

    return sleep_current_a < target_microamps * 0.000001
end

return AdaptivePolling
