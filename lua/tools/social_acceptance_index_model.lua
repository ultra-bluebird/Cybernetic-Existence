-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/social_acceptance_index_model.lua
-- Destination: lua/tools/

local SocialAcceptanceIndexModel = {}
SocialAcceptanceIndexModel.__index = SocialAcceptanceIndexModel

local required_dimensions = {
    "public_sentiment",
    "policy_inclusivity",
    "service_accessibility",
}

local default_weights = {
    public_sentiment = 0.30,
    policy_inclusivity = 0.35,
    service_accessibility = 0.35,
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
    assert(not seen[value], "cyclic index records are not supported")
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

    local result = {}
    local total = 0

    for _, dimension in ipairs(required_dimensions) do
        local weight = finite_number(
            weights[dimension] or 0,
            "weight for " .. dimension
        )

        assert(weight >= 0, "weights must be non-negative")
        result[dimension] = weight
        total = total + weight
    end

    assert(total > 0, "at least one social-acceptance weight must be positive")

    for dimension, value in pairs(result) do
        result[dimension] = value / total
    end

    return result
end

local function validate_evidence(evidence)
    assert(type(evidence) == "table", "evidence must be a table")

    local normalized = {}

    for _, dimension in ipairs(required_dimensions) do
        normalized[dimension] = evidence[dimension] == true
    end

    return normalized
end

local function index_band(index)
    if index >= 0.85 then
        return "strongly_supportive"
    end

    if index >= 0.70 then
        return "supportive"
    end

    if index >= 0.50 then
        return "mixed_or_incomplete"
    end

    return "exclusion_risk"
end

function SocialAcceptanceIndexModel.new(config)
    config = config or {}

    return setmetatable({
        weights = normalized_weights(config.weights or default_weights),
        minimum_sample_count = math.max(
            1,
            math.floor(finite_number(
                config.minimum_sample_count or 25,
                "minimum_sample_count"
            ))
        ),
        minimum_acceptable_index = clamp01(
            config.minimum_acceptable_index or 0.75
        ),
        assessments = {},
        sequence = 0,
    }, SocialAcceptanceIndexModel)
end

function SocialAcceptanceIndexModel:evaluate(assessment)
    assert(type(assessment) == "table", "assessment must be a table")

    local assessment_id = required_text(
        assessment.assessment_id,
        "assessment_id"
    )
    local community_reference = required_text(
        assessment.community_reference,
        "community_reference"
    )
    local scores = assessment.scores or {}
    local evidence = validate_evidence(assessment.evidence or {})

    assert(type(scores) == "table", "assessment.scores must be a table")

    local normalized_scores = {}
    local weighted_index = 0
    local evidence_count = 0
    local findings = {}

    for _, dimension in ipairs(required_dimensions) do
        local score = clamp01(scores[dimension] or 0)
        normalized_scores[dimension] = score
        weighted_index = weighted_index + (score * self.weights[dimension])

        if evidence[dimension] then
            evidence_count = evidence_count + 1
        else
            findings[#findings + 1] = {
                dimension = dimension,
                detail = "evidence is incomplete for this index dimension",
            }
        end
    end

    local sample_count = math.max(
        0,
        math.floor(finite_number(
            assessment.aggregate_sample_count or 0,
            "aggregate_sample_count"
        ))
    )

    if sample_count < self.minimum_sample_count then
        findings[#findings + 1] = {
            dimension = "aggregate_sample_count",
            detail = "aggregate sample count is below the configured minimum",
        }
    end

    local policy_exclusion_detected =
        assessment.policy_exclusion_detected == true
    local access_denial_detected =
        assessment.access_denial_detected == true
    local assistive_need_ignored =
        assessment.assistive_need_ignored == true

    if policy_exclusion_detected then
        findings[#findings + 1] = {
            dimension = "policy_inclusivity",
            detail = "policy exclusion affecting augmented citizens was reported",
        }
    end

    if access_denial_detected then
        findings[#findings + 1] = {
            dimension = "service_accessibility",
            detail = "service-access denial affecting assistive or augmented access was reported",
        }
    end

    if assistive_need_ignored then
        findings[#findings + 1] = {
            dimension = "service_accessibility",
            detail = "declared assistive need was not accommodated",
        }
    end

    local index = clamp01(weighted_index)
    local evidence_complete = evidence_count == #required_dimensions
    local structural_exclusion = policy_exclusion_detected
        or access_denial_detected
        or assistive_need_ignored

    local acceptable = index >= self.minimum_acceptable_index
        and evidence_complete
        and sample_count >= self.minimum_sample_count
        and not structural_exclusion

    local harm_risk = clamp01(
        ((1 - index) * 0.55)
            + ((not evidence_complete) and 0.15 or 0)
            + ((sample_count < self.minimum_sample_count) and 0.10 or 0)
            + (structural_exclusion and 0.25 or 0)
    )

    local result = {
        assessment_id = assessment_id,
        community_reference = community_reference,
        advisory_only = true,
        social_acceptance_index = index,
        acceptance_band = index_band(index),
        acceptable = acceptable,
        aggregate_sample_count = sample_count,
        scores = normalized_scores,
        weights = copy_value(self.weights),
        evidence = evidence,
        findings = findings,
        excludes_individual_profiles = true,
        includes_raw_sentiment_content = false,
        knowledge_factor = clamp01(
            (evidence_count / #required_dimensions) * 0.70
                + math.min(1.0, sample_count / self.minimum_sample_count) * 0.30
        ),
        eco_impact_value = clamp01(assessment.eco_impact_value or 0.50),
        harm_risk = harm_risk,
        assessed_at_utc = assessment.assessed_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.assessments[#self.assessments + 1] = copy_value(result)

    return result
end

function SocialAcceptanceIndexModel:compare(assessments)
    assert(
        type(assessments) == "table" and #assessments > 0,
        "assessments must contain at least one assessment"
    )

    local results = {}

    for _, assessment in ipairs(assessments) do
        results[#results + 1] = self:evaluate(assessment)
    end

    table.sort(results, function(left, right)
        if left.social_acceptance_index == right.social_acceptance_index then
            return left.community_reference < right.community_reference
        end

        return left.social_acceptance_index > right.social_acceptance_index
    end)

    return {
        advisory_only = true,
        ranked_assessments = results,
        best_assessment = results[1],
        knowledge_factor = results[1].knowledge_factor,
        eco_impact_value = results[1].eco_impact_value,
        harm_risk = results[1].harm_risk,
        generated_at_utc = utc_now(),
    }
end

function SocialAcceptanceIndexModel:report_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")

    assert(
        sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer"
    )

    local results = {}
    local highest_harm_risk = 0
    local total_index = 0

    for _, result in ipairs(self.assessments) do
        if result.sequence > sequence then
            results[#results + 1] = copy_value(result)
            highest_harm_risk = math.max(
                highest_harm_risk,
                result.harm_risk
            )
            total_index = total_index + result.social_acceptance_index
        end
    end

    local count = #results

    return {
        from_sequence = sequence,
        assessment_count = count,
        average_social_acceptance_index = count == 0
            and 0
            or total_index / count,
        assessments = results,
        knowledge_factor = count == 0 and 0 or (function()
            local total = 0

            for _, result in ipairs(results) do
                total = total + result.knowledge_factor
            end

            return total / count
        end)(),
        eco_impact_value = count == 0 and 0.50 or (function()
            local total = 0

            for _, result in ipairs(results) do
                total = total + result.eco_impact_value
            end

            return total / count
        end)(),
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return SocialAcceptanceIndexModel
