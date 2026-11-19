-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/biointerface_evidence_registry.lua
-- Destination: lua/tools/

local BiointerfaceEvidenceRegistry = {}

local COMPATIBILITY_LAYERS = {
    {
        id = "tissue_contact",
        name = "Tissue contact",
        properties = {
            "surface_energy",
            "porosity",
            "hydration",
            "roughness",
        },
        required_tags = {
            "0xA17C4E",
        },
    },
    {
        id = "mechanical_match",
        name = "Mechanical match",
        properties = {
            "elastic_modulus",
            "viscoelasticity",
            "strain",
            "fatigue",
        },
        required_tags = {
            "0xB29D1F",
        },
    },
    {
        id = "ionic_transport",
        name = "Ionic transport",
        properties = {
            "ionic_conductivity",
            "diffusion",
            "swelling",
            "charge_transfer",
        },
        required_tags = {
            "0xC83A7B",
        },
    },
    {
        id = "electronic_function",
        name = "Electronic function",
        properties = {
            "impedance",
            "capacitance",
            "noise_floor",
            "switching_stability",
        },
        required_tags = {
            "0xD4F09A",
        },
    },
    {
        id = "biological_response",
        name = "Biological response",
        properties = {
            "cytotoxicity",
            "immune_activation",
            "fibrosis",
            "biodegradation",
            "clearance",
        },
        required_tags = {
            "0xA17C4E",
            "0xF72B3D",
            "0x19AE64",
        },
    },
}

local EVIDENCE_TAGS = {
    ["0xA17C4E"] = "Cytotoxicity and viability assay record",
    ["0xB29D1F"] = "Mechanical-modulus and strain-match record",
    ["0xC83A7B"] = "Ionic-conductivity and swelling record",
    ["0xD4F09A"] = "Impedance and signal-stability record",
    ["0xE16C82"] = "Encapsulation and chemical-stability record",
    ["0xF72B3D"] = "Immune-response and fibrosis record",
    ["0x19AE64"] = "Degradation and clearance record",
    ["0x2C5F91"] = "Thermal exposure record",
    ["0x3D8A20"] = "Reproducibility and provenance record",
    ["0x4E71BC"] = "Independent replication record",
}

local HYDROGEL_REQUIRED_TAGS = {
    "0xA17C4E",
    "0xB29D1F",
    "0xC83A7B",
    "0xD4F09A",
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

local function shallow_copy(source)
    local result = {}

    for key, value in pairs(source) do
        result[key] = value
    end

    return result
end

local function copy_array(source)
    local result = {}

    for index, value in ipairs(source) do
        result[index] = value
    end

    return result
end

local function tags_to_set(tags)
    require_table(tags, "evidence_tags")

    local result = {}

    for index, tag in ipairs(tags) do
        require_string(tag, "evidence_tags[" .. index .. "]")
        result[tag] = true
    end

    return result
end

local function missing_tags(required_tags, supplied_tag_set)
    local missing = {}

    for _, tag in ipairs(required_tags) do
        if not supplied_tag_set[tag] then
            table.insert(missing, tag)
        end
    end

    return missing
end

--- SC-034: Evaluates completeness of a documented interface-evidence checklist.
--- Values represent the presence of structured evidence records, not a medical,
--- engineering, legal, or deployment authorization.
---@param checklist table
---@return table
function BiointerfaceEvidenceRegistry.cybernetic_host_compatibility_checklist(checklist)
    require_table(checklist, "compatibility_checklist")

    local supplied_tags = tags_to_set(checklist.evidence_tags or {})
    local documented_layers = checklist.documented_layers or {}
    require_table(documented_layers, "compatibility_checklist.documented_layers")

    local layer_results = {}
    local missing_evidence_tags = {}
    local complete_layer_count = 0

    for _, layer in ipairs(COMPATIBILITY_LAYERS) do
        local layer_documented = documented_layers[layer.id] == true
        local missing_for_layer = missing_tags(layer.required_tags, supplied_tags)
        local evidence_complete = #missing_for_layer == 0
        local layer_complete = layer_documented and evidence_complete

        if layer_complete then
            complete_layer_count = complete_layer_count + 1
        end

        for _, tag in ipairs(missing_for_layer) do
            missing_evidence_tags[tag] = true
        end

        layer_results[layer.id] = {
            name = layer.name,
            documented = layer_documented,
            evidence_complete = evidence_complete,
            complete = layer_complete,
            properties = copy_array(layer.properties),
            required_tags = copy_array(layer.required_tags),
            missing_tags = missing_for_layer,
        }
    end

    local missing_tags_list = {}

    for tag, _ in pairs(missing_evidence_tags) do
        table.insert(missing_tags_list, tag)
    end

    table.sort(missing_tags_list)

    local completeness = complete_layer_count / #COMPATIBILITY_LAYERS

    return {
        object_id = "sc-034",
        name = "CyberneticHostCompatibilityChecklist",
        layer_completeness = completeness,
        complete_layer_count = complete_layer_count,
        total_layer_count = #COMPATIBILITY_LAYERS,
        layers = layer_results,
        supplied_evidence_tags = shallow_copy(supplied_tags),
        missing_evidence_tags = missing_tags_list,
        knowledge_factor = completeness,
        eco_impact_value = 0.0,
        harm_risk = clamp(1.0 - completeness, 0.0, 1.0),
        authority_effect = "none",
        interpretation =
            "Evidence-completeness checklist only. Completion does not demonstrate clinical safety, "
            .. "device effectiveness, personal compatibility, certification, or permission for real-world use.",
    }
end

--- SC-035: Resolves a predefined evidence tag to a human-readable record class.
--- The resolver intentionally does not fabricate a protocol, raw-data URI,
--- sample identifier, participant data, or experimental result.
---@param tag string
---@return table
function BiointerfaceEvidenceRegistry.evidence_tag_resolver(tag)
    require_string(tag, "tag")

    local description = EVIDENCE_TAGS[tag]
    local known = description ~= nil

    return {
        object_id = "sc-035",
        name = "EvidenceTagResolver",
        tag = tag,
        known = known,
        description = description or "Unknown evidence tag",
        protocol_reference = nil,
        raw_data_location = nil,
        knowledge_factor = known and 0.50 or 0.0,
        eco_impact_value = 0.0,
        harm_risk = known and 0.0 or 0.20,
        authority_effect = "none",
        interpretation =
            "Tag-class lookup only. Bind protocol identifiers, data locations, data governance, "
            .. "and reviewer records externally through an approved provenance registry.",
    }
end

--- SC-036: Validates a hydrogel material-specification record and checks that
--- the required evidence classes are present. Values must be measured with
--- documented methods; this utility does not infer biocompatibility from material
--- properties alone.
---@param specification table
---@return table
function BiointerfaceEvidenceRegistry.soft_biointerface_hydrogel_spec(specification)
    require_table(specification, "hydrogel_specification")

    local elastic_modulus_kpa = specification.elastic_modulus_kpa
    local swelling_ratio = specification.swelling_ratio
    local ionic_conductivity_s_cm = specification.ionic_conductivity_s_cm
    local adhesion_energy_j_m2 = specification.adhesion_energy_j_m2
    local fatigue_life_cycles = specification.fatigue_life_cycles
    local cell_viability_fraction = specification.cell_viability_fraction

    require_positive(
        elastic_modulus_kpa,
        "hydrogel_specification.elastic_modulus_kpa"
    )
    require_nonnegative(
        swelling_ratio,
        "hydrogel_specification.swelling_ratio"
    )
    require_nonnegative(
        ionic_conductivity_s_cm,
        "hydrogel_specification.ionic_conductivity_s_cm"
    )
    require_nonnegative(
        adhesion_energy_j_m2,
        "hydrogel_specification.adhesion_energy_j_m2"
    )
    require_nonnegative(
        fatigue_life_cycles,
        "hydrogel_specification.fatigue_life_cycles"
    )
    require_unit_interval(
        cell_viability_fraction,
        "hydrogel_specification.cell_viability_fraction"
    )

    local supplied_tags = tags_to_set(specification.evidence_tags or {})
    local missing_required_tags = missing_tags(HYDROGEL_REQUIRED_TAGS, supplied_tags)
    local evidence_complete = #missing_required_tags == 0

    local property_completeness = 1.0
    local evidence_completeness =
        (#HYDROGEL_REQUIRED_TAGS - #missing_required_tags)
        / #HYDROGEL_REQUIRED_TAGS

    local material_record_completeness =
        property_completeness * 0.50 + evidence_completeness * 0.50

    return {
        object_id = "sc-036",
        name = "SoftBiointerfaceHydrogelSpec",
        valid = true,
        properties = {
            elastic_modulus_kpa = elastic_modulus_kpa,
            swelling_ratio = swelling_ratio,
            ionic_conductivity_s_cm = ionic_conductivity_s_cm,
            adhesion_energy_j_m2 = adhesion_energy_j_m2,
            fatigue_life_cycles = fatigue_life_cycles,
            cell_viability_fraction = cell_viability_fraction,
        },
        required_evidence_tags = copy_array(HYDROGEL_REQUIRED_TAGS),
        missing_evidence_tags = missing_required_tags,
        evidence_complete = evidence_complete,
        material_record_completeness = material_record_completeness,
        units = {
            elastic_modulus_kpa = "kPa",
            swelling_ratio = "dimensionless mass or volume ratio; method must be documented",
            ionic_conductivity_s_cm = "S/cm",
            adhesion_energy_j_m2 = "J/m^2",
            fatigue_life_cycles = "cycles",
            cell_viability_fraction = "fraction, 0..1",
        },
        knowledge_factor = material_record_completeness,
        eco_impact_value = 0.0,
        harm_risk = clamp(
            (1.0 - cell_viability_fraction) * 0.60
                + (1.0 - evidence_completeness) * 0.40,
            0.0,
            1.0
        ),
        authority_effect = "none",
        interpretation =
            "Material-record validator only. It cannot establish biological compatibility, "
            .. "long-term stability, medical safety, regulatory compliance, or suitability for use in people or animals.",
    }
end

return BiointerfaceEvidenceRegistry
