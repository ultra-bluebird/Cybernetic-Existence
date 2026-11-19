local maintenance_workload_review = {}

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function unit_interval(value)
    return finite(value) and value >= 0.0 and value <= 1.0
end

function maintenance_workload_review.evaluate(input)
    if type(input) ~= "table"
        or not finite(input.energyreq_j)
        or not finite(input.energy_budget_j)
        or not finite(input.delta_vt)
        or not finite(input.thermal_delta_vt_threshold)
        or not unit_interval(input.harm_risk_r)
        or input.energyreq_j < 0.0
        or input.energy_budget_j <= 0.0
        or input.thermal_delta_vt_threshold <= 0.0
        or type(input.reviewer_available) ~= "boolean"
        or type(input.interlocks_verified) ~= "boolean" then
        return {
            decision = "REJECTED_INPUT",
            reasons = { "invalid_or_non_finite_workload_input" },
            autonomous_actuation_permitted = false
        }
    end

    local reasons = {}

    if input.energyreq_j >= input.energy_budget_j then
        table.insert(reasons, "energy_budget_reached_or_exceeded")
    end
    if math.abs(input.delta_vt) >= input.thermal_delta_vt_threshold then
        table.insert(reasons, "delta_vt_threshold_reached_or_exceeded")
    end
    if input.harm_risk_r > 0.30 then
        table.insert(reasons, "harm_risk_exceeds_0_30")
    end
    if not input.reviewer_available then
        table.insert(reasons, "human_reviewer_unavailable")
    end
    if not input.interlocks_verified then
        table.insert(reasons, "safety_interlocks_unverified")
    end

    if #reasons > 0 then
        return {
            decision = "HUMAN_REVIEW_REQUIRED",
            reasons = reasons,
            autonomous_actuation_permitted = false
        }
    end

    return {
        decision = "WITHIN_REVIEW_BOUNDS",
        reasons = { "operator_review_still_required_before_any_physical_action" },
        autonomous_actuation_permitted = false
    }
end

return maintenance_workload_review
