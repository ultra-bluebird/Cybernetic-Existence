#!/usr/bin/env lua
-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/eco_access_report_renderer.lua
-- Purpose: Local report renderer for eco-access assessment

-- Load required modules
local AssistiveClarificationRouter = require("lua.tools.assistive_clarification_router")
local EcoAccessAssessor = require("lua.eco_restoration.normalized_eco_access_assessor")

-- Get command-line arguments
local args = {...}

if #args < 2 then
    io.stderr:write("Usage: lua eco_access_report_renderer.lua <input_file> <output_file>\n")
    os.exit(1)
end

local input_file = args[1]
local output_file = args[2]

-- Read input file
local file, err = io.open(input_file, "r")
if not file then
    io.stderr:write("Error: Cannot open input file: " .. input_file .. " - " .. tostring(err) .. "\n")
    os.exit(1)
end

local content = file:read("*all")
file:close()

-- Parse key=value format
local function parse_input(content)
    local result = {}
    for line in content:gmatch("[^\r\n]+") do
        -- Skip empty lines and comments
        if line:match("%S") and not line:match("^#") then
            local key, value = line:match("^([^=]+)=(.*)$")
            if key and value then
                -- Trim whitespace from key
                key = key:match("^%s*(.-)%s*$")
                -- Trim whitespace from value
                value = value:match("^%s*(.-)%s*$")
                result[key] = value
            end
        end
    end
    return result
end

local data = parse_input(content)

-- Required fields for assess_site_conditions
local required_fields = {
    "temperature_celsius",
    "relative_humidity_percent",
    "pm25_micrograms_per_cubic_meter",
    "corridor_width_meters",
    "accessible_surface_confirmed",
    "identity_required_for_access",
    "waste_diversion_ratio",
    "energy_efficiency_ratio"
}

-- Validate required fields
for _, field in ipairs(required_fields) do
    if data[field] == nil then
        io.stderr:write("Error: Missing required field: " .. field .. "\n")
        os.exit(1)
    end
end

-- Convert and validate numeric fields
local function to_number(value, field_name)
    local num = tonumber(value)
    if num == nil then
        io.stderr:write("Error: Field " .. field_name .. " must be a number, got: " .. tostring(value) .. "\n")
        os.exit(1)
    end
    return num
end

local function to_boolean(value, field_name)
    if value == "true" then
        return true
    elseif value == "false" then
        return false
    else
        io.stderr:write("Error: Field " .. field_name .. " must be 'true' or 'false', got: " .. tostring(value) .. "\n")
        os.exit(1)
    end
end

-- Build input table for assessment
local input = {
    temperature_celsius = to_number(data.temperature_celsius, "temperature_celsius"),
    relative_humidity_percent = to_number(data.relative_humidity_percent, "relative_humidity_percent"),
    pm25_micrograms_per_cubic_meter = to_number(data.pm25_micrograms_per_cubic_meter, "pm25_micrograms_per_cubic_meter"),
    corridor_width_meters = to_number(data.corridor_width_meters, "corridor_width_meters"),
    accessible_surface_confirmed = to_boolean(data.accessible_surface_confirmed, "accessible_surface_confirmed"),
    identity_required_for_access = to_boolean(data.identity_required_for_access, "identity_required_for_access"),
    waste_diversion_ratio = to_number(data.waste_diversion_ratio, "waste_diversion_ratio"),
    energy_efficiency_ratio = to_number(data.energy_efficiency_ratio, "energy_efficiency_ratio")
}

-- Validate ranges
if input.relative_humidity_percent < 0 or input.relative_humidity_percent > 100 then
    io.stderr:write("Error: relative_humidity_percent must be between 0 and 100\n")
    os.exit(1)
end

if input.pm25_micrograms_per_cubic_meter < 0 then
    io.stderr:write("Error: pm25_micrograms_per_cubic_meter must be non-negative\n")
    os.exit(1)
end

if input.corridor_width_meters < 0 then
    io.stderr:write("Error: corridor_width_meters must be non-negative\n")
    os.exit(1)
end

if input.waste_diversion_ratio < 0 or input.waste_diversion_ratio > 1 then
    io.stderr:write("Error: waste_diversion_ratio must be between 0 and 1\n")
    os.exit(1)
end

if input.energy_efficiency_ratio < 0 then
    io.stderr:write("Error: energy_efficiency_ratio must be non-negative\n")
    os.exit(1)
end

-- Process optional message field with routing
local routed_topic = "none"
local clarification_state = "not_applicable"
local redacted_message_preview = "none"

if data.message then
    local decision = AssistiveClarificationRouter.make_assistive_decision(data.message)
    
    if decision.status == "routed" then
        routed_topic = decision.topic
        clarification_state = "routed"
    elseif decision.status == "needs_clarification" then
        routed_topic = "clarification_needed"
        clarification_state = decision.reason_code
    else
        routed_topic = "error"
        clarification_state = decision.reason or "unknown"
    end
    
    redacted_message_preview = decision.redacted_preview or "none"
end

-- Call site-condition assessment
local assessment, err = EcoAccessAssessor.assess_site_conditions(input)
if not assessment then
    io.stderr:write("Error: Assessment failed: " .. tostring(err) .. "\n")
    os.exit(1)
end

-- Generate timestamp
local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")

-- Build report
local report_lines = {
    "================================================================================",
    "ECO-ACCESS ASSESSMENT REPORT",
    "================================================================================",
    "",
    "Timestamp: " .. timestamp,
    "",
    "--------------------------------------------------------------------------------",
    "MESSAGE ROUTING",
    "--------------------------------------------------------------------------------",
    "Routed Topic: " .. routed_topic,
    "Clarification State: " .. clarification_state,
    "Redacted Message Preview: " .. redacted_message_preview,
    "",
    "--------------------------------------------------------------------------------",
    "CONDITION FLAGS",
    "--------------------------------------------------------------------------------",
    "Privacy/Access Concern: " .. tostring(assessment.condition_flags.privacy_access_concern),
    "Mobility Concern: " .. tostring(assessment.condition_flags.mobility_concern),
    "Environmental Attention: " .. tostring(assessment.condition_flags.environmental_attention),
    "Air Quality Attention: " .. tostring(assessment.condition_flags.air_quality_attention),
    "Accessible Surface Confirmed: " .. tostring(assessment.condition_flags.accessible_surface_confirmed),
    "Corridor Adequate: " .. tostring(assessment.condition_flags.corridor_adequate),
    "",
    "--------------------------------------------------------------------------------",
    "NORMALIZED METRICS",
    "--------------------------------------------------------------------------------",
    "knowledge_factor: " .. string.format("%.4f", assessment.knowledge_factor),
    "eco_impact_value: " .. string.format("%.4f", assessment.eco_impact_value),
    "harm_risk: " .. string.format("%.4f", assessment.harm_risk),
    "",
    "--------------------------------------------------------------------------------",
    "DECISION SUPPORT STATUS",
    "--------------------------------------------------------------------------------",
    "decision_support_only=true",
    "",
    "--------------------------------------------------------------------------------",
    "LIMITATIONS",
    "--------------------------------------------------------------------------------",
    "This report is decision support and does not certify accessibility, safety, or regulatory compliance.",
    "",
    "================================================================================",
    "END OF REPORT",
    "================================================================================"
}

-- Write output file
local out_file, err = io.open(output_file, "w")
if not out_file then
    io.stderr:write("Error: Cannot open output file: " .. output_file .. " - " .. tostring(err) .. "\n")
    os.exit(1)
end

for _, line in ipairs(report_lines) do
    out_file:write(line .. "\n")
end

out_file:close()

print("Report written to: " .. output_file)
os.exit(0)
