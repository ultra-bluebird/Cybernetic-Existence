local SemanticAudit = {}

local required_dimensions = {
    "identifier",
    "semantic_version",
    "term_type",
    "unit",
    "range",
    "requiredness",
    "purpose_constraint",
    "gate_relationship",
    "failure_state"
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

local function contains(values, target)
    if type(values) ~= "table" then
        return false
    end

    for _, value in ipairs(values) do
        if value == target then
            return true
        end
    end

    return false
end

local function contract_is_complete(contract)
    return type(contract) == "table"
        and type(contract.term_type) == "string"
        and contract.term_type ~= ""
        and type(contract.unit_or_value_class) == "string"
        and contract.unit_or_value_class ~= ""
        and type(contract.required) == "boolean"
        and type(contract.purpose_constraint) == "string"
        and contract.purpose_constraint ~= ""
        and type(contract.gate_relationship) == "string"
        and contract.gate_relationship ~= ""
        and type(contract.failure_state) == "string"
        and contract.failure_state ~= ""
end

local function artifact_has_required_dimensions(artifact)
    if type(artifact) ~= "table"
        or type(artifact.matched_dimensions) ~= "table" then
        return false
    end

    for _, dimension in ipairs(required_dimensions) do
        if not contains(artifact.matched_dimensions, dimension) then
            return false
        end
    end

    return true
end

function SemanticAudit.evaluate(input)
    if type(input) ~= "table"
        or type(input.canonical_term_name) ~= "string"
        or input.canonical_term_name == ""
        or type(input.canonical_semantic_version) ~= "string"
        or input.canonical_semantic_version == ""
        or not contract_is_complete(input.expected_contract)
        or type(input.artifact_comparisons) ~= "table"
        or #input.artifact_comparisons == 0 then
        return result(
            "insufficient_evidence",
            { "semantic_integrity_audit_input_incomplete" }
        )
    end

    local review_required = false
    local coverage_gap = false
    local drift_artifacts = {}

    for _, artifact in ipairs(input.artifact_comparisons) do
        if type(artifact) ~= "table"
            or type(artifact.artifact_type) ~= "string"
            or artifact.artifact_type == ""
            or type(artifact.artifact_reference) ~= "string"
            or artifact.artifact_reference == ""
            or type(artifact.comparison_state) ~= "string" then
            return result(
                "insufficient_evidence",
                { "artifact_comparison_record_incomplete" }
            )
        end

        if artifact.comparison_state == "semantic_drift_detected" then
            table.insert(drift_artifacts, artifact.artifact_reference)
        elseif artifact.comparison_state == "needs_review" then
            review_required = true
        end

        if artifact.comparison_state == "aligned"
            and not artifact_has_required_dimensions(artifact) then
            coverage_gap = true
        end
    end

    if #drift_artifacts > 0 then
        return result(
            "blocked_by_policy",
            {
                "semantic_drift_detected",
                "dual_interpretation_or_versioned_migration_required"
            },
            {
                canonical_term_name = input.canonical_term_name,
                drift_artifacts = drift_artifacts
            }
        )
    end

    if review_required or coverage_gap then
        return result(
            "needs_review",
            {
                "semantic_audit_requires_additional_artifact_or_dimension_review"
            },
            {
                canonical_term_name = input.canonical_term_name,
                coverage_gap = coverage_gap
            }
        )
    end

    return result(
        "advisory_only",
        {
            "semantic_integrity_audit_aligned"
        },
        {
            canonical_term_name = input.canonical_term_name,
            canonical_semantic_version = input.canonical_semantic_version
        }
    )
end

function SemanticAudit.render_accessible_explanation(assessment)
    local state = assessment.output_state or "needs_review"
    local reasons = table.concat(assessment.reason_codes or {}, ", ")

    return "Semantic integrity audit result: " .. state .. ". "
        .. "This audit checks whether a canonical term has the same identifier, version, "
        .. "type, unit, range, purpose boundary, gate role, and failure state across "
        .. "policy, schema, code, tests, and explanations. "
        .. "It does not assess people or expose raw evidence. "
        .. "A detected mismatch requires a versioned migration or human review. "
        .. "Reason codes: " .. reasons .. "."
end

return SemanticAudit
