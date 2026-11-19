local external_action_gate = {}

local function nonblank(value)
    return type(value) == "string" and value ~= ""
end

function external_action_gate.evaluate(packet)
    if type(packet) ~= "table"
        or not nonblank(packet.action_id)
        or not nonblank(packet.target_valve_id)
        or not nonblank(packet.requested_change)
        or not nonblank(packet.purpose)
        or not nonblank(packet.approved_at_utc)
        or not nonblank(packet.expires_at_utc) then
        return {
            decision = "REJECTED_INPUT",
            physical_actuation_authorized = false,
            reasons = { "missing_required_approval_packet_fields" }
        }
    end

    local requirements = {
        { "qualified_human_approver_id", "qualified_human_approver_missing" },
        { "qualification_current", "qualification_missing_or_expired" },
        { "exact_action_approved", "exact_valve_change_not_separately_approved" },
        { "risk_review_complete", "risk_review_incomplete" },
        { "safety_interlocks_verified", "safety_interlocks_unverified" },
        { "site_procedure_verified", "site_procedure_unverified" },
        { "accessible_explanation_provided", "accessible_explanation_missing" },
        { "audit_record_prepared", "audit_record_missing" }
    }

    local reasons = {}

    for _, requirement in ipairs(requirements) do
        local field = requirement[1]
        local reason = requirement[2]
        if field == "qualified_human_approver_id" then
            if not nonblank(packet[field]) then
                table.insert(reasons, reason)
            end
        elseif packet[field] ~= true then
            table.insert(reasons, reason)
        end
    end

    if #reasons > 0 then
        return {
            decision = "HUMAN_APPROVAL_REQUIRED",
            physical_actuation_authorized = false,
            reasons = reasons
        }
    end

    return {
        decision = "APPROVAL_PACKET_COMPLETE",
        physical_actuation_authorized = false,
        reasons = {
            "qualified_human_must_review_the_packet",
            "this_component_cannot_authorize_or_execute_a_valve_change"
        }
    }
end

return external_action_gate
