-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/augmented_rights_doctrinal_mapper.lua
-- Destination: lua/tools/

local AugmentedRightsDoctrinalMapper = {}
AugmentedRightsDoctrinalMapper.__index = AugmentedRightsDoctrinalMapper

local doctrines = {
    {
        id = "bodily_and_cognitive_autonomy",
        rights = {
            "augmentation_pursuit",
            "cognitive_liberty",
            "neural_privacy",
        },
        foundation = {
            "Fourteenth Amendment liberty interests",
            "Ninth Amendment retained-rights principle",
            "State constitutional, statutory, professional, and consent-law protections where applicable",
        },
        implementation = {
            "Do not condition ordinary access on rejecting lawful assistive or augmentation choices.",
            "Require explicit, revocable consent for optional neural, biometric, or device-data processing.",
            "Treat cognitive and neural data as highly sensitive personal data.",
        },
        limitation = "This module is an advocacy and policy-mapping tool. It does not determine constitutional doctrine, legality, medical safety, or eligibility.",
    },
    {
        id = "privacy_and_data_sovereignty",
        rights = {
            "neural_privacy",
            "data_ownership_and_control",
            "offline_existence",
        },
        foundation = {
            "Fourth Amendment privacy principles",
            "State privacy law and applicable sectoral privacy rules",
            "GDPR-style purpose limitation, data minimization, transparency, and revocable control where applicable",
        },
        implementation = {
            "Minimize direct identifiers, biometrics, neural signals, telemetry, and precise location.",
            "Provide a local-only or offline mode for essential access where technically feasible.",
            "Provide an accessible deletion, retention, and sharing-control path.",
        },
        limitation = "Ownership, deletion, and portability rights vary by jurisdiction, contract, data category, and service role.",
    },
    {
        id = "accessible_equal_participation",
        rights = {
            "assistive_technology_as_necessity",
            "interoperability",
            "democratic_participation",
            "equal_access",
        },
        foundation = {
            "ADA Titles II and III where applicable",
            "Fourteenth Amendment equal-protection principles",
            "Effective communication and reasonable-modification requirements",
        },
        implementation = {
            "Treat declared assistive technology as necessary for equal access.",
            "Provide effective communication and an equivalent fallback modality.",
            "Avoid text-only, device-specific, or certification-gated civic participation paths.",
        },
        limitation = "A legal accommodation analysis depends on the covered entity, program, requested modification, and facts of the case.",
    },
    {
        id = "continuity_and_identity_integrity",
        rights = {
            "psychological_continuity",
            "identity_integrity",
            "self_asserted_identity",
        },
        foundation = {
            "Due-process and equal-treatment principles",
            "Privacy, data-protection, and accessibility obligations where applicable",
            "Contractual and public-service continuity commitments",
        },
        implementation = {
            "Do not treat an interface, device, or accessibility configuration change as identity failure.",
            "Preserve authorized task context and preferences through supported transitions.",
            "Accept self-asserted identity for ordinary service interactions without unnecessary third-party certification.",
        },
        limitation = "This policy cannot establish legal identity, defeat legally required identity checks, or resolve disputes over third-party records.",
    },
    {
        id = "repair_modification_and_interoperability",
        rights = {
            "right_to_repair",
            "right_to_modify",
            "interoperability",
        },
        foundation = {
            "Consumer-protection and competition policy",
            "Repair exemptions and jurisdiction-specific repair statutes",
            "Accessibility and equal-participation objectives",
        },
        implementation = {
            "Support documented repair, maintenance, compatibility, and safe user-controlled configuration pathways.",
            "Do not use unnecessary repair restrictions to block essential assistive access.",
            "Provide open, documented local interfaces where feasible and safe.",
        },
        limitation = "Repair, modification, warranty, safety, and security obligations vary by device, manufacturer agreement, medical regulation, and jurisdiction.",
    },
    {
        id = "non_discrimination_and_equal_protection",
        rights = {
            "non_discrimination",
            "augmentation_status_neutrality",
            "identity_verifiability_neutrality",
        },
        foundation = {
            "Fourteenth Amendment Equal Protection Clause",
            "ADA statutory protections where disability-related barriers apply",
            "Civil-rights, consumer-protection, and public-accommodation laws where applicable",
        },
        implementation = {
            "Do not reduce ordinary access because of augmentation status or assistive use.",
            "Do not use unverifiable identity status as a proxy for untrustworthiness or exclusion.",
            "Require documented, evidence-based reasons for material adverse decisions and provide accessible review.",
        },
        limitation = "Augmentation status is not currently a recognized suspect or quasi-suspect classification under U.S. Supreme Court doctrine; this module identifies an advocacy position rather than a settled rule.",
    },
}

local required_rights = {
    "assistive_technology_as_necessity",
    "augmentation_status_neutrality",
    "cognitive_liberty",
    "data_ownership_and_control",
    "democratic_participation",
    "equal_access",
    "identity_integrity",
    "interoperability",
    "neural_privacy",
    "offline_existence",
    "psychological_continuity",
    "right_to_modify",
    "right_to_repair",
    "self_asserted_identity",
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
    assert(not seen[value], "cyclic mapping values are not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function contains(list, target)
    for _, item in ipairs(list) do
        if item == target then
            return true
        end
    end

    return false
end

function AugmentedRightsDoctrinalMapper.new(config)
    config = config or {}

    return setmetatable({
        minimum_evidence_factor = clamp01(
            config.minimum_evidence_factor or 0.75
        ),
        assessments = {},
        sequence = 0,
    }, AugmentedRightsDoctrinalMapper)
end

function AugmentedRightsDoctrinalMapper:map(policy)
    assert(type(policy) == "table", "policy must be a table")

    local policy_id = required_text(policy.policy_id, "policy_id")
    local declared_rights = policy.rights or {}
    local evidence = policy.evidence or {}

    assert(type(declared_rights) == "table", "policy.rights must be a table")
    assert(type(evidence) == "table", "policy.evidence must be a table")

    local right_status = {}
    local missing_rights = {}
    local evidence_count = 0

    for _, right in ipairs(required_rights) do
        local declared = declared_rights[right] == true
        local supported = evidence[right] == true

        right_status[right] = {
            declared = declared,
            evidence_complete = supported,
        }

        if not declared then
            missing_rights[#missing_rights + 1] = right
        end

        if supported then
            evidence_count = evidence_count + 1
        end
    end

    local doctrine_results = {}
    local remedies = {}
    local doctrine_count = 0
    local doctrine_supported_count = 0

    for _, doctrine in ipairs(doctrines) do
        doctrine_count = doctrine_count + 1
        local doctrine_supported = true

        for _, right in ipairs(doctrine.rights) do
            local status = right_status[right]

            if not status or not status.declared or not status.evidence_complete then
                doctrine_supported = false
                break
            end
        end

        doctrine_results[doctrine.id] = {
            supported = doctrine_supported,
            foundation = copy_value(doctrine.foundation),
            implementation = copy_value(doctrine.implementation),
            limitation = doctrine.limitation,
        }

        if doctrine_supported then
            doctrine_supported_count = doctrine_supported_count + 1
        else
            for _, implementation in ipairs(doctrine.implementation) do
                remedies[#remedies + 1] = implementation
            end
        end
    end

    local evidence_factor = evidence_count / #required_rights
    local doctrine_factor = doctrine_supported_count / doctrine_count
    local knowledge_factor = clamp01(
        evidence_factor * 0.60
            + doctrine_factor * 0.30
            + (policy.evidence_complete == true and 0.10 or 0)
    )

    local harm_risk = clamp01(
        (1 - evidence_factor) * 0.35
            + (1 - doctrine_factor) * 0.30
            + (policy.collects_raw_neural_signals == true and 0.25 or 0)
            + (policy.denies_access_for_augmentation_status == true and 0.25 or 0)
            + (policy.requires_proof_of_augmentation == true and 0.20 or 0)
    )

    local result = {
        policy_id = policy_id,
        advisory_only = true,
        legal_notice = "This is a rights-advocacy and technical-policy mapping, not legal advice or a legal conclusion.",
        doctrinal_continuity_strategy = true,
        strategic_innovation_strategy = true,
        right_status = right_status,
        doctrine_results = doctrine_results,
        missing_rights = missing_rights,
        recommended_policy_actions = remedies,
        evidence_factor = evidence_factor,
        doctrine_factor = doctrine_factor,
        ready_for_advocacy_review =
            knowledge_factor >= self.minimum_evidence_factor,
        knowledge_factor = knowledge_factor,
        eco_impact_value = clamp01(policy.eco_impact_value or 0.50),
        harm_risk = harm_risk,
        assessed_at_utc = policy.assessed_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.assessments[#self.assessments + 1] = copy_value(result)

    return result
end

function AugmentedRightsDoctrinalMapper:catalog()
    return {
        advisory_only = true,
        doctrines = copy_value(doctrines),
        required_rights = copy_value(required_rights),
        generated_at_utc = utc_now(),
    }
end

return AugmentedRightsDoctrinalMapper
