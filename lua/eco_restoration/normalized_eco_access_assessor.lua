-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/eco_restoration/normalized_eco_access_assessor.lua
-- Purpose: Normalized eco-access assessment function for site conditions

local EcoAccessAssessor = {}

-- Default configurable project targets
local DEFAULT_CORRIDOR_WIDTH_TARGET = 1.8  -- meters
local DEFAULT_TEMPERATURE_TARGET = 32      -- Celsius
local DEFAULT_PM25_TARGET = 35             -- µg/m³

--- Assess site conditions
-- Input requirements:
--   temperature_celsius: finite number
--   relative_humidity_percent: 0-100
--   pm25_micrograms_per_cubic_meter: non-negative number
--   corridor_width_meters: non-negative number
--   accessible_surface_confirmed: boolean
--   identity_required_for_access: boolean
--   waste_diversion_ratio: 0-1
--   energy_efficiency_ratio: non-negative number
-- Returns condition flags, metrics, and decision_support_only flag
function EcoAccessAssessor.assess_site_conditions(input)
    if type(input) ~= "table" then
        return nil, "input must be a table"
    end
    
    -- Validate temperature_celsius: finite number
    local temperature_celsius = input.temperature_celsius
    if type(temperature_celsius) ~= "number" or temperature_celsius ~= temperature_celsius or 
       temperature_celsius == math.huge or temperature_celsius == -math.huge then
        return nil, "temperature_celsius must be a finite number"
    end
    
    -- Validate relative_humidity_percent: 0-100
    local relative_humidity_percent = input.relative_humidity_percent
    if type(relative_humidity_percent) ~= "number" or relative_humidity_percent < 0 or relative_humidity_percent > 100 then
        return nil, "relative_humidity_percent must be between 0 and 100"
    end
    
    -- Validate pm25_micrograms_per_cubic_meter: non-negative number
    local pm25_micrograms_per_cubic_meter = input.pm25_micrograms_per_cubic_meter
    if type(pm25_micrograms_per_cubic_meter) ~= "number" or pm25_micrograms_per_cubic_meter < 0 then
        return nil, "pm25_micrograms_per_cubic_meter must be non-negative"
    end
    
    -- Validate corridor_width_meters: non-negative number
    local corridor_width_meters = input.corridor_width_meters
    if type(corridor_width_meters) ~= "number" or corridor_width_meters < 0 then
        return nil, "corridor_width_meters must be non-negative"
    end
    
    -- Validate accessible_surface_confirmed: boolean
    local accessible_surface_confirmed = input.accessible_surface_confirmed
    if type(accessible_surface_confirmed) ~= "boolean" then
        return nil, "accessible_surface_confirmed must be a boolean"
    end
    
    -- Validate identity_required_for_access: boolean
    local identity_required_for_access = input.identity_required_for_access
    if type(identity_required_for_access) ~= "boolean" then
        return nil, "identity_required_for_access must be a boolean"
    end
    
    -- Validate waste_diversion_ratio: 0-1
    local waste_diversion_ratio = input.waste_diversion_ratio
    if type(waste_diversion_ratio) ~= "number" or waste_diversion_ratio < 0 or waste_diversion_ratio > 1 then
        return nil, "waste_diversion_ratio must be between 0 and 1"
    end
    
    -- Validate energy_efficiency_ratio: non-negative number
    local energy_efficiency_ratio = input.energy_efficiency_ratio
    if type(energy_efficiency_ratio) ~= "number" or energy_efficiency_ratio < 0 then
        return nil, "energy_efficiency_ratio must be non-negative"
    end
    
    -- Get configurable targets (with defaults)
    local corridor_width_target = input.corridor_width_target or DEFAULT_CORRIDOR_WIDTH_TARGET
    local temperature_target = input.temperature_target or DEFAULT_TEMPERATURE_TARGET
    local pm25_target = input.pm25_target or DEFAULT_PM25_TARGET
    
    -- Produce explicit condition flags
    local condition_flags = {}
    
    -- Privacy/access concern if identity_required_for_access is true
    condition_flags.privacy_access_concern = identity_required_for_access
    
    -- Mobility concern if corridor width is below target
    condition_flags.mobility_concern = corridor_width_meters < corridor_width_target
    
    -- Environmental attention if temperature exceeds target
    condition_flags.environmental_attention = temperature_celsius > temperature_target
    
    -- Air-quality attention if PM2.5 exceeds target
    condition_flags.air_quality_attention = pm25_micrograms_per_cubic_meter > pm25_target
    
    -- Additional basic flags
    condition_flags.accessible_surface_confirmed = accessible_surface_confirmed
    condition_flags.corridor_adequate = corridor_width_meters >= corridor_width_target
    
    -- Calculate knowledge_factor: input completeness and basic consistency, clamped to 0-1
    -- All inputs are validated, so we assess consistency
    local knowledge_factor = 1.0
    
    -- Reduce knowledge factor if any concerning conditions are present
    local concern_count = 0
    if condition_flags.privacy_access_concern then concern_count = concern_count + 1 end
    if condition_flags.mobility_concern then concern_count = concern_count + 1 end
    if condition_flags.environmental_attention then concern_count = concern_count + 1 end
    if condition_flags.air_quality_attention then concern_count = concern_count + 1 end
    
    -- Each concern reduces knowledge factor slightly
    knowledge_factor = math.max(0.0, 1.0 - (concern_count * 0.1))
    knowledge_factor = math.min(1.0, math.max(0.0, knowledge_factor))
    
    -- Calculate eco_impact_value: weighted positive score
    -- Components: waste diversion, energy efficiency (capped at 1), accessible surface, corridor adequacy
    local waste_score = waste_diversion_ratio  -- Already 0-1
    local energy_score = math.min(1.0, energy_efficiency_ratio / 10.0)  -- Normalize, cap at 1
    local access_score = accessible_surface_confirmed and 1.0 or 0.0
    local corridor_score = corridor_width_meters >= corridor_width_target and 1.0 or 
                           math.min(1.0, corridor_width_meters / corridor_width_target)
    
    -- Weighted average (equal weights)
    local eco_impact_value = (waste_score + energy_score + access_score + corridor_score) / 4.0
    eco_impact_value = math.min(1.0, math.max(0.0, eco_impact_value))
    
    -- Calculate harm_risk: worst relevant normalized concern, clamped to 0-1
    local harm_components = {}
    
    -- Privacy harm
    if identity_required_for_access then
        table.insert(harm_components, 0.7)  -- Significant privacy concern
    end
    
    -- Mobility harm (based on how far below target)
    if corridor_width_meters < corridor_width_target then
        local mobility_gap = (corridor_width_target - corridor_width_meters) / corridor_width_target
        table.insert(harm_components, math.min(1.0, mobility_gap))
    end
    
    -- Environmental harm (based on temperature excess)
    if temperature_celsius > temperature_target then
        local temp_excess = (temperature_celsius - temperature_target) / temperature_target
        table.insert(harm_components, math.min(1.0, temp_excess))
    end
    
    -- Air quality harm (based on PM2.5 excess)
    if pm25_micrograms_per_cubic_meter > pm25_target then
        local pm25_excess = (pm25_micrograms_per_cubic_meter - pm25_target) / pm25_target
        table.insert(harm_components, math.min(1.0, pm25_excess))
    end
    
    -- Harm risk is the maximum of all components, or 0 if none
    local harm_risk = 0.0
    if #harm_components > 0 then
        for _, component in ipairs(harm_components) do
            if component > harm_risk then
                harm_risk = component
            end
        end
    end
    harm_risk = math.min(1.0, math.max(0.0, harm_risk))
    
    return {
        condition_flags = condition_flags,
        knowledge_factor = knowledge_factor,
        eco_impact_value = eco_impact_value,
        harm_risk = harm_risk,
        decision_support_only = true,
        inputs = {
            temperature_celsius = temperature_celsius,
            relative_humidity_percent = relative_humidity_percent,
            pm25_micrograms_per_cubic_meter = pm25_micrograms_per_cubic_meter,
            corridor_width_meters = corridor_width_meters,
            accessible_surface_confirmed = accessible_surface_confirmed,
            identity_required_for_access = identity_required_for_access,
            waste_diversion_ratio = waste_diversion_ratio,
            energy_efficiency_ratio = energy_efficiency_ratio
        },
        targets = {
            corridor_width_target_meters = corridor_width_target,
            temperature_target_celsius = temperature_target,
            pm25_target_micrograms_per_cubic_meter = pm25_target
        },
        interpretation = "Site condition assessment for decision support only. " ..
                         "This does not certify accessibility, safety, or regulatory compliance."
    }
end

return EcoAccessAssessor
