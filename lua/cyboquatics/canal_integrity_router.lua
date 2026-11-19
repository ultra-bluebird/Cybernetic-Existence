local canal_integrity_router = {}

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function unit_interval(value)
    return finite(value) and value >= 0.0 and value <= 1.0
end

local function valid_pseudonym(value)
    return type(value) == "string"
        and #value >= 12
        and #value <= 96
        and value:match("^[A-Za-z0-9_-]+$") ~= nil
end

function canal_integrity_router.evaluate(input)
    if type(input) ~= "table"
        or not valid_pseudonym(input.node_pseudonym)
        or type(input.observation_time_bucket_utc) ~= "string"
        or input.observation_time_bucket_utc == ""
        or not finite(input.flow_m3_s)
        or input.flow_m3_s < 0.0
        or not finite(input.temperature_c)
        or not unit_interval(input.quality_0_1)
        or not unit_interval(input.minimum_quality_0_1) then
        return {
            integrity_status = "REJECTED_INPUT",
            reasons = { "invalid_pseudonymous_integrity_input" }
        }
    end

    local reasons = {}

    if input.quality_0_1 < input.minimum_quality_0_1 then
        table.insert(reasons, "quality_below_configured_threshold")
    end
    if input.exact_location_present == true then
        table.insert(reasons, "exact_location_prohibited")
    end
    if input.direct_identity_present == true then
        table.insert(reasons, "direct_identity_prohibited")
    end
    if input.continuous_surveillance_present == true then
        table.insert(reasons, "continuous_surveillance_prohibited")
    end

    if #reasons > 0 then
        return {
            integrity_status = "INTEGRITY_REVIEW_REQUIRED",
            reasons = reasons
        }
    end

    return {
        integrity_status = "INTEGRITY_EVIDENCE_PRESENT",
        reasons = { "time_bucketed_pseudonymous_observation_valid" }
    }
end

return canal_integrity_router
