#!/usr/bin/env lua
-- Lua 5.4
-- Offline validator and retention planner for privacy-preserving civic data systems.
-- This tool analyzes supplied metadata only. It does not access databases, services,
-- identity vaults, consent records, sensors, or external systems.

local M = {}

local OBJECTS = {
  [6] = {
    name = "Data Minimization Mandate Engine",
    required = {
      metadata_only_scan = true,
      permitted_domain_declared = true,
      consent_gate_required = true,
      quarantine_requires_review = true,
      direct_database_access_disabled = true,
    },
    prohibited_fields = {
      "identity",
      "biometric",
      "did",
      "diagnosis",
      "augmentation_status",
      "behavioral_profile",
    },
  },
  [7] = {
    name = "Ephemeral Session Manager",
    required = {
      single_use_token = true,
      automatic_expiry = true,
      persistent_profile_linkage_disabled = true,
      cross_service_tracking_disabled = true,
      token_content_minimized = true,
    },
    prohibited_fields = {
      "resident_id",
      "persistent_profile_id",
      "did",
      "biometric",
      "behavioral_profile",
    },
  },
  [8] = {
    name = "Consent Artifact Registry",
    required = {
      stores_consent_existence_only = true,
      stores_action_reference = true,
      stores_scope = true,
      stores_expiry = true,
      resident_identity_not_stored = true,
      consent_mutation_auditable = true,
    },
    prohibited_fields = {
      "resident_id",
      "real_name",
      "biometric",
      "medical_data",
      "did",
      "persistent_profile_id",
    },
  },
  [9] = {
    name = "Non-Retaliation Policy Enforcer",
    required = {
      baseline_service_unconditional = true,
      accommodation_unconditional = true,
      appeal_unconditional = true,
      policy_input_audit_enabled = true,
      violating_policy_blocked = true,
      human_review_path_available = true,
    },
    prohibited_fields = {
      "contribution",
      "productivity",
      "credibility",
      "reputation",
      "public_disclosure",
      "identity_verification",
    },
  },
  [10] = {
    name = "Automated Data Retention Purger",
    required = {
      retention_period_declared = true,
      purpose_declared = true,
      expiry_deletion_scheduled = true,
      deletion_log_minimized = true,
      legal_hold_review_supported = true,
      deletion_failure_reported = true,
    },
    prohibited_fields = {
      "indefinite_retention",
      "retention_without_purpose",
      "manual_retention_extension",
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

local function contains(values, target)
  for _, value in ipairs(values) do
    if value == target then
      return true
    end
  end

  return false
end

local function ensure_string_array(values, label)
  require_table(values, label)

  for index, value in ipairs(values) do
    assert(
      type(value) == "string" and value ~= "",
      label .. "[" .. index .. "] must be a non-empty string"
    )
  end
end

local function count_required_safeguards(configuration, requirements)
  local total = 0
  local satisfied = 0
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

local function find_prohibited_fields(object, observed_fields)
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
    "policy_documented",
    "schema_documented",
    "retention_schedule_documented",
    "independent_review_completed",
    "appeal_or_remediation_documented",
  }

  local count = 0

  for _, field in ipairs(evidence_fields) do
    if normalize_boolean(configuration[field]) == true then
      count = count + 1
    end
  end

  return count / #evidence_fields
end

local function calculate_eco_impact(configuration, compliance_score, violation_count)
  local local_processing = normalize_boolean(configuration.local_processing_preferred) == true
  local unnecessary_transfer_disabled =
    normalize_boolean(configuration.unnecessary_data_transfer_disabled) == true

  local resource_efficiency = 0

  if local_processing then
    resource_efficiency = resource_efficiency + 0.5
  end

  if unnecessary_transfer_disabled then
    resource_efficiency = resource_efficiency + 0.5
  end

  return clamp(
    (0.55 * compliance_score) +
    (0.30 * resource_efficiency) -
    (0.15 * math.min(violation_count, 1)),
    0,
    1
  )
end

local function calculate_harm_risk(configuration, compliance_score, violation_count)
  local external_transfer = normalize_boolean(configuration.external_data_transfer) == true
  local automated_action = normalize_boolean(configuration.automatic_quarantine_or_deletion) == true
  local review_required = normalize_boolean(configuration.quarantine_requires_review) == true
  local remediation = normalize_boolean(configuration.appeal_or_remediation_documented) == true

  local risk = (1 - compliance_score) * 0.55
  risk = risk + math.min(violation_count / 4, 1) * 0.30

  if external_transfer then
    risk = risk + 0.10
  end

  if automated_action and not review_required and not remediation then
    risk = risk + 0.10
  end

  return clamp(risk, 0, 1)
end

local function classify_result(compliance_score, harm_risk, violation_count)
  if violation_count == 0 and compliance_score >= 0.85 and harm_risk <= 0.15 then
    return "privacy-preserving design candidate"
  end

  if harm_risk <= 0.40 then
    return "conditional: remediate findings before deployment"
  end

  return "not suitable: material data-rights or service-access risk"
end

function M.assess(object_id, configuration, observed_fields)
  local object = OBJECTS[object_id]

  assert(object, "object_id must be an integer from 6 through 10")
  require_table(configuration, "configuration")

  observed_fields = observed_fields or {}
  ensure_string_array(observed_fields, "observed_fields")

  local compliance_score, missing = count_required_safeguards(
    configuration,
    object.required
  )

  local prohibited_findings = find_prohibited_fields(object, observed_fields)
  local knowledge_factor = calculate_knowledge_factor(configuration)
  local eco_impact_value = calculate_eco_impact(
    configuration,
    compliance_score,
    #prohibited_findings
  )

  local harm_risk = calculate_harm_risk(
    configuration,
    compliance_score,
    #prohibited_findings
  )

  return {
    object_id = object_id,
    object_name = object.name,
    status = classify_result(compliance_score, harm_risk, #prohibited_findings),
    safeguard_coverage = compliance_score,
    knowledge_factor = knowledge_factor,
    eco_impact_value = eco_impact_value,
    harm_risk = harm_risk,
    unmet_safeguards = missing,
    prohibited_data_or_policy_inputs = prohibited_findings,
    assessment_scope = "offline metadata and configuration assessment only",
  }
end

function M.retention_due(record, now_epoch)
  require_table(record, "record")
  assert(type(now_epoch) == "number" and now_epoch >= 0, "now_epoch must be non-negative")

  local created_at = assert(
    tonumber(record.created_at_epoch),
    "record.created_at_epoch must be a number"
  )

  local retention_seconds = assert(
    tonumber(record.retention_seconds),
    "record.retention_seconds must be a number"
  )

  assert(created_at >= 0, "record.created_at_epoch must be non-negative")
  assert(retention_seconds >= 0, "record.retention_seconds must be non-negative")

  local legal_hold = normalize_boolean(record.legal_hold) == true
  local expires_at = created_at + retention_seconds

  return {
    record_reference = tostring(record.record_reference or ""),
    expires_at_epoch = expires_at,
    due_for_deletion = not legal_hold and now_epoch >= expires_at,
    legal_hold = legal_hold,
  }
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
    "Civic Data-Rights Assessment",
    "Object: " .. result.object_id .. " — " .. result.object_name,
    "Status: " .. result.status,
    "Safeguard coverage: " .. percent(result.safeguard_coverage),
    "knowledge_factor: " .. percent(result.knowledge_factor),
    "eco_impact_value: " .. percent(result.eco_impact_value),
    "harm_risk: " .. percent(result.harm_risk),
    "Unmet safeguards: " .. join_or_none(result.unmet_safeguards),
    "Prohibited data or policy inputs: " ..
      join_or_none(result.prohibited_data_or_policy_inputs),
    "Scope: " .. result.assessment_scope,
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
        local parsed = normalize_boolean(value)
        configuration[key] = parsed ~= nil and parsed or value
      end
    end
  end

  file:close()
  return configuration, observed_fields
end

local function usage()
  io.stderr:write(
    "Usage: lua civic_data_rights_auditor.lua <object-id:6-10> <config-file>\n" ..
    "Use key=true or key=false. Repeat observed_field=<field> for each observed field.\n"
  )
end

local function main(arguments)
  local object_id = tonumber(arguments[1])
  local config_path = arguments[2]

  if not object_id or not config_path then
    usage()
    return 2
  end

  local ok, report_or_error = pcall(function()
    local configuration, observed_fields = M.parse_key_value_file(config_path)
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
