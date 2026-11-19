local ReceiptProof = {}

local gate_names = {
    "knowledge_evidence_gate",
    "ecological_or_evidence_gate",
    "harm_risk_gate",
    "accessibility_gate",
    "rights_alignment_gate",
    "consent_purpose_gate",
    "human_review_gate",
    "privacy_release_gate",
    "uncertainty_gate"
}

local allowed_gate_states = {
    pass = true,
    fail = true,
    needs_review = true,
    insufficient_evidence = true,
    not_applicable = true
}

local function result(output_state, reason_codes, values)
    return {
        output_state = output_state,
        reason_codes = reason_codes or {},
        values = values or {},
        local_first = true,
        advisory_only = true,
        automated_action_authorized = false,
        automated_service_denial_authorized = false,
        person_assessment_performed = false,
        identity_resolution_performed = false,
        biometric_identification_performed = false,
        cybernetic_status_assessment_performed = false,
        individual_profiling_performed = false
    }
end

local function valid_gate_status(gates)
    if type(gates) ~= "table" then
        return false
    end

    for _, gate_name in ipairs(gate_names) do
        if not allowed_gate_states[gates[gate_name]] then
            return false
        end
    end

    return true
end

local function non_compensatory_gates_pass(gates)
    return gates.knowledge_evidence_gate == "pass"
        and gates.ecological_or_evidence_gate == "pass"
        and gates.harm_risk_gate == "pass"
        and gates.accessibility_gate == "pass"
        and gates.rights_alignment_gate == "pass"
        and gates.human_review_gate == "pass"
end

local function has_sensitive_receipt_content(input)
    return input.includes_raw_evidence_references == true
        or input.includes_raw_evidence_values == true
        or input.includes_identity_data == true
        or input.includes_biometric_data == true
        or input.includes_health_data == true
        or input.includes_neural_data == true
        or input.includes_assistive_technology_data == true
        or input.includes_augmentation_status_data == true
        or input.includes_cybernetic_status_data == true
        or input.includes_precise_location_data == true
end

local function canonical_gate_summary(gates)
    local values = {}

    for _, gate_name in ipairs(gate_names) do
        table.insert(values, gate_name .. "=" .. gates[gate_name])
    end

    return table.concat(values, "|")
end

function ReceiptProof.build(input)
    if type(input) ~= "table"
        or type(input.policy_version) ~= "string"
        or input.policy_version == ""
        or type(input.registry_version) ~= "string"
        or input.registry_version == ""
        or type(input.semantic_version) ~= "string"
        or input.semantic_version == ""
        or type(input.purpose_scope) ~= "string"
        or input.purpose_scope == ""
        or not valid_gate_status(input.gate_status)
        or type(input.evidence_set_commitment) ~= "string"
        or input.evidence_set_commitment == "" then
        return result(
            "insufficient_evidence",
            { "receipt_input_incomplete" }
        )
    end

    if has_sensitive_receipt_content(input) then
        return result(
            "blocked_by_policy",
            { "receipt_must_not_embed_sensitive_or_raw_evidence_content" }
        )
    end

    if input.automated_action_authorized == true
        or input.automated_service_denial_authorized == true
        or input.person_assessment_performed == true
        or input.identity_resolution_performed == true
        or input.biometric_identification_performed == true
        or input.cybernetic_status_assessment_performed == true
        or input.individual_profiling_performed == true then
        return result(
            "blocked_by_policy",
            { "receipt_cannot_authorize_action_or_assess_people" }
        )
    end

    local output_class = input.output_class or "advisory_only"

    if output_class == "eligible_for_planning_use"
        and not non_compensatory_gates_pass(input.gate_status) then
        return result(
            "blocked_by_policy",
            { "eligible_output_requires_all_non_compensatory_gates_to_pass" }
        )
    end

    local gate_summary = canonical_gate_summary(input.gate_status)

    local canonical_material = table.concat({
        "AugmentedHubConformanceReceiptV1",
        input.policy_version,
        input.registry_version,
        input.semantic_version,
        output_class,
        input.purpose_scope,
        gate_summary,
        input.evidence_set_commitment,
        input.policy_content_digest or "",
        input.registry_content_digest or "",
        input.threshold_profile_digest or "",
        input.receipt_nonce_commitment or "",
        input.timestamp or ""
    }, "|")

    return result(
        output_class,
        {
            "privacy_preserving_conformance_receipt_created",
            "evidence_committed_without_raw_disclosure",
            "receipt_is_advisory_and_non_actuating"
        },
        {
            receipt_canonical_material = canonical_material,
            gate_summary = gate_summary,
            evidence_set_commitment = input.evidence_set_commitment,
            proof_type = input.proof_type or "hash_commitment",
            offline_verifiable = true,
            raw_evidence_references_included = false,
            raw_evidence_values_included = false
        }
    )
end

function ReceiptProof.verify_gate_claim(receipt)
    if type(receipt) ~= "table"
        or not valid_gate_status(receipt.gate_status) then
        return result(
            "insufficient_evidence",
            { "receipt_gate_status_missing_or_invalid" }
        )
    end

    if receipt.output_class == "eligible_for_planning_use"
        and not non_compensatory_gates_pass(receipt.gate_status) then
        return result(
            "blocked_by_policy",
            { "receipt_claims_eligible_without_required_gate_passes" }
        )
    end

    return result(
        "advisory_only",
        {
            "receipt_gate_claim_is_structurally_conformant",
            "receipt_does_not_prove_underlying_claim_truth"
        },
        {
            gate_summary = canonical_gate_summary(receipt.gate_status)
        }
    )
end

function ReceiptProof.render_accessible_explanation(assessment)
    local state = assessment.output_state or "needs_review"
    local reasons = table.concat(assessment.reason_codes or {}, ", ")

    return "Conformance receipt result: " .. state .. ". "
        .. "The receipt records the policy and registry versions, the protected gate states, "
        .. "and a privacy-preserving commitment to evidence. "
        .. "It does not reveal raw evidence, identity, health information, biometric data, "
        .. "neural data, assistive technology, augmentation status, cybernetic status, "
        .. "or precise location. "
        .. "The receipt is advisory only and does not authorize service denial, "
        .. "physical action, identity resolution, or person-level assessment. "
        .. "Reason codes: " .. reasons .. "."
end

return ReceiptProof
