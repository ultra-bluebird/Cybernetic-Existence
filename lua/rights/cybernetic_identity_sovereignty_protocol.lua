local IdentitySovereignty = {}

local function result(state, reason_codes, values)
    return {
        declaration_state = state,
        reason_codes = reason_codes or {},
        values = values or {},
        local_first = true,
        release_class = "local_only",
        self_assertion_accepted = true,
        external_certification_required = false,
        biometric_identification_required = false,
        external_connectivity_required = false,
        forced_disclosure_permitted = false,
        cybernetic_status_penalty_permitted = false,
        identity_inference_permitted = false,
        device_inspection_required = false,
        neural_data_required = false,
        assistive_telemetry_required = false,
        automated_service_denial_permitted = false
    }
end

local function prohibited_request(input)
    return input.requests_external_certification == true
        or input.requests_biometric_identification == true
        or input.requests_device_inspection == true
        or input.requests_neural_data == true
        or input.requests_assistive_telemetry == true
        or input.requests_cybernetic_status_verification == true
        or input.requests_cybernetic_status_penalty == true
        or input.requests_identity_inference == true
        or input.requests_forced_disclosure == true
        or input.requests_service_denial == true
end

function IdentitySovereignty.evaluate(input)
    if type(input) ~= "table" then
        return result(
            "conflict_preserved",
            { "identity_sovereignty_input_missing_requires_accessible_review" }
        )
    end

    if prohibited_request(input) then
        return result(
            "conflict_preserved",
            {
                "external_verification_or_status_penalty_prohibited",
                "self_assertion_remains_valid_for_protective_purposes",
                "blocked_by_policy"
            }
        )
    end

    if input.withdrawal_requested == true then
        return result(
            "withdrawn_for_future_use",
            {
                "future_nonessential_use_withdrawn",
                "historic_protection_records_preserved",
                "accessible_confirmation_required"
            },
            {
                raw_local_declaration_action = "delete_or_restrict_according_to_withdrawal_scope",
                historic_protection_history = "preserved"
            }
        )
    end

    if input.external_record_conflict == true then
        return result(
            "conflict_preserved",
            {
                "preserve_both_require_review",
                "self_assertion_remains_sufficient_for_protective_purposes",
                "external_record_cannot_override_identity_sovereignty",
                "human_review_of_workflow_only"
            },
            {
                conflict_state = "preserve_both_require_review",
                review_outcome = "protective_use_continues"
            }
        )
    end

    if input.update_requested == true then
        return result(
            "locally_updated",
            {
                "self_asserted_declaration_updated_locally",
                "no_external_certification_required"
            }
        )
    end

    return result(
        "protective_use_active",
        {
            "self_assertion_accepted_for_protective_purposes",
            "no_external_certification_required",
            "no_biometric_or_status_disclosure_required"
        }
    )
end

function IdentitySovereignty.render_accessible_confirmation(assessment)
    local state = assessment.declaration_state or "conflict_preserved"
    local reasons = table.concat(assessment.reason_codes or {}, ", ")

    return "Your self-asserted identity is accepted for protective purposes. "
        .. "No external certification, biometric identification, device inspection, "
        .. "neural data, or cybernetic-status disclosure is required. "
        .. "Current local state: " .. state .. ". "
        .. "Reason codes: " .. reasons .. ". "
        .. "Accessible human review and non-digital escalation remain available."
end

return IdentitySovereignty
