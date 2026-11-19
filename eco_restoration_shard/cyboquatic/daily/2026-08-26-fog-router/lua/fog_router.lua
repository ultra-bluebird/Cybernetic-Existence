local known_media = {
    freshwater = true,
    brackish_water = true,
    wastewater = true,
    stormwater = true,
    sediment = true
}

local function finite_in_range(value, minimum, maximum)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
        and value >= minimum
        and value <= maximum
end

local function parse_boolean(text)
    if text == "true" then
        return true
    end
    if text == "false" then
        return false
    end
    return nil
end

local function decision(route, code, explanation)
    return {
        route = route,
        code = code,
        explanation = explanation
    }
end

local function route_observation(value)
    if value.node_id == "" or value.observed_at == "" then
        return decision(
            "REJECTED_INPUT",
            "MISSING_REQUIRED_FIELD",
            "A pseudonymous node identifier and observation time are required."
        )
    end

    if not value.consent_active then
        return decision(
            "REJECTED_INPUT",
            "CONSENT_NOT_ACTIVE",
            "The purpose-limited consent state is not active; do not process this observation."
        )
    end

    if not finite_in_range(value.confidence, 0.0, 1.0)
        or not finite_in_range(value.completeness, 0.0, 1.0)
        or not finite_in_range(value.measurement_quality, 0.0, 1.0)
        or not finite_in_range(value.k, 0.0, 1.0)
        or not finite_in_range(value.e, 0.0, 1.0)
        or not finite_in_range(value.r, 0.0, 1.0)
        or not finite_in_range(value.flow_m3_s, 0.0, 1000.0)
        or not finite_in_range(value.temperature_c, -5.0, 60.0) then
        return decision(
            "REJECTED_INPUT",
            "INVALID_BOUNDED_VALUE",
            "One or more measurements are missing, non-finite, or outside the configured local bounds."
        )
    end

    if value.fog or not known_media[value.media] then
        return decision(
            "FOG_REVIEW",
            "FOG_EXPLICIT",
            "FOG is explicit or the media is unknown; preserve uncertainty and request qualified human review."
        )
    end

    if value.completeness < 0.90
        or value.confidence < 0.70
        or value.measurement_quality < 0.70
        or value.k < 0.70 then
        return decision(
            "FOG_REVIEW",
            "EVIDENCE_INCOMPLETE",
            "Evidence completeness, confidence, measurement quality, or knowledge quality is insufficient for known-media review."
        )
    end

    if value.r > 0.30 then
        return decision(
            "QUARANTINED_INPUT",
            "RISK_ABOVE_AUTOMATION_BOUND",
            "Risk of harm exceeds 0.30; quarantine the record for qualified human review and do not automate a recommendation."
        )
    end

    return decision(
        "KNOWN_MEDIA",
        "KNOWN_MEDIA_READY",
        "Known media with complete, authorized evidence is suitable for human review only; no physical action is authorized."
    )
end

if #arg ~= 13 then
    io.stderr:write(
        "usage: fog_router.lua node_id observed_at media confidence completeness fog flow_m3_s " ..
        "temperature_c measurement_quality K E R consent_active\n"
    )
    os.exit(2)
end

local fog = parse_boolean(arg[6])
local consent_active = parse_boolean(arg[13])

if fog == nil or consent_active == nil then
    print("route=REJECTED_INPUT")
    print("code=PARSE_FAILURE")
    print("explanation=Input values must use decimal numbers and lowercase true or false booleans.")
    os.exit(1)
end

local value = {
    node_id = arg[1],
    observed_at = arg[2],
    media = arg[3],
    confidence = tonumber(arg[4]),
    completeness = tonumber(arg[5]),
    fog = fog,
    flow_m3_s = tonumber(arg[7]),
    temperature_c = tonumber(arg[8]),
    measurement_quality = tonumber(arg[9]),
    k = tonumber(arg[10]),
    e = tonumber(arg[11]),
    r = tonumber(arg[12]),
    consent_active = consent_active
}

local result = route_observation(value)
print("route=" .. result.route)
print("code=" .. result.code)
print("explanation=" .. result.explanation)

if result.route == "REJECTED_INPUT" then
    os.exit(1)
end
