-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/acceptance_index_calculator.lua
-- Destination: lua/tools/

local AcceptanceIndexCalculator = {}
AcceptanceIndexCalculator.__index = AcceptanceIndexCalculator

local required_components = {
    "public_support_score",
    "hostility_score",
    "inclusion_policy_score",
    "accessibility_score",
}

local default_weights = {
    public_support_score = 0.25,
    hostility_score = 0.25,
    inclusion_policy_score = 0.25,
    accessibility_score = 0.25,
}

local function required_text(value, field)
    assert(type(value) == "string" and value:match("%S"),
        (field or "value") .. " must be a non-empty string")
    return value
end

local function finite_number(value, field)
    assert(
        type(value) == "number"
            and value == value
            and value ~= math.huge
            and value ~= -math.huge,
        (field or "value") .. " must be a finite number"
    )
    return value
end

local function clamp01(value)
    value = finite_number(value, "score")

    if value < 0 then
        return 0
    end

    if value > 1 then
        return 1
    end

    return value
end

local function utc_now()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function copy_value(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic acceptance data is not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function normalized_weights(weights)
    assert(type(weights) == "table", "weights must be a table")

    local total = 0
    local normalized = {}

    for _, component in ipairs(required_components) do
        local weight = finite_number(
            weights[component] or 0,
            "weight for " .. component
        )

        assert(weight >= 0, "weights must be non-negative")
        normalized[component] = weight
        total = total + weight
    end

    assert(total > 0, "at least one weight must be positive")

    for component, weight in pairs(normalized) do
        normalized[component] = weight / total
    end

    return normalized
end

local function acceptance_band(value)
    if value >= 0.85 then
        return "strongly_supportive"
    end

    if value >= 0.70 then
        return "supportive"
    end

    if value >= 0.50 then
        return "mixed_or_incomplete"
    end

    return "exclusion_risk"
end

function AcceptanceIndexCalculator.new(config)
    config = config or {}

    return setmetatable({
        weights = normalized_weights(config.weights or default_weights),
        minimum_aggregate_sample_count = math.max(
            1,
            math.floor(finite_number(
                config.minimum_aggregate_sample_count or 25,
                "minimum_aggregate_sample_count"
            ))
        ),
        minimum_knowledge_factor = clamp01(
            config.minimum_knowledge_factor or 0.75
        ),
        calculations = {},
        sequence = 0,
    }, AcceptanceIndexCalculator)
end

function AcceptanceIndexCalculator:calculate(input)
    assert(type(input) == "table", "input must be a table")

    local calculation_id = required_text(
        input.calculation_id,
        "calculation_id"
    )
    local community_reference = required_text(
        input.community_reference,
        "community_reference"
    )
    local metrics = input.metrics or {}
    local evidence = input.evidence or {}

    assert(type(metrics) == "table", "metrics must be a table")
    assert(type(evidence) == "table", "evidence must be a table")

    local values = {}
    local evidence_count = 0
    local findings = {}

    for _, component in ipairs(required_components) do
        values[component] = clamp01(metrics[component] or 0)

        if evidence[component] == true then
            evidence_count = evidence_count + 1
        else
            findings[#findings + 1] = {
                component = component,
                detail = "evidence is incomplete for this component",
            }
        end
    end

    local aggregate_sample_count = math.max(
        0,
        math.floor(finite_number(
            input.aggregate_sample_count or 0,
            "aggregate_sample_count"
        ))
    )

    if aggregate_sample_count < self.minimum_aggregate_sample_count then
        findings[#findings + 1] = {
            component = "aggregate_sample_count",
            detail = "aggregate sample count is below the required minimum",
        }
    end

    local documented_exclusion_condition =
        input.documented_exclusion_condition == true
    local assistive_access_failure =
        input.assistive_access_failure == true
    local identity_verifiability_penalty =
        input.identity_verifiability_penalty == true

    if documented_exclusion_condition then
        findings[#findings + 1] = {
            component = "inclusion_policy_score",
            detail = "documented exclusion condition was reported",
        }
    end

    if assistive_access_failure then
        findings[#findings + 1] = {
            component = "accessibility_score",
            detail = "assistive-access failure was reported",
        }
    end

    if identity_verifiability_penalty then
        findings[#findings + 1] = {
            component = "inclusion_policy_score",
            detail = "identity-verifiability penalty was reported",
        }
    end

    local evidence_coverage = evidence_count / #required_components
    local sample_coverage = math.min(
        1,
        aggregate_sample_count / self.minimum_aggregate_sample_count
    )
    local knowledge_factor = clamp01(
        evidence_coverage * 0.70 + sample_coverage * 0.30
    )

    local acceptance_index = clamp01(
        values.public_support_score * self.weights.public_support_score
            + (1 - values.hostility_score) * self.weights.hostility_score
            + values.inclusion_policy_score
                * self.weights.inclusion_policy_score
            + values.accessibility_score
                * self.weights.accessibility_score
    )

    local structural_exclusion = documented_exclusion_condition
        or assistive_access_failure
        or identity_verifiability_penalty

    local acceptable = acceptance_index >= 0.70
        and knowledge_factor >= self.minimum_knowledge_factor
        and not structural_exclusion

    local harm_risk = clamp01(
        (1 - acceptance_index) * 0.50
            + values.hostility_score * 0.25
            + (1 - knowledge_factor) * 0.15
            + (structural_exclusion and 0.25 or 0)
    )

    local result = {
        calculation_id = calculation_id,
        community_reference = community_reference,
        advisory_only = true,
        formula = {
            public_support_weight = self.weights.public_support_score,
            non_hostility_weight = self.weights.hostility_score,
            policy_inclusion_weight = self.weights.inclusion_policy_score,
            service_accessibility_weight = self.weights.accessibility_score,
            expression = "A = ws*S + wh*(1-H) + wp*P + wa*X",
        },
        inputs = {
            public_support_score = values.public_support_score,
            hostility_score = values.hostility_score,
            inclusion_policy_score = values.inclusion_policy_score,
            accessibility_score = values.accessibility_score,
            aggregate_sample_count = aggregate_sample_count,
            evidence_coverage = evidence_coverage,
        },
        acceptance_index = acceptance_index,
        acceptance_band = acceptance_band(acceptance_index),
        acceptable = acceptable,
        documented_exclusion_condition = documented_exclusion_condition,
        assistive_access_failure = assistive_access_failure,
        identity_verifiability_penalty = identity_verifiability_penalty,
        findings = findings,
        raw_individual_data_used = false,
        raw_sentiment_text_retained = false,
        knowledge_factor = knowledge_factor,
        eco_impact_value = clamp01(input.eco_impact_value or 0.50),
        harm_risk = harm_risk,
        calculated_at_utc = input.calculated_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.calculations[#self.calculations + 1] = copy_value(result)

    return result
end

function AcceptanceIndexCalculator:report_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")

    assert(
        sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer"
    )

    local calculations = {}
    local highest_harm_risk = 0

    for _, calculation in ipairs(self.calculations) do
        if calculation.sequence > sequence then
            calculations[#calculations + 1] = copy_value(calculation)
            highest_harm_risk = math.max(
                highest_harm_risk,
                calculation.harm_risk
            )
        end
    end

    return {
        from_sequence = sequence,
        calculation_count = #calculations,
        calculations = calculations,
        knowledge_factor = #calculations == 0 and 0 or (function()
            local total = 0

            for _, calculation in ipairs(calculations) do
                total = total + calculation.knowledge_factor
            end

            return total / #calculations
        end)(),
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return AcceptanceIndexCalculator
