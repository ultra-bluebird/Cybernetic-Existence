-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/augmented_rights_claim_boundary.lua
-- Destination: lua/tools/

local AugmentedRightsClaimBoundary = {}
AugmentedRightsClaimBoundary.__index = AugmentedRightsClaimBoundary

local supported_claims = {
    "assistive_technology_as_necessity",
    "cognitive_liberty",
    "data_minimization",
    "democratic_participation",
    "effective_communication",
    "equal_access",
    "identity_continuity",
    "neural_privacy",
    "offline_existence",
    "repair_and_modification",
    "self_asserted_identity",
    "technology_interoperability",
}

local advocacy_claims = {
    "augmentation_status_heightened_scrutiny",
    "data_ownership",
    "electromagnetic_interference_protection",
    "neural_expectation_of_privacy",
    "psychological_continuity",
}

local function required_text(value, field)
    assert(type(value) == "string" and value:match("%S"),
        (field or "value") .. " must be a non-empty string")
    return value
end

local function finite_number(value, field)
    assert(
        type(value) == "number"
            and value == value
            and value ~= math.huge
            and value ~= -math.huge,
        (field or "value") .. " must be a finite number"
    )
    return value
end

local function clamp01(value)
    value = finite_number(value, "score")

    if value < 0 then
        return 0
    end

    if value > 1 then
        return 1
    end

    return value
end

local function utc_now()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function copy_value(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic claim records are not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function is_supported_claim(claim)
    return supported_claims[claim] == true
end

local function is_advocacy_claim(claim)
    return advocacy_claims[claim] == true
end

function AugmentedRightsClaimBoundary.new(config)
    config = config or {}

    return setmetatable({
        minimum_evidence_quality = clamp01(
            config.minimum_evidence_quality or 0.75
        ),
        assessments = {},
        sequence = 0,
    }, AugmentedRightsClaimBoundary)
end

function AugmentedRightsClaimBoundary:assess(claim)
    assert(type(claim) == "table", "claim must be a table")

    local claim_id = required_text(claim.claim_id, "claim_id")
    local claim_type = required_text(claim.claim_type, "claim_type")
    local evidence_quality = clamp01(claim.evidence_quality or 0)
    local jurisdiction = claim.jurisdiction
        and required_text(claim.jurisdiction, "jurisdiction")
        or "not_specified"

    local classification
    local allowed_for_public_material
    local required_notice
    local findings = {}

    if is_supported_claim(claim_type) then
        classification = "existing_framework_mapping"
        allowed_for_public_material = evidence_quality
            >= self.minimum_evidence_quality
        required_notice =
            "Describe this as a policy and accessibility mapping; do not present it as a guaranteed legal outcome."
    elseif is_advocacy_claim(claim_type) then
        classification = "advocacy_or_unsettled_doctrine"
        allowed_for_public_material = evidence_quality
            >= self.minimum_evidence_quality
        required_notice =
            "Describe this as an advocacy position or proposed legal development, not settled constitutional law."
    else
        classification = "unsupported_or_out_of_scope"
        allowed_for_public_material = false
        required_notice =
            "Do not publish this claim as a legal, medical, technical, or constitutional conclusion without qualified review."
        findings[#findings + 1] =
            "claim type is not included in the approved mapping catalog"
    end

    if evidence_quality < self.minimum_evidence_quality then
        findings[#findings + 1] =
            "evidence quality is below the configured public-advocacy threshold"
    end

    if claim.asserts_current_legal_rule == true
        and classification == "advocacy_or_unsettled_doctrine" then
        allowed_for_public_material = false
        findings[#findings + 1] =
            "an unsettled advocacy claim must not be represented as a current legal rule"
    end

    if claim.requires_individual_identity_proof == true then
        allowed_for_public_material = false
        findings[#findings + 1] =
            "rights advocacy must not require identity proof from affected individuals"
    end

    if claim.includes_raw_neural_data == true
        or claim.includes_biometrics == true
        or claim.includes_device_identifiers == true then
        allowed_for_public_material = false
        findings[#findings + 1] =
            "public advocacy material must not contain raw neural, biometric, or device-identifying data"
    end

    local harm_risk = clamp01(
        (classification == "unsupported_or_out_of_scope" and 0.35 or 0.05)
            + (evidence_quality < self.minimum_evidence_quality and 0.20 or 0)
            + (claim.asserts_current_legal_rule == true
                and classification == "advocacy_or_unsettled_doctrine"
                and 0.25 or 0)
    )

    local result = {
        claim_id = claim_id,
        claim_type = claim_type,
        jurisdiction = jurisdiction,
        classification = classification,
        allowed_for_public_material = allowed_for_public_material,
        required_notice = required_notice,
        findings = findings,
        legal_advice_provided = false,
        individual_identity_proof_required = false,
        raw_neural_data_retained = false,
        biometric_data_retained = false,
        device_identifiers_retained = false,
        knowledge_factor = evidence_quality,
        eco_impact_value = clamp01(claim.eco_impact_value or 0.50),
        harm_risk = harm_risk,
        assessed_at_utc = claim.assessed_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.assessments[#self.assessments + 1] = copy_value(result)

    return result
end

function AugmentedRightsClaimBoundary:catalog()
    return {
        supported_claims = copy_value(supported_claims),
        advocacy_claims = copy_value(advocacy_claims),
        legal_notice = "This catalog is a policy and advocacy boundary, not legal advice.",
        generated_at_utc = utc_now(),
    }
end

return AugmentedRightsClaimBoundary
