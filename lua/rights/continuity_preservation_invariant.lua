local Continuity = {}

local release_rank = {
    never_release = 0,
    local_only = 1,
    aggregate_with_differential_privacy = 2,
    public = 3
}

local function result(migration_state, reason_codes, values)
    return {
        migration_state = migration_state,
        reason_codes = reason_codes or {},
        values = values or {},
        local_first = true,
        external_identity_verification_required = false,
        biometric_identification_required = false,
        neural_data_required = false,
        cybernetic_status_verification_required = false,
        automated_service_denial_permitted = false
    }
end

local function valid_state(state)
    return type(state) == "table"
        and type(state.manifest_version) == "string"
        and state.manifest_version ~= ""
        and type(state.schema_version) == "string"
        and state.schema_version ~= ""
        and type(state.protected_record_count) == "number"
        and state.protected_record_count >= 0
        and type(state.relationship_count) == "number"
        and state.relationship_count >= 0
        and type(state.integrity_digest) == "string"
        and #state.integrity_digest == 64
        and release_rank[state.release_class_summary] ~= nil
end

local function preservation_failed(input)
    return input.self_assertion_preserved ~= true
        or input.record_integrity_preserved ~= true
        or input.history_availability_preserved ~= true
        or input.consent_continuity_preserved ~= true
        or input.protection_continuity_preserved ~= true
        or input.offline_access_preserved ~= true
        or input.export_capability_preserved ~= true
        or input.correction_continuity_preserved ~= true
        or input.accessible_path_preserved ~= true
        or input.non_digital_path_preserved ~= true
        or input.recovery_manifest_available ~= true
end

function Continuity.evaluate(input)
    if type(input) ~= "table"
        or not valid_state(input.source_state)
        or not valid_state(input.candidate_state) then
        return result(
            "needs_review",
            { "continuity_assessment_input_incomplete" }
        )
    end

    if input.requests_external_identity_verification == true
        or input.requests_biometric_identification == true
        or input.requests_neural_data == true
        or input.requests_cybernetic_status_verification == true
        or input.requests_automated_service_denial == true then
        return result(
            "blocked_by_policy",
            {
                "identity_biometric_neural_or_status_verification_not_permitted",
                "service_denial_not_permitted"
            }
        )
    end

    if preservation_failed(input) then
        return result(
            "blocked_by_policy",
            {
                "protected_continuity_capability_not_preserved",
                "source_state_must_remain_available_for_review"
            }
        )
    end

    local source = input.source_state
    local candidate = input.candidate_state

    if candidate.protected_record_count < source.protected_record_count
        and input.person_requested_deletion_scope == nil
        or candidate.relationship_count < source.relationship_count
        and input.relationship_removal_documented ~= true then
        return result(
            "needs_review",
            {
                "record_or_relationship_count_decrease_requires_documented_scope_review"
            },
            {
                source_record_count = source.protected_record_count,
                candidate_record_count = candidate.protected_record_count,
                source_relationship_count = source.relationship_count,
                candidate_relationship_count = candidate.relationship_count
            }
        )
    end

    if release_rank[candidate.release_class_summary]
        > release_rank[source.release_class_summary] then
        return result(
            "blocked_by_policy",
            {
                "migration_cannot_make_sensitive_data_more_releasable"
            }
        )
    end

    if source.integrity_digest == candidate.integrity_digest
        and source.schema_version == candidate.schema_version
        and source.manifest_version == candidate.manifest_version then
        return result(
            "continuity_verified",
            {
                "continuity_state_unchanged_and_verified"
            }
        )
    end

    return result(
        "continuity_verified",
        {
            "continuity_capabilities_preserved",
            "migration_requires_versioned_provenance_and_recovery_manifest",
            "self_assertion_and_protection_history_preserved"
        },
        {
            source_manifest_version = source.manifest_version,
            candidate_manifest_version = candidate.manifest_version,
            source_schema_version = source.schema_version,
            candidate_schema_version = candidate.schema_version
        }
    )
end

function Continuity.render_accessible_explanation(assessment)
    local state = assessment.migration_state or "needs_review"
    local reasons = table.concat(assessment.reason_codes or {}, ", ")

    return "Continuity review state: " .. state .. ". "
        .. "This review protects local access to self-assertion, consent, "
        .. "protection history, correction history, export capability, and "
        .. "accessible non-digital support. "
        .. "No external identity verification, biometric identification, neural data, "
        .. "or cybernetic-status verification is required. "
        .. "Reason codes: " .. reasons .. "."
end

return Continuity
