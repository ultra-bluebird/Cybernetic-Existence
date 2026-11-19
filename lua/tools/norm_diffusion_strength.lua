-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/norm_diffusion_strength.lua
-- Destination: lua/tools/

local NormDiffusionStrength = {}
NormDiffusionStrength.__index = NormDiffusionStrength

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
    assert(not seen[value], "cyclic diffusion records are not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function sorted_observations(observations)
    local sorted = copy_value(observations)

    table.sort(sorted, function(left, right)
        return left.period_index < right.period_index
    end)

    return sorted
end

local function validate_observation(observation)
    assert(type(observation) == "table", "observation must be a table")

    return {
        period_index = math.floor(
            finite_number(observation.period_index, "period_index")
        ),
        support_rate = clamp01(observation.support_rate),
        aggregate_sample_count = math.max(
            0,
            math.floor(finite_number(
                observation.aggregate_sample_count,
                "aggregate_sample_count"
            ))
        ),
        evidence_complete = observation.evidence_complete == true,
        observed_at_utc = observation.observed_at_utc or utc_now(),
    }
end

local function weighted_rate_of_change(observations)
    if #observations < 2 then
        return 0
    end

    local change_total = 0
    local weight_total = 0

    for index = 2, #observations do
        local previous = observations[index - 1]
        local current = observations[index]
        local elapsed_periods = current.period_index - previous.period_index

        assert(elapsed_periods > 0,
            "period_index values must be strictly increasing")

        local sample_weight = math.min(
            previous.aggregate_sample_count,
            current.aggregate_sample_count
        )

        local rate = (current.support_rate - previous.support_rate)
            / elapsed_periods

        change_total = change_total + rate * sample_weight
        weight_total = weight_total + sample_weight
    end

    if weight_total == 0 then
        return 0
    end

    return change_total / weight_total
end

function NormDiffusionStrength.new(config)
    config = config or {}

    return setmetatable({
        minimum_sample_count = math.max(
            1,
            math.floor(finite_number(
                config.minimum_sample_count or 25,
                "minimum_sample_count"
            ))
        ),
        strong_growth_rate = finite_number(
            config.strong_growth_rate or 0.05,
            "strong_growth_rate"
        ),
        moderate_growth_rate = finite_number(
            config.moderate_growth_rate or 0.02,
            "moderate_growth_rate"
        ),
        analyses = {},
        sequence = 0,
    }, NormDiffusionStrength)
end

function NormDiffusionStrength:analyze(series)
    assert(type(series) == "table", "series must be a table")

    local norm_id = required_text(series.norm_id, "norm_id")
    local community_reference = required_text(
        series.community_reference,
        "community_reference"
    )
    local observations = series.observations or {}

    assert(
        type(observations) == "table" and #observations >= 2,
        "at least two aggregate observations are required"
    )

    local normalized = {}

    for _, observation in ipairs(observations) do
        normalized[#normalized + 1] = validate_observation(observation)
    end

    normalized = sorted_observations(normalized)

    local insufficient_samples = 0
    local incomplete_evidence = 0
    local total_sample_count = 0
    local support_total = 0

    for _, observation in ipairs(normalized) do
        total_sample_count = total_sample_count
            + observation.aggregate_sample_count
        support_total = support_total + observation.support_rate

        if observation.aggregate_sample_count < self.minimum_sample_count then
            insufficient_samples = insufficient_samples + 1
        end

        if not observation.evidence_complete then
            incomplete_evidence = incomplete_evidence + 1
        end
    end

    local first = normalized[1]
    local last = normalized[#normalized]
    local elapsed_periods = last.period_index - first.period_index

    assert(elapsed_periods > 0,
        "observation period range must be positive")

    local diffusion_rate = weighted_rate_of_change(normalized)
    local net_support_change = last.support_rate - first.support_rate
    local average_support_rate = support_total / #normalized

    local direction
    if diffusion_rate >= self.strong_growth_rate then
        direction = "strong_positive_diffusion"
    elseif diffusion_rate >= self.moderate_growth_rate then
        direction = "positive_diffusion"
    elseif diffusion_rate > -self.moderate_growth_rate then
        direction = "stable_or_indeterminate"
    elseif diffusion_rate > -self.strong_growth_rate then
        direction = "negative_diffusion"
    else
        direction = "strong_negative_diffusion"
    end

    local evidence_coverage = 1 - (incomplete_evidence / #normalized)
    local sample_coverage = 1 - (insufficient_samples / #normalized)
    local knowledge_factor = clamp01(
        evidence_coverage * 0.60 + sample_coverage * 0.40
    )

    local diffusion_strength = clamp01(
        (math.max(0, diffusion_rate) / math.max(
            self.strong_growth_rate,
            0.000001
        )) * 0.55
            + last.support_rate * 0.30
            + knowledge_factor * 0.15
    )

    local harm_risk = clamp01(
        (diffusion_rate < 0 and math.min(0.35, -diffusion_rate * 3) or 0)
            + ((1 - last.support_rate) * 0.30)
            + ((1 - knowledge_factor) * 0.20)
    )

    local recommendations = {}

    if knowledge_factor < 0.75 then
        recommendations[#recommendations + 1] =
            "Improve aggregate evidence coverage before interpreting social change."
    end

    if direction == "strong_negative_diffusion"
        or direction == "negative_diffusion" then
        recommendations[#recommendations + 1] =
            "Prioritize accessible, community-led education and listen for reported barriers."
    elseif direction == "stable_or_indeterminate" then
        recommendations[#recommendations + 1] =
            "Use voluntary, privacy-preserving outreach and measure whether access barriers remain."
    else
        recommendations[#recommendations + 1] =
            "Maintain inclusion practices and verify that reported support corresponds to equal service access."
    end

    local result = {
        norm_id = norm_id,
        community_reference = community_reference,
        advisory_only = true,
        individual_tracking_used = false,
        raw_discourse_retained = false,
        observation_count = #normalized,
        total_aggregate_sample_count = total_sample_count,
        first_support_rate = first.support_rate,
        latest_support_rate = last.support_rate,
        average_support_rate = average_support_rate,
        net_support_change = net_support_change,
        diffusion_rate_per_period = diffusion_rate,
        diffusion_strength = diffusion_strength,
        direction = direction,
        evidence_coverage = evidence_coverage,
        sample_coverage = sample_coverage,
        recommendations = recommendations,
        knowledge_factor = knowledge_factor,
        eco_impact_value = clamp01(series.eco_impact_value or 0.50),
        harm_risk = harm_risk,
        analyzed_at_utc = series.analyzed_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.analyses[#self.analyses + 1] = copy_value(result)

    return result
end

function NormDiffusionStrength:report_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")

    assert(
        sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer"
    )

    local analyses = {}
    local highest_harm_risk = 0

    for _, analysis in ipairs(self.analyses) do
        if analysis.sequence > sequence then
            analyses[#analyses + 1] = copy_value(analysis)
            highest_harm_risk = math.max(
                highest_harm_risk,
                analysis.harm_risk
            )
        end
    end

    return {
        from_sequence = sequence,
        analysis_count = #analyses,
        analyses = analyses,
        knowledge_factor = #analyses == 0 and 0 or (function()
            local total = 0

            for _, analysis in ipairs(analyses) do
                total = total + analysis.knowledge_factor
            end

            return total / #analyses
        end)(),
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return NormDiffusionStrength
