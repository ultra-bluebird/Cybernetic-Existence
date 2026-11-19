local cybernetic_access_acceptance_research = {}

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

local function mean(values, field_name)
    assert(type(values) == "table" and #values > 0,
        field_name .. " must be a non-empty array")

    local total = 0
    for index, value in ipairs(values) do
        total = total + assert_finite(value, field_name .. "[" .. index .. "]")
    end

    return total / #values
end

local function sorted_keys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function cybernetic_access_acceptance_research.non_invasive_status_ping(input)
    assert(type(input) == "table", "status-ping input must be a table")

    local service_available = assert_boolean(
        input.service_available,
        "service_available"
    )
    local status_freshness_s = assert_nonnegative(
        input.status_freshness_s,
        "status_freshness_s"
    )
    local maximum_status_age_s = assert_positive(
        input.maximum_status_age_s,
        "maximum_status_age_s"
    )
    local carries_identity = assert_boolean(
        input.carries_identity,
        "carries_identity"
    )
    local carries_health_data = assert_boolean(
        input.carries_health_data,
        "carries_health_data"
    )
    local contains_unique_persistent_identifier = assert_boolean(
        input.contains_unique_persistent_identifier,
        "contains_unique_persistent_identifier"
    )
    local locally_interpretable = assert_boolean(
        input.locally_interpretable,
        "locally_interpretable"
    )
    local human_fallback_available = assert_boolean(
        input.human_fallback_available,
        "human_fallback_available"
    )

    local fresh = status_freshness_s <= maximum_status_age_s
    local data_minimized = not carries_identity
        and not carries_health_data
        and not contains_unique_persistent_identifier

    return {
        status_ping_usable = service_available
            and fresh
            and data_minimized
            and locally_interpretable,
        service_available = service_available,
        fresh = fresh,
        data_minimized = data_minimized,
        locally_interpretable = locally_interpretable,
        human_fallback_available = human_fallback_available,
        required_payload_boundary = {
            "service_status_only",
            "short_lived_or_session_scoped",
            "no_identity_data",
            "no_health_data",
            "no_persistent_unique_identifier",
        },
        decision = service_available and fresh and data_minimized and locally_interpretable
            and "publish a minimal local status signal; retain an accessible non-digital fallback"
            or "do not rely on the status signal for access; correct the privacy, freshness, or availability gap",
    }
end

function cybernetic_access_acceptance_research.emc_zone_assessment(input)
    assert(type(input) == "table", "EMC zone input must be a table")
    assert(type(input.measurements) == "table" and #input.measurements > 0,
        "measurements must be a non-empty array")

    local host_threshold = assert_nonnegative(
        input.host_safe_interference_threshold,
        "host_safe_interference_threshold"
    )
    assert(host_threshold > 0,
        "host_safe_interference_threshold must be greater than zero")

    local zone_measurements = {}
    local maximum_interference = 0
    local total_interference = 0

    for index, measurement in ipairs(input.measurements) do
        assert(type(measurement) == "table",
            "measurements[" .. index .. "] must be a table")

        local location_id = assert_string(
            measurement.location_id,
            "measurements[" .. index .. "].location_id"
        )
        local interference = assert_nonnegative(
            measurement.interference,
            "measurements[" .. index .. "].interference"
        )
        local duration_s = assert_nonnegative(
            measurement.duration_s,
            "measurements[" .. index .. "].duration_s"
        )

        maximum_interference = math.max(maximum_interference, interference)
        total_interference = total_interference + interference

        zone_measurements[#zone_measurements + 1] = {
            location_id = location_id,
            interference = interference,
            duration_s = duration_s,
            compatible = interference < host_threshold,
            margin = host_threshold - interference,
        }
    end

    return {
        host_safe_interference_threshold = host_threshold,
        maximum_measured_interference = maximum_interference,
        mean_measured_interference = total_interference / #zone_measurements,
        zone_compatible = maximum_interference < host_threshold,
        measurements = zone_measurements,
        recommendation = maximum_interference < host_threshold
            and "treat the zone as provisionally compatible for the supplied threshold and measurement conditions"
            or "identify and mitigate locations at or above the host-specific threshold before treating the zone as compatible",
        limitation = "This is a measurement comparison tool. It does not substitute for qualified electromagnetic compatibility assessment, spectrum compliance, device-specific testing, or medical guidance.",
    }
end

function cybernetic_access_acceptance_research.acceptance_step(input)
    assert(type(input) == "table", "acceptance input must be a table")

    local acceptance = assert_unit_interval(input.acceptance, "acceptance")
    local fairness_signals = assert_unit_interval(
        input.fairness_signals,
        "fairness_signals"
    )
    local discrimination_events = assert_unit_interval(
        input.discrimination_events,
        "discrimination_events"
    )
    local peer_influence = assert_nonnegative(
        input.peer_influence,
        "peer_influence"
    )
    local institutional_influence = assert_nonnegative(
        input.institutional_influence,
        "institutional_influence"
    )
    local backlash = assert_nonnegative(input.backlash, "backlash")
    local time_step = assert_positive(input.time_step, "time_step")

    local derivative =
        peer_influence * acceptance * (1 - acceptance) +
        institutional_influence * fairness_signals * (1 - acceptance) -
        backlash * discrimination_events * acceptance

    local next_acceptance = clamp(
        acceptance + derivative * time_step,
        0,
        1
    )

    return {
        acceptance = acceptance,
        next_acceptance = next_acceptance,
        change = next_acceptance - acceptance,
        derivative = derivative,
        positive_change = next_acceptance > acceptance,
        fairness_signals = fairness_signals,
        discrimination_events = discrimination_events,
        interpretation = next_acceptance > acceptance
            and "the supplied scenario increases modeled acceptance"
            or "the supplied scenario does not increase modeled acceptance",
    }
end

function cybernetic_access_acceptance_research.simulate_acceptance(input)
    assert(type(input) == "table", "acceptance simulation input must be a table")
    assert(type(input.initial_state) == "table",
        "input.initial_state must be a table")
    assert(type(input.periods) == "table" and #input.periods > 0,
        "periods must be a non-empty array")

    local state = {
        acceptance = assert_unit_interval(
            input.initial_state.acceptance,
            "initial_state.acceptance"
        ),
        peer_influence = assert_nonnegative(
            input.initial_state.peer_influence,
            "initial_state.peer_influence"
        ),
        institutional_influence = assert_nonnegative(
            input.initial_state.institutional_influence,
            "initial_state.institutional_influence"
        ),
        backlash = assert_nonnegative(
            input.initial_state.backlash,
            "initial_state.backlash"
        ),
    }

    local trace = {}

    for index, period in ipairs(input.periods) do
        assert(type(period) == "table", "periods[" .. index .. "] must be a table")

        local result = cybernetic_access_acceptance_research.acceptance_step({
            acceptance = state.acceptance,
            fairness_signals = assert_unit_interval(
                period.fairness_signals,
                "periods[" .. index .. "].fairness_signals"
            ),
            discrimination_events = assert_unit_interval(
                period.discrimination_events,
                "periods[" .. index .. "].discrimination_events"
            ),
            peer_influence = state.peer_influence,
            institutional_influence = state.institutional_influence,
            backlash = state.backlash,
            time_step = assert_positive(
                period.time_step,
                "periods[" .. index .. "].time_step"
            ),
        })

        trace[#trace + 1] = {
            period = index,
            acceptance = result.acceptance,
            next_acceptance = result.next_acceptance,
            change = result.change,
            fairness_signals = result.fairness_signals,
            discrimination_events = result.discrimination_events,
        }

        state.acceptance = result.next_acceptance
    end

    return {
        trace = trace,
        final_acceptance = state.acceptance,
        initial_acceptance = trace[1].acceptance,
        total_change = state.acceptance - trace[1].acceptance,
        limitation = "This is a scenario model, not a prediction of any group or individual. Parameters require transparent local evidence, participatory review, and sensitivity analysis.",
    }
end

function cybernetic_access_acceptance_research.access_parity(input)
    assert(type(input) == "table", "access-parity input must be a table")
    assert(type(input.components) == "table" and #input.components > 0,
        "components must be a non-empty array")

    local results = {}

    for index, component in ipairs(input.components) do
        assert(type(component) == "table",
            "components[" .. index .. "] must be a table")

        local component_type = assert_string(
            component.component_type,
            "components[" .. index .. "].component_type"
        )
        local cybernetic_access = assert_unit_interval(
            component.cybernetic_host_access,
            "components[" .. index .. "].cybernetic_host_access"
        )
        local baseline_access = assert_unit_interval(
            component.baseline_access,
            "components[" .. index .. "].baseline_access"
        )
        local human_review = assert_boolean(
            component.accessible_human_review,
            "components[" .. index .. "].accessible_human_review"
        )
        local continuity = assert_boolean(
            component.continuity_measure,
            "components[" .. index .. "].continuity_measure"
        )

        local parity = 1 - math.abs(cybernetic_access - baseline_access)
        local redesign_required = parity < 1 or not human_review or not continuity

        results[#results + 1] = {
            component_type = component_type,
            cybernetic_host_access = cybernetic_access,
            baseline_access = baseline_access,
            access_parity = parity,
            accessible_human_review = human_review,
            continuity_measure = continuity,
            redesign_or_protection_required = redesign_required,
        }
    end

    return {
        components = results,
        mean_access_parity = mean((function()
            local values = {}
            for _, result in ipairs(results) do
                values[#values + 1] = result.access_parity
            end
            return values
        end)(), "access parity values"),
        limitation = "Parity must be evaluated with representative, voluntary, non-identifying accessibility testing and cannot be inferred from device category alone.",
    }
end

function cybernetic_access_acceptance_research.privacy_preserving_eligibility(input)
    assert(type(input) == "table", "eligibility input must be a table")

    local proof_verified = assert_boolean(
        input.proof_verified,
        "proof_verified"
    )
    local eligibility_confirmed = assert_boolean(
        input.eligibility_confirmed,
        "eligibility_confirmed"
    )
    local identity_disclosed = assert_boolean(
        input.identity_disclosed,
        "identity_disclosed"
    )
    local medical_data_disclosed = assert_boolean(
        input.medical_data_disclosed,
        "medical_data_disclosed"
    )
    local persistent_identifier_used = assert_boolean(
        input.persistent_identifier_used,
        "persistent_identifier_used"
    )
    local scope_limited = assert_boolean(
        input.proof_scope_limited,
        "proof_scope_limited"
    )
    local expiry_enforced = assert_boolean(
        input.proof_expiry_enforced,
        "proof_expiry_enforced"
    )
    local accessible_non_digital_fallback = assert_boolean(
        input.accessible_non_digital_fallback,
        "accessible_non_digital_fallback"
    )

    local disclosure_free = not identity_disclosed
        and not medical_data_disclosed
        and not persistent_identifier_used
    local proof = proof_verified and eligibility_confirmed
    local access = proof and disclosure_free and scope_limited and expiry_enforced

    return {
        proof = proof,
        disclosure_free = disclosure_free,
        scope_limited = scope_limited,
        expiry_enforced = expiry_enforced,
        accessible_non_digital_fallback = accessible_non_digital_fallback,
        access_eligible_without_disclosure = access,
        protocol_properties = {
            "verifiable_eligibility_claim",
            "purpose_limited_proof",
            "short_validity_period",
            "minimal_disclosure",
            "no_persistent_cross_service_identifier",
            "accessible_human_or_non_digital_fallback",
        },
        decision = access
            and "accept the verified, scoped proof without requesting identity or medical data"
            or "do not request additional sensitive data; provide an accessible fallback and correct the proof-design gap",
    }
end

function cybernetic_access_acceptance_research.assessment_metrics(input)
    assert(type(input) == "table", "metrics input must be a table")

    local knowledge_factor = mean({
        assert_unit_interval(input.measurement_coverage, "measurement_coverage"),
        assert_unit_interval(input.participatory_validation, "participatory_validation"),
        assert_unit_interval(input.privacy_design_review, "privacy_design_review"),
        assert_unit_interval(input.continuity_test_coverage, "continuity_test_coverage"),
    }, "knowledge-factor inputs")

    local eco_impact_value = mean({
        assert_unit_interval(input.service_continuity_benefit, "service_continuity_benefit"),
        assert_unit_interval(input.access_equity_benefit, "access_equity_benefit"),
        assert_unit_interval(input.energy_or_resource_efficiency, "energy_or_resource_efficiency"),
    }, "eco-impact inputs")

    local harm_risk = mean({
        assert_unit_interval(input.interference_risk, "interference_risk"),
        assert_unit_interval(input.data_disclosure_risk, "data_disclosure_risk"),
        assert_unit_interval(input.exclusion_risk, "exclusion_risk"),
        assert_unit_interval(input.acceptance_backlash_risk, "acceptance_backlash_risk"),
    }, "harm-risk inputs")

    return {
        knowledge_factor = knowledge_factor,
        eco_impact_value = eco_impact_value,
        harm_risk = harm_risk,
    }
end

return cybernetic_access_acceptance_research
