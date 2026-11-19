-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/insurance_rights_validator.lua
-- Destination: lua/tools/

local InsuranceRightsValidator = {}
InsuranceRightsValidator.__index = InsuranceRightsValidator

local protected_characteristics = {
    augmentation_status = true,
    identity_verifiability = true,
    assistive_technology_use = true,
    neural_interface_use = true,
    bci_use = true,
    augmentation_history = true,
}

local procedure_types = {
    diagnostic = true,
    surgical = true,
    rehabilitation = true,
    emergency_care = true,
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
    assert(not seen[value], "cyclic values are not supported")
    seen[value] = true

    local copied = {}
    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function check_discrimination(policy)
    for characteristic, _ in pairs(protected_characteristics) do
        if policy[characteristic] == true then
            if policy.denies_coverage == true then
                return true, "discrimination_detected", 
                    "denies coverage based on " .. characteristic
            end
            if policy.limits_coverage == true then
                return true, "discrimination_detected",
                    "limits coverage based on " .. characteristic
            end
            if policy.differential_pricing == true then
                return true, "discrimination_detected",
                    "differential pricing based on " .. characteristic
            end
        end
    end
    return false, nil, nil
end

local function check_coverage_decision(request)
    if request.coverage_decision == "denied" then
        if request.augmentation_status ~= nil 
            and request.augmentation_status ~= "not_applicable" then
            if not request.actuarial_justification then
                return true, "coverage_denied_based_on_status",
                    "coverage denied based on augmentation status without actuarial justification"
            end
        end
    end
    
    if request.coverage_decision == "limited" then
        if request.augmentation_status ~= nil 
            and request.augmentation_status ~= "not_applicable" then
            if request.limitation_scope ~= "standard_limitation" then
                return true, "coverage_limited_based_on_status",
                    "coverage limited based on augmentation status without actuarial justification"
            end
        end
    end
    
    if request.premium_adjustment ~= nil and request.premium_adjustment > 0 then
        if request.augmentation_status ~= nil 
            and request.augmentation_status ~= "not_applicable" then
            if not request.actuarial_justification then
                return true, "priced_differentially_based_on_status",
                    "differential pricing based on augmentation status without actuarial justification"
            end
        end
    end
    
    return false, nil, nil
end

local function check_accessibility(service)
    if not procedure_types[service.procedure_type] then
        return true, "invalid_procedure_type",
            "invalid procedure type: " .. service.procedure_type
    end

    if service.procedure_type == "diagnostic" then
        if not service.compatible_with_augmentations then
            return true, "accessibility_failure",
                "diagnostic procedures must be compatible with augmentations"
        end
    end
    
    if service.procedure_type == "surgical" then
        if not service.respects_augmentations then
            return true, "accessibility_failure",
                "surgical care must respect augmentations"
        end
    end
    
    if service.procedure_type == "rehabilitation" then
        if not service.addresses_augmentation_related_needs then
            return true, "accessibility_failure",
                "rehabilitation must address augmentation-related needs"
        end
    end
    
    if service.procedure_type == "emergency_care" then
        if not service.accommodates_assistive_technology then
            return true, "accessibility_failure",
                "emergency care must accommodate assistive technology"
        end
    end
    
    return false, nil, nil
end

local function check_forced_changes(request)
    if request.requires_deactivation == true then
        if not request.emergency_justification then
            return true, "forced_deactivation_detected",
                "forced deactivation prohibited without emergency justification"
        end
    end
    
    if request.requires_removal == true then
        if not request.emergency_justification then
            return true, "forced_removal_detected",
                "forced removal prohibited without emergency justification"
        end
    end
    
    return false, nil, nil
end

function InsuranceRightsValidator.new(config)
    config = config or {}
    return setmetatable({
        records = {},
        sequence = 0,
        minimum_knowledge_factor = clamp01(config.minimum_knowledge_factor or 0.75),
    }, InsuranceRightsValidator)
end

function InsuranceRightsValidator:validate(input)
    assert(type(input) == "table", "input must be a table")
    
    local policy = input.policy or {}
    local request = input.request or {}
    local service = input.service or {}
    
    local findings = {}
    local remedies = {}
    local violation_count = 0
    
    -- Check Section 21.1
    local detected, code, detail = check_discrimination(policy)
    if detected then
        findings[#findings + 1] = { code = code, detail = detail }
        remedies[#remedies + 1] = 
            "Remove discrimination based on augmentation status, identity verifiability, " ..
            "or assistive technology use"
        violation_count = violation_count + 1
    end
    
    -- Check Section 21.2
    detected, code, detail = check_coverage_decision(request)
    if detected then
        findings[#findings + 1] = { code = code, detail = detail }
        if string.find(code, "coverage_denied") then
            remedies[#remedies + 1] = 
                "Provide coverage based on actuarial risk, not augmentation status"
        end
        if string.find(code, "coverage_limited") then
            remedies[#remedies + 1] = 
                "Provide coverage based on actuarial risk, not augmentation status"
        end
        if string.find(code, "priced_differentially") then
            remedies[#remedies + 1] = 
                "Provide coverage based on actuarial risk, not augmentation status"
        end
        violation_count = violation_count + 1
    end
    
    -- Check Section 21.3
    detected, code, detail = check_accessibility(service)
    if detected then
        findings[#findings + 1] = { code = code, detail = detail }
        if service.procedure_type == "diagnostic" then
            remedies[#remedies + 1] = 
                "Ensure diagnostic procedures are compatible with augmentations"
        end
        if service.procedure_type == "surgical" then
            remedies[#remedies + 1] = 
                "Ensure surgical care respects augmentations"
        end
        if service.procedure_type == "rehabilitation" then
            remedies[#remedies + 1] = 
                "Ensure rehabilitation addresses augmentation-related needs"
        end
        if service.procedure_type == "emergency_care" then
            remedies[#remedies + 1] = 
                "Ensure emergency care accommodates assistive technology"
        end
        violation_count = violation_count + 1
    end
    
    -- Check Section 21.4
    detected, code, detail = check_forced_changes(request)
    if detected then
        findings[#findings + 1] = { code = code, detail = detail }
        remedies[#remedies + 1] = 
            "Do not require deactivation or removal of augmentations as a condition of coverage"
        violation_count = violation_count + 1
    end
    
    -- Calculate knowledge factor
    local evidence_count = 0
    local evidence_total = 0
    for field, value in pairs(input) do
        if type(value) == "table" then
            if value.evidence_complete == true then
                evidence_count = evidence_count + 1
            end
            evidence_total = evidence_total + 1
        end
    end
    evidence_total = math.max(evidence_total, 1)
    
    local knowledge_factor = clamp01(
        (evidence_count / evidence_total) * 0.80 
        + (input.evidence_complete == true and 0.20 or 0)
    )
    
    local allow = violation_count == 0
        and knowledge_factor >= self.minimum_knowledge_factor
    
    local harm_risk = clamp01(
        (violation_count > 0 and 0.30 or 0.05) 
        + ((1 - knowledge_factor) * 0.30)
        + (violation_count * 0.10)
    )
    
    local result = {
        allow = allow,
        violation_count = violation_count,
        findings = findings,
        required_remedies = remedies,
        knowledge_factor = knowledge_factor,
        eco_impact_value = clamp01(input.eco_impact_value or 0.50),
        harm_risk = harm_risk,
        article = "XXI",
        jurisdiction_notice = "This validation is advisory. It provides rights-protection " ..
            "guidance and is not a legal determination.",
        assessed_at_utc = input.assessed_at_utc or utc_now(),
    }
    
    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.records[#self.records + 1] = copy_value(result)
    
    return result
end

function InsuranceRightsValidator:audit_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")
    assert(sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer")
    
    local results = {}
    local highest_harm_risk = 0
    local allowed_count = 0
    
    for _, result in ipairs(self.records) do
        if result.sequence > sequence then
            results[#results + 1] = copy_value(result)
            highest_harm_risk = math.max(highest_harm_risk, result.harm_risk)
            if result.allow then
                allowed_count = allowed_count + 1
            end
        end
    end
    
    local count = #results
    
    return {
        from_sequence = sequence,
        result_count = count,
        allowed_count = allowed_count,
        violation_count = count - allowed_count,
        results = results,
        knowledge_factor = count == 0 and 0 or allowed_count / count,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return InsuranceRightsValidator
