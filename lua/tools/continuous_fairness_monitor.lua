-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/continuous_fairness_monitor.lua
-- Destination: lua/tools/

local ContinuousFairnessMonitor = {}
ContinuousFairnessMonitor.__index = ContinuousFairnessMonitor

local protected_dimensions = {
    "assistive_accommodation",
    "continuity_preservation",
    "identity_neutrality",
    "privacy_preservation",
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
    assert(not seen[value], "cyclic fairness records are not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function average(values)
    if #values == 0 then
        return 0
    end

    local total = 0

    for _, value in ipairs(values) do
        total = total + value
    end

    return total / #values
end

local function bounded_append(values, value, capacity)
    values[#values + 1] = value

    while #values > capacity do
        table.remove(values, 1)
    end
end

local function normalize_dimensions(dimensions)
    assert(type(dimensions) == "table", "dimensions must be a table")

    local normalized = {}

    for _, dimension in ipairs(protected_dimensions) do
        normalized[dimension] = clamp01(dimensions[dimension] or 0)
    end

    return normalized
end

local function dimension_average(dimensions)
    local total = 0

    for _, dimension in ipairs(protected_dimensions) do
        total = total + dimensions[dimension]
    end

    return total / #protected_dimensions
end

local function has_critical_condition(outcome)
    return outcome.assistive_access_failure == true
        or outcome.identity_verifiability_penalty == true
        or outcome.continuity_access_failure == true
        or outcome.raw_identifier_disclosure == true
        or outcome.augmentation_status_penalty == true
end

function ContinuousFairnessMonitor.new(config)
    config = config or {}

    return setmetatable({
        window_size = math.max(
            2,
            math.floor(finite_number(
                config.window_size or 12,
                "window_size"
            ))
        ),
        maximum_fairness_gap = clamp01(
            config.maximum_fairness_gap or 0.15
        ),
        maximum_baseline_decline = clamp01(
            config.maximum_baseline_decline or 0.12
        ),
        minimum_evidence_coverage = clamp01(
            config.minimum_evidence_coverage or 0.75
        ),
        groups = {},
        observations = {},
        alerts = {},
        sequence = 0,
    }, ContinuousFairnessMonitor)
end

function ContinuousFairnessMonitor:_group_state(group_reference)
    local group = self.groups[group_reference]

    if not group then
        group = {
            dimensions = {},
            fairness_scores = {},
            evidence_scores = {},
            observation_count = 0,
        }

        for _, dimension in ipairs(protected_dimensions) do
            group.dimensions[dimension] = {}
        end

        self.groups[group_reference] = group
    end

    return group
end

function ContinuousFairnessMonitor:observe(outcome)
    assert(type(outcome) == "table", "outcome must be a table")

    local outcome_id = required_text(outcome.outcome_id, "outcome_id")
    local service_reference = required_text(
        outcome.service_reference,
        "service_reference"
    )
    local group_reference = required_text(
        outcome.group_reference,
        "group_reference"
    )

    assert(
        outcome.aggregate_group == true,
        "fairness monitoring requires an aggregate group reference"
    )
    assert(
        outcome.contains_individual_identifiers ~= true,
        "individual identifiers are not accepted by this monitor"
    )
    assert(
        outcome.contains_raw_assistive_data ~= true,
        "raw assistive data is not accepted by this monitor"
    )
    assert(
        outcome.contains_biometric_data ~= true,
        "biometric data is not accepted by this monitor"
    )

    local dimensions = normalize_dimensions(outcome.dimensions or {})
    local evidence_complete = outcome.evidence_complete == true
    local dimension_score = dimension_average(dimensions)
    local critical_condition = has_critical_condition(outcome)
    local fairness_score = clamp01(
        dimension_score - (critical_condition and 0.35 or 0)
    )
    local evidence_score = evidence_complete and 1.0 or 0.0

    local group = self:_group_state(group_reference)

    bounded_append(
        group.fairness_scores,
        fairness_score,
        self.window_size
    )
    bounded_append(
        group.evidence_scores,
        evidence_score,
        self.window_size
    )

    for _, dimension in ipairs(protected_dimensions) do
        bounded_append(
            group.dimensions[dimension],
            dimensions[dimension],
            self.window_size
        )
    end

    group.observation_count = group.observation_count + 1

    local normalized = {
        outcome_id = outcome_id,
        service_reference = service_reference,
        group_reference = group_reference,
        aggregate_group = true,
        dimensions = dimensions,
        fairness_score = fairness_score,
        evidence_complete = evidence_complete,
        critical_condition = critical_condition,
        critical_flags = {
            assistive_access_failure =
                outcome.assistive_access_failure == true,
            identity_verifiability_penalty =
                outcome.identity_verifiability_penalty == true,
            continuity_access_failure =
                outcome.continuity_access_failure == true,
            raw_identifier_disclosure =
                outcome.raw_identifier_disclosure == true,
            augmentation_status_penalty =
                outcome.augmentation_status_penalty == true,
        },
        knowledge_factor = evidence_complete and 0.85 or 0.55,
        eco_impact_value = clamp01(outcome.eco_impact_value or 0.50),
        harm_risk = clamp01(
            (1 - fairness_score) * 0.55
                + (critical_condition and 0.30 or 0)
                + (not evidence_complete and 0.15 or 0)
        ),
        observed_at_utc = outcome.observed_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    normalized.sequence = self.sequence
    self.observations[#self.observations + 1] = copy_value(normalized)

    local alert = self:evaluate_service(service_reference)

    return {
        observation = normalized,
        service_assessment = alert,
    }
end

function ContinuousFairnessMonitor:_service_groups(service_reference)
    local results = {}

    for group_reference, group in pairs(self.groups) do
        local relevant = false

        for _, observation in ipairs(self.observations) do
            if observation.service_reference == service_reference
                and observation.group_reference == group_reference then
                relevant = true
                break
            end
        end

        if relevant then
            results[#results + 1] = {
                group_reference = group_reference,
                state = group,
            }
        end
    end

    return results
end

function ContinuousFairnessMonitor:evaluate_service(service_reference)
    service_reference = required_text(
        service_reference,
        "service_reference"
    )

    local groups = self:_service_groups(service_reference)
    local group_results = {}
    local mean_scores = {}
    local latest_scores = {}
    local evidence_scores = {}
    local critical_observations = 0

    for _, item in ipairs(groups) do
        local group = item.state
        local fair_average = average(group.fairness_scores)
        local evidence_average = average(group.evidence_scores)
        local latest_score = group.fairness_scores[#group.fairness_scores] or 0

        local dimensions = {}

        for _, dimension in ipairs(protected_dimensions) do
            dimensions[dimension] = average(group.dimensions[dimension])
        end

        group_results[#group_results + 1] = {
            group_reference = item.group_reference,
            observation_count = group.observation_count,
            rolling_fairness_score = fair_average,
            latest_fairness_score = latest_score,
            evidence_coverage = evidence_average,
            dimension_scores = dimensions,
        }

        mean_scores[#mean_scores + 1] = fair_average
        latest_scores[#latest_scores + 1] = latest_score
        evidence_scores[#evidence_scores + 1] = evidence_average
    end

    for _, observation in ipairs(self.observations) do
        if observation.service_reference == service_reference
            and observation.critical_condition then
            critical_observations = critical_observations + 1
        end
    end

    local highest_score = 0
    local lowest_score = 1

    for _, score in ipairs(mean_scores) do
        highest_score = math.max(highest_score, score)
        lowest_score = math.min(lowest_score, score)
    end

    local fairness_gap = #mean_scores > 1
        and highest_score - lowest_score
        or 0

    local rolling_fairness = average(mean_scores)
    local latest_fairness = average(latest_scores)
    local baseline_decline = math.max(0, rolling_fairness - latest_fairness)
    local evidence_coverage = average(evidence_scores)

    local reasons = {}

    if fairness_gap > self.maximum_fairness_gap then
        reasons[#reasons + 1] =
            "aggregate fairness gap between groups exceeds the configured threshold"
    end

    if baseline_decline > self.maximum_baseline_decline then
        reasons[#reasons + 1] =
            "latest fairness outcome declined beyond the configured rolling baseline threshold"
    end

    if evidence_coverage < self.minimum_evidence_coverage then
        reasons[#reasons + 1] =
            "evidence coverage is below the configured monitoring threshold"
    end

    if critical_observations > 0 then
        reasons[#reasons + 1] =
            "one or more critical access, continuity, identity-neutrality, or privacy conditions were reported"
    end

    local alert_level = "low"

    if critical_observations > 0
        or fairness_gap > self.maximum_fairness_gap * 1.5
        or baseline_decline > self.maximum_baseline_decline * 1.5 then
        alert_level = "high"
    elseif #reasons > 0 then
        alert_level = "watch"
    end

    local assessment = {
        service_reference = service_reference,
        advisory_only = true,
        individual_tracking_used = false,
        group_count = #group_results,
        group_results = group_results,
        rolling_fairness_score = rolling_fairness,
        latest_fairness_score = latest_fairness,
        fairness_gap = fairness_gap,
        baseline_decline = baseline_decline,
        evidence_coverage = evidence_coverage,
        critical_observation_count = critical_observations,
        alert_level = alert_level,
        drift_detected = #reasons > 0,
        reasons = reasons,
        recommended_review = #reasons > 0
            and "Conduct an accountable, accessible, privacy-preserving review; do not automate service denial or enforcement."
            or "Continue aggregate monitoring and accessible feedback review.",
        knowledge_factor = clamp01(
            evidence_coverage * 0.70
                + math.min(1.0, #group_results / 2) * 0.30
        ),
        eco_impact_value = 0.50,
        harm_risk = clamp01(
            fairness_gap * 0.35
                + baseline_decline * 0.30
                + (1 - evidence_coverage) * 0.15
                + (critical_observations > 0 and 0.30 or 0)
        ),
        assessed_at_utc = utc_now(),
    }

    if assessment.drift_detected then
        self:_record_alert(assessment)
    end

    return assessment
end

function ContinuousFairnessMonitor:_record_alert(assessment)
    local alert = {
        alert_id = "fairness-alert-" .. tostring(self.sequence + 1),
        service_reference = assessment.service_reference,
        alert_level = assessment.alert_level,
        reasons = copy_value(assessment.reasons),
        fairness_gap = assessment.fairness_gap,
        baseline_decline = assessment.baseline_decline,
        evidence_coverage = assessment.evidence_coverage,
        critical_observation_count = assessment.critical_observation_count,
        advisory_only = true,
        automatic_enforcement_performed = false,
        created_at_utc = utc_now(),
        knowledge_factor = assessment.knowledge_factor,
        eco_impact_value = assessment.eco_impact_value,
        harm_risk = assessment.harm_risk,
    }

    self.alerts[#self.alerts + 1] = alert
end

function ContinuousFairnessMonitor:alerts_since(index)
    index = index or 0
    finite_number(index, "index")

    assert(
        index >= 0 and index % 1 == 0,
        "index must be a non-negative integer"
    )

    local results = {}
    local highest_harm_risk = 0

    for alert_index = index + 1, #self.alerts do
        local alert = self.alerts[alert_index]
        results[#results + 1] = copy_value(alert)
        highest_harm_risk = math.max(
            highest_harm_risk,
            alert.harm_risk
        )
    end

    return {
        from_index = index,
        alert_count = #results,
        alerts = results,
        knowledge_factor = #results == 0 and 0 or (function()
            local total = 0

            for _, alert in ipairs(results) do
                total = total + alert.knowledge_factor
            end

            return total / #results
        end)(),
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return ContinuousFairnessMonitor
