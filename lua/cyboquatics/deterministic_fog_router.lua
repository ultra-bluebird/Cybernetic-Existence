local deterministic_fog_router = {}

local approved_media = {
    AQUEOUS = true,
    SEDIMENT = true,
    BIOREACTOR = true,
    ORGANIC_DEBRIS = true
}

local function in_milli_range(value)
    return type(value) == "number"
        and value % 1 == 0
        and value >= 0
        and value <= 1000
end

function deterministic_fog_router.evaluate(input)
    if type(input) ~= "table"
        or not in_milli_range(input.confidence_milli)
        or not in_milli_range(input.completeness_milli)
        or not in_milli_range(input.knowledge_factor_milli)
        or not in_milli_range(input.harm_risk_milli)
        or type(input.uncertainty_flag) ~= "boolean"
        or type(input.hazard_flag) ~= "boolean" then
        return { route = "REJECTED_INPUT", reason = "INVALID_INPUT" }
    end

    if type(input.media_class) ~= "string" or not approved_media[input.media_class] then
        return { route = "REJECTED_INPUT", reason = "UNKNOWN_MEDIA" }
    end

    if input.hazard_flag then
        return { route = "FOG_REVIEW", reason = "HAZARD_FLAG" }
    end

    if input.uncertainty_flag then
        return { route = "FOG_REVIEW", reason = "UNCERTAINTY_FLAG" }
    end

    if input.confidence_milli < 700 then
        return { route = "FOG_REVIEW", reason = "CONFIDENCE_BELOW_700" }
    end

    if input.completeness_milli < 900 then
        return { route = "FOG_REVIEW", reason = "COMPLETENESS_BELOW_900" }
    end

    if input.knowledge_factor_milli < 700 then
        return { route = "FOG_REVIEW", reason = "KNOWLEDGE_BELOW_700" }
    end

    if input.harm_risk_milli > 300 then
        return { route = "FOG_REVIEW", reason = "HARM_RISK_ABOVE_300" }
    end

    return { route = "KNOWN_MEDIA_REVIEWABLE", reason = "ELIGIBLE" }
end

return deterministic_fog_router
