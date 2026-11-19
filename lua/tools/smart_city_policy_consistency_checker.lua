-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/smart_city_policy_consistency_checker.lua
-- Destination: lua/tools/

local PolicyConsistencyChecker = {}
PolicyConsistencyChecker.__index = PolicyConsistencyChecker

local constitutional_rights = {
    "dignity_and_equal_treatment",
    "privacy_and_data_sovereignty",
    "accessibility_and_assistive_necessity",
    "continuity_and_identity_neutrality",
    "autonomy_and_revocable_consent",
    "participation_and_expression",
    "wellbeing_and_happiness",
    "transparency_and_accountability",
    "ecological_responsibility",
}

local critical_rights = {
    accessibility_and_assistive_necessity = true,
    continuity_and_identity_neutrality = true,
    dignity_and_equal_treatment = true,
    privacy_and_data_sovereignty = true,
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
    assert(not seen[value], "cyclic policy values are not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function validate_boolean_rights(rights)
    assert(type(rights) == "table", "rights declaration must be a table")

    local normalized = {}
    local completed = 0

    for _, right in ipairs(constitutional_rights) do
        local value = rights[right]

        if value == true or value == false then
            normalized[right] = value

            if value then
                completed = completed + 1
            end
        else
            normalized[right] = false
        end
    end

    return normalized, completed
end

function PolicyConsistencyChecker.new(config)
    config = config or {}

    return setmetatable({
        minimum_knowledge_factor = clamp01(
            config.minimum_knowledge_factor or 0.75
        ),
        assessments = {},
        sequence = 0,
    }, PolicyConsistencyChecker)
end

function PolicyConsistencyChecker:check(policy)
    assert(type(policy) == "table", "policy must be a table")

    local policy_id = required_text(policy.policy_id, "policy_id")
    local policy_kind = required_text(policy.policy_kind, "policy_kind")
    local declared_rights, satisfied_right_count =
        validate_boolean_rights(policy.constitutional_rights or {})

    local evidence = policy.evidence or {}
    assert(type(evidence) == "table", "policy.evidence must be a table")

    local conflicts = {}
    local remedies = {}
    local evidence_count = 0
    local critical_conflict = false

    for _, right in ipairs(constitutional_rights) do
        if evidence[right] == true then
            evidence_count = evidence_count + 1
        end

        if not declared_rights[right] then
            conflicts[#conflicts + 1] = {
                right = right,
                severity = critical_rights[right] and "critical" or "review",
                detail = "policy does not demonstrate consistency with this constitutional right",
            }

            remedies[#remedies + 1] =
                "Add enforceable safeguards and documented evidence for "
                .. right .. "."

            if critical_rights[right] then
                critical_conflict = true
            end
        elseif evidence[right] ~= true then
            conflicts[#conflicts + 1] = {
                right = right,
                severity = critical_rights[right] and "critical" or "review",
                detail = "policy declares this right but provides incomplete evidence",
            }

            remedies[#remedies + 1] =
                "Provide implementation evidence for "
                .. right .. "."

            if critical_rights[right] then
                critical_conflict = true
            end
        end
    end

    local prohibited_conditions = {
        {
            field = "collects_raw_identifiers",
            right = "privacy_and_data_sovereignty",
            detail = "raw identifier collection conflicts with data minimization",
        },
        {
            field = "collects_biometrics",
            right = "privacy_and_data_sovereignty",
            detail = "biometric collection conflicts with privacy-by-design",
        },
        {
            field = "collects_raw_neural_signals",
            right = "privacy_and_data_sovereignty",
            detail = "raw neural-signal collection conflicts with neurorights safeguards",
        },
        {
            field = "uses_identity_verifiability_for_access",
            right = "dignity_and_equal_treatment",
            detail = "identity verifiability must not determine ordinary service access",
        },
        {
            field = "requires_third_party_identity_certification",
            right = "dignity_and_equal_treatment",
            detail = "third-party certification is an exclusionary identity gate",
        },
        {
            field = "denies_access_for_augmentation_status",
            right = "dignity_and_equal_treatment",
            detail = "augmentation status must not be used to deny access",
        },
        {
            field = "treats_assistive_technology_as_optional",
            right = "accessibility_and_assistive_necessity",
            detail = "declared assistive technology must be treated as necessary",
        },
        {
            field = "penalizes_interface_change",
            right = "continuity_and_identity_neutrality",
            detail = "assistive interface changes must not break continuity or access",
        },
        {
            field = "blocks_accessible_grievance_path",
            right = "transparency_and_accountability",
            detail = "an accessible grievance path is required",
        },
        {
            field = "coercive_design_detected",
            right = "wellbeing_and_happiness",
            detail = "coercive interaction design conflicts with wellbeing and autonomy",
        },
    }

    for _, condition in ipairs(prohibited_conditions) do
        if policy[condition.field] == true then
            conflicts[#conflicts + 1] = {
                right = condition.right,
                severity = "critical",
                detail = condition.detail,
            }

            remedies[#remedies + 1] =
                "Remove the prohibited condition: " .. condition.field .. "."

            critical_conflict = true
        end
    end

    local ecological_harm_risk = clamp01(
        policy.ecological_harm_risk or 0
    )

    if policy.material_ecological_impact == true
        and (
            policy.ecological_assessment_available ~= true
            or ecological_harm_risk > 0.35
        ) then
        conflicts[#conflicts + 1] = {
            right = "ecological_responsibility",
            severity = "critical",
            detail = "material ecological impact lacks a qualifying ecological assessment or exceeds the declared harm corridor",
        }

        remedies[#remedies + 1] =
            "Complete ecological review and reduce ecological harm risk before deployment."

        critical_conflict = true
    end

    local rights_coverage = satisfied_right_count / #constitutional_rights
    local evidence_coverage = evidence_count / #constitutional_rights
    local knowledge_factor = clamp01(
        rights_coverage * 0.45
            + evidence_coverage * 0.45
            + (policy.evidence_complete == true and 0.10 or 0)
    )

    local consistent = not critical_conflict
        and #conflicts == 0
        and knowledge_factor >= self.minimum_knowledge_factor

    local harm_risk = clamp01(
        ((1 - rights_coverage) * 0.35)
            + ((1 - evidence_coverage) * 0.25)
            + (critical_conflict and 0.30 or 0)
            + (ecological_harm_risk * 0.10)
    )

    local result = {
        policy_id = policy_id,
        policy_kind = policy_kind,
        advisory_only = true,
        constitution_reference = "augmented_hub_constitution.rego",
        consistent = consistent,
        deployment_recommendation = consistent
            and "eligible_for_governed_review"
            or "resolve_conflicts_before_deployment",
        constitutional_rights = declared_rights,
        rights_coverage = rights_coverage,
        evidence_coverage = evidence_coverage,
        conflicts = conflicts,
        required_remedies = remedies,
        knowledge_factor = knowledge_factor,
        eco_impact_value = clamp01(policy.eco_impact_value or 0.50),
        harm_risk = harm_risk,
        checked_at_utc = policy.checked_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.assessments[#self.assessments + 1] = copy_value(result)

    return result
end

function PolicyConsistencyChecker:report_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")

    assert(
        sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer"
    )

    local assessments = {}
    local highest_harm_risk = 0
    local consistent_count = 0

    for _, assessment in ipairs(self.assessments) do
        if assessment.sequence > sequence then
            assessments[#assessments + 1] = copy_value(assessment)
            highest_harm_risk = math.max(
                highest_harm_risk,
                assessment.harm_risk
            )

            if assessment.consistent then
                consistent_count = consistent_count + 1
            end
        end
    end

    local assessment_count = #assessments

    return {
        from_sequence = sequence,
        assessment_count = assessment_count,
        consistent_count = consistent_count,
        conflict_count = assessment_count - consistent_count,
        assessments = assessments,
        knowledge_factor = assessment_count == 0 and 0
            or consistent_count / assessment_count,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return PolicyConsistencyChecker
