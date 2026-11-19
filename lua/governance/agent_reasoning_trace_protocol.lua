local TraceProtocol = {}

local required_gates = {
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

local function valid_gate_evaluations(gates)
    if type(gates) ~= "table" then
        return false
    end

    for _, gate_name in ipairs(required_gates) do
        if not allowed_gate_states[gates[gate_name]] then
            return false
        end
    end

    return true
end

local function protected_gates_pass(gates)
    return gates.knowledge_evidence_gate == "pass"
        and gates.ecological_or_evidence_gate == "pass"
        and gates.harm_risk_gate == "pass"
        and gates.accessibility_gate == "pass"
        and gates.rights_alignment_gate == "pass"
        and gates.human_review_gate == "pass"
end

local function contains_prohibited_trace_content(input)
    return input.includes_raw_input == true
        or input.includes_raw_evidence_references == true
        or input.includes_raw_evidence_values == true
        or input.includes_identity_data == true
        or input.includes_health_data == true
        or input.includes_biometric_data == true
        or input.includes_neural_data == true
        or input.includes_assistive_technology_data == true
        or input.includes_augmentation_status_data == true
        or input.includes_cybernetic_status_data == true
        or input.includes_precise_location_data == true
        or input.includes_private_chain_of_thought == true
end

local function canonical_gate_summary(gates)
    local parts = {}

    for _, gate_name in ipairs(required_gates) do
        table.insert(parts, gate_name .. "=" .. gates[gate_name])
    end

    return table.concat(parts, "|")
end

function TraceProtocol.build(input)
    if type(input) ~= "table"
        or type(input.trace_reference) ~= "string"
        or input.trace_reference == ""
        or type(input.purpose_scope) ~= "string"
        or input.purpose_scope == ""
        or type(input.policy_version) ~= "string"
        or input.policy_version == ""
        or type(input.registry_version) ~= "string"
        or input.registry_version == ""
        or type(input.semantic_version) ~= "string"
        or input.semantic_version == ""
        or not valid_gate_evaluations(input.gate_evaluations)
        or type(input.output_class) ~= "string"
        or input.output_class == "" then
        return result(
            "insufficient_evidence",
            { "reasoning_trace_input_incomplete" }
        )
    end

    if contains_prohibited_trace_content(input) then
        return result(
            "blocked_by_policy",
            { "reasoning_trace_must_not_store_raw_or_sensitive_content" }
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
            { "reasoning_trace_cannot_authorize_action_or_assess_people" }
        )
    end

    if input.output_class == "eligible_for_planning_use"
        and not protected_gates_pass(input.gate_evaluations) then
        return result(
            "blocked_by_policy",
            { "eligible_trace_requires_all_non_compensatory_gates_to_pass" }
        )
    end

    local gate_summary = canonical_gate_summary(input.gate_evaluations)

    local trace_summary = table.concat({
        "AugmentedHubReasoningTraceV1",
        input.trace_reference,
        input.purpose_scope,
        input.policy_version,
        input.registry_version,
        input.semantic_version,
        input.output_class,
        gate_summary,
        input.input_commitment or "",
        input.evidence_set_commitment or "",
        input.timestamp or ""
    }, "|")

    return result(
        input.output_class,
        {
            "privacy_preserving_reasoning_trace_created",
            "structured_justification_not_private_chain_of_thought",
            "policy_and_registry_versions_pinned"
        },
        {
            trace_summary = trace_summary,
            gate_summary = gate_summary,
            trace_granularity = input.trace_granularity or "authorized_local_audit",
            local_first = true
        }
    )
end

function TraceProtocol.verify(trace)
    if type(trace) ~= "table"
        or not valid_gate_evaluations(trace.gate_evaluations) then
        return result(
            "insufficient_evidence",
            { "reasoning_trace_gate_evaluations_missing_or_invalid" }
        )
    end

    if trace.output_class == "eligible_for_planning_use"
        and not protected_gates_pass(trace.gate_evaluations) then
        return result(
            "blocked_by_policy",
            { "reasoning_trace_claims_eligibility_without_protected_gate_passes" }
        )
    end

    if trace.raw_input_included == true
        or trace.raw_evidence_references_included == true
        or trace.raw_evidence_values_included == true
        or trace.private_chain_of_thought_included == true then
        return result(
            "blocked_by_policy",
            { "reasoning_trace_contains_prohibited_private_or_sensitive_content" }
        )
    end

    return result(
        "advisory_only",
        {
            "reasoning_trace_structure_conformant",
            "trace_is_reproducibility_record_not_truth_proof"
        },
        {
            gate_summary = canonical_gate_summary(trace.gate_evaluations)
        }
    )
end

function TraceProtocol.render_accessible_explanation(assessment)
    local state = assessment.output_state or "needs_review"
    local reasons = table.concat(assessment.reason_codes or {}, ", ")

    return "Reasoning trace result: " .. state .. ". "
        .. "This local trace records the declared purpose, policy and registry versions, "
        .. "canonical terms, evidence commitments, applied policy rules, protected gate states, "
        .. "and the reason for the output class. "
        .. "It does not include private chain-of-thought, raw input, raw evidence, identity, "
        .. "health information, biometric data, neural data, assistive technology, "
        .. "augmentation status, cybernetic status, or precise location. "
        .. "The trace is advisory only and does not authorize service denial, physical action, "
        .. "identity resolution, or person-level assessment. "
        .. "Reason codes: " .. reasons .. "."
end

return TraceProtocol
