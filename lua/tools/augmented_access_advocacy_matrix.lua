-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/augmented_access_advocacy_matrix.lua
-- Destination: lua/tools/

local AugmentedAccessAdvocacyMatrix = {}
AugmentedAccessAdvocacyMatrix.__index = AugmentedAccessAdvocacyMatrix

local frameworks = {
    ada_title_ii = {
        label = "ADA Title II",
        scope = "State and local government programs, services, activities, and covered digital access obligations.",
        supports = {
            "effective_communication",
            "reasonable_modification",
            "accessible_grievance_path",
            "equal_public_service_access",
        },
        limitation = "Applicability, requested modifications, undue burden, fundamental alteration, and effective communication are fact-specific legal questions.",
    },
    ada_title_iii = {
        label = "ADA Title III",
        scope = "Public accommodations operated by private entities.",
        supports = {
            "effective_communication",
            "reasonable_modification",
            "equal_public_accommodation_access",
        },
        limitation = "Coverage and accommodation duties depend on the entity, service, facts, and applicable regulations.",
    },
    rehabilitation_act_504 = {
        label = "Rehabilitation Act Section 504",
        scope = "Programs and activities receiving federal financial assistance.",
        supports = {
            "non_discrimination",
            "effective_communication",
            "reasonable_modification",
        },
        limitation = "Coverage depends on receipt of federal financial assistance and the program-specific legal context.",
    },
    rehabilitation_act_508 = {
        label = "Rehabilitation Act Section 508",
        scope = "Federal agency information and communication technology.",
        supports = {
            "federal_ict_accessibility",
            "assistive_technology_compatibility",
            "accessible_digital_participation",
        },
        limitation = "Section 508 generally governs federal agency ICT and has defined technical and procurement scope.",
    },
    equal_protection = {
        label = "Fourteenth Amendment Equal Protection",
        scope = "State action and governmental classifications.",
        supports = {
            "state_action_non_discrimination",
            "documented_non_arbitrary_decisionmaking",
        },
        limitation = "Augmentation status is not currently recognized by U.S. Supreme Court doctrine as a suspect or quasi-suspect classification.",
    },
    privacy_data_governance = {
        label = "Privacy and Data Governance",
        scope = "Applicable privacy, consumer-protection, health, biometric, contractual, and jurisdiction-specific rules.",
        supports = {
            "data_minimization",
            "purpose_limitation",
            "consent_control",
            "retention_control",
        },
        limitation = "The United States does not have a single comprehensive federal privacy law; legal protection varies by data type, actor, state, and contract.",
    },
    right_to_repair_policy = {
        label = "Right-to-Repair and Interoperability Policy",
        scope = "Consumer protection, competition, copyright exemptions, state repair laws, procurement, and accessibility advocacy.",
        supports = {
            "repair_access",
            "modification_advocacy",
            "interoperability_advocacy",
        },
        limitation = "Repair, warranty, safety, cybersecurity, device regulation, and contractual restrictions vary substantially by product and jurisdiction.",
    },
}

local requested_protections = {
    "accessible_digital_participation",
    "accessible_grievance_path",
    "assistive_technology_compatibility",
    "consent_control",
    "data_minimization",
    "effective_communication",
    "equal_public_accommodation_access",
    "equal_public_service_access",
    "federal_ict_accessibility",
    "identity_verifiability_neutrality",
    "interoperability_advocacy",
    "modification_advocacy",
    "neural_privacy",
    "offline_existence",
    "psychological_continuity",
    "repair_access",
    "reasonable_modification",
    "self_asserted_identity",
    "state_action_non_discrimination",
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
    assert(not seen[value], "cyclic advocacy records are not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function list_contains(values, target)
    for _, value in ipairs(values) do
        if value == target then
            return true
        end
    end

    return false
end

local function protection_is_known(protection)
    return list_contains(requested_protections, protection)
end

local function supporting_frameworks(protection)
    local results = {}

    for framework_id, framework in pairs(frameworks) do
        if list_contains(framework.supports, protection) then
            results[#results + 1] = {
                framework_id = framework_id,
                framework_label = framework.label,
                scope = framework.scope,
                limitation = framework.limitation,
            }
        end
    end

    table.sort(results, function(left, right)
        return left.framework_id < right.framework_id
    end)

    return results
end

function AugmentedAccessAdvocacyMatrix.new(config)
    config = config or {}

    return setmetatable({
        minimum_evidence_quality = clamp01(
            config.minimum_evidence_quality or 0.75
        ),
        assessments = {},
        sequence = 0,
    }, AugmentedAccessAdvocacyMatrix)
end

function AugmentedAccessAdvocacyMatrix:assess(request)
    assert(type(request) == "table", "request must be a table")

    local request_id = required_text(request.request_id, "request_id")
    local protections = request.protections or {}

    assert(type(protections) == "table", "protections must be a table")

    local evidence_quality = clamp01(request.evidence_quality or 0)
    local requested = {}
    local unknown = {}
    local mappings = {}
    local uncovered = {}

    for _, protection in ipairs(protections) do
        protection = required_text(protection, "protection")

        if protection_is_known(protection) then
            requested[#requested + 1] = protection

            local matches = supporting_frameworks(protection)

            mappings[protection] = matches

            if #matches == 0 then
                uncovered[#uncovered + 1] = protection
            end
        else
            unknown[#unknown + 1] = protection
        end
    end

    local policy_gaps = {}

    for _, protection in ipairs(requested) do
        if protection == "neural_privacy"
            or protection == "offline_existence"
            or protection == "psychological_continuity"
            or protection == "identity_verifiability_neutrality"
            or protection == "self_asserted_identity" then
            policy_gaps[#policy_gaps + 1] = {
                protection = protection,
                recommendation = "Treat as an explicit constitutional, statutory, procurement, privacy, or service-design advocacy objective; do not represent it as a settled universal legal entitlement.",
            }
        end
    end

    if request.claims_quasi_suspect_status == true then
        policy_gaps[#policy_gaps + 1] = {
            protection = "augmentation_status_heightened_scrutiny",
            recommendation = "Frame heightened scrutiny as a litigation and legislative advocacy position. Do not claim quasi-suspect status is established doctrine.",
        }
    end

    if request.requires_proof_of_augmentation == true then
        policy_gaps[#policy_gaps + 1] = {
            protection = "proof_of_augmentation",
            recommendation = "Remove unnecessary proof-of-augmentation requirements from ordinary access and accessibility processes.",
        }
    end

    local mapping_coverage = #requested == 0
        and 0
        or (#requested - #uncovered) / #requested

    local knowledge_factor = clamp01(
        mapping_coverage * 0.55
            + evidence_quality * 0.35
            + (request.jurisdiction_specified == true and 0.10 or 0)
    )

    local harm_risk = clamp01(
        (#unknown > 0 and 0.15 or 0)
            + ((1 - mapping_coverage) * 0.25)
            + ((evidence_quality < self.minimum_evidence_quality) and 0.15 or 0)
            + (request.requires_proof_of_augmentation == true and 0.25 or 0)
            + (request.denies_assistive_access == true and 0.30 or 0)
    )

    local result = {
        request_id = request_id,
        advisory_only = true,
        legal_notice = "This is an advocacy and policy-design mapping, not legal advice or a legal-compliance determination.",
        requested_protections = requested,
        framework_mappings = mappings,
        uncovered_protections = uncovered,
        unknown_protections = unknown,
        policy_gaps = policy_gaps,
        existing_framework_catalog = copy_value(frameworks),
        advocacy_ready = knowledge_factor >= self.minimum_evidence_quality
            and #unknown == 0,
        knowledge_factor = knowledge_factor,
        eco_impact_value = clamp01(request.eco_impact_value or 0.50),
        harm_risk = harm_risk,
        assessed_at_utc = request.assessed_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.assessments[#self.assessments + 1] = copy_value(result)

    return result
end

function AugmentedAccessAdvocacyMatrix:framework_catalog()
    return {
        frameworks = copy_value(frameworks),
        known_protections = copy_value(requested_protections),
        legal_notice = "Framework entries are policy-mapping aids and require qualified jurisdiction-specific legal review.",
        generated_at_utc = utc_now(),
    }
end

return AugmentedAccessAdvocacyMatrix
