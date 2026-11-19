-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/neuromorphic_biohybrid_ota_governance.lua
-- Destination: lua/tools/

local Governance = {}

local ORGANIC_NEUROMORPHIC_REQUIRED_TAGS = {
    "0xD4F09A",
    "0xE16C82",
}

local BIOHYBRID_REQUIREMENTS = {
    "soft_conformal_hydrated_chemically_stable_material",
    "externally_verifiable_measurement",
    "clinical_oversight",
}

local BIOHYBRID_BOTTLENECKS = {
    "inflammatory_response",
    "signal_stability",
    "encapsulation",
    "adhesion",
    "impedance_drift",
}

local OTA_REQUIRED_FIELDS = {
    "signed_artifact_manifest",
    "version_identifier",
    "dependency_inventory",
    "test_evidence",
    "reproducible_build_record",
    "validated_software_function_declaration",
    "material_interface_evidence_package",
    "separate_resource_ledgers",
    "human_authorization",
    "regulatory_review_status",
    "incident_response_plan",
    "independent_bmv_review",
}

local function is_finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local function require_table(value, name)
    assert(type(value) == "table", name .. " must be a table")
end

local function require_string(value, name)
    assert(type(value) == "string" and value ~= "", name .. " must be a non-empty string")
end

local function require_boolean(value, name)
    assert(type(value) == "boolean", name .. " must be a boolean")
end

local function require_finite(value, name)
    assert(is_finite_number(value), name .. " must be a finite number")
end

local function require_nonnegative(value, name)
    require_finite(value, name)
    assert(value >= 0, name .. " must be non-negative")
end

local function require_positive(value, name)
    require_finite(value, name)
    assert(value > 0, name .. " must be greater than zero")
end

local function require_unit_interval(value, name)
    require_finite(value, name)
    assert(value >= 0 and value <= 1, name .. " must be within [0, 1]")
end

local function copy_array(source)
    local result = {}

    for index, value in ipairs(source) do
        result[index] = value
    end

    return result
end

local function contains_nonempty_value(value)
    if type(value) == "string" then
        return value ~= ""
    end

    if type(value) == "table" then
        return next(value) ~= nil
    end

    return value ~= nil and value ~= false
end

local function tag_set(tags)
    require_table(tags, "evidence_tags")

    local result = {}

    for index, tag in ipairs(tags) do
        require_string(tag, "evidence_tags[" .. index .. "]")
        result[tag] = true
    end

    return result
end

local function missing_items(required, supplied)
    local missing = {}

    for _, item in ipairs(required) do
        if not supplied[item] then
            table.insert(missing, item)
        end
    end

    return missing
end

local function present_requirement_set(requirements)
    require_table(requirements, "requirements")

    local present = {}

    for key, value in pairs(requirements) do
        if contains_nonempty_value(value) then
            present[key] = true
        end
    end

    return present
end

--- SC-037: Validates a material/device evidence record for an organic
--- electrochemical resistive-switching device. This is a research-record
--- evaluator only; it does not claim biological safety, conduct experiments,
--- modify devices, or control external equipment.
---@param specification table
---@return table
function Governance.organic_neuromorphic_device_spec(specification)
    require_table(specification, "organic_neuromorphic_device_spec")

    local switching_voltage_v = specification.switching_voltage_v
    local on_off_ratio = specification.on_off_ratio
    local endurance_cycles = specification.endurance_cycles
    local state_retention_s = specification.state_retention_s
    local electrolyte_compatibility = specification.electrolyte_compatibility

    require_nonnegative(
        switching_voltage_v,
        "organic_neuromorphic_device_spec.switching_voltage_v"
    )
    require_positive(
        on_off_ratio,
        "organic_neuromorphic_device_spec.on_off_ratio"
    )
    require_nonnegative(
        endurance_cycles,
        "organic_neuromorphic_device_spec.endurance_cycles"
    )
    require_nonnegative(
        state_retention_s,
        "organic_neuromorphic_device_spec.state_retention_s"
    )
    require_boolean(
        electrolyte_compatibility,
        "organic_neuromorphic_device_spec.electrolyte_compatibility"
    )

    local supplied_tags = tag_set(specification.evidence_tags or {})
    local missing_evidence_tags = missing_items(
        ORGANIC_NEUROMORPHIC_REQUIRED_TAGS,
        supplied_tags
    )
    local evidence_complete = #missing_evidence_tags == 0

    local performance_completeness = 1.0
    local evidence_completeness =
        (#ORGANIC_NEUROMORPHIC_REQUIRED_TAGS - #missing_evidence_tags)
        / #ORGANIC_NEUROMORPHIC_REQUIRED_TAGS

    local low_power_indicator = clamp(
        1.0 - switching_voltage_v / 5.0,
        0.0,
        1.0
    )

    local record_completeness =
        performance_completeness * 0.55
        + evidence_completeness * 0.45

    return {
        object_id = "sc-037",
        name = "OrganicNeuromorphicDeviceSpec",
        valid = true,
        properties = {
            switching_voltage_v = switching_voltage_v,
            on_off_ratio = on_off_ratio,
            endurance_cycles = endurance_cycles,
            state_retention_s = state_retention_s,
            electrolyte_compatibility = electrolyte_compatibility,
        },
        required_evidence_tags = copy_array(ORGANIC_NEUROMORPHIC_REQUIRED_TAGS),
        missing_evidence_tags = missing_evidence_tags,
        evidence_complete = evidence_complete,
        low_power_indicator = low_power_indicator,
        units = {
            switching_voltage_v = "V",
            on_off_ratio = "dimensionless ratio",
            endurance_cycles = "cycles",
            state_retention_s = "s",
        },
        knowledge_factor = record_completeness,
        eco_impact_value = low_power_indicator,
        harm_risk = clamp(
            (electrolyte_compatibility and 0.0 or 0.40)
                + (1.0 - evidence_completeness) * 0.40
                + (1.0 - low_power_indicator) * 0.20,
            0.0,
            1.0
        ),
        authority_effect = "none",
        interpretation =
            "Device-specification completeness result only. Electrolyte compatibility and "
            .. "evidence tags do not establish biocompatibility, long-term stability, clinical safety, "
            .. "or suitability for use with people or animals.",
    }
end

--- SC-038: Evaluates whether a biohybrid research record documents the stated
--- material, measurement, and clinical-oversight requirements, while tracking
--- explicitly assessed bottlenecks. It is not a clinical evaluator and cannot
--- make treatment, deployment, or access decisions.
---@param record table
---@return table
function Governance.biohybrid_signal_processing_spec(record)
    require_table(record, "biohybrid_signal_processing_record")

    local requirements = present_requirement_set(record.requirements or {})
    local bottlenecks = record.bottlenecks or {}

    require_table(bottlenecks, "biohybrid_signal_processing_record.bottlenecks")

    local missing_requirements = missing_items(BIOHYBRID_REQUIREMENTS, requirements)
    local documented_bottlenecks = {}
    local unassessed_bottlenecks = {}

    for _, bottleneck in ipairs(BIOHYBRID_BOTTLENECKS) do
        local assessed = bottlenecks[bottleneck] == true

        if assessed then
            table.insert(documented_bottlenecks, bottleneck)
        else
            table.insert(unassessed_bottlenecks, bottleneck)
        end
    end

    local requirement_coverage =
        (#BIOHYBRID_REQUIREMENTS - #missing_requirements)
        / #BIOHYBRID_REQUIREMENTS

    local bottleneck_coverage =
        #documented_bottlenecks / #BIOHYBRID_BOTTLENECKS

    local record_complete =
        #missing_requirements == 0
        and #unassessed_bottlenecks == 0

    return {
        object_id = "sc-038",
        name = "BiohybridSignalProcessingSpec",
        record_complete = record_complete,
        requirement_coverage = requirement_coverage,
        bottleneck_coverage = bottleneck_coverage,
        documented_requirements = requirements,
        missing_requirements = missing_requirements,
        documented_bottlenecks = documented_bottlenecks,
        unassessed_bottlenecks = unassessed_bottlenecks,
        knowledge_factor =
            requirement_coverage * 0.60 + bottleneck_coverage * 0.40,
        eco_impact_value = 0.0,
        harm_risk = clamp(
            (1.0 - requirement_coverage) * 0.60
                + (1.0 - bottleneck_coverage) * 0.40,
            0.0,
            1.0
        ),
        authority_effect = "none",
        interpretation =
            "Documentation-completeness assessment only. It cannot establish reduced interface burden, "
            .. "biological compatibility, clinical benefit, clinical safety, or readiness for use.",
    }
end

--- SC-039: Checks whether an OTA research proposal contains the documentation
--- and independent-review conditions required for research-queue review.
--- Acceptance means documentation-complete for human review only; this utility
--- never deploys an update, contacts devices, changes software, or replaces
--- external authorization and regulatory processes.
---@param proposal table
---@return table
function Governance.ota_research_gate_proposal(proposal)
    require_table(proposal, "ota_research_proposal")

    local supplied_fields = present_requirement_set(proposal)
    local missing_fields = missing_items(OTA_REQUIRED_FIELDS, supplied_fields)

    local resource_ledgers = proposal.separate_resource_ledgers
    local independent_bmv_review = proposal.independent_bmv_review
    local human_authorization = proposal.human_authorization

    require_table(resource_ledgers, "ota_research_proposal.separate_resource_ledgers")
    require_table(independent_bmv_review, "ota_research_proposal.independent_bmv_review")
    require_table(human_authorization, "ota_research_proposal.human_authorization")

    local ledgers_separated =
        resource_ledgers.ota_compute ~= nil
        and resource_ledgers.lab_energy ~= nil
        and resource_ledgers.physiological_observations ~= nil

    local b_score = independent_bmv_review.biological_evidence
    local m_score = independent_bmv_review.mechanical_compatibility
    local v_score = independent_bmv_review.verification_quality

    require_unit_interval(
        b_score,
        "ota_research_proposal.independent_bmv_review.biological_evidence"
    )
    require_unit_interval(
        m_score,
        "ota_research_proposal.independent_bmv_review.mechanical_compatibility"
    )
    require_unit_interval(
        v_score,
        "ota_research_proposal.independent_bmv_review.verification_quality"
    )

    local authorization_recorded =
        contains_nonempty_value(human_authorization.authorization_id)
        and contains_nonempty_value(human_authorization.authorized_at)
        and human_authorization.approved == true

    local documentation_complete = #missing_fields == 0
    local eligible_for_human_queue_review =
        documentation_complete
        and ledgers_separated
        and authorization_recorded

    local additional_gaps = {}

    if not ledgers_separated then
        table.insert(additional_gaps, "separate_resource_ledgers_incomplete")
    end

    if not authorization_recorded then
        table.insert(additional_gaps, "human_authorization_incomplete")
    end

    return {
        object_id = "sc-039",
        name = "OtaResearchGateProposal",
        eligible_for_human_queue_review = eligible_for_human_queue_review,
        documentation_complete = documentation_complete,
        missing_required_fields = missing_fields,
        additional_gaps = additional_gaps,
        independent_review_scores = {
            biological_evidence = b_score,
            mechanical_compatibility = m_score,
            verification_quality = v_score,
        },
        non_convertibility_invariant =
            "OTA compute, laboratory energy, and physiological observations are separate non-convertible ledger classes.",
        authority_effect = "none",
        knowledge_factor = clamp(
            ((#OTA_REQUIRED_FIELDS - #missing_fields) / #OTA_REQUIRED_FIELDS) * 0.70
                + (ledgers_separated and 0.15 or 0.0)
                + (authorization_recorded and 0.15 or 0.0),
            0.0,
            1.0
        ),
        eco_impact_value = 0.0,
        harm_risk = clamp(
            (#missing_fields / #OTA_REQUIRED_FIELDS) * 0.60
                + (ledgers_separated and 0.0 or 0.20)
                + (authorization_recorded and 0.0 or 0.20),
            0.0,
            1.0
        ),
        interpretation =
            "Research-queue documentation gate only. A passing result does not authorize, "
            .. "schedule, transmit, install, apply, or validate any update, and it does not "
            .. "supersede human authorization, regulatory review, or independent technical review.",
    }
end

return Governance
