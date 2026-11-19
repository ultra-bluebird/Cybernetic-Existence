-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/augmented_rights_scenario_assessor.lua
-- Destination: lua/tools/

local ScenarioAssessor = {}
ScenarioAssessor.__index = ScenarioAssessor

local scenario_types = {
    assistive_access_denial = true,
    data_access_request = true,
    employment_access = true,
    institutional_device_restriction = true,
    public_service_access = true,
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
    assert(not seen[value], "cyclic scenario data is not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function assess_employment_access(input)
    local findings = {}
    local advocacy = {}

    if input.employer_is_government == true then
        advocacy[#advocacy + 1] =
            "Evaluate state-action and Equal Protection arguments with qualified legal counsel."
    else
        advocacy[#advocacy + 1] =
            "Evaluate statutory employment, disability, contract, and consumer-protection remedies with qualified legal counsel."
    end

    if input.device_policy_is_necessary_for_specific_safety_risk ~= true then
        findings[#findings + 1] =
            "The manufacturer-approval requirement lacks documented, individualized safety justification."
    end

    if input.alternative_compatible_device_reviewed ~= true then
        findings[#findings + 1] =
            "No documented individualized compatibility or accommodation review was supplied."
    end

    return {
        likely_legal_path = "fact-specific statutory and constitutional analysis",
        prediction = "indeterminate_without_jurisdictional_and_factual_review",
        findings = findings,
        advocacy_actions = advocacy,
        doctrinal_notice = "Do not assume intermediate scrutiny applies to augmentation status; it is an advocacy position, not settled federal doctrine.",
    }
end

local function assess_data_access(input)
    local findings = {}
    local advocacy = {}

    if input.government_actor ~= true then
        findings[#findings + 1] =
            "Fourth Amendment warrant doctrine generally constrains government conduct, not private company conduct alone."
        advocacy[#advocacy + 1] =
            "Assess applicable privacy, consumer-protection, contract, health-data, biometric, and state-law safeguards."
    else
        advocacy[#advocacy + 1] =
            "Assess Fourth Amendment, warrant, subpoena, and statutory process requirements with qualified counsel."
    end

    if input.warrant_present ~= true then
        findings[#findings + 1] =
            "No warrant was identified in the supplied scenario."
    end

    if input.data_scope_minimized ~= true then
        findings[#findings + 1] =
            "Requested data scope is not documented as minimized or particularized."
    end

    return {
        likely_legal_path = "government-search and applicable privacy-law analysis",
        prediction = "fact_specific; no categorical neural-data warrant rule is established by this module",
        findings = findings,
        advocacy_actions = advocacy,
        doctrinal_notice = "A neural expectation of privacy is an important proposed doctrine, not a settled universal judicial test.",
    }
end

local function assess_assistive_access(input)
    local findings = {}
    local advocacy = {
        "Document the requested aid, the functional barrier, available alternatives, and effective-communication needs.",
        "Seek accessible grievance, accommodation, and qualified legal review paths.",
    }

    if input.public_entity ~= true then
        findings[#findings + 1] =
            "Title II may not be the controlling framework if the actor is not a state or local public entity."
    end

    if input.effective_communication_available ~= true then
        findings[#findings + 1] =
            "Effective communication support is not documented."
    end

    if input.reasonable_modification_reviewed ~= true then
        findings[#findings + 1] =
            "No documented reasonable-modification or accommodation review was supplied."
    end

    if input.alternative_equally_effective ~= true then
        findings[#findings + 1] =
            "No equally effective accessible alternative was documented."
    end

    return {
        likely_legal_path = "ADA, Section 504, education law, and jurisdiction-specific accommodation analysis",
        prediction = "fact_specific; cost, undue burden, fundamental alteration, and program-specific duties require qualified review",
        findings = findings,
        advocacy_actions = advocacy,
        doctrinal_notice = "This assessor does not conclude that a particular device must be provided or that cost can never be considered.",
    }
end

local function assess_institutional_restriction(input)
    local findings = {}
    local advocacy = {
        "Request individualized medical, disability, due-process, and institutional-policy review.",
        "Preserve the person's access to necessary assistive support and effective communication pending qualified review where possible.",
    }

    if input.device_medically_or_functionally_necessary ~= true then
        findings[#findings + 1] =
            "The supplied record does not document functional or medical necessity for the device."
    end

    if input.individualized_safety_assessment_available ~= true then
        findings[#findings + 1] =
            "No individualized safety assessment was documented."
    end

    if input.due_process_available ~= true then
        findings[#findings + 1] =
            "No accessible review or due-process path was documented."
    end

    return {
        likely_legal_path = "institutional due-process, disability-rights, medical-care, and jurisdiction-specific constitutional analysis",
        prediction = "high-risk rights issue requiring urgent qualified legal and clinical review; no outcome is predetermined",
        findings = findings,
        advocacy_actions = advocacy,
        doctrinal_notice = "The legal analysis differs across correctional, medical, educational, and other institutional contexts.",
    }
end

local evaluators = {
    employment_access = assess_employment_access,
    data_access_request = assess_data_access,
    assistive_access_denial = assess_assistive_access,
    institutional_device_restriction = assess_institutional_restriction,
    public_service_access = assess_assistive_access,
}

function ScenarioAssessor.new()
    return setmetatable({
        assessments = {},
        sequence = 0,
    }, ScenarioAssessor)
end

function ScenarioAssessor:assess(input)
    assert(type(input) == "table", "scenario input must be a table")

    local scenario_id = required_text(input.scenario_id, "scenario_id")
    local scenario_type = required_text(input.scenario_type, "scenario_type")

    assert(scenario_types[scenario_type], "unsupported scenario_type")

    local evaluator = evaluators[scenario_type]
    local analysis = evaluator(input)
    local evidence_complete = input.evidence_complete == true
    local risk_signals = #analysis.findings

    local result = {
        scenario_id = scenario_id,
        scenario_type = scenario_type,
        advisory_only = true,
        legal_notice = "This is an issue-spotting and advocacy tool, not legal advice, legal representation, or a prediction of a court outcome.",
        analysis = analysis,
        automatic_outcome_claimed = false,
        qualified_review_required = true,
        knowledge_factor = evidence_complete and 0.80 or 0.55,
        eco_impact_value = clamp01(input.eco_impact_value or 0.50),
        harm_risk = clamp01(
            math.min(0.55, risk_signals * 0.12)
                + (evidence_complete and 0.05 or 0.20)
        ),
        assessed_at_utc = input.assessed_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.assessments[#self.assessments + 1] = copy_value(result)

    return result
end

return ScenarioAssessor
