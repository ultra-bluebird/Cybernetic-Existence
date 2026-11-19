#!/usr/bin/env lua
-- Lua 5.4
-- Offline validator for privacy-preserving accessible infrastructure metadata.
-- This module evaluates supplied configuration and event data. It does not control
-- crossing signals, doors, lighting hardware, cameras, network connections, or people.

local M = {}

local OBJECTS = {
  [14] = {
    name = "Accessible Signal Extension Beacon",
    required = {
      local_activation_available = true,
      request_extension_only = true,
      identity_not_transmitted = true,
      device_serial_not_transmitted = true,
      biometrics_not_transmitted = true,
      short_range_transmission = true,
      low_power_operation = true,
      signal_expiry_defined = true,
    },
    prohibited_fields = {
      "resident_id",
      "real_name",
      "did",
      "device_serial",
      "biometric",
      "persistent_identifier",
      "location_history",
      "behavioral_profile",
    },
  },
  [15] = {
    name = "Door Safety Interlock Controller",
    required = {
      local_control_only = true,
      presence_sensor_available = true,
      force_sensor_available = true,
      stop_signal_available = true,
      reversal_function_available = true,
      protected_zone_defined = true,
      remote_analytics_override_disabled = true,
      identity_system_override_disabled = true,
      fault_state_blocks_closure = true,
      maintenance_test_documented = true,
    },
    prohibited_fields = {
      "resident_id",
      "face_image",
      "biometric",
      "identity_verification",
      "remote_override",
      "behavioral_profile",
    },
  },
  [16] = {
    name = "Adaptive Street Lighting System",
    required = {
      aggregate_flow_only = true,
      anonymous_thermal_counting = true,
      image_storage_disabled = true,
      trajectory_storage_disabled = true,
      individual_history_storage_disabled = true,
      time_of_day_input_available = true,
      brightness_bounds_defined = true,
      energy_use_monitoring_available = true,
    },
    prohibited_fields = {
      "face_image",
      "video",
      "individual_trajectory",
      "persistent_identifier",
      "resident_id",
      "individual_history",
      "behavioral_profile",
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

local function contains(values, target)
  for _, value in ipairs(values) do
    if value == target then
      return true
    end
  end

  return false
end

local function count_required(configuration, requirements)
  local met = 0
  local total = 0
  local missing = {}

  for field, expected in pairs(requirements) do
    total = total + 1

    if normalize_boolean(configuration[field]) == expected then
      met = met + 1
    else
      missing[#missing + 1] = field
    end
  end

  table.sort(missing)
  return met / total, missing
end

local function prohibited_findings(object, observed_fields)
  local findings = {}

  for _, field in ipairs(observed_fields) do
    if contains(object.prohibited_fields, field) then
      findings[#findings + 1] = field
    end
  end

  table.sort(findings)
  return findings
end

local function documentation_score(configuration)
  local evidence = {
    "scope_documented",
    "data_schema_documented",
    "safety_review_completed",
    "maintenance_process_documented",
    "failure_behavior_documented",
  }

  local met = 0

  for _, field in ipairs(evidence) do
    if normalize_boolean(configuration[field]) == true then
      met = met + 1
    end
  end

  return met / #evidence
end

local function resource_score(configuration)
  local efficiency_fields = {
    "low_power_operation",
    "local_processing_preferred",
    "maintenance_repair_preferred",
    "unnecessary_data_transfer_disabled",
  }

  local met = 0

  for _, field in ipairs(efficiency_fields) do
    if normalize_boolean(configuration[field]) == true then
      met = met + 1
    end
  end

  return met / #efficiency_fields
end

local function calculate_harm_risk(configuration, coverage, findings_count)
  local external_transfer = normalize_boolean(configuration.external_data_transfer) == true
  local remote_override = normalize_boolean(configuration.remote_override_enabled) == true
  local human_review = normalize_boolean(configuration.human_review_available) == true

  local risk = (1 - coverage) * 0.55
  risk = risk + math.min(findings_count / 3, 1) * 0.30

  if external_transfer then
    risk = risk + 0.05
  end

  if remote_override then
    risk = risk + 0.10
  end

  if not human_review then
    risk = risk + 0.05
  end

  return clamp(risk, 0, 1)
end

local function classify(coverage, harm_risk, findings_count)
  if coverage >= 0.85 and harm_risk <= 0.15 and findings_count == 0 then
    return "privacy-preserving safety design candidate"
  end

  if harm_risk <= 0.40 then
    return "conditional: resolve safeguards before deployment"
  end

  return "not suitable: material safety, autonomy, or privacy risk"
end

function M.assess(object_id, configuration, observed_fields)
  local object = OBJECTS[object_id]
  assert(object, "object_id must be an integer from 14 through 16")

  require_table(configuration, "configuration")

  observed_fields = observed_fields or {}
  validate_string_array(observed_fields, "observed_fields")

  local coverage, missing = count_required(configuration, object.required)
  local findings = prohibited_findings(object, observed_fields)
  local knowledge_factor = documentation_score(configuration)
  local eco_impact_value = clamp(
    (coverage * 0.55) +
    (resource_score(configuration) * 0.35) -
    (math.min(#findings, 1) * 0.10),
    0,
    1
  )

  local harm_risk = calculate_harm_risk(
    configuration,
    coverage,
    #findings
  )

  return {
    object_id = object_id,
    object_name = object.name,
    status = classify(coverage, harm_risk, #findings),
    safeguard_coverage = coverage,
    knowledge_factor = knowledge_factor,
    eco_impact_value = eco_impact_value,
    harm_risk = harm_risk,
    missing_safeguards = missing,
    prohibited_data_or_control_findings = findings,
    scope = "offline decision support only; this module does not operate infrastructure",
  }
end

function M.evaluate_extension_request(request)
  require_table(request, "request")

  local request_extension_only = normalize_boolean(request.request_extension_only)
  local identity_present = normalize_boolean(request.identity_present)
  local device_serial_present = normalize_boolean(request.device_serial_present)
  local biometrics_present = normalize_boolean(request.biometrics_present)
  local request_age_seconds = assert(
    tonumber(request.request_age_seconds),
    "request.request_age_seconds must be numeric"
  )

  local maximum_request_age_seconds = assert(
    tonumber(request.maximum_request_age_seconds),
    "request.maximum_request_age_seconds must be numeric"
  )

  assert(request_age_seconds >= 0, "request.request_age_seconds must be non-negative")
  assert(
    maximum_request_age_seconds > 0,
    "request.maximum_request_age_seconds must be greater than zero"
  )

  local valid = request_extension_only == true
    and identity_present ~= true
    and device_serial_present ~= true
    and biometrics_present ~= true
    and request_age_seconds <= maximum_request_age_seconds

  return {
    accepted_for_local_controller_review = valid,
    rejection_reasons = {
      request_extension_only ~= true and "request_not_extension_only" or nil,
      identity_present == true and "identity_present" or nil,
      device_serial_present == true and "device_serial_present" or nil,
      biometrics_present == true and "biometrics_present" or nil,
      request_age_seconds > maximum_request_age_seconds and "request_expired" or nil,
    },
    limitation = "This result is a local validation recommendation, not a command to modify a crossing signal.",
  }
end

function M.evaluate_door_safety_state(state)
  require_table(state, "state")

  local presence_detected = normalize_boolean(state.presence_detected)
  local force_threshold_exceeded = normalize_boolean(state.force_threshold_exceeded)
  local stop_requested = normalize_boolean(state.stop_requested)
  local sensor_fault = normalize_boolean(state.sensor_fault)
  local remote_override_requested = normalize_boolean(state.remote_override_requested)

  local closure_permitted = presence_detected ~= true
    and force_threshold_exceeded ~= true
    and stop_requested ~= true
    and sensor_fault ~= true
    and remote_override_requested ~= true

  local action
  if sensor_fault == true or stop_requested == true or force_threshold_exceeded == true then
    action = "hold_open_or_reverse_for_local_safety_review"
  elseif presence_detected == true then
    action = "hold_open_pending_zone_clearance"
  elseif remote_override_requested == true then
    action = "reject_remote_override_and_require_local_safety_review"
  else
    action = "closure_may_be_considered_by_certified_local_controller"
  end

  return {
    closure_permitted = closure_permitted,
    recommended_local_action = action,
    limitation = "This function is not a certified door controller and must not replace safety-rated hardware or required inspections.",
  }
end

function M.calculate_lighting_setpoint(input)
  require_table(input, "input")

  local aggregate_count = assert(
    tonumber(input.aggregate_pedestrian_count),
    "input.aggregate_pedestrian_count must be numeric"
  )

  local minimum_brightness = assert(
    tonumber(input.minimum_brightness),
    "input.minimum_brightness must be numeric"
  )

  local maximum_brightness = assert(
    tonumber(input.maximum_brightness),
    "input.maximum_brightness must be numeric"
  )

  local count_for_maximum_brightness = assert(
    tonumber(input.count_for_maximum_brightness),
    "input.count_for_maximum_brightness must be numeric"
  )

  assert(aggregate_count >= 0, "input.aggregate_pedestrian_count must be non-negative")
  assert(minimum_brightness >= 0, "input.minimum_brightness must be non-negative")
  assert(
    maximum_brightness >= minimum_brightness,
    "input.maximum_brightness must be at least input.minimum_brightness"
  )
  assert(
    count_for_maximum_brightness > 0,
    "input.count_for_maximum_brightness must be greater than zero"
  )

  local normalized_flow = clamp(
    aggregate_count / count_for_maximum_brightness,
    0,
    1
  )

  local setpoint = minimum_brightness +
    ((maximum_brightness - minimum_brightness) * normalized_flow)

  return {
    aggregate_pedestrian_count = aggregate_count,
    brightness_setpoint = setpoint,
    normalized_flow = normalized_flow,
    limitation = "This calculation uses supplied anonymous aggregate counts only and does not assess illumination-code compliance or public safety conditions.",
  }
end

local function compact_non_nil(values)
  local compact = {}

  for _, value in ipairs(values) do
    if value ~= nil then
      compact[#compact + 1] = value
    end
  end

  return compact
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

function M.render_report(result)
  require_table(result, "result")

  return table.concat({
    "Physical Access Safety Assessment",
    "Object: " .. result.object_id .. " — " .. result.object_name,
    "Status: " .. result.status,
    "Safeguard coverage: " .. percent(result.safeguard_coverage),
    "knowledge_factor: " .. percent(result.knowledge_factor),
    "eco_impact_value: " .. percent(result.eco_impact_value),
    "harm_risk: " .. percent(result.harm_risk),
    "Missing safeguards: " .. join_or_none(result.missing_safeguards),
    "Prohibited findings: " ..
      join_or_none(result.prohibited_data_or_control_findings),
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
    "Usage: lua physical_access_safety_assessor.lua <object-id:14-16> <config-file>\n" ..
    "Configuration format: key=true or key=false.\n" ..
    "Repeat observed_field=<field> to audit a declared schema or control input.\n"
  )
end

local function main(arguments)
  local object_id = tonumber(arguments[1])
  local configuration_path = arguments[2]

  if not object_id or not configuration_path then
    usage()
    return 2
  end

  local ok, report_or_error = pcall(function()
    local configuration, observed_fields = M.parse_key_value_file(configuration_path)
    local result = M.assess(object_id, configuration, observed_fields)
    return M.render_report(result)
  end)

  if not ok then
    io.stderr:write("Assessment failed: " .. tostring(report_or_error) .. "\n")
    return 1
  end

  io.write(report_or_error .. "\n")
  return 0
end

if ... == nil then
  os.exit(main(arg))
end

return M
