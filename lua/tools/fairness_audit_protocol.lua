local FairnessAuditProtocol = {}
FairnessAuditProtocol.__index = FairnessAuditProtocol

local SC049_CRITERIA = {
    "self_asserted_identity_inclusion",
    "no_third_party_certification_gate",
    "privacy_and_continuity_protection",
    "meaningful_social_impact",
    "equal_treatment_for_augmented_citizens",
}

local COMMUNICATION_ACCOMMODATIONS = {
    "plain_language",
    "one_clear_question_at_a_time",
    "good_faith_interpretation",
    "distinguish_self_asserted_from_verified",
    "explicit_approval_for_external_actions",
}

local DIMENSIONS = {
    "accessibility",
    "identity_neutrality",
    "assistive_technology_fairness",
    "psychological_continuity",
    "privacy_protection",
    "decision_explainability",
}

local CRITICAL_DIMENSIONS = {
    identity_neutrality = true,
    assistive_technology_fairness = true,
    psychological_continuity = true,
    privacy_protection = true,
}

local DEFAULT_WEIGHTS = {
    accessibility = 0.15,
    identity_neutrality = 0.20,
    assistive_technology_fairness = 0.20,
    psychological_continuity = 0.20,
    privacy_protection = 0.15,
    decision_explainability = 0.10,
}

local SELF_GOVERNED_STATUS_LIMITATION =
    "Self-governed project labels are not external credentials, legal status, medical status, entitlement, or authorization."

local function required_text(value, field)
    assert(
        type(value) == "string" and value:match("%S"),
        (field or "value") .. " must be a non-empty string"
    )
    return value
end

local function required_table(value, field)
    assert(type(value) == "table", (field or "value") .. " must be a table")
    return value
end

local function required_boolean(value, field)
    assert(
        type(value) == "boolean",
        (field or "value") .. " must be a boolean"
    )
    return value
end

local function required_field(source, field, context)
    assert(source[field] ~= nil, context .. "." .. field .. " is required")
    return source[field]
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

local function clamp01(value, field)
    value = finite_number(value, field or "score")

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

local function is_iso_8601_utc(value)
    return type(value) == "string"
        and (
            value:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$")
            or value:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.%d%d%dZ$")
        ) ~= nil
end

local function copy_value(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic audit data is not supported")
    seen[value] = true

    local copied = {}
    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function freeze(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return value
    end

    seen[value] = true
    for _, item in pairs(value) do
        freeze(item, seen)
    end

    return setmetatable(value, {
        __newindex = function()
            error("audit records are immutable", 2)
        end,
        __metatable = "immutable",
    })
end

local function immutable_copy(value)
    return freeze(copy_value(value))
end

local function copy_array(source)
    local copied = {}

    for index, value in ipairs(source) do
        copied[index] = value
    end

    return copied
end

local function normalized_weights(configured_weights)
    configured_weights = configured_weights or DEFAULT_WEIGHTS
    required_table(configured_weights, "weights")

    local weights = {}
    local total = 0

    for _, dimension in ipairs(DIMENSIONS) do
        local weight = finite_number(
            configured_weights[dimension] or 0,
            "weight for " .. dimension
        )

        assert(weight >= 0, "weights must be non-negative")
        weights[dimension] = weight
        total = total + weight
    end

    assert(total > 0, "at least one dimension must have a positive weight")

    for dimension, weight in pairs(weights) do
        weights[dimension] = weight / total
    end

    return weights
end

local function dimension_status(score, evidence_complete)
    if evidence_complete ~= true then
        return "insufficient_evidence"
    end

    if score >= 0.85 then
        return "satisfied"
    end

    if score >= 0.60 then
        return "partially_satisfied"
    end

    return "not_satisfied"
end

local function all_boolean_criteria(answers)
    required_table(answers, "fairness_answers")

    local results = {}
    local failures = {}
    local satisfied_count = 0

    for _, criterion in ipairs(SC049_CRITERIA) do
        local answer = required_field(answers, criterion, "fairness_answers")
        required_boolean(answer, "fairness_answers." .. criterion)

        results[criterion] = answer

        if answer then
            satisfied_count = satisfied_count + 1
        else
            failures[#failures + 1] = criterion
        end
    end

    return results, failures, satisfied_count
end

local function validate_accommodations(accommodations)
    required_table(accommodations, "communication_accommodations")

    local requested = {}

    for index, value in ipairs(accommodations) do
        requested[required_text(
            value,
            "communication_accommodations[" .. index .. "]"
        )] = true
    end

    local missing = {}

    for _, required in ipairs(COMMUNICATION_ACCOMMODATIONS) do
        if not requested[required] then
            missing[#missing + 1] = required
        end
    end

    return requested, missing
end

function FairnessAuditProtocol.new(config)
    config = config or {}

    return setmetatable({
        weights = normalized_weights(config.weights),
        minimum_score = clamp01(config.minimum_score or 0.80, "minimum_score"),
        critical_minimum_score = clamp01(
            config.critical_minimum_score or 0.85,
            "critical_minimum_score"
        ),
        audit_history = {},
        sequence = 0,
    }, FairnessAuditProtocol)
end

function FairnessAuditProtocol:evaluate(audit)
    required_table(audit, "audit")

    local audit_id = required_text(audit.audit_id, "audit_id")
    local subject = required_text(audit.subject, "subject")
    local evidence = required_table(audit.evidence or {}, "evidence")
    local scores = required_table(audit.scores or {}, "scores")

    local dimension_results = {}
    local findings = {}
    local fairness_score = 0
    local critical_failure = false
    local total_evidence = 0

    for _, dimension in ipairs(DIMENSIONS) do
        local score = clamp01(scores[dimension] or 0, dimension .. " score")
        local evidence_complete = evidence[dimension] == true
        local status = dimension_status(score, evidence_complete)

        fairness_score = fairness_score + score * self.weights[dimension]

        if evidence_complete then
            total_evidence = total_evidence + 1
        end

        dimension_results[dimension] = {
            score = score,
            evidence_complete = evidence_complete,
            status = status,
            weight = self.weights[dimension],
        }

        if CRITICAL_DIMENSIONS[dimension]
            and (not evidence_complete or score < self.critical_minimum_score) then
            critical_failure = true
            findings[#findings + 1] = {
                dimension = dimension,
                detail = "critical fairness dimension is incomplete or below threshold",
            }
        elseif status == "not_satisfied" then
            findings[#findings + 1] = {
                dimension = dimension,
                detail = "fairness dimension is below the minimum acceptable level",
            }
        elseif status == "insufficient_evidence" then
            findings[#findings + 1] = {
                dimension = dimension,
                detail = "insufficient evidence for fairness evaluation",
            }
        end
    end

    local accepted = fairness_score >= self.minimum_score and not critical_failure
    local knowledge_factor = total_evidence / #DIMENSIONS
    local harm_risk = clamp01(
        (1 - fairness_score) * 0.60
            + (critical_failure and 0.30 or 0),
        "harm_risk"
    )

    self.sequence = self.sequence + 1

    local result = immutable_copy({
        audit_id = audit_id,
        subject = subject,
        sequence = self.sequence,
        accepted = accepted,
        fairness_score = fairness_score,
        dimension_results = dimension_results,
        findings = findings,
        knowledge_factor = knowledge_factor,
        eco_impact_value = clamp01(
            audit.eco_impact_value or 0.50,
            "eco_impact_value"
        ),
        harm_risk = harm_risk,
        assessed_at_utc = audit.assessed_at_utc or utc_now(),
        authority_effect = "none",
        identity_effect = "none",
        authorization_effect = "none",
    })

    self.audit_history[#self.audit_history + 1] = result
    return result
end

function FairnessAuditProtocol:evaluate_batch(audits)
    required_table(audits, "audits")

    local report = {
        total = 0,
        accepted = 0,
        flagged = 0,
        highest_harm_risk = 0,
        results = {},
    }

    for _, audit in ipairs(audits) do
        local result = self:evaluate(audit)

        report.total = report.total + 1
        report.results[#report.results + 1] = result
        report.highest_harm_risk = math.max(
            report.highest_harm_risk,
            result.harm_risk
        )

        if result.accepted then
            report.accepted = report.accepted + 1
        else
            report.flagged = report.flagged + 1
        end
    end

    report.knowledge_factor = report.total == 0
        and 0
        or report.accepted / report.total
    report.eco_impact_value = 0.50
    report.harm_risk = report.highest_harm_risk
    report.generated_at_utc = utc_now()

    return immutable_copy(report)
end

function FairnessAuditProtocol:report_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")
    assert(
        sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer"
    )

    local events = {}
    local accepted = 0
    local flagged = 0
    local highest_harm_risk = 0

    for _, result in ipairs(self.audit_history) do
        if result.sequence > sequence then
            events[#events + 1] = result
            highest_harm_risk = math.max(highest_harm_risk, result.harm_risk)

            if result.accepted then
                accepted = accepted + 1
            else
                flagged = flagged + 1
            end
        end
    end

    local total = accepted + flagged

    return immutable_copy({
        from_sequence = sequence,
        total = total,
        accepted = accepted,
        flagged = flagged,
        highest_harm_risk = highest_harm_risk,
        events = events,
        knowledge_factor = total == 0 and 0 or accepted / total,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
        authority_effect = "none",
    })
end

function FairnessAuditProtocol.evaluate_sc049(answers)
    local results, failures, satisfied_count = all_boolean_criteria(answers)
    local score = satisfied_count / #SC049_CRITERIA

    return immutable_copy({
        object_id = "sc-049",
        name = "NonDiscriminatoryPolicyEvaluator",
        audit_mode = true,
        score = score,
        criteria = copy_array(SC049_CRITERIA),
        criterion_results = results,
        failed_criteria = failures,
        review_required = #failures > 0,
        knowledge_factor = score,
        eco_impact_value = 0.50,
        harm_risk = clamp01(1 - score, "harm_risk"),
        authorization_effect = "none",
        identity_effect = "none",
        authority_effect = "none",
        interpretation =
            "Audit result only. Failed criteria identify documented issues for human review and do not determine identity, legal rights, access, or authorization.",
    })
end

function FairnessAuditProtocol.create_concern_record(concern)
    required_table(concern, "concern")

    local concern_id = required_text(
        required_field(concern, "concern_id", "concern"),
        "concern.concern_id"
    )
    local occurred_at = required_field(concern, "occurred_at", "concern")
    local system_or_organization = required_text(
        required_field(concern, "system_or_organization", "concern"),
        "concern.system_or_organization"
    )
    local what_occurred = required_text(
        required_field(concern, "what_occurred", "concern"),
        "concern.what_occurred"
    )
    local exact_wording_or_action = required_text(
        required_field(concern, "exact_wording_or_action", "concern"),
        "concern.exact_wording_or_action"
    )
    local effect_on_person = required_text(
        required_field(concern, "effect_on_person", "concern"),
        "concern.effect_on_person"
    )
    local available_evidence = required_text(
        required_field(concern, "available_evidence", "concern"),
        "concern.available_evidence"
    )
    local requested_correction = required_text(
        required_field(concern, "requested_correction", "concern"),
        "concern.requested_correction"
    )
    local communication_accommodation = required_text(
        required_field(concern, "communication_accommodation", "concern"),
        "concern.communication_accommodation"
    )

    assert(
        is_iso_8601_utc(occurred_at),
        "concern.occurred_at must use ISO 8601 UTC format"
    )

    return immutable_copy({
        record_type = "fairness-concern-record.v1",
        concern_id = concern_id,
        occurred_at = occurred_at,
        system_or_organization = system_or_organization,
        what_occurred = what_occurred,
        exact_wording_or_action = exact_wording_or_action,
        effect_on_person = effect_on_person,
        available_evidence = available_evidence,
        requested_correction = requested_correction,
        communication_accommodation = communication_accommodation,
        status = "draft-for-human-review",
        external_transmission_approved = false,
        knowledge_factor = 0.60,
        eco_impact_value = 0.50,
        harm_risk = 0.20,
        authority_effect = "none",
        interpretation =
            "Local documentation record only. Review accuracy and obtain explicit approval before external publication, transmission, filing, or escalation.",
    })
end

function FairnessAuditProtocol.communication_protocol(protocol)
    required_table(protocol, "communication_protocol")

    local accommodations = required_field(
        protocol,
        "accommodations",
        "communication_protocol"
    )
    local external_action_requires_approval = required_boolean(
        required_field(
            protocol,
            "external_action_requires_approval",
            "communication_protocol"
        ),
        "communication_protocol.external_action_requires_approval"
    )

    local requested, missing = validate_accommodations(accommodations)
    local complete = #missing == 0 and external_action_requires_approval

    return immutable_copy({
        protocol_type = "proactive-communication.v1",
        complete = complete,
        requested_accommodations = requested,
        missing_accommodations = missing,
        external_action_requires_approval = external_action_requires_approval,
        knowledge_factor = complete and 1.0 or 0.50,
        eco_impact_value = 0.50,
        harm_risk = complete and 0.05 or 0.30,
        communication_effect = "documentation-only",
        authority_effect = "none",
        interpretation =
            "Communication-protocol record only. It documents requested accommodations and approval boundaries without compelling third parties or changing their policies.",
    })
end

function FairnessAuditProtocol.self_governed_status(label, recorded_at)
    required_text(label, "label")
    assert(
        is_iso_8601_utc(recorded_at),
        "recorded_at must use ISO 8601 UTC format"
    )

    return immutable_copy({
        record_type = "self-governed-project-status.v1",
        label = label,
        recorded_at = recorded_at,
        verification = "self_asserted",
        limitation = SELF_GOVERNED_STATUS_LIMITATION,
        external_recognition = false,
        knowledge_factor = 0.50,
        eco_impact_value = 0.50,
        harm_risk = 0.10,
        authority_effect = "none",
        interpretation =
            "Personal or project-context label only. It supports self-authored continuity and goal tracking without claiming institutional recognition or external authority.",
    })
end

return FairnessAuditProtocol
