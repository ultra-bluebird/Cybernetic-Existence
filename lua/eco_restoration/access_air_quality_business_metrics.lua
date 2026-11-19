-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/eco_restoration/access_air_quality_business_metrics.lua
-- Destination: lua/eco_restoration/

local Metrics = {}

local DEFAULT_ECO_FOOTPRINT_COEFFICIENTS = {
    energy = 1.0,
    water = 0.5,
    waste = 0.8,
    green_investment = 0.3,
}

local PM25_UNIT = "µg/m³"
local REQUIRED_EVIDENCE_TAG = "0xA17C4E"

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

local function require_string(value, name)
    assert(type(value) == "string" and value ~= "", name .. " must be a non-empty string")
end

local function require_field(input, field, context)
    assert(input[field] ~= nil, context .. "." .. field .. " is required")
    return input[field]
end

local function shallow_copy(source)
    local result = {}

    for key, value in pairs(source) do
        result[key] = value
    end

    return result
end

local function is_iso_8601_utc(value)
    if type(value) ~= "string" then
        return false
    end

    return value:match(
        "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.%d%d%dZ$"
    ) ~= nil
end

local function validate_location(location)
    if type(location) == "string" then
        return location ~= ""
    end

    if type(location) ~= "table" then
        return false
    end

    local geojson_type = location.type
    local coordinates = location.coordinates

    if geojson_type == "Point"
        and type(coordinates) == "table"
        and #coordinates >= 2
        and is_finite_number(coordinates[1])
        and is_finite_number(coordinates[2]) then
        return true
    end

    return false
end

--- SC-022: Produces a transparent maintenance-priority indicator for an
--- accessible path segment. Inputs are normalized severity/context factors
--- unless a caller documents a consistent alternative scale.
---@param input table
---@return table
function Metrics.handicap_path_maintenance_urgency(input)
    require_table(input, "path_maintenance_input")

    local hazard = require_field(input, "hazard", "path_maintenance_input")
    local use_frequency = require_field(
        input,
        "use_frequency",
        "path_maintenance_input"
    )
    local vulnerability = require_field(
        input,
        "vulnerability",
        "path_maintenance_input"
    )
    local remaining_life = require_field(
        input,
        "remaining_life",
        "path_maintenance_input"
    )

    require_nonnegative(hazard, "path_maintenance_input.hazard")
    require_nonnegative(
        use_frequency,
        "path_maintenance_input.use_frequency"
    )
    require_nonnegative(
        vulnerability,
        "path_maintenance_input.vulnerability"
    )
    require_nonnegative(
        remaining_life,
        "path_maintenance_input.remaining_life"
    )

    local urgency
    local status

    if remaining_life == 0 then
        urgency = math.huge
        status = "immediate-review-required"
    else
        urgency = (hazard * use_frequency * vulnerability) / remaining_life
        status = "prioritization-evidence"
    end

    return {
        object_id = "sc-022",
        name = "HandicapPathMaintenanceUrgency",
        urgency = urgency,
        status = status,
        inputs = {
            hazard = hazard,
            use_frequency = use_frequency,
            vulnerability = vulnerability,
            remaining_life = remaining_life,
        },
        units =
            "relative priority indicator; all non-dimensional inputs require documented normalization",
        knowledge_factor = remaining_life > 0 and 0.65 or 0.45,
        eco_impact_value = 0.15,
        harm_risk = remaining_life == 0
            and 1.0
            or clamp(urgency, 0.0, 1.0),
        authority_effect = "none",
        interpretation =
            "Maintenance prioritization evidence only. An infinite urgency identifies a "
            .. "zero remaining-life input for immediate human inspection; it does not dispatch crews or alter public infrastructure.",
    }
end

--- SC-023: Validates a community PM2.5 sensor fact while retaining uncertainty,
--- location, source identity, and evidence-tag provenance. It does not infer
--- individual exposure, health status, or regulatory compliance.
---@param fact table
---@return table
function Metrics.community_air_quality_sensor_fact(fact)
    require_table(fact, "air_quality_fact")

    local subject = require_field(fact, "subject", "air_quality_fact")
    local property = require_field(fact, "property", "air_quality_fact")
    local value = require_field(fact, "value", "air_quality_fact")
    local unit = require_field(fact, "unit", "air_quality_fact")
    local timestamp = require_field(fact, "timestamp", "air_quality_fact")
    local location = require_field(fact, "location", "air_quality_fact")
    local uncertainty = require_field(fact, "uncertainty", "air_quality_fact")
    local evidence_tag = require_field(fact, "evidence_tag", "air_quality_fact")

    require_string(subject, "air_quality_fact.subject")
    assert(
        property == "PM2.5",
        "air_quality_fact.property must be PM2.5"
    )
    require_nonnegative(value, "air_quality_fact.value")
    assert(
        unit == PM25_UNIT,
        "air_quality_fact.unit must be " .. PM25_UNIT
    )
    assert(
        is_iso_8601_utc(timestamp),
        "air_quality_fact.timestamp must be ISO 8601 UTC with milliseconds"
    )
    assert(
        validate_location(location),
        "air_quality_fact.location must be a non-empty address string or GeoJSON Point"
    )
    require_nonnegative(uncertainty, "air_quality_fact.uncertainty")
    require_string(evidence_tag, "air_quality_fact.evidence_tag")
    assert(
        evidence_tag == REQUIRED_EVIDENCE_TAG,
        "air_quality_fact.evidence_tag must be " .. REQUIRED_EVIDENCE_TAG
    )

    local relative_uncertainty

    if value > 0 then
        relative_uncertainty = uncertainty / value
    else
        relative_uncertainty = uncertainty > 0 and math.huge or 0.0
    end

    return {
        object_id = "sc-023",
        name = "CommunityAirQualitySensorFact",
        valid = true,
        fact = {
            subject = subject,
            property = property,
            value = value,
            unit = unit,
            timestamp = timestamp,
            location = location,
            uncertainty = uncertainty,
            evidence_tag = evidence_tag,
        },
        relative_uncertainty = relative_uncertainty,
        knowledge_factor = value > 0
            and clamp(1.0 - relative_uncertainty, 0.0, 1.0)
            or 0.50,
        eco_impact_value = 0.30,
        harm_risk = 0.05,
        authority_effect = "none",
        interpretation =
            "Validated community measurement record. It retains uncertainty and provenance, "
            .. "but is not a personal exposure estimate, health assessment, or regulatory determination.",
    }
end

--- SC-024: Calculates a configurable, unit-dependent business-place footprint
--- index. All activity inputs must be normalized to consistent reporting
--- periods and documented units before comparisons are made.
---@param input table
---@param coefficients table|nil
---@return table
function Metrics.business_place_eco_footprint(input, coefficients)
    require_table(input, "business_eco_footprint_input")

    local energy = require_field(input, "energy", "business_eco_footprint_input")
    local water = require_field(input, "water", "business_eco_footprint_input")
    local waste = require_field(input, "waste", "business_eco_footprint_input")
    local green_investment = require_field(
        input,
        "green_investment",
        "business_eco_footprint_input"
    )

    require_nonnegative(energy, "business_eco_footprint_input.energy")
    require_nonnegative(water, "business_eco_footprint_input.water")
    require_nonnegative(waste, "business_eco_footprint_input.waste")
    require_nonnegative(
        green_investment,
        "business_eco_footprint_input.green_investment"
    )

    coefficients = coefficients or {}
    require_table(coefficients, "business_eco_footprint_coefficients")

    local c = shallow_copy(DEFAULT_ECO_FOOTPRINT_COEFFICIENTS)

    for key, value in pairs(coefficients) do
        assert(
            c[key] ~= nil,
            "unsupported footprint coefficient: " .. tostring(key)
        )
        require_nonnegative(value, "business_eco_footprint_coefficients." .. key)
        c[key] = value
    end

    local gross_footprint =
        c.energy * energy
        + c.water * water
        + c.waste * waste

    local green_investment_credit =
        c.green_investment * green_investment

    local net_footprint = gross_footprint - green_investment_credit
    local bounded_footprint = math.max(0.0, net_footprint)

    local investment_offset_ratio = 0.0

    if gross_footprint > 0 then
        investment_offset_ratio = clamp(
            green_investment_credit / gross_footprint,
            0.0,
            1.0
        )
    end

    return {
        object_id = "sc-024",
        name = "BusinessPlaceEcoFootprint",
        gross_footprint_index = gross_footprint,
        green_investment_credit_index = green_investment_credit,
        net_footprint_index = net_footprint,
        bounded_footprint_index = bounded_footprint,
        investment_offset_ratio = investment_offset_ratio,
        coefficients = c,
        inputs = {
            energy = energy,
            water = water,
            waste = waste,
            green_investment = green_investment,
        },
        units =
            "unit-dependent index; all inputs must share documented normalization and reporting period",
        knowledge_factor = 0.60,
        eco_impact_value = investment_offset_ratio,
        harm_risk = clamp(
            gross_footprint > 0 and bounded_footprint / gross_footprint or 0.0,
            0.0,
            1.0
        ),
        authority_effect = "none",
        interpretation =
            "Comparative sustainability scenario index. It does not constitute a verified "
            .. "life-cycle assessment, regulatory finding, emissions inventory, or business ranking.",
    }
end

return Metrics
