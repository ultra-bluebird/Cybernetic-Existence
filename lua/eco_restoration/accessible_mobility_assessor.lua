#!/usr/bin/env lua
-- Lua 5.4
-- Offline planning utility for accessible civic mobility metadata.
-- It evaluates supplied route segments and kiosk capabilities only.
-- It performs no sensing, tracking, routing requests, calls, or external actions.

local M = {}

local OBJECTS = {
  [11] = {
    name = "Universal Path Clearance Monitor",
    required = {
      non_imaging_sensor = true,
      geometry_only_storage = true,
      individual_tracking_disabled = true,
      individual_identifiers_disabled = true,
      accessible_route_scope_defined = true,
      maintenance_review_supported = true,
    },
    prohibited_fields = {
      "face_image",
      "video",
      "audio_recording",
      "resident_id",
      "device_identifier",
      "persistent_location_history",
      "biometric",
    },
  },
  [12] = {
    name = "Low-EMI Route Planner",
    required = {
      emi_map_source_declared = true,
      fixed_sensor_inputs_only = true,
      purpose_not_collected = true,
      identity_not_collected = true,
      route_option_is_optional = true,
      route_uncertainty_disclosed = true,
    },
    prohibited_fields = {
      "medical_diagnosis",
      "augmentation_status",
      "resident_id",
      "persistent_profile_id",
      "route_history",
      "behavioral_profile",
    },
  },
  [13] = {
    name = "Non-Digital Assistance Kiosk",
    required = {
      tactile_controls_available = true,
      large_print_available = true,
      audio_output_available = true,
      human_operator_phone_available = true,
      login_not_required = true,
      identity_disclosure_not_required = true,
      emergency_help_available = true,
    },
    prohibited_fields = {
      "account_required",
      "identity_verification_required",
      "biometric_capture",
      "persistent_usage_profile",
      "advertising_identifier",
    },
  },
}

local BOOLEAN = {
  ["true"] = true,
  ["false"] = false,
}

local function clamp(value, lower, upper)
  if value < lower then
    return lower
  end

  if value > upper then
    return upper
  end

  return value
end

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize_boolean(value)
  if type(value) == "boolean" then
    return value
  end

  if type(value) == "string" then
    return BOOLEAN[value:lower()]
  end

  return nil
end

local function require_table(value, name)
  assert(type(value) == "table", name .. " must be a table")
end

local function validate_string_array(values, name)
  require_table(values, name)

  for index, value in ipairs(values) do
    assert(
      type(value) == "string" and value ~= "",
      name .. "[" .. index .. "] must be a non-empty string"
    )
  end
end

local function array_contains(values, target)
  for _, value in ipairs(values) do
    if value == target then
      return true
    end
  end

  return false
end

local function percent(value)
  return string.format("%.1f%%", value * 100)
end

local function join_or_none(values)
  if #values == 0 then
    return "none"
  end

  return table.concat(values, ", ")
end

local function check_requirements(configuration, requirements)
  local met = 0
  local total = 0
  local missing = {}

  for requirement, expected in pairs(requirements) do
    total = total + 1

    if normalize_boolean(configuration[requirement]) == expected then
      met = met + 1
    else
      missing[#missing + 1] = requirement
    end
  end

  table.sort(missing)
  return met / total, missing
end

local function find_prohibited_fields(object, observed_fields)
  local findings = {}

  for _, field in ipairs(observed_fields) do
    if array_contains(object.prohibited_fields, field) then
      findings[#findings + 1] = field
    end
  end

  table.sort(findings)
  return findings
end

local function evidence_score(configuration)
  local evidence_fields = {
    "scope_documented",
    "data_schema_documented",
    "maintenance_process_documented",
    "accessibility_review_completed",
    "uncertainty_or_limitations_documented",
  }

  local completed = 0

  for _, field in ipairs(evidence_fields) do
    if normalize_boolean(configuration[field]) == true then
      completed = completed + 1
    end
  end

  return completed / #evidence_fields
end

local function calculate_eco_impact(configuration, safeguard_coverage, findings_count)
  local low_power = normalize_boolean(configuration.low_power_operation_preferred) == true
  local local_processing = normalize_boolean(configuration.local_processing_preferred) == true
  local repair_prioritized = normalize_boolean(configuration.repair_before_replacement) == true

  local resource_score = 0
  if low_power then
    resource_score = resource_score + 1 / 3
  end
  if local_processing then
    resource_score = resource_score + 1 / 3
  end
  if repair_prioritized then
    resource_score = resource_score + 1 / 3
  end

  return clamp(
    0.50 * safeguard_coverage +
    0.35 * resource_score -
    0.15 * math.min(findings_count, 1),
    0,
    1
  )
end

local function calculate_harm_risk(configuration, safeguard_coverage, findings_count)
  local external_transfer = normalize_boolean(configuration.external_data_transfer) == true
  local no_human_escalation = normalize_boolean(configuration.human_escalation_available) ~= true
  local unreviewed_automation = normalize_boolean(configuration.automated_alert_or_guidance) == true
    and normalize_boolean(configuration.human_review_available) ~= true

  local risk = (1 - safeguard_coverage) * 0.50
  risk = risk + math.min(findings_count / 3, 1) * 0.35

  if external_transfer then
    risk = risk + 0.10
  end

  if no_human_escalation then
    risk = risk + 0.03
  end

  if unreviewed_automation then
    risk = risk + 0.02
  end

  return clamp(risk, 0, 1)
end

local function classify(safeguard_coverage, harm_risk, findings_count)
  if findings_count == 0 and safeguard_coverage >= 0.85 and harm_risk <= 0.15 then
    return "accessible, privacy-preserving design candidate"
  end

  if harm_risk <= 0.40 then
    return "conditional: address missing safeguards before deployment"
  end

  return "not suitable: material accessibility, privacy, or safety risk"
end

function M.assess(object_id, configuration, observed_fields)
  local object = OBJECTS[object_id]
  assert(object, "object_id must be an integer from 11 through 13")

  require_table(configuration, "configuration")

  observed_fields = observed_fields or {}
  validate_string_array(observed_fields, "observed_fields")

  local safeguard_coverage, missing = check_requirements(configuration, object.required)
  local prohibited_findings = find_prohibited_fields(object, observed_fields)
  local knowledge_factor = evidence_score(configuration)
  local eco_impact_value = calculate_eco_impact(
    configuration,
    safeguard_coverage,
    #prohibited_findings
  )

  local harm_risk = calculate_harm_risk(
    configuration,
    safeguard_coverage,
    #prohibited_findings
  )

  return {
    object_id = object_id,
    object_name = object.name,
    status = classify(safeguard_coverage, harm_risk, #prohibited_findings),
    safeguard_coverage = safeguard_coverage,
    knowledge_factor = knowledge_factor,
    eco_impact_value = eco_impact_value,
    harm_risk = harm_risk,
    missing_safeguards = missing,
    prohibited_data_findings = prohibited_findings,
    scope = "offline metadata assessment only; not a sensor, route, or kiosk controller",
  }
end

function M.assess_path_clearance(segment)
  require_table(segment, "segment")

  local segment_id = assert(
    segment.segment_id,
    "segment.segment_id is required"
  )

  local clearance_meters = assert(
    tonumber(segment.clearance_meters),
    "segment.clearance_meters must be numeric"
  )

  local required_clearance_meters = assert(
    tonumber(segment.required_clearance_meters),
    "segment.required_clearance_meters must be numeric"
  )

  assert(clearance_meters >= 0, "segment.clearance_meters must be non-negative")
  assert(
    required_clearance_meters > 0,
    "segment.required_clearance_meters must be greater than zero"
  )

  local ratio = clearance_meters / required_clearance_meters

  return {
    segment_id = tostring(segment_id),
    clearance_meters = clearance_meters,
    required_clearance_meters = required_clearance_meters,
    clearance_ratio = ratio,
    meets_declared_threshold = clearance_meters >= required_clearance_meters,
    shortfall_meters = math.max(0, required_clearance_meters - clearance_meters),
  }
end

function M.assess_route_emi(route_segments, maximum_preferred_emi)
  require_table(route_segments, "route_segments")

  maximum_preferred_emi = assert(
    tonumber(maximum_preferred_emi),
    "maximum_preferred_emi must be numeric"
  )

  assert(maximum_preferred_emi >= 0, "maximum_preferred_emi must be non-negative")
  assert(#route_segments > 0, "route_segments must not be empty")

  local total_length_meters = 0
  local weighted_emi_sum = 0
  local peak_emi = 0
  local above_preference = {}

  for index, segment in ipairs(route_segments) do
    require_table(segment, "route_segments[" .. index .. "]")

    local segment_id = assert(segment.segment_id, "route segment_id is required")
    local length_meters = assert(
      tonumber(segment.length_meters),
      "route segment length_meters must be numeric"
    )

    local emi_level = assert(
      tonumber(segment.emi_level),
      "route segment emi_level must be numeric"
    )

    assert(length_meters > 0, "route segment length_meters must be greater than zero")
    assert(emi_level >= 0, "route segment emi_level must be non-negative")

    total_length_meters = total_length_meters + length_meters
    weighted_emi_sum = weighted_emi_sum + (length_meters * emi_level)
    peak_emi = math.max(peak_emi, emi_level)

    if emi_level > maximum_preferred_emi then
      above_preference[#above_preference + 1] = tostring(segment_id)
    end
  end

  return {
    total_length_meters = total_length_meters,
    length_weighted_emi = weighted_emi_sum / total_length_meters,
    peak_emi = peak_emi,
    maximum_preferred_emi = maximum_preferred_emi,
    segments_above_preference = above_preference,
    meets_declared_preference = #above_preference == 0,
    limitation = "EMI values are supplied inputs; this function does not measure exposure or determine medical safety.",
  }
end

function M.render_report(result)
  require_table(result, "result")

  return table.concat({
    "Accessible Mobility Assessment",
    "Object: " .. result.object_id .. " — " .. result.object_name,
    "Status: " .. result.status,
    "Safeguard coverage: " .. percent(result.safeguard_coverage),
    "knowledge_factor: " .. percent(result.knowledge_factor),
    "eco_impact_value: " .. percent(result.eco_impact_value),
    "harm_risk: " .. percent(result.harm_risk),
    "Missing safeguards: " .. join_or_none(result.missing_safeguards),
    "Prohibited data findings: " .. join_or_none(result.prohibited_data_findings),
    "Scope: " .. result.scope,
  }, "\n")
end

function M.parse_key_value_file(path)
  assert(type(path) == "string" and path ~= "", "path must be a non-empty string")

  local file, open_error = io.open(path, "r")
  assert(file, "cannot open configuration file: " .. tostring(open_error))

  local configuration = {}
  local observed_fields = {}

  for line in file:lines() do
    local stripped = trim(line)

    if stripped ~= "" and stripped:sub(1, 1) ~= "#" then
      local key, value = stripped:match("^([%a_][%w_]*)%s*=%s*(.-)%s*$")
      assert(key and value, "invalid configuration line: " .. line)

      if key == "observed_field" then
        observed_fields[#observed_fields + 1] = value
      else
        local boolean_value = normalize_boolean(value)
        configuration[key] = boolean_value ~= nil and boolean_value or value
      end
    end
  end

  file:close()
  return configuration, observed_fields
end

local function usage()
  io.stderr:write(
    "Usage: lua accessible_mobility_assessor.lua <object-id:11-13> <config-file>\n" ..
    "Configuration uses key=true or key=false.\n" ..
    "Repeat observed_field=<field> to audit fields declared in a data schema.\n"
  )
end

local function main(arguments)
  local object_id = tonumber(arguments[1])
  local configuration_path = arguments[2]

  if not object_id or not configuration_path then
    usage()
    return 2
  end

  local ok, output_or_error = pcall(function()
    local configuration, observed_fields = M.parse_key_value_file(configuration_path)
    local result = M.assess(object_id, configuration, observed_fields)
    return M.render_report(result)
  end)

  if not ok then
    io.stderr:write("Assessment failed: " .. tostring(output_or_error) .. "\n")
    return 1
  end

  io.write(output_or_error .. "\n")
  return 0
end

if ... == nil then
  os.exit(main(arg))
end

return M
