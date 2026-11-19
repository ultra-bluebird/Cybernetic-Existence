local SwarmEcologicalTaskPolicy = {}
SwarmEcologicalTaskPolicy.__index = SwarmEcologicalTaskPolicy

local VALID_TASK_CLASSES = {
    litter_collection = true,
    leaf_removal = true,
    drain_clearing = true,
    bioswale_inlet_clearing = true,
    accessibility_obstruction_review = true,
}

local VALID_SAFETY_STATES = {
    approved = true,
    review_required = true,
    blocked = true,
}

local VALID_ENERGY_BANDS = {
    critical = true,
    reserve_only = true,
    adequate = true,
    high = true,
}

local VALID_DEPLOYMENT_STATES = {
    simulation_only = true,
    shadow_mode = true,
    human_review_required = true,
}

local function assert_table(value, name)
    if type(value) ~= "table" then
        error(name .. " must be a table", 3)
    end
end

local function assert_boolean(value, name, expected)
    if value ~= expected then
        error(name .. " must be " .. tostring(expected), 3)
    end
end

local function assert_integer(value, name, minimum, maximum)
    if type(value) ~= "number" or value % 1 ~= 0 or value < minimum or value > maximum then
        error(name .. " must be an integer from " .. tostring(minimum) .. " through " .. tostring(maximum), 3)
    end
end

local function assert_fraction(value, name)
    if type(value) ~= "number" or value < 0 or value > 1 then
        error(name .. " must be a fraction from 0 through 1", 3)
    end
end

local function assert_non_empty_string(value, name, maximum_length)
    if type(value) ~= "string" or value == "" then
        error(name .. " must be a non-empty string", 3)
    end

    if #value > maximum_length then
        error(name .. " exceeds the maximum length", 3)
    end
end

function SwarmEcologicalTaskPolicy.new(policy)
    assert_table(policy, "policy")

    if policy.schema ~= "javasphere.swarm-ecological-task-policy/v1" then
        error("Unsupported swarm ecological task policy schema.", 2)
    end

    assert_non_empty_string(policy.policy_name, "policy.policy_name", 96)

    assert_table(policy.governance, "policy.governance")
    assert_boolean(
        policy.governance.community_review_completed,
        "policy.governance.community_review_completed",
        true
    )
    assert_boolean(
        policy.governance.qualified_operations_review_required,
        "policy.governance.qualified_operations_review_required",
        true
    )
    assert_boolean(
        policy.governance.human_dispatch_approval_required,
        "policy.governance.human_dispatch_approval_required",
        true
    )

    assert_table(policy.privacy, "policy.privacy")
    assert_boolean(policy.privacy.raw_location_history_stored, "policy.privacy.raw_location_history_stored", false)
    assert_boolean(policy.privacy.resident_data_stored, "policy.privacy.resident_data_stored", false)
    assert_boolean(policy.privacy.camera_or_audio_required, "policy.privacy.camera_or_audio_required", false)
    assert_boolean(policy.privacy.worker_tracking_enabled, "policy.privacy.worker_tracking_enabled", false)
    assert_boolean(policy.privacy.external_export_allowed, "policy.privacy.external_export_allowed", false)

    assert_table(policy.safety, "policy.safety")
    assert_boolean(
        policy.safety.accessible_route_protection_required,
        "policy.safety.accessible_route_protection_required",
        true
    )
    assert_boolean(
        policy.safety.pedestrian_safety_clearance_required,
        "policy.safety.pedestrian_safety_clearance_required",
        true
    )
    assert_boolean(
        policy.safety.noise_window_enforcement_required,
        "policy.safety.noise_window_enforcement_required",
        true
    )
    assert_boolean(
        policy.safety.return_energy_reserve_required,
        "policy.safety.return_energy_reserve_required",
        true
    )

    assert_table(policy.coordination, "policy.coordination")
    assert_boolean(policy.coordination.signed_messages_required, "policy.coordination.signed_messages_required", true)
    assert_boolean(policy.coordination.short_lived_leases_required, "policy.coordination.short_lived_leases_required", true)
    assert_integer(policy.coordination.lease_expiry_seconds, "policy.coordination.lease_expiry_seconds", 30, 3600)
    assert_boolean(policy.coordination.eventual_consistency_allowed, "policy.coordination.eventual_consistency_allowed", true)
    assert_boolean(policy.coordination.automatic_route_closure_allowed, "policy.coordination.automatic_route_closure_allowed", false)
    assert_boolean(policy.coordination.automatic_public_space_enforcement_allowed, "policy.coordination.automatic_public_space_enforcement_allowed", false)

    if not VALID_DEPLOYMENT_STATES[policy.deployment_state] then
        error("Unsupported deployment state.", 2)
    end

    return setmetatable({
        policy = policy,
    }, SwarmEcologicalTaskPolicy)
end

function SwarmEcologicalTaskPolicy:evaluate_eligibility(candidate)
    assert_table(candidate, "candidate")

    if not VALID_TASK_CLASSES[candidate.task_class] then
        error("Unsupported task class.", 2)
    end

    if not VALID_SAFETY_STATES[candidate.pedestrian_safety_state] then
        error("Unsupported pedestrian safety state.", 2)
    end

    if not VALID_SAFETY_STATES[candidate.accessible_route_state] then
        error("Unsupported accessible route state.", 2)
    end

    if not VALID_SAFETY_STATES[candidate.hazard_clearance_state] then
        error("Unsupported hazard clearance state.", 2)
    end

    if not VALID_ENERGY_BANDS[candidate.energy_band] then
        error("Unsupported energy band.", 2)
    end

    if candidate.pedestrian_safety_state ~= "approved" then
        return false, "Pedestrian safety clearance is not approved."
    end

    if candidate.accessible_route_state ~= "approved" then
        return false, "Accessible route protection is not approved."
    end

    if candidate.hazard_clearance_state ~= "approved" then
        return false, "Hazard clearance is not approved."
    end

    if candidate.noise_window_allowed ~= true then
        return false, "The task is outside its approved noise window."
    end

    if candidate.energy_band == "critical" or candidate.energy_band == "reserve_only" then
        return false, "The bot energy band does not preserve a safe return reserve."
    end

    if candidate.zone_service_floor_satisfied ~= true then
        return false, "The task would violate a declared zone service-floor obligation."
    end

    return true, "Candidate satisfies local ecological-task eligibility constraints."
end

function SwarmEcologicalTaskPolicy:calculate_bid(candidate)
    local eligible, reason = self:evaluate_eligibility(candidate)

    if not eligible then
        return {
            eligible = false,
            bid = 0,
            reason = reason,
        }
    end

    assert_fraction(candidate.ecological_benefit, "candidate.ecological_benefit")
    assert_fraction(candidate.urgency, "candidate.urgency")
    assert_fraction(candidate.coverage_need, "candidate.coverage_need")
    assert_fraction(candidate.travel_cost, "candidate.travel_cost")
    assert_fraction(candidate.energy_cost, "candidate.energy_cost")
    assert_fraction(candidate.noise_cost, "candidate.noise_cost")

    local numerator =
        0.45 * candidate.ecological_benefit +
        0.30 * candidate.urgency +
        0.25 * candidate.coverage_need

    local denominator =
        1 +
        0.35 * candidate.travel_cost +
        0.40 * candidate.energy_cost +
        0.25 * candidate.noise_cost

    return {
        eligible = true,
        bid = numerator / denominator,
        reason = "Candidate satisfies safety, accessibility, hazard, noise, energy, and coverage constraints.",
    }
end

return SwarmEcologicalTaskPolicy
