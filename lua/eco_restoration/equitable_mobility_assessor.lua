#!/usr/bin/env lua
-- Lua 5.4
-- Offline assessment for inclusive civic-mobility designs and supplied public metrics.
-- This program does not operate transit systems, receive reports, identify people,
-- provide safety-critical crossing control, or alter physical infrastructure.

local M = {}

local OBJECTS = {
  [17] = {
    name = "Transit Service Equity Dashboard",
    required = {
      public_route_metrics_only = true,
      route_stop_time_window_aggregation = true,
      rider_identity_not_collected = true,
      service_baseline_published = true,
      below_baseline_zones_highlighted = true,
      accessibility_status_included = true,
      methodology_documented = true,
    },
    prohibited_fields = {
      "rider_id",
      "resident_id",
      "real_name",
      "persistent_device_identifier",
      "trip_history",
      "behavioral_profile",
      "biometric",
    },
  },
  [18] = {
    name = "Accessible Path Obstruction Reporter",
    required = {
      phone_submission_available = true,
      web_submission_available = true,
      in_person_submission_available = true,
      name_not_required = true,
      account_not_required = true,
      explanation_not_required = true,
      location_and_time_minimized = true,
      remediation_status_available = true,
    },
    prohibited_fields = {
      "resident_id",
      "real_name",
      "account_identifier",
      "medical_diagnosis",
      "augmentation_status",
      "behavioral_profile",
      "persistent_device_identifier",
    },
  },
  [19] = {
    name = "Silent Crossing Corridor",
    required = {
      visual_cue_available = true,
      tactile_cue_available = true,
      low_audio_option_available = true,
      available_on_request = true,
      request_reason_not_collected = true,
      identity_not_collected = true,
      local_safety_review_documented = true,
    },
    prohibited_fields = {
      "medical_diagnosis",
      "hearing_device_type",
      "augmentation_status",
      "resident_id",
      "real_name",
      "behavioral_profile",
    },
  },
  [20] = {
    name = "Reflective/High-Contrast Wayfinding System",
    required = {
      tactile_ground_indicators_installed = true,
      high_contrast_signage_installed = true,
      reflective_markers_installed = true,
      universally_installed = true,
      per_person_activation_not_required = true,
      maintenance_inspection_documented = true,
      material_safety_documented = true,
    },
    prohibited_fields = {
      "resident_id",
      "medical_diagnosis",
      "cognitive_profile",
      "assistive_device_identifier",
      "biometric",
      "individual_navigation_history",
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

local function require_table(value, label)
  assert(type(value) == "table", label .. " must be a table")
end

local function validate_string_array(values, label)
  require_table(values, label)

  for index, value in ipairs(values) do
    assert(
      type(value) == "string" and value ~= "",
      label .. "[" .. index .. "] must be a non-empty string"
    )
  end
end

local function contains(values, expected)
  for _, value in ipairs(values) do
    if value == expected then
      return true
    end
  end

  return false
end

local function evaluate_requirements(configuration, requirements)
  local satisfied = 0
  local total = 0
  local missing = {}

  for field, expected in pairs(requirements) do
    total = total + 1

    if normalize_boolean(configuration[field]) == expected then
      satisfied = satisfied + 1
    else
      missing[#missing + 1] = field
    end
  end

  table.sort(missing)
  return satisfied / total, missing
end

local function find_prohibited_inputs(object, observed_fields)
  local findings = {}

  for _, field in ipairs(observed_fields) do
    if contains(object.prohibited_fields, field) then
      findings[#findings + 1] = field
    end
  end

  table.sort(findings)
  return findings
end

local function calculate_knowledge_factor(configuration)
  local evidence_fields = {
    "scope_documented",
    "data_or_design_schema_documented",
    "accessibility_review_completed",
    "maintenance_process_documented",
    "limitations_documented",
  }

  local complete = 0

  for _, field in ipairs(evidence_fields) do
    if normalize_boolean(configuration[field]) == true then
      complete = complete + 1
    end
  end

  return complete / #evidence_fields
end

local function calculate_resource_score(configuration)
  local resource_fields = {
    "local_processing_preferred",
    "low_power_operation_preferred",
    "repair_before_replacement",
    "unnecessary_data_transfer_disabled",
  }

  local met = 0

  for _, field in ipairs(resource_fields) do
    if normalize_boolean(configuration[field]) == true then
      met = met + 1
    end
  end

  return met / #resource_fields
end

local function calculate_harm_risk(configuration, safeguard_coverage, finding_count)
  local external_transfer = normalize_boolean(configuration.external_data_transfer) == true
  local no_human_remediation = normalize_boolean(configuration.human_remediation_available) ~= true
  local unreviewed_automation = normalize_boolean(configuration.automated_action_enabled) == true
    and normalize_boolean(configuration.human_review_available) ~= true

  local risk = (1 - safeguard_coverage) * 0.55
  risk = risk + math.min(finding_count / 3, 1) * 0.30

  if external_transfer then
    risk = risk + 0.05
  end

  if no_human_remediation then
    risk = risk + 0.05
  end

  if unreviewed_automation then
    risk = risk + 0.05
  end

  return clamp(risk, 0, 1)
end

local function classify(safeguard_coverage, harm_risk, finding_count)
  if finding_count == 0 and safeguard_coverage >= 0.85 and harm_risk <= 0.15 then
    return "inclusive, privacy-preserving design candidate"
  end

  if harm_risk <= 0.40 then
    return "conditional: remediate access, privacy, or maintenance gaps"
  end

  return "not suitable: material accessibility, privacy, or safety risk"
end

function M.assess(object_id, configuration, observed_fields)
  local object = OBJECTS[object_id]
  assert(object, "object_id must be an integer from 17 through 20")

  require_table(configuration, "configuration")
  observed_fields = observed_fields or {}
  validate_string_array(observed_fields, "observed_fields")

  local safeguard_coverage, missing = evaluate_requirements(
    configuration,
    object.required
  )

  local prohibited_findings = find_prohibited_inputs(object, observed_fields)
  local knowledge_factor = calculate_knowledge_factor(configuration)
  local resource_score = calculate_resource_score(configuration)

  local eco_impact_value = clamp(
    (0.55 * safeguard_coverage) +
    (0.35 * resource_score) -
    (0.10 * math.min(#prohibited_findings, 1)),
    0,
    1
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
    scope = "offline design and metadata assessment only",
  }
end

function M.assess_transit_service(rows, baseline)
  require_table(rows, "rows")
  require_table(baseline, "baseline")

  local minimum_frequency = assert(
    tonumber(baseline.minimum_frequency_per_hour),
    "baseline.minimum_frequency_per_hour must be numeric"
  )

  local minimum_on_time_percent = assert(
    tonumber(baseline.minimum_on_time_percent),
    "baseline.minimum_on_time_percent must be numeric"
  )

  assert(minimum_frequency >= 0, "baseline.minimum_frequency_per_hour must be non-negative")
  assert(
    minimum_on_time_percent >= 0 and minimum_on_time_percent <= 100,
    "baseline.minimum_on_time_percent must be between 0 and 100"
  )

  local assessed = {}

  for index, row in ipairs(rows) do
    require_table(row, "rows[" .. index .. "]")

    local route = assert(row.route, "row.route is required")
    local stop = assert(row.stop, "row.stop is required")
    local time_window = assert(row.time_window, "row.time_window is required")

    local frequency = assert(
      tonumber(row.frequency_per_hour),
      "row.frequency_per_hour must be numeric"
    )

    local on_time_percent = assert(
      tonumber(row.on_time_percent),
      "row.on_time_percent must be numeric"
    )

    assert(frequency >= 0, "row.frequency_per_hour must be non-negative")
    assert(
      on_time_percent >= 0 and on_time_percent <= 100,
      "row.on_time_percent must be between 0 and 100"
    )

    local accessibility_status = tostring(row.accessibility_status or "unknown")
    local below_frequency = frequency < minimum_frequency
    local below_on_time = on_time_percent < minimum_on_time_percent
    local accessibility_unknown = accessibility_status == "unknown"

    assessed[#assessed + 1] = {
      route = tostring(route),
      stop = tostring(stop),
      time_window = tostring(time_window),
      frequency_per_hour = frequency,
      on_time_percent = on_time_percent,
      accessibility_status = accessibility_status,
      below_published_baseline = below_frequency or below_on_time or accessibility_unknown,
      baseline_gaps = {
        below_frequency and "frequency" or nil,
        below_on_time and "on_time_performance" or nil,
        accessibility_unknown and "accessibility_status_unknown" or nil,
      },
    }
  end

  return assessed
end

function M.validate_obstruction_report(report)
  require_table(report, "report")

  local channel = assert(report.channel, "report.channel is required")
  local location_reference = assert(
    report.location_reference,
    "report.location_reference is required"
  )

  local observed_at_epoch = assert(
    tonumber(report.observed_at_epoch),
    "report.observed_at_epoch must be numeric"
  )

  assert(observed_at_epoch >= 0, "report.observed_at_epoch must be non-negative")

  local allowed_channels = {
    phone = true,
    web = true,
    in_person = true,
  }

  assert(allowed_channels[channel] == true, "channel must be phone, web, or in_person")

  local identity_present = normalize_boolean(report.identity_present) == true
  local account_present = normalize_boolean(report.account_present) == true
  local explanation_required = normalize_boolean(report.explanation_required) == true

  local accepted = not identity_present and not account_present and not explanation_required

  return {
    accepted_for_remediation_queue_review = accepted,
    channel = channel,
    location_reference = tostring(location_reference),
    observed_at_epoch = observed_at_epoch,
    privacy_findings = {
      identity_present and "identity_present" or nil,
      account_present and "account_present" or nil,
      explanation_required and "explanation_required" or nil,
    },
    limitation = "This function validates a minimal report schema only and does not submit, store, geocode, or dispatch a repair request.",
  }
end

function M.evaluate_universal_wayfinding_installation(installation)
  require_table(installation, "installation")

  local tactile = normalize_boolean(installation.tactile_ground_indicators_installed) == true
  local contrast = normalize_boolean(installation.high_contrast_signage_installed) == true
  local reflective = normalize_boolean(installation.reflective_markers_installed) == true
  local universal = normalize_boolean(installation.universally_installed) == true
  local personal_activation = normalize_boolean(
    installation.per_person_activation_not_required
  ) == true

  local complete = tactile and contrast and reflective and universal and personal_activation

  return {
    universally_available = complete,
    missing_elements = {
      not tactile and "tactile_ground_indicators_installed" or nil,
      not contrast and "high_contrast_signage_installed" or nil,
      not reflective and "reflective_markers_installed" or nil,
      not universal and "universally_installed" or nil,
      not personal_activation and "per_person_activation_not_required" or nil,
    },
    limitation = "This check does not determine compliance with applicable accessibility, traffic-control, construction, or material-safety requirements.",
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
  return #values == 0 and "none" or table.concat(values, ", ")
end

function M.render_report(result)
  require_table(result, "result")

  return table.concat({
    "Equitable Mobility Assessment",
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
    "Usage: lua equitable_mobility_assessor.lua <object-id:17-20> <config-file>\n" ..
    "Use key=true or key=false. Repeat observed_field=<field> for schema inputs.\n"
  )
end

local function main(arguments)
  local object_id = tonumber(arguments[1])
  local config_path = arguments[2]

  if not object_id or not config_path then
    usage()
    return 2
  end

  local ok, output_or_error = pcall(function()
    local configuration, observed_fields = M.parse_key_value_file(config_path)
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
