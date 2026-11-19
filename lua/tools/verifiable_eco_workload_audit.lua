local verifiable_eco_workload_audit = {}

local function is_finite(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function assert_finite(value, field_name)
    assert(is_finite(value), field_name .. " must be a finite number")
    return value
end

local function assert_nonnegative(value, field_name)
    assert_finite(value, field_name)
    assert(value >= 0, field_name .. " must be non-negative")
    return value
end

local function assert_positive(value, field_name)
    assert_nonnegative(value, field_name)
    assert(value > 0, field_name .. " must be greater than zero")
    return value
end

local function assert_unit_interval(value, field_name)
    assert_finite(value, field_name)
    assert(value >= 0 and value <= 1, field_name .. " must be in [0, 1]")
    return value
end

local function assert_boolean(value, field_name)
    assert(type(value) == "boolean", field_name .. " must be boolean")
    return value
end

local function assert_string(value, field_name)
    assert(type(value) == "string" and value ~= "",
        field_name .. " must be a non-empty string")
    return value
end

local function clamp(value, lower, upper)
    if value < lower then
        return lower
    end
    if value > upper then
        return upper
    end
    return value
end

local function average(values, field_name)
    assert(type(values) == "table" and #values > 0,
        field_name .. " must be a non-empty array")

    local total = 0
    for index, value in ipairs(values) do
        total = total + assert_finite(value, field_name .. "[" .. index .. "]")
    end

    return total / #values
end

local function sort_descending(items)
    table.sort(items, function(left, right)
        if left.score == right.score then
            return left.id < right.id
        end
        return left.score > right.score
    end)
end

function verifiable_eco_workload_audit.information_gain(entropy_before, entropy_after)
    entropy_before = assert_nonnegative(entropy_before, "entropy_before")
    entropy_after = assert_nonnegative(entropy_after, "entropy_after")

    return math.max(0, entropy_before - entropy_after)
end

function verifiable_eco_workload_audit.eco_fact_score(input)
    assert(type(input) == "table", "eco-fact input must be a table")
    assert(type(input.weights) == "table", "input.weights must be a table")

    local information_gain = assert_unit_interval(
        input.information_gain,
        "information_gain"
    )
    local novelty = assert_unit_interval(input.novelty, "novelty")
    local verifiability = assert_unit_interval(
        input.verifiability,
        "verifiability"
    )
    local uncertainty = assert_unit_interval(input.uncertainty, "uncertainty")
    local method_disclosed = assert_boolean(
        input.method_disclosed,
        "method_disclosed"
    )
    local aggregation_safe = assert_boolean(
        input.aggregation_safe,
        "aggregation_safe"
    )

    local information_gain_weight = assert_nonnegative(
        input.weights.information_gain,
        "weights.information_gain"
    )
    local novelty_weight = assert_nonnegative(
        input.weights.novelty,
        "weights.novelty"
    )
    local verifiability_weight = assert_nonnegative(
        input.weights.verifiability,
        "weights.verifiability"
    )
    local total_weight =
        information_gain_weight + novelty_weight + verifiability_weight

    assert(total_weight > 0, "at least one eco-fact weight must be positive")

    local raw_score = (
        information_gain_weight * information_gain +
        novelty_weight * novelty +
        verifiability_weight * verifiability
    ) / total_weight

    local score = raw_score * (1 - uncertainty)
    local publishable = score >= (input.publication_threshold or 0.75)
        and method_disclosed
        and aggregation_safe

    return {
        fact_score = score,
        raw_score = raw_score,
        information_gain = information_gain,
        novelty = novelty,
        verifiability = verifiability,
        uncertainty = uncertainty,
        method_disclosed = method_disclosed,
        aggregation_safe = aggregation_safe,
        publishable_candidate = publishable,
        publication_requirements = {
            "aggregate_or_non_identifying_source_data",
            "measurement_units_and_time_window",
            "method_and_uncertainty_disclosure",
            "independent_or_cross_sensor_verification_when_available",
            "non_stigmatizing_public_language",
        },
        decision = publishable
            and "release as a qualified aggregate eco-fact with method, period, units, uncertainty, and verification notes"
            or "retain for validation; do not publish as a public eco-fact yet",
    }
end

function verifiable_eco_workload_audit.drift_or_event_assessment(input)
    assert(type(input) == "table", "drift input must be a table")

    local reading = assert_finite(input.reading, "reading")
    local baseline_mean = assert_finite(input.baseline_mean, "baseline_mean")
    local baseline_standard_deviation = assert_positive(
        input.baseline_standard_deviation,
        "baseline_standard_deviation"
    )
    local event_threshold_z = assert_positive(
        input.event_threshold_z,
        "event_threshold_z"
    )
    local reference_sensor_agreement = assert_unit_interval(
        input.reference_sensor_agreement,
        "reference_sensor_agreement"
    )
    local expected_physical_context = assert_unit_interval(
        input.expected_physical_context,
        "expected_physical_context"
    )
    local calibration_health = assert_unit_interval(
        input.calibration_health,
        "calibration_health"
    )
    local persistent_offset_windows = assert_nonnegative(
        input.persistent_offset_windows,
        "persistent_offset_windows"
    )
    local drift_window_threshold = assert_positive(
        input.drift_window_threshold,
        "drift_window_threshold"
    )

    local z_score = (reading - baseline_mean) / baseline_standard_deviation
    local anomalous = math.abs(z_score) >= event_threshold_z

    local event_evidence = average({
        reference_sensor_agreement,
        expected_physical_context,
        calibration_health,
    }, "event evidence")

    local drift_evidence = average({
        1 - reference_sensor_agreement,
        1 - calibration_health,
        clamp(persistent_offset_windows / drift_window_threshold, 0, 1),
    }, "drift evidence")

    local classification
    if not anomalous then
        classification = "within_baseline_variation"
    elseif drift_evidence > event_evidence then
        classification = "candidate_calibration_drift"
    else
        classification = "candidate_environmental_event"
    end

    return {
        z_score = z_score,
        anomalous = anomalous,
        event_evidence = event_evidence,
        drift_evidence = drift_evidence,
        classification = classification,
        decision = classification == "candidate_environmental_event"
            and "cross-check independent measurements and context before issuing a public eco-fact"
            or "inspect calibration, placement, timing, and sensor health before treating the change as environmental",
        limitation = "This is an interpretable screening method, not a universal best detector. Select models using labeled local history, failure-mode testing, and uncertainty evaluation.",
    }
end

function verifiable_eco_workload_audit.door_latency_budget(input)
    assert(type(input) == "table", "latency input must be a table")
    assert(type(input.sensors) == "table" and #input.sensors > 0,
        "sensors must be a non-empty array")

    local total_budget_ms = assert_positive(
        input.total_budget_ms,
        "total_budget_ms"
    )
    local reserve_ms = assert_nonnegative(input.reserve_ms, "reserve_ms")
    assert(reserve_ms < total_budget_ms,
        "reserve_ms must be smaller than total_budget_ms")

    local available_ms = total_budget_ms - reserve_ms
    local total_priority = 0

    for index, sensor in ipairs(input.sensors) do
        assert(type(sensor) == "table", "sensors[" .. index .. "] must be a table")
        total_priority = total_priority + assert_positive(
            sensor.priority,
            "sensors[" .. index .. "].priority"
        )
    end

    local allocations = {}
    local planned_total_ms = reserve_ms

    for index, sensor in ipairs(input.sensors) do
        local name = assert_string(sensor.name, "sensors[" .. index .. "].name")
        local priority = assert_positive(sensor.priority, "sensors[" .. index .. "].priority")
        local minimum_ms = assert_nonnegative(
            sensor.minimum_ms,
            "sensors[" .. index .. "].minimum_ms"
        )
        local maximum_ms = assert_positive(
            sensor.maximum_ms,
            "sensors[" .. index .. "].maximum_ms"
        )
        assert(maximum_ms >= minimum_ms,
            "sensors[" .. index .. "] maximum_ms must be at least minimum_ms")

        local allocated_ms = available_ms * priority / total_priority
        allocated_ms = math.max(minimum_ms, math.min(maximum_ms, allocated_ms))
        planned_total_ms = planned_total_ms + allocated_ms

        allocations[#allocations + 1] = {
            name = name,
            allocated_ms = allocated_ms,
            minimum_ms = minimum_ms,
            maximum_ms = maximum_ms,
            priority = priority,
        }
    end

    return {
        total_budget_ms = total_budget_ms,
        reserve_ms = reserve_ms,
        allocated_sensor_time_ms = planned_total_ms - reserve_ms,
        planned_total_ms = planned_total_ms,
        within_budget = planned_total_ms <= total_budget_ms,
        allocations = allocations,
        decision = planned_total_ms <= total_budget_ms
            and "validate the allocation against observed end-to-end timing, fail-safe passage behavior, and accessibility requirements"
            or "reduce requested sensor bounds or increase the validated budget; do not rely on the proposed allocation",
        limitation = "Latency allocation alone cannot establish door safety. Preserve non-sensor-dependent access and qualified safety validation.",
    }
end

function verifiable_eco_workload_audit.rank_predictive_maintenance(input)
    assert(type(input) == "table", "maintenance input must be a table")
    assert(type(input.assets) == "table" and #input.assets > 0,
        "assets must be a non-empty array")

    local energy_weight = assert_nonnegative(input.energy_weight, "energy_weight")
    local downtime_weight = assert_nonnegative(input.downtime_weight, "downtime_weight")
    local service_continuity_weight = assert_nonnegative(
        input.service_continuity_weight,
        "service_continuity_weight"
    )
    local inspection_confidence_weight = assert_nonnegative(
        input.inspection_confidence_weight,
        "inspection_confidence_weight"
    )
    local total_weight =
        energy_weight + downtime_weight + service_continuity_weight
        + inspection_confidence_weight
    assert(total_weight > 0, "at least one maintenance weight must be positive")

    local ranked = {}

    for index, asset in ipairs(input.assets) do
        assert(type(asset) == "table", "assets[" .. index .. "] must be a table")

        local id = assert_string(asset.id, "assets[" .. index .. "].id")
        local energy_waste_risk = assert_unit_interval(
            asset.energy_waste_risk,
            "assets[" .. index .. "].energy_waste_risk"
        )
        local downtime_risk = assert_unit_interval(
            asset.downtime_risk,
            "assets[" .. index .. "].downtime_risk"
        )
        local service_continuity_criticality = assert_unit_interval(
            asset.service_continuity_criticality,
            "assets[" .. index .. "].service_continuity_criticality"
        )
        local inspection_confidence = assert_unit_interval(
            asset.inspection_confidence,
            "assets[" .. index .. "].inspection_confidence"
        )

        local score = (
            energy_weight * energy_waste_risk +
            downtime_weight * downtime_risk +
            service_continuity_weight * service_continuity_criticality +
            inspection_confidence_weight * inspection_confidence
        ) / total_weight

        ranked[#ranked + 1] = {
            id = id,
            score = score,
            energy_waste_risk = energy_waste_risk,
            downtime_risk = downtime_risk,
            service_continuity_criticality = service_continuity_criticality,
            inspection_confidence = inspection_confidence,
            inspection_priority = score >= (input.inspection_threshold or 0.7),
        }
    end

    sort_descending(ranked)

    return {
        ranked_assets = ranked,
        highest_priority_asset = ranked[1],
        limitation = "This ranks supplied risk indicators; it does not predict failure, control equipment, or replace qualified maintenance and accessibility continuity planning.",
    }
end

function verifiable_eco_workload_audit.fair_neighborhood_policy(input)
    assert(type(input) == "table", "policy input must be a table")
    assert(type(input.neighborhoods) == "table" and #input.neighborhoods > 0,
        "neighborhoods must be a non-empty array")

    local fairness_tolerance = assert_unit_interval(
        input.fairness_tolerance,
        "fairness_tolerance"
    )
    local utility_weight = assert_nonnegative(input.utility_weight, "utility_weight")
    local fairness_weight = assert_nonnegative(input.fairness_weight, "fairness_weight")
    local ecological_weight = assert_nonnegative(
        input.ecological_weight,
        "ecological_weight"
    )
    local total_weight = utility_weight + fairness_weight + ecological_weight
    assert(total_weight > 0, "at least one policy weight must be positive")

    local service_levels = {}
    local candidates = {}

    for index, neighborhood in ipairs(input.neighborhoods) do
        assert(type(neighborhood) == "table",
            "neighborhoods[" .. index .. "] must be a table")

        local id = assert_string(neighborhood.id, "neighborhoods[" .. index .. "].id")
        local service_benefit = assert_unit_interval(
            neighborhood.service_benefit,
            "neighborhoods[" .. index .. "].service_benefit"
        )
        local ecological_benefit = assert_unit_interval(
            neighborhood.ecological_benefit,
            "neighborhoods[" .. index .. "].ecological_benefit"
        )
        local access_continuity = assert_unit_interval(
            neighborhood.access_continuity,
            "neighborhoods[" .. index .. "].access_continuity"
        )
        local voluntary_aggregate_data = assert_boolean(
            neighborhood.voluntary_aggregate_data,
            "neighborhoods[" .. index .. "].voluntary_aggregate_data"
        )

        service_levels[#service_levels + 1] = service_benefit
        candidates[#candidates + 1] = {
            id = id,
            service_benefit = service_benefit,
            ecological_benefit = ecological_benefit,
            access_continuity = access_continuity,
            voluntary_aggregate_data = voluntary_aggregate_data,
        }
    end

    local mean_service = average(service_levels, "service levels")
    local maximum_disparity = 0

    for _, candidate in ipairs(candidates) do
        candidate.service_disparity = math.abs(
            candidate.service_benefit - mean_service
        )
        maximum_disparity = math.max(
            maximum_disparity,
            candidate.service_disparity
        )

        candidate.score = (
            utility_weight * candidate.service_benefit +
            fairness_weight * (1 - candidate.service_disparity) +
            ecological_weight * candidate.ecological_benefit
        ) / total_weight

        candidate.score = candidate.score
            * candidate.access_continuity
            * (candidate.voluntary_aggregate_data and 1 or 0)
    end

    sort_descending(candidates)

    return {
        ranked_policy_outcomes = candidates,
        mean_service_benefit = mean_service,
        maximum_service_disparity = maximum_disparity,
        fairness_tolerance = fairness_tolerance,
        fairness_constraint_met = maximum_disparity <= fairness_tolerance,
        recommendation = maximum_disparity <= fairness_tolerance
            and "the supplied policy outcome meets its aggregate parity bound; continue participatory review and monitor for changing disparities"
            or "reject or revise the policy outcome until aggregate service disparities meet the stated fairness bound",
        limitation = "This is not an implementation of reinforcement learning or automated resource control. Any learning system must remain constrained by public rules, aggregate fairness checks, human oversight, and non-identifying data practices.",
    }
end

function verifiable_eco_workload_audit.assessment_metrics(input)
    assert(type(input) == "table", "metrics input must be a table")

    local knowledge_factor = average({
        assert_unit_interval(input.sensor_validation_coverage, "sensor_validation_coverage"),
        assert_unit_interval(input.cross_check_quality, "cross_check_quality"),
        assert_unit_interval(input.maintenance_history_quality, "maintenance_history_quality"),
        assert_unit_interval(input.community_review_quality, "community_review_quality"),
    }, "knowledge-factor inputs")

    local eco_impact_value = average({
        assert_unit_interval(input.eco_fact_value, "eco_fact_value"),
        assert_unit_interval(input.energy_waste_reduction, "energy_waste_reduction"),
        assert_unit_interval(input.service_continuity_benefit, "service_continuity_benefit"),
        assert_unit_interval(input.neighborhood_equity_benefit, "neighborhood_equity_benefit"),
    }, "eco-impact inputs")

    local harm_risk = average({
        assert_unit_interval(input.false_event_risk, "false_event_risk"),
        assert_unit_interval(input.sensor_fusion_failure_risk, "sensor_fusion_failure_risk"),
        assert_unit_interval(input.maintenance_misprioritization_risk, "maintenance_misprioritization_risk"),
        assert_unit_interval(input.neighborhood_exclusion_risk, "neighborhood_exclusion_risk"),
        assert_unit_interval(input.privacy_risk, "privacy_risk"),
    }, "harm-risk inputs")

    return {
        knowledge_factor = knowledge_factor,
        eco_impact_value = eco_impact_value,
        harm_risk = harm_risk,
    }
end

return verifiable_eco_workload_audit
