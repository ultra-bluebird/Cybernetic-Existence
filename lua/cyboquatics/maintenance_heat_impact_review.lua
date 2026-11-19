local maintenance_heat_impact_review = {}

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function unit_interval(value)
    return finite(value) and value >= 0.0 and value <= 1.0
end

function maintenance_heat_impact_review.evaluate(input)
    if type(input) ~= "table"
        or not finite(input.energyreq_j)
        or input.energyreq_j < 0.0
        or not finite(input.local_energy_budget_j)
        or input.local_energy_budget_j <= 0.0
        or not finite(input.delta_vt)
        or not finite(input.local_abs_delta_vt_heat_threshold)
        or input.local_abs_delta_vt_heat_threshold <= 0.0
        or not unit_interval(input.harm_risk_r)
        or type(input.reviewer_available) ~= "boolean"
        or type(input.interlocks_verified) ~= "boolean" then
        return {
            decision = "REJECTED_INPUT",
            physical_actuation_authorized = false,
            reasons = { "invalid_energy_delta_vt_or_review_input" }
        }
    end

    local reasons = {}

    if input.energyreq_j > input.local_energy_budget_j then
        table.insert(reasons, "energyreq_j_exceeds_local_budget")
    end
    if math.abs(input.delta_vt) > input.local_abs_delta_vt_heat_threshold then
        table.insert(reasons, "absolute_delta_vt_exceeds_heat_threshold")
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
            decision = "DEFER_TO_HUMAN_REVIEW",
            physical_actuation_authorized = false,
            reasons = reasons
        }
    end

    return {
        decision = "WITHIN_LOCAL_REVIEW_BOUNDS",
        physical_actuation_authorized = false,
        reasons = { "human_approval_required_before_any_physical_action" }
    }
end

return maintenance_heat_impact_review
