local M = {}

M.SCHEMA_VERSION = "cyberrank-governance-v1"
M.TIER2_WIRE = "active_lifetime"
M.MAX_EVIDENCE_TAGS = 32
M.MAX_EVIDENCE_TAG_LENGTH = 96
M.MAX_COMMITMENT_LENGTH = 128

M.DECISION = {
    allow = "allow",
    allow_with_conditions = "allow_with_conditions",
    expired = "expired",
    hold = "hold",
    suspend = "suspend",
    deny = "deny",
}

M.SERVICE_CLASS = {
    life_safety = "life_safety",
    health_support = "health_support",
    water_sanitation = "water_sanitation",
    emergency_communications = "emergency_communications",
    climate_support = "climate_support",
    assistive_access = "assistive_access",
    public_emergency_designation = "public_emergency_designation",
    general_service = "general_service",
}

M.UNCERTAINTY = {
    high_confidence = "high_confidence",
    some_uncertainty = "some_uncertainty",
    considerable_uncertainty = "considerable_uncertainty",
    unreliable = "unreliable",
}

M.LOCAL_PLATFORM_EVENT = {
    model_output_observed = "model_output_observed",
    biological_observation_received = "biological_observation_received",
    access_event_observed = "access_event_observed",
    research_result_recorded = "research_result_recorded",
    external_complaint_received = "external_complaint_received",
    auxiliary_policy_updated = "auxiliary_policy_updated",
    tier3_artifact_referenced = "tier3_artifact_referenced",
    cryptographic_profile_updated = "cryptographic_profile_updated",
    consent_epoch_updated = "consent_epoch_updated",
    continuity_dossier_updated = "continuity_dossier_updated",
}

local essential_service_classes = {
    [M.SERVICE_CLASS.life_safety] = true,
    [M.SERVICE_CLASS.health_support] = true,
    [M.SERVICE_CLASS.water_sanitation] = true,
    [M.SERVICE_CLASS.emergency_communications] = true,
    [M.SERVICE_CLASS.climate_support] = true,
    [M.SERVICE_CLASS.assistive_access] = true,
    [M.SERVICE_CLASS.public_emergency_designation] = true,
}

local uncertainty_levels = {
    [M.UNCERTAINTY.high_confidence] = true,
    [M.UNCERTAINTY.some_uncertainty] = true,
    [M.UNCERTAINTY.considerable_uncertainty] = true,
    [M.UNCERTAINTY.unreliable] = true,
}

local valid_service_classes = {
    [M.SERVICE_CLASS.life_safety] = true,
    [M.SERVICE_CLASS.health_support] = true,
    [M.SERVICE_CLASS.water_sanitation] = true,
    [M.SERVICE_CLASS.emergency_communications] = true,
    [M.SERVICE_CLASS.climate_support] = true,
    [M.SERVICE_CLASS.assistive_access] = true,
    [M.SERVICE_CLASS.public_emergency_designation] = true,
    [M.SERVICE_CLASS.general_service] = true,
}

local decision_rank = {
    [M.DECISION.allow] = 0,
    [M.DECISION.allow_with_conditions] = 1,
    [M.DECISION.expired] = 2,
    [M.DECISION.hold] = 3,
    [M.DECISION.suspend] = 4,
    [M.DECISION.deny] = 5,
}

local prohibited_data_classes = {
    cybernetic_status = true,
    integrated_technology_status = true,
    bci_status = true,
    companion_system_status = true,
    health_information = true,
    disability_information = true,
    biometric_information = true,
    neural_information = true,
    physiological_information = true,
    nutritional_information = true,
    communication_pattern = true,
    behavioral_profile = true,
    device_fingerprint = true,
    network_characteristics = true,
    repair_history = true,
    persistent_location_history = true,
    institution_managed_private_data = true,
}

local prohibited_practices = {
    require_proof_of_private_integration = true,
    require_private_technical_disclosure = true,
    require_medical_disclosure = true,
    require_neural_disclosure = true,
    require_biometric_disclosure = true,
    require_device_inventory = true,
    require_institutional_record_disclosure = true,
    perform_identity_inference = true,
    perform_status_scoring = true,
    create_public_registry = true,
    perform_compulsory_scanning = true,
    automatic_denial_on_uncertainty = true,
    retaliate_for_access_request = true,
}

local function is_string(value)
    return type(value) == "string"
end

local function is_nonempty_string(value)
    return is_string(value) and value:match("%S") ~= nil
end

local function is_boolean(value)
    return type(value) == "boolean"
end

local function is_finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function in_unit_interval(value)
    return is_finite_number(value) and value >= 0.0 and value <= 1.0
end

local function copy_array(values)
    local result = {}

    for index, value in ipairs(values or {}) do
        result[index] = value
    end

    return result
end

local function copy_set(values)
    local result = {}

    for key, value in pairs(values or {}) do
        result[key] = value
    end

    return result
end

local function copy_authorization(authorization)
    return {
        grants = copy_array(authorization.grants),
        policy_version = authorization.policy_version,
        consent_version = authorization.consent_version,
    }
end

local function copy_rank_record(rank)
    return {
        evidence_id = rank.evidence_id,
        lower_bound_micros = rank.lower_bound_micros,
        center_micros = rank.center_micros,
        upper_bound_micros = rank.upper_bound_micros,
    }
end

local function copy_rank_history(history)
    local result = {}

    for index, rank in ipairs(history or {}) do
        result[index] = copy_rank_record(rank)
    end

    return result
end

local function array_contains_prohibited(values, prohibited)
    for _, value in ipairs(values or {}) do
        if prohibited[value] then
            return true, value
        end
    end

    return false, nil
end

local function obligation_set(values)
    local result = {}

    for _, value in ipairs(values or {}) do
        result[value] = true
    end

    return result
end

local function sorted_keys(values)
    local result = {}

    for key in pairs(values) do
        result[#result + 1] = key
    end

    table.sort(result)
    return result
end

local function result(decision, reasons, obligations)
    return {
        decision = decision,
        reasons = copy_array(reasons),
        obligations = obligation_set(obligations),
    }
end

local function assert_valid_authorization(authorization)
    assert(type(authorization) == "table", "authorization must be a table")
    assert(type(authorization.grants) == "table", "authorization.grants must be an array")
    assert(is_nonempty_string(authorization.policy_version),
        "authorization.policy_version must be a non-empty string")
    assert(is_nonempty_string(authorization.consent_version),
        "authorization.consent_version must be a non-empty string")

    for index, grant in ipairs(authorization.grants) do
        assert(is_nonempty_string(grant),
            "authorization.grants[" .. index .. "] must be a non-empty string")
    end
end

function M.validate_rank_record(rank)
    assert(type(rank) == "table", "rank record must be a table")
    assert(is_nonempty_string(rank.evidence_id), "rank.evidence_id must be a non-empty string")
    assert(is_finite_number(rank.lower_bound_micros)
        and rank.lower_bound_micros >= 0
        and rank.lower_bound_micros % 1 == 0,
        "rank.lower_bound_micros must be a non-negative integer")
    assert(is_finite_number(rank.center_micros)
        and rank.center_micros >= 0
        and rank.center_micros % 1 == 0,
        "rank.center_micros must be a non-negative integer")
    assert(is_finite_number(rank.upper_bound_micros)
        and rank.upper_bound_micros >= 0
        and rank.upper_bound_micros % 1 == 0,
        "rank.upper_bound_micros must be a non-negative integer")
    assert(rank.lower_bound_micros <= rank.center_micros,
        "rank lower bound must not exceed center")
    assert(rank.center_micros <= rank.upper_bound_micros,
        "rank center must not exceed upper bound")

    return true
end

function M.new_rank_record(
    evidence_id,
    lower_bound_micros,
    center_micros,
    upper_bound_micros
)
    local rank = {
        evidence_id = evidence_id,
        lower_bound_micros = lower_bound_micros,
        center_micros = center_micros,
        upper_bound_micros = upper_bound_micros,
    }

    M.validate_rank_record(rank)
    return rank
end

function M.validate_cyberrank_state(state)
    assert(type(state) == "table", "CyberRank state must be a table")
    assert_valid_authorization(state.authorization)
    assert(type(state.rank_history) == "table",
        "CyberRank state rank_history must be an array")

    for _, rank in ipairs(state.rank_history) do
        M.validate_rank_record(rank)
    end

    return true
end

function M.new_cyberrank_state(authorization)
    assert_valid_authorization(authorization)

    return {
        authorization = copy_authorization(authorization),
        rank_history = {},
    }
end

function M.apply_rank_update(state, rank)
    M.validate_cyberrank_state(state)
    M.validate_rank_record(rank)

    local rank_history = copy_rank_history(state.rank_history)
    rank_history[#rank_history + 1] = copy_rank_record(rank)

    return {
        authorization = copy_authorization(state.authorization),
        rank_history = rank_history,
    }
end

function M.latest_rank(state)
    M.validate_cyberrank_state(state)
    local rank = state.rank_history[#state.rank_history]

    if rank == nil then
        return nil
    end

    return copy_rank_record(rank)
end

function M.tier2_active_lifetime()
    return M.TIER2_WIRE
end

function M.parse_tier2_wire(value)
    if value == M.TIER2_WIRE then
        return M.tier2_active_lifetime()
    end

    return nil, "invalid CyberRank Tier2 wire value"
end

function M.tier2_next(current, event)
    assert(current == M.TIER2_WIRE,
        "current Tier2 state must be active_lifetime")
    assert(M.LOCAL_PLATFORM_EVENT[event] == event,
        "invalid local platform event")

    return current
end

function M.tier2_status_is_active_lifetime(current)
    return current == M.TIER2_WIRE
end

function M.compose_decisions(left, right)
    assert(decision_rank[left] ~= nil, "left decision is invalid")
    assert(decision_rank[right] ~= nil, "right decision is invalid")

    if decision_rank[left] >= decision_rank[right] then
        return left
    end

    return right
end

function M.validate_biomech_scorecard(scorecard)
    assert(type(scorecard) == "table", "scorecard must be a table")
    assert(scorecard.schema_version == "cyberrank-biomech-scorecard-v1",
        "scorecard.schema_version must be cyberrank-biomech-scorecard-v1")
    assert(is_nonempty_string(scorecard.aln_clause),
        "scorecard.aln_clause must be a non-empty string")
    assert(in_unit_interval(scorecard.min_score),
        "scorecard.min_score must be within 0..1")
    assert(in_unit_interval(scorecard.max_score),
        "scorecard.max_score must be within 0..1")
    assert(scorecard.min_score <= scorecard.max_score,
        "scorecard.min_score must not exceed scorecard.max_score")
    assert(in_unit_interval(scorecard.baseline_weight),
        "scorecard.baseline_weight must be within 0..1")
    assert(in_unit_interval(scorecard.fused_risk_weight),
        "scorecard.fused_risk_weight must be within 0..1")
    assert(type(scorecard.evidence_tags) == "table",
        "scorecard.evidence_tags must be an array")
    assert(#scorecard.evidence_tags > 0
        and #scorecard.evidence_tags <= M.MAX_EVIDENCE_TAGS,
        "scorecard.evidence_tags must contain 1..32 tags")

    for index, tag in ipairs(scorecard.evidence_tags) do
        assert(is_nonempty_string(tag)
            and #tag <= M.MAX_EVIDENCE_TAG_LENGTH,
            "scorecard.evidence_tags[" .. index .. "] is invalid")
    end

    assert(scorecard.hostdid == nil,
        "scorecard must not store a host identifier")
    assert(scorecard.bostromaddress == nil,
        "scorecard must not store an address")
    assert(scorecard.biometric_data == nil,
        "scorecard must not store biometric data")
    assert(scorecard.neural_data == nil,
        "scorecard must not store neural data")
    assert(scorecard.medical_data == nil,
        "scorecard must not store medical data")
    assert(scorecard.private_institutional_data == nil,
        "scorecard must not store institution-managed private data")

    return true
end

function M.new_biomech_scorecard(input)
    input = input or {}

    local scorecard = {
        schema_version = "cyberrank-biomech-scorecard-v1",
        aln_clause = input.aln_clause or "ALN.CYBERRANK.CONTINUITY.v1",
        min_score = input.min_score or 0.0,
        max_score = input.max_score or 1.0,
        baseline_weight = input.baseline_weight or 1.0,
        fused_risk_weight = input.fused_risk_weight or 1.0,
        evidence_tags = copy_array(input.evidence_tags or {
            "thermal",
            "energy",
            "duty_cycle",
            "comfort",
            "rights",
            "continuity",
            "ecological",
            "device_correction",
        }),
    }

    M.validate_biomech_scorecard(scorecard)
    return scorecard
end

function M.score_biomech_observation(scorecard, observation)
    M.validate_biomech_scorecard(scorecard)
    assert(type(observation) == "table", "observation must be a table")
    assert(in_unit_interval(observation.baseline),
        "observation.baseline must be within 0..1")
    assert(in_unit_interval(observation.fused_risk),
        "observation.fused_risk must be within 0..1")

    local raw =
        scorecard.baseline_weight * observation.baseline
        - scorecard.fused_risk_weight * observation.fused_risk

    local normalized = raw

    if normalized < scorecard.min_score then
        normalized = scorecard.min_score
    end

    if normalized > scorecard.max_score then
        normalized = scorecard.max_score
    end

    return {
        score = normalized,
        within_bounds = normalized >= scorecard.min_score
            and normalized <= scorecard.max_score,
        evidence_tags = copy_array(scorecard.evidence_tags),
    }
end

function M.validate_tier3_commitment(attestation)
    assert(type(attestation) == "table", "Tier3 attestation must be a table")
    assert(attestation.schema_version == M.SCHEMA_VERSION,
        "Tier3 attestation schema_version is invalid")
    assert(is_nonempty_string(attestation.attestation_id),
        "Tier3 attestation_id must be a non-empty string")
    assert(is_nonempty_string(attestation.identity_commitment)
        and #attestation.identity_commitment <= M.MAX_COMMITMENT_LENGTH,
        "Tier3 identity_commitment is invalid")
    assert(is_nonempty_string(attestation.continuity_commitment)
        and #attestation.continuity_commitment <= M.MAX_COMMITMENT_LENGTH,
        "Tier3 continuity_commitment is invalid")
    assert(is_nonempty_string(attestation.privileges_commitment)
        and #attestation.privileges_commitment <= M.MAX_COMMITMENT_LENGTH,
        "Tier3 privileges_commitment is invalid")
    assert(is_nonempty_string(attestation.responsibilities_commitment)
        and #attestation.responsibilities_commitment <= M.MAX_COMMITMENT_LENGTH,
        "Tier3 responsibilities_commitment is invalid")
    assert(is_nonempty_string(attestation.governance_terms_commitment)
        and #attestation.governance_terms_commitment <= M.MAX_COMMITMENT_LENGTH,
        "Tier3 governance_terms_commitment is invalid")
    assert(is_finite_number(attestation.issued_at_epoch_seconds)
        and attestation.issued_at_epoch_seconds >= 0
        and attestation.issued_at_epoch_seconds % 1 == 0,
        "Tier3 issued_at_epoch_seconds must be a non-negative integer")
    assert(is_boolean(attestation.active),
        "Tier3 active must be boolean")

    assert(attestation.holder == nil,
        "Tier3 attestation must not store a holder address")
    assert(attestation.hostdid == nil,
        "Tier3 attestation must not store a host identifier")
    assert(attestation.bostromaddress == nil,
        "Tier3 attestation must not store an address")
    assert(attestation.biometric_data == nil,
        "Tier3 attestation must not store biometric data")
    assert(attestation.neural_data == nil,
        "Tier3 attestation must not store neural data")
    assert(attestation.medical_data == nil,
        "Tier3 attestation must not store medical data")
    assert(attestation.private_institutional_data == nil,
        "Tier3 attestation must not store institution-managed private data")

    return true
end

function M.new_tier3_commitment(input)
    input = input or {}

    local attestation = {
        schema_version = M.SCHEMA_VERSION,
        attestation_id = input.attestation_id,
        identity_commitment = input.identity_commitment,
        continuity_commitment = input.continuity_commitment,
        privileges_commitment = input.privileges_commitment,
        responsibilities_commitment = input.responsibilities_commitment,
        governance_terms_commitment = input.governance_terms_commitment,
        issued_at_epoch_seconds = input.issued_at_epoch_seconds,
        active = input.active ~= false,
    }

    M.validate_tier3_commitment(attestation)
    return attestation
end

function M.archive_tier3_commitment(attestation, archive_reason_commitment)
    M.validate_tier3_commitment(attestation)
    assert(is_nonempty_string(archive_reason_commitment)
        and #archive_reason_commitment <= M.MAX_COMMITMENT_LENGTH,
        "archive_reason_commitment is invalid")
    assert(attestation.active,
        "Tier3 attestation is already inactive")

    return {
        schema_version = attestation.schema_version,
        attestation_id = attestation.attestation_id,
        identity_commitment = attestation.identity_commitment,
        continuity_commitment = attestation.continuity_commitment,
        privileges_commitment = attestation.privileges_commitment,
        responsibilities_commitment = attestation.responsibilities_commitment,
        governance_terms_commitment = attestation.governance_terms_commitment,
        issued_at_epoch_seconds = attestation.issued_at_epoch_seconds,
        active = false,
        archive_reason_commitment = archive_reason_commitment,
    }
end

function M.validate_service_request(request)
    assert(type(request) == "table", "service request must be a table")
    assert(valid_service_classes[request.service_class],
        "service_class is invalid")
    assert(is_boolean(request.digital_path_available),
        "digital_path_available must be boolean")
    assert(is_boolean(request.non_digital_path_available),
        "non_digital_path_available must be boolean")
    assert(is_boolean(request.human_fallback_available),
        "human_fallback_available must be boolean")
    assert(is_boolean(request.outcome_equivalence_verified),
        "outcome_equivalence_verified must be boolean")
    assert(is_boolean(request.correction_path_available),
        "correction_path_available must be boolean")
    assert(is_boolean(request.appeal_path_available),
        "appeal_path_available must be boolean")
    assert(is_boolean(request.accessible_status_available),
        "accessible_status_available must be boolean")
    assert(is_boolean(request.account_required),
        "account_required must be boolean")
    assert(is_boolean(request.account_necessary),
        "account_necessary must be boolean")
    assert(uncertainty_levels[request.uncertainty_level],
        "uncertainty_level is invalid")
    assert(is_boolean(request.critical_automated_decision_requested),
        "critical_automated_decision_requested must be boolean")
    assert(type(request.requested_data_classes) == "table",
        "requested_data_classes must be an array")
    assert(type(request.requested_practices) == "table",
        "requested_practices must be an array")

    return true
end

function M.rights_preserving_baseline(service_class)
    assert(valid_service_classes[service_class],
        "service_class is invalid")

    return {
        service_class = service_class,
        digital_path_available = true,
        non_digital_path_available = true,
        human_fallback_available = true,
        outcome_equivalence_verified = true,
        correction_path_available = true,
        appeal_path_available = true,
        accessible_status_available = true,
        account_required = false,
        account_necessary = false,
        uncertainty_level = M.UNCERTAINTY.high_confidence,
        critical_automated_decision_requested = false,
        requested_data_classes = {},
        requested_practices = {},
    }
end

function M.evaluate_service_request(request)
    M.validate_service_request(request)

    local has_prohibited_data = array_contains_prohibited(
        request.requested_data_classes,
        prohibited_data_classes
    )

    if has_prohibited_data then
        return result(
            M.DECISION.deny,
            { "requested private status-related data is prohibited" },
            {
                "stop_prohibited_collection",
                "provide_neutral_access_pathway",
                "record_privacy_preserving_audit",
                "provide_correction_path",
                "provide_appeal_path",
                "require_human_review",
            }
        )
    end

    local has_prohibited_practice = array_contains_prohibited(
        request.requested_practices,
        prohibited_practices
    )

    if has_prohibited_practice then
        return result(
            M.DECISION.deny,
            { "requested practice violates a core CyberRank protection" },
            {
                "stop_prohibited_practice",
                "provide_neutral_access_pathway",
                "record_privacy_preserving_audit",
                "provide_correction_path",
                "provide_appeal_path",
                "require_human_review",
            }
        )
    end

    local is_essential = essential_service_classes[request.service_class] == true
    local continuity_path_available =
        request.digital_path_available
        or request.non_digital_path_available
        or request.human_fallback_available

    if is_essential and not continuity_path_available then
        return result(
            M.DECISION.suspend,
            { "essential service has no available continuity pathway" },
            {
                "open_continuity_incident",
                "activate_human_fallback",
                "provide_non_digital_pathway",
                "publish_accessible_status",
                "provide_correction_path",
                "provide_appeal_path",
                "require_human_review",
            }
        )
    end

    if is_essential and not request.outcome_equivalence_verified then
        return result(
            M.DECISION.hold,
            { "essential-service pathway equivalence is not verified" },
            {
                "verify_outcome_equivalence",
                "activate_human_fallback",
                "provide_non_digital_pathway",
                "provide_correction_path",
                "provide_appeal_path",
                "require_human_review",
            }
        )
    end

    if not request.correction_path_available
        or not request.appeal_path_available then
        return result(
            M.DECISION.hold,
            { "correction or appeal pathway is unavailable" },
            {
                "provide_correction_path",
                "provide_appeal_path",
                "provide_accessible_status",
                "require_human_review",
            }
        )
    end

    if request.account_required and not request.account_necessary then
        return result(
            M.DECISION.hold,
            { "an unnecessary account requirement creates an access barrier" },
            {
                "provide_account_free_pathway",
                "provide_non_digital_pathway",
                "record_privacy_preserving_audit",
                "provide_correction_path",
                "provide_appeal_path",
            }
        )
    end

    if request.critical_automated_decision_requested
        and request.uncertainty_level == M.UNCERTAINTY.unreliable then
        return result(
            M.DECISION.hold,
            { "unreliable automation may not finalize a critical decision" },
            {
                "block_automated_critical_decision",
                "activate_human_fallback",
                "provide_accessible_uncertainty_notice",
                "provide_correction_path",
                "provide_appeal_path",
                "require_human_review",
            }
        )
    end

    return result(
        M.DECISION.allow_with_conditions,
        { "rights-preserving pathway is available" },
        {
            "minimize_operational_data",
            "preserve_non_disclosure",
            "provide_accessible_status",
            "provide_correction_path",
            "provide_appeal_path",
            "record_privacy_preserving_audit",
            "require_renewal",
        }
    )
end

function M.obligations_as_array(policy_result)
    assert(type(policy_result) == "table", "policy result must be a table")
    assert(type(policy_result.obligations) == "table",
        "policy result obligations must be a set")

    return sorted_keys(policy_result.obligations)
end

return M
