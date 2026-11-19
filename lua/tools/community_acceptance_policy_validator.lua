-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/community_acceptance_policy_validator.lua
-- Destination: lua/tools/

local CommunityAcceptancePolicyValidator = {}
CommunityAcceptancePolicyValidator.__index = CommunityAcceptancePolicyValidator

local required_inclusion_commitments = {
    "augmented_citizens_explicitly_included",
    "assistive_technology_accommodated",
    "identity_verifiability_neutral",
    "no_augmentation_status_exclusion",
    "accessible_feedback_path",
    "measurable_inclusion_goal",
    "public_outcome_reporting",
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
    assert(not seen[value], "cyclic policy records are not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

function CommunityAcceptancePolicyValidator.new(config)
    config = config or {}

    return setmetatable({
        minimum_inclusion_goal = clamp01(
            config.minimum_inclusion_goal or 0.80
        ),
        assessments = {},
        sequence = 0,
    }, CommunityAcceptancePolicyValidator)
end

function CommunityAcceptancePolicyValidator:evaluate(policy)
    assert(type(policy) == "table", "policy must be a table")

    local policy_id = required_text(policy.policy_id, "policy_id")
    local policy_kind = required_text(policy.policy_kind, "policy_kind")

    assert(
        policy_kind == "public_event" or policy_kind == "smart_city_service",
        "policy_kind must be public_event or smart_city_service"
    )

    local commitments = policy.inclusion_commitments or {}
    assert(type(commitments) == "table",
        "inclusion_commitments must be a table")

    local evidence = policy.evidence or {}
    assert(type(evidence) == "table", "evidence must be a table")

    local findings = {}
    local fulfilled_commitments = 0
    local evidence_count = 0

    for _, commitment in ipairs(required_inclusion_commitments) do
        if commitments[commitment] == true then
            fulfilled_commitments = fulfilled_commitments + 1
        else
            findings[#findings + 1] = {
                commitment = commitment,
                detail = "required inclusion commitment is missing",
            }
        end

        if evidence[commitment] == true then
            evidence_count = evidence_count + 1
        else
            findings[#findings + 1] = {
                commitment = commitment,
                detail = "implementation evidence is incomplete",
            }
        end
    end

    local inclusion_goal = clamp01(policy.measurable_inclusion_goal or 0)

    if inclusion_goal < self.minimum_inclusion_goal then
        findings[#findings + 1] = {
            commitment = "measurable_inclusion_goal",
            detail = "inclusion goal is below the configured minimum",
        }
    end

    if policy.requires_third_party_identity_certification == true then
        findings[#findings + 1] = {
            commitment = "identity_verifiability_neutral",
            detail = "third-party identity certification is an exclusionary gate",
        }
    end

    if policy.denies_assistive_use == true then
        findings[#findings + 1] = {
            commitment = "assistive_technology_accommodated",
            detail = "assistive technology use must not cause denial of service",
        }
    end

    if policy.excludes_augmentation_status == true then
        findings[#findings + 1] = {
            commitment = "no_augmentation_status_exclusion",
            detail = "augmentation status must not be used to exclude participation",
        }
    end

    local evidence_complete = evidence_count == #required_inclusion_commitments
    local commitment_score =
        fulfilled_commitments / #required_inclusion_commitments

    local discrimination_risk =
        policy.requires_third_party_identity_certification == true
        or policy.denies_assistive_use == true
        or policy.excludes_augmentation_status == true

    local compliant = commitment_score == 1
        and evidence_complete
        and inclusion_goal >= self.minimum_inclusion_goal
        and not discrimination_risk

    local harm_risk = clamp01(
        ((1 - commitment_score) * 0.35)
            + ((1 - inclusion_goal) * 0.20)
            + ((not evidence_complete) and 0.15 or 0)
            + (discrimination_risk and 0.35 or 0)
    )

    local result = {
        policy_id = policy_id,
        policy_kind = policy_kind,
        compliant = compliant,
        advisory_only = true,
        commitment_score = commitment_score,
        measurable_inclusion_goal = inclusion_goal,
        fulfilled_commitment_count = fulfilled_commitments,
        required_commitment_count = #required_inclusion_commitments,
        evidence_complete = evidence_complete,
        findings = findings,
        knowledge_factor = clamp01(
            (evidence_count / #required_inclusion_commitments) * 0.80
                + (policy.evidence_complete == true and 0.20 or 0)
        ),
        eco_impact_value = clamp01(policy.eco_impact_value or 0.50),
        harm_risk = harm_risk,
        assessed_at_utc = policy.assessed_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.assessments[#self.assessments + 1] = copy_value(result)

    return result
end

function CommunityAcceptancePolicyValidator:evaluate_batch(policies)
    assert(type(policies) == "table", "policies must be a table")

    local results = {}
    local compliant_count = 0
    local highest_harm_risk = 0

    for _, policy in ipairs(policies) do
        local result = self:evaluate(policy)

        results[#results + 1] = result
        highest_harm_risk = math.max(
            highest_harm_risk,
            result.harm_risk
        )

        if result.compliant then
            compliant_count = compliant_count + 1
        end
    end

    local count = #results

    return {
        policy_count = count,
        compliant_count = compliant_count,
        noncompliant_count = count - compliant_count,
        results = results,
        knowledge_factor = count == 0 and 0
            or compliant_count / count,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

function CommunityAcceptancePolicyValidator:report_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")

    assert(
        sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer"
    )

    local results = {}
    local compliant_count = 0
    local highest_harm_risk = 0

    for _, result in ipairs(self.assessments) do
        if result.sequence > sequence then
            results[#results + 1] = copy_value(result)
            highest_harm_risk = math.max(
                highest_harm_risk,
                result.harm_risk
            )

            if result.compliant then
                compliant_count = compliant_count + 1
            end
        end
    end

    local count = #results

    return {
        from_sequence = sequence,
        policy_count = count,
        compliant_count = compliant_count,
        noncompliant_count = count - compliant_count,
        results = results,
        knowledge_factor = count == 0 and 0
            or compliant_count / count,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return CommunityAcceptancePolicyValidator
