local M = {}

local allowed_particle_classes = {
    pm10 = true,
    pm2_5 = true,
    coarse_mineral = true,
    organic_dust = true,
    unknown = true
}

local function finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function valid_probability(value)
    return finite_number(value) and value >= 0.0 and value <= 1.0
end

local function valid_text(value)
    return type(value) == "string" and value:match("%S") ~= nil
end

local function withheld(fog_state, reason)
    return {
        status = "withheld",
        fog_state = fog_state,
        queue = "human_review_queue",
        reason = reason
    }
end

function M.evaluate(event)
    if type(event) ~= "table" then
        return withheld("withhold", "dust transport event must be a table")
    end

    for _, field in ipairs({
        "event_id",
        "hex_anchor",
        "observed_at_utc",
        "meteorological_bin",
        "model_version",
        "threshold_version",
        "matrix"
    }) do
        if not valid_text(event[field]) then
            return withheld("withhold", field .. " must be a non-empty string")
        end
    end

    if event.source_valid ~= true
        or event.parameter_current ~= true
        or event.consent_scope_valid ~= true
        or event.retention_eligible ~= true then
        return withheld(
            "withhold",
            "source, parameter, consent, or retention eligibility is not valid"
        )
    end

    if not valid_probability(event.fog_threshold) then
        return withheld("withhold", "fog_threshold must be a probability in [0, 1]")
    end

    if type(event.particle_classes) ~= "table" or #event.particle_classes == 0 then
        return withheld(
            "human_review_pending",
            "no particle-class transport evidence is available"
        )
    end

    for _, particle in ipairs(event.particle_classes) do
        if type(particle) ~= "table"
            or not allowed_particle_classes[particle.class] then
            return withheld(
                "human_review_pending",
                "an unsupported particle class requires model-scope review"
            )
        end

        if not valid_probability(particle.transport_probability) then
            return withheld(
                "withhold",
                "particle transport probability must be within [0, 1]"
            )
        end

        if particle.calibration_valid ~= true then
            return withheld(
                "human_review_pending",
                "particle transport calibration is not valid for this event"
            )
        end

        if particle.transport_probability > event.fog_threshold then
            return withheld(
                "unmodeled_media",
                "a particle class exceeds the declared aerosol transport uncertainty threshold"
            )
        end
    end

    return {
        status = "informational",
        fog_state = "clear",
        queue = "human_review_queue",
        reason = "No declared particle class exceeds the configured transport uncertainty threshold."
    }
end

return M
