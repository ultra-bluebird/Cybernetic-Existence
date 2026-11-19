local FogHysteresisMachine = {}

FogHysteresisMachine.CLEAR = "clear"
FogHysteresisMachine.UNMODELED_MEDIA = "unmodeled_media"

local function finite_unit_interval(value, name)
    assert(type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge,
        name .. " must be finite")

    assert(value >= 0 and value <= 1,
        name .. " must be within [0, 1]")
end

local function positive_integer(value, name)
    assert(type(value) == "number"
        and value % 1 == 0
        and value > 0,
        name .. " must be a positive integer")
end

function FogHysteresisMachine.validate_config(config)
    assert(type(config) == "table", "config must be a table")

    finite_unit_interval(config.theta_low, "theta_low")
    finite_unit_interval(config.theta_high, "theta_high")
    positive_integer(config.minimum_dwell_seconds, "minimum_dwell_seconds")

    assert(config.theta_low < config.theta_high,
        "theta_low must be strictly lower than theta_high")

    assert(config.advisory_only == true,
        "hysteresis must be advisory_only")

    return true
end

function FogHysteresisMachine.initial_state(at_utc)
    positive_integer(at_utc, "at_utc")

    return {
        state = FogHysteresisMachine.CLEAR,
        last_transition_at_utc = at_utc,
        advisory_only = true
    }
end

function FogHysteresisMachine.transition(
    previous,
    uncertainty,
    at_utc,
    config
)
    FogHysteresisMachine.validate_config(config)

    assert(type(previous) == "table", "previous state must be a table")
    assert(previous.state == FogHysteresisMachine.CLEAR
        or previous.state == FogHysteresisMachine.UNMODELED_MEDIA,
        "previous state is invalid")

    positive_integer(previous.last_transition_at_utc,
        "previous.last_transition_at_utc")
    positive_integer(at_utc, "at_utc")
    assert(at_utc >= previous.last_transition_at_utc,
        "at_utc must not precede last_transition_at_utc")

    finite_unit_interval(uncertainty, "uncertainty")

    local candidate = previous.state

    if uncertainty > config.theta_high then
        candidate = FogHysteresisMachine.UNMODELED_MEDIA
    elseif uncertainty < config.theta_low then
        candidate = FogHysteresisMachine.CLEAR
    end

    local elapsed = at_utc - previous.last_transition_at_utc
    local dwell_satisfied = elapsed >= config.minimum_dwell_seconds
    local changed = candidate ~= previous.state and dwell_satisfied

    if changed then
        return {
            state = candidate,
            last_transition_at_utc = at_utc,
            advisory_only = true,
            transition_reason = "threshold_and_minimum_dwell_satisfied",
            observed_uncertainty = uncertainty
        }
    end

    return {
        state = previous.state,
        last_transition_at_utc = previous.last_transition_at_utc,
        advisory_only = true,
        transition_reason = candidate == previous.state
            and "hysteresis_hold_band"
            or "minimum_dwell_not_elapsed",
        observed_uncertainty = uncertainty
    }
end

return FogHysteresisMachine
