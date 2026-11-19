local Validator = {}
Validator.__index = Validator

local required_protections = {
    "assistive_technology_recognized_as_necessary",
    "no_service_denial_for_assistive_use",
    "reasonable_accommodation_process",
    "continuity_during_interface_change",
    "privacy_preserving_support",
    "equivalent_service_access",
}

local function required_text(value, field)
    assert(type(value) == "string" and value:match("%S"),
        (field or "value") .. " must be a non-empty string")
    return value
end

local function finite_number(value, field)
    assert(type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge,
        (field or "value") .. " must be a finite number")
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

function Validator.new(config)
    config = config or {}

    return setmetatable({
        minimum_score = clamp01(config.minimum_score or 0.85),
        audits = {},
        sequence = 0,
    }, Validator)
end

function Validator:validate(policy)
    assert(type(policy) == "table", "policy must be a table")

    local policy_id = required_text(policy.policy_id, "policy_id")
    local protections = policy.assistive_technology_protections or {}

    assert(type(protections) == "table",
        "assistive_technology_protections must be a table")

    local findings = {}
    local satisfied = 0

    for _, protection in ipairs(required_protections) do
        if protections[protection] == true then
            satisfied = satisfied + 1
        else
            findings[#findings + 1] = {
                requirement = protection,
                detail = "required assistive-technology protection is absent",
            }
        end
    end

    if policy.treats_assistive_technology_as_optional == true then
        findings[#findings + 1] = {
            requirement = "assistive_technology_recognized_as_necessary",
            detail = "policy incorrectly categorizes assistive technology as optional",
        }
    end

    if policy.requires_third_party_certification_for_assistive_use == true then
        findings[#findings + 1] = {
            requirement = "no_service_denial_for_assistive_use",
            detail = "third-party certification cannot be a prerequisite for assistive use",
        }
    end

    if policy.denies_access_after_interface_change == true then
        findings[#findings + 1] = {
            requirement = "continuity_during_interface_change",
            detail = "policy denies continuity across an assistive interface change",
        }
    end

    local requirement_score = satisfied / #required_protections
    local valid = requirement_score >= self.minimum_score and #findings == 0
    local knowledge_factor = policy.evidence_complete == true and 0.85 or 0.60
    local harm_risk = clamp01(0.05 + (#findings * 0.18))

    local result = {
        policy_id = policy_id,
        valid = valid,
        requirement_score = requirement_score,
        required_protection_count = #required_protections,
        satisfied_protection_count = satisfied,
        findings = findings,
        knowledge_factor = knowledge_factor,
        eco_impact_value = 0.50,
        harm_risk = harm_risk,
        assessed_at_utc = policy.assessed_at_utc or os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.audits[#self.audits + 1] = copy_value(result)

    return result
end

function Validator:validate_batch(policies)
    assert(type(policies) == "table", "policies must be a table")

    local summary = {
        total = 0,
        valid = 0,
        invalid = 0,
        highest_harm_risk = 0,
        results = {},
    }

    for _, policy in ipairs(policies) do
        local result = self:validate(policy)

        summary.total = summary.total + 1
        summary.results[#summary.results + 1] = result
        summary.highest_harm_risk = math.max(summary.highest_harm_risk, result.harm_risk)

        if result.valid then
            summary.valid = summary.valid + 1
        else
            summary.invalid = summary.invalid + 1
        end
    end

    summary.knowledge_factor = summary.total == 0 and 0
        or summary.valid / summary.total
    summary.eco_impact_value = 0.50
    summary.harm_risk = summary.highest_harm_risk
    summary.assessed_at_utc = os.date("!%Y-%m-%dT%H:%M:%SZ")

    return summary
end

function Validator:report_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")
    assert(sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer")

    local events = {}
    local highest_harm_risk = 0
    local valid = 0
    local invalid = 0

    for _, audit in ipairs(self.audits) do
        if audit.sequence > sequence then
            events[#events + 1] = copy_value(audit)
            highest_harm_risk = math.max(highest_harm_risk, audit.harm_risk)

            if audit.valid then
                valid = valid + 1
            else
                invalid = invalid + 1
            end
        end
    end

    local total = valid + invalid

    return {
        from_sequence = sequence,
        total = total,
        valid = valid,
        invalid = invalid,
        highest_harm_risk = highest_harm_risk,
        events = events,
        knowledge_factor = total == 0 and 0 or valid / total,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
end

return Validator
