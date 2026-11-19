local FairnessScore = {}
FairnessScore.__index = FairnessScore

local function finite_number(value, field)
    assert(type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge,
        (field or "value") .. " must be a finite number")
    return value
end

local function clamp01(value)
    value = finite_number(value, "value")

    if value < 0 then
        return 0
    end

    if value > 1 then
        return 1
    end

    return value
end

local function required_text(value, field)
    assert(type(value) == "string" and value:match("%S"),
        (field or "value") .. " must be a non-empty string")
    return value
end

local function normalized_weights(weights)
    assert(type(weights) == "table", "weights must be a table")

    local total = 0
    local result = {}

    for key, value in pairs(weights) do
        value = finite_number(value, "weight " .. tostring(key))
        assert(value >= 0, "weights must be non-negative")
        result[key] = value
        total = total + value
    end

    assert(total > 0, "at least one fairness weight must be positive")

    for key, value in pairs(result) do
        result[key] = value / total
    end

    return result
end

function FairnessScore.new(config)
    config = config or {}

    return setmetatable({
        weights = normalized_weights(config.weights or {
            accessibility = 0.35,
            identity_neutrality = 0.35,
            assistive_accommodation = 0.30,
        }),
        minimum_acceptable_score = clamp01(config.minimum_acceptable_score or 0.75),
    }, FairnessScore)
end

function FairnessScore:evaluate(service)
    assert(type(service) == "table", "service must be a table")

    local service_id = required_text(service.service_id, "service_id")
    local accessibility = clamp01(service.accessibility)
    local identity_neutrality = clamp01(service.identity_neutrality)
    local assistive_accommodation = clamp01(service.assistive_accommodation)

    local score = accessibility * self.weights.accessibility
        + identity_neutrality * self.weights.identity_neutrality
        + assistive_accommodation * self.weights.assistive_accommodation

    local deficiencies = {}

    if accessibility < 0.75 then
        deficiencies[#deficiencies + 1] = "accessibility below recommended threshold"
    end

    if identity_neutrality < 0.75 then
        deficiencies[#deficiencies + 1] = "identity-neutral treatment below recommended threshold"
    end

    if assistive_accommodation < 0.75 then
        deficiencies[#deficiencies + 1] = "assistive-technology accommodation below recommended threshold"
    end

    local harm_risk = clamp01(
        ((1 - accessibility) * self.weights.accessibility)
        + ((1 - identity_neutrality) * self.weights.identity_neutrality)
        + ((1 - assistive_accommodation) * self.weights.assistive_accommodation)
    )

    return {
        service_id = service_id,
        fairness_score = score,
        acceptable = score >= self.minimum_acceptable_score,
        accessibility = accessibility,
        identity_neutrality = identity_neutrality,
        assistive_accommodation = assistive_accommodation,
        deficiencies = deficiencies,
        knowledge_factor = service.evidence_complete == true and 0.85 or 0.60,
        eco_impact_value = 0.50,
        harm_risk = harm_risk,
        assessed_at_utc = service.assessed_at_utc or os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
end

return FairnessScore
