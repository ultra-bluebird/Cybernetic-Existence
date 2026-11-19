local EqualTreatmentAudit = {}
EqualTreatmentAudit.__index = EqualTreatmentAudit

local negative_decisions = {
    denied = true,
    reduced_access = true,
    delayed = true,
    escalated = true,
}

local function required_text(value, field)
    assert(type(value) == "string" and value:match("%S"),
        (field or "value") .. " must be a non-empty string")
    return value
end

local function clamp01(value)
    assert(type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge,
        "score values must be finite numbers")

    if value < 0 then
        return 0
    end

    if value > 1 then
        return 1
    end

    return value
end

local function copy_value(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic audit records are not supported")
    seen[value] = true

    local result = {}
    for key, item in pairs(value) do
        result[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return result
end

function EqualTreatmentAudit.new(config)
    config = config or {}

    return setmetatable({
        required_accommodation_status = config.required_accommodation_status
            or "provided",
        audit_events = {},
        sequence = 0,
    }, EqualTreatmentAudit)
end

function EqualTreatmentAudit:audit_decision(decision)
    assert(type(decision) == "table", "decision must be a table")

    local decision_id = required_text(decision.decision_id, "decision_id")
    local outcome = required_text(decision.outcome, "outcome")
    local findings = {}

    local verifiability = decision.identity_verifiability or "unknown"
    local accommodation_status = decision.assistive_accommodation_status or "not_recorded"
    local negative = negative_decisions[outcome] == true

    if negative and (verifiability == "unverifiable"
        or verifiability == "self_asserted"
        or verifiability == "unknown") then
        findings[#findings + 1] = {
            category = "identity_verifiability_penalty",
            detail = "negative outcome requires evidence it was not based on verifiability status",
        }
    end

    if decision.assistive_need_declared == true
        and accommodation_status ~= self.required_accommodation_status then
        findings[#findings + 1] = {
            category = "unmet_assistive_need",
            detail = "declared assistive requirement was not recorded as provided",
        }
    end

    if decision.identity_neutrality_checked ~= true then
        findings[#findings + 1] = {
            category = "missing_identity_neutrality_check",
            detail = "decision lacks a recorded identity-neutrality assessment",
        }
    end

    local harm_risk = clamp01(0.05 + (#findings * 0.25))

    local report = {
        decision_id = decision_id,
        outcome = outcome,
        subject_reference = decision.subject_reference or "not_provided",
        accepted = #findings == 0,
        findings = findings,
        knowledge_factor = decision.evidence_complete == true and 0.80 or 0.55,
        eco_impact_value = 0.50,
        harm_risk = harm_risk,
        assessed_at_utc = decision.assessed_at_utc or os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    self.sequence = self.sequence + 1
    report.sequence = self.sequence
    self.audit_events[#self.audit_events + 1] = copy_value(report)

    return report
end

function EqualTreatmentAudit:audit_batch(decisions)
    assert(type(decisions) == "table", "decisions must be a table")

    local summary = {
        total = 0,
        accepted = 0,
        flagged = 0,
        highest_harm_risk = 0,
        reports = {},
    }

    for _, decision in ipairs(decisions) do
        local report = self:audit_decision(decision)

        summary.total = summary.total + 1
        summary.reports[#summary.reports + 1] = report
        summary.highest_harm_risk = math.max(summary.highest_harm_risk, report.harm_risk)

        if report.accepted then
            summary.accepted = summary.accepted + 1
        else
            summary.flagged = summary.flagged + 1
        end
    end

    summary.knowledge_factor = summary.total == 0 and 0
        or summary.accepted / summary.total
    summary.eco_impact_value = 0.50
    summary.harm_risk = summary.highest_harm_risk
    summary.assessed_at_utc = os.date("!%Y-%m-%dT%H:%M:%SZ")

    return summary
end

function EqualTreatmentAudit:report_since(sequence)
    sequence = sequence or 0
    assert(type(sequence) == "number" and sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer")

    local report = {
        from_sequence = sequence,
        events = {},
        total = 0,
        accepted = 0,
        flagged = 0,
        highest_harm_risk = 0,
    }

    for _, event in ipairs(self.audit_events) do
        if event.sequence > sequence then
            report.events[#report.events + 1] = copy_value(event)
            report.total = report.total + 1
            report.highest_harm_risk = math.max(report.highest_harm_risk, event.harm_risk)

            if event.accepted then
                report.accepted = report.accepted + 1
            else
                report.flagged = report.flagged + 1
            end
        end
    end

    report.knowledge_factor = report.total == 0 and 0
        or report.accepted / report.total
    report.eco_impact_value = 0.50
    report.harm_risk = report.highest_harm_risk
    report.generated_at_utc = os.date("!%Y-%m-%dT%H:%M:%SZ")

    return report
end

return EqualTreatmentAudit
