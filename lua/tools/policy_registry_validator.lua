-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/policy_registry_validator.lua
-- Destination: lua/tools/

local Registry = {}

local REQUIRED_POLICY_CRITERIA = {
    "self_asserted_identity_inclusion",
    "no_third_party_certification_gate",
    "privacy_and_continuity_protection",
    "meaningful_social_impact",
    "equal_treatment_for_augmented_citizens",
}

local SMART_CITY_OBJECTS = {
    { id = "sc-001", name = "IdentityProtectionProfile", category = "identity-protection" },
    { id = "sc-002", name = "ExistenceValidator", category = "fairness-logic" },
    { id = "sc-003", name = "AcceptanceIndexCalculator", category = "social-acceptance" },
    { id = "sc-004", name = "NormDiffusionStrength", category = "social-acceptance" },
    { id = "sc-005", name = "PolarizationEntropy", category = "social-acceptance" },
    { id = "sc-006", name = "UrbanHeatIslandIntensity", category = "eco-restoration" },
    { id = "sc-007", name = "AlbedoRadiativeCooling", category = "eco-restoration" },
    { id = "sc-008", name = "EvapotranspirationCooling", category = "eco-restoration" },
    { id = "sc-009", name = "StormwaterRetention", category = "eco-restoration" },
    { id = "sc-010", name = "EquityWeightedEcoBenefit", category = "eco-restoration" },
    { id = "sc-011", name = "InterfaceEvidenceScorer", category = "cybernetic-compatibility" },
    { id = "sc-012", name = "ResourceAccountingLedger", category = "resource-accounting" },
    { id = "sc-013", name = "CorridorCalibrationModel", category = "sensor-calibration" },
    { id = "sc-014", name = "SensorAlignmentSolver", category = "sensor-alignment" },
    { id = "sc-015", name = "AutomationSafetyPFD", category = "automation-safety" },
    { id = "sc-016", name = "ElectronicConversionEfficiency", category = "power-electronics" },
    { id = "sc-017", name = "AutomaticDoorAccessibilityPolicy", category = "building-automation" },
    { id = "sc-018", name = "MaintenanceBotSurfaceAnomaly", category = "maintenance-bots" },
    { id = "sc-019", name = "GatheringHubInclusiveDesign", category = "community-space" },
    { id = "sc-020", name = "TransitSignalPriorityEquity", category = "transit-system" },
    { id = "sc-021", name = "AssistancePanelMultimodal", category = "assistance-panel" },
    { id = "sc-022", name = "HandicapPathMaintenanceUrgency", category = "accessibility-infrastructure" },
    { id = "sc-023", name = "CommunityAirQualitySensorFact", category = "environmental-sensor" },
    { id = "sc-024", name = "BusinessPlaceEcoFootprint", category = "commercial-sustainability" },
    { id = "sc-025", name = "WasteCollectionRouteOptimizer", category = "waste-management" },
    { id = "sc-026", name = "PublicLightingAdaptiveControl", category = "public-lighting" },
    { id = "sc-027", name = "WaterLeakDetectionFact", category = "water-system" },
    { id = "sc-028", name = "BiodiversityConnectivityIndex", category = "ecological-restoration" },
    { id = "sc-029", name = "TreeCanopyCoolingBenefit", category = "urban-forestry" },
    { id = "sc-030", name = "GreenRoofThermalMass", category = "building-retrofit" },
    { id = "sc-031", name = "PermeablePavementRunoff", category = "stormwater-management" },
    { id = "sc-032", name = "HeatExposureRiskByZone", category = "climate-adaptation" },
    { id = "sc-033", name = "SocialAcceptanceModel", category = "social-acceptance" },
    { id = "sc-034", name = "CyberneticHostCompatibilityChecklist", category = "cybernetic-compatibility" },
    { id = "sc-035", name = "EvidenceTagResolver", category = "evidence-provenance" },
    { id = "sc-036", name = "SoftBiointerfaceHydrogelSpec", category = "biointerface" },
    { id = "sc-037", name = "OrganicNeuromorphicDeviceSpec", category = "neuromorphic" },
    { id = "sc-038", name = "BiohybridSignalProcessingSpec", category = "signal-processing" },
    { id = "sc-039", name = "OtaResearchGateProposal", category = "research-governance" },
    { id = "sc-040", name = "ConsentBoundaryRegisters", category = "consent-governance" },
    { id = "sc-041", name = "AuthorshipLedgerEntry", category = "attribution" },
    { id = "sc-042", name = "RecoveryAccessTestRecord", category = "continuity" },
    { id = "sc-043", name = "ContinuityArchiveRecord", category = "continuity" },
    { id = "sc-044", name = "CyberRankTier2Status", category = "self-governed-status" },
    { id = "sc-045", name = "FairnessValidationRule", category = "fairness-validation" },
    { id = "sc-046", name = "PersonhoodExpressionRecord", category = "identity" },
    { id = "sc-047", name = "PrivacyDataMap", category = "privacy" },
    { id = "sc-048", name = "IncidentResponsePlan", category = "safety" },
    { id = "sc-049", name = "NonDiscriminatoryPolicyEvaluator", category = "policy-audit" },
    { id = "sc-050", name = "SmartCityObjectRegistry", category = "meta" },
}

local function require_table(value, name)
    assert(type(value) == "table", name .. " must be a table")
end

local function require_boolean(value, name)
    assert(type(value) == "boolean", name .. " must be a boolean")
end

local function copy_array(source)
    local result = {}

    for index, value in ipairs(source) do
        result[index] = value
    end

    return result
end

local function copy_object(object)
    return {
        id = object.id,
        name = object.name,
        category = object.category,
    }
end

local function evaluate_criterion_answers(answers)
    require_table(answers, "policy_answers")

    local satisfied_count = 0
    local missing_criteria = {}
    local criterion_results = {}

    for _, criterion in ipairs(REQUIRED_POLICY_CRITERIA) do
        local answer = answers[criterion]
        require_boolean(answer, "policy_answers." .. criterion)

        criterion_results[criterion] = answer

        if answer then
            satisfied_count = satisfied_count + 1
        else
            table.insert(missing_criteria, criterion)
        end
    end

    return criterion_results, satisfied_count, missing_criteria
end

--- SC-049: Evaluates a documented policy against the supplied anti-discrimination
--- criteria. This is a review aid only: it does not determine legality, identity
--- validity, service eligibility, access permissions, or a binding policy outcome.
---@param answers table
---@return table
function Registry.non_discriminatory_policy_evaluator(answers)
    local criterion_results, satisfied_count, missing_criteria =
        evaluate_criterion_answers(answers)

    local total_criteria = #REQUIRED_POLICY_CRITERIA
    local score = satisfied_count / total_criteria
    local review_required = satisfied_count < total_criteria

    return {
        object_id = "sc-049",
        name = "NonDiscriminatoryPolicyEvaluator",
        score = score,
        satisfied_criteria = satisfied_count,
        total_criteria = total_criteria,
        criterion_results = criterion_results,
        missing_criteria = missing_criteria,
        review_required = review_required,
        criteria = copy_array(REQUIRED_POLICY_CRITERIA),
        knowledge_factor = 0.65,
        eco_impact_value = 0.0,
        harm_risk = 1.0 - score,
        authority_effect = "none",
        interpretation =
            "Structured policy-review checklist only. A score does not establish legal compliance, "
            .. "prove equal outcomes, validate an identity claim, grant access, or replace an "
            .. "independent accessibility, civil-rights, privacy, or legal review.",
    }
end

--- SC-050: Returns the stable registry identifiers in ascending numeric order.
---@return table
function Registry.list_ids()
    local ids = {}

    for index, object in ipairs(SMART_CITY_OBJECTS) do
        ids[index] = object.id
    end

    return ids
end

--- SC-050: Returns registered object names in stable registry order.
---@return table
function Registry.list_names()
    local names = {}

    for index, object in ipairs(SMART_CITY_OBJECTS) do
        names[index] = object.name
    end

    return names
end

--- SC-050: Returns unique categories sorted lexicographically for deterministic
--- reporting and reproducible local integrations.
---@return table
function Registry.categories()
    local seen = {}
    local categories = {}

    for _, object in ipairs(SMART_CITY_OBJECTS) do
        if not seen[object.category] then
            seen[object.category] = true
            table.insert(categories, object.category)
        end
    end

    table.sort(categories)
    return categories
end

--- SC-050: Returns an independent copy of a registered object descriptor.
---@param object_id string
---@return table|nil
function Registry.find_by_id(object_id)
    assert(type(object_id) == "string" and object_id ~= "", "object_id must be a non-empty string")

    for _, object in ipairs(SMART_CITY_OBJECTS) do
        if object.id == object_id then
            return copy_object(object)
        end
    end

    return nil
end

--- SC-050: Validates registry ordering, count, identifier uniqueness, and
--- required descriptor fields. This is a local metadata check only.
---@return table
function Registry.validate()
    local seen_ids = {}
    local seen_names = {}
    local expected_number = 1

    for _, object in ipairs(SMART_CITY_OBJECTS) do
        assert(type(object.id) == "string", "registry object id must be a string")
        assert(type(object.name) == "string", "registry object name must be a string")
        assert(type(object.category) == "string", "registry object category must be a string")
        assert(not seen_ids[object.id], "duplicate registry object id: " .. object.id)
        assert(not seen_names[object.name], "duplicate registry object name: " .. object.name)

        local object_number = tonumber(object.id:match("^sc%-(%d%d%d)$"))

        assert(
            object_number == expected_number,
            "registry IDs must be contiguous and ordered from sc-001 through sc-050"
        )

        seen_ids[object.id] = true
        seen_names[object.name] = true
        expected_number = expected_number + 1
    end

    assert(#SMART_CITY_OBJECTS == 50, "registry must contain exactly 50 objects")

    return {
        object_id = "sc-050",
        name = "SmartCityObjectRegistry",
        valid = true,
        object_count = #SMART_CITY_OBJECTS,
        ids = Registry.list_ids(),
        names = Registry.list_names(),
        categories = Registry.categories(),
        knowledge_factor = 1.0,
        eco_impact_value = 0.0,
        harm_risk = 0.0,
        authority_effect = "none",
        interpretation =
            "Local registry validation only. Registry membership does not make an object "
            .. "independently verified, authorized, legally valid, deployed, or appropriate "
            .. "for a specific public-service decision.",
    }
end

return Registry
