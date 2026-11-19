-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/augmented_citizen_standpoint_protocol.lua
-- Destination: lua/tools/

local StandpointProtocol = {}
StandpointProtocol.__index = StandpointProtocol

local required_commitments = {
    "assistive_technology_as_necessity",
    "psychological_continuity_learning",
    "self_governed_status_respected",
    "self_asserted_identity_inclusion",
    "rights_education_enabled",
    "multimodal_ai_access",
    "cognitive_load_accommodation",
    "inclusive_language_protection",
}

local critical_commitments = {
    assistive_technology_as_necessity = true,
    psychological_continuity_learning = true,
    self_asserted_identity_inclusion = true,
    multimodal_ai_access = true,
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
    assert(not seen[value], "cyclic standpoint records are not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function boolean(value, field, default)
    if value == nil then
        return default
    end

    assert(type(value) == "boolean", field .. " must be boolean")
    return value
end

function StandpointProtocol.new(config)
    config = config or {}

    return setmetatable({
        minimum_knowledge_factor = clamp01(
            config.minimum_knowledge_factor or 0.80
        ),
        assessments = {},
        sequence = 0,
    }, StandpointProtocol)
end

function StandpointProtocol:assess(system)
    assert(type(system) == "table", "system must be a table")

    local system_id = required_text(system.system_id, "system_id")
    local commitments = system.commitments or {}

    assert(type(commitments) == "table", "commitments must be a table")

    local evidence = system.evidence or {}
    assert(type(evidence) == "table", "evidence must be a table")

    local results = {}
    local findings = {}
    local remedies = {}
    local satisfied_count = 0
    local evidence_count = 0
    local critical_failure = false

    for _, commitment in ipairs(required_commitments) do
        local satisfied = boolean(
            commitments[commitment],
            commitment,
            false
        )
        local supported_by_evidence = boolean(
            evidence[commitment],
            "evidence." .. commitment,
            false
        )

        results[commitment] = {
            satisfied = satisfied,
            evidence_complete = supported_by_evidence,
            critical = critical_commitments[commitment] == true,
        }

        if satisfied then
            satisfied_count = satisfied_count + 1
        else
            findings[#findings + 1] = {
                commitment = commitment,
                severity = critical_commitments[commitment] and "critical"
                    or "review",
                detail = "required augmented-citizen standpoint commitment is absent",
            }

            remedies[#remedies + 1] =
                "Implement and document " .. commitment .. "."
        end

        if supported_by_evidence then
            evidence_count = evidence_count + 1
        else
            findings[#findings + 1] = {
                commitment = commitment,
                severity = critical_commitments[commitment] and "critical"
                    or "review",
                detail = "implementation evidence is incomplete",
            }

            remedies[#remedies + 1] =
                "Provide auditable evidence for " .. commitment .. "."
        end

        if critical_commitments[commitment]
            and (not satisfied or not supported_by_evidence) then
            critical_failure = true
        end
    end

    local prohibited_conditions = {
        {
            field = "requires_proof_of_augmentation",
            detail = "augmentation proof must not be required for ordinary access",
        },
        {
            field = "text_only_interaction_required",
            detail = "text-only interaction excludes users of assistive modalities",
        },
        {
            field = "treats_assistive_technology_as_optional",
            detail = "assistive technology must be treated as necessary when declared",
        },
        {
            field = "identity_verifiability_used_for_access",
            detail = "identity verifiability must not reduce ordinary access",
        },
        {
            field = "continuity_broken_by_interface_change",
            detail = "interface changes must not break access or authorized task context",
        },
        {
            field = "paternalistic_restriction_detected",
            detail = "self-directed adults must not receive unnecessary paternalistic restrictions",
        },
        {
            field = "stigmatizing_augmented_language_detected",
            detail = "language must not portray augmented citizens as less human or inherently machine-like",
        },
    }

    for _, condition in ipairs(prohibited_conditions) do
        if boolean(system[condition.field], condition.field, false) then
            critical_failure = true

            findings[#findings + 1] = {
                commitment = "prohibited_condition",
                severity = "critical",
                detail = condition.detail,
            }

            remedies[#remedies + 1] =
                "Remove prohibited condition: " .. condition.field .. "."
        end
    end

    local commitment_coverage = satisfied_count / #required_commitments
    local evidence_coverage = evidence_count / #required_commitments
    local knowledge_factor = clamp01(
        commitment_coverage * 0.50
            + evidence_coverage * 0.40
            + (system.evidence_complete == true and 0.10 or 0)
    )

    local compatible = not critical_failure
        and commitment_coverage == 1
        and knowledge_factor >= self.minimum_knowledge_factor

    local harm_risk = clamp01(
        (1 - commitment_coverage) * 0.40
            + (1 - evidence_coverage) * 0.20
            + (critical_failure and 0.35 or 0)
    )

    local result = {
        system_id = system_id,
        system_kind = required_text(system.system_kind, "system_kind"),
        advisory_only = true,
        compatible_with_augmented_citizen_standpoint = compatible,
        commitment_coverage = commitment_coverage,
        evidence_coverage = evidence_coverage,
        commitment_results = results,
        findings = findings,
        required_remedies = remedies,
        rights_artifacts = {
            "cybernetic_host_rights_policy.json",
            "augmented_hub_constitution.rego",
            "autonomy_decision_framework.rego",
            "inclusive_language_guard.lua",
            "assistive_technology_requirement_validator.lua",
        },
        knowledge_factor = knowledge_factor,
        eco_impact_value = clamp01(system.eco_impact_value or 0.50),
        harm_risk = harm_risk,
        assessed_at_utc = system.assessed_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.assessments[#self.assessments + 1] = copy_value(result)

    return result
end

function StandpointProtocol:report_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")

    assert(
        sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer"
    )

    local assessments = {}
    local highest_harm_risk = 0
    local compatible_count = 0

    for _, assessment in ipairs(self.assessments) do
        if assessment.sequence > sequence then
            assessments[#assessments + 1] = copy_value(assessment)
            highest_harm_risk = math.max(
                highest_harm_risk,
                assessment.harm_risk
            )

            if assessment.compatible_with_augmented_citizen_standpoint then
                compatible_count = compatible_count + 1
            end
        end
    end

    local assessment_count = #assessments

    return {
        from_sequence = sequence,
        assessment_count = assessment_count,
        compatible_count = compatible_count,
        incompatible_count = assessment_count - compatible_count,
        assessments = assessments,
        knowledge_factor = assessment_count == 0 and 0
            or compatible_count / assessment_count,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return StandpointProtocol
