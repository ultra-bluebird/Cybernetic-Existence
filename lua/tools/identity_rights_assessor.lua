#!/usr/bin/env lua
-- Lua 5.4
-- Offline decision-support assessment for privacy-preserving civic identity designs.
-- Input is a Lua table or a key=value text file. This tool never contacts registries,
-- services, identity vaults, or distributed ledgers.

local M = {}

local OBJECTS = {
  [1] = {
    name = "Sovereign Identity Vault",
    required = {
      resident_control = true,
      local_encryption = true,
      credential_minimization = true,
      no_direct_city_query = true,
    },
    privacy_weight = 1.00,
    service_weight = 0.70,
  },
  [2] = {
    name = "Self-Sovereign Identity Anchor",
    required = {
      public_key_reference_only = true,
      alias_optional = true,
      excludes_real_name = true,
      excludes_biometrics = true,
      excludes_medical_data = true,
      resident_key_control = true,
    },
    privacy_weight = 0.90,
    service_weight = 0.55,
  },
  [3] = {
    name = "Identity-Neutral Service Router",
    required = {
      functional_request_only = true,
      anonymous_session = true,
      no_did_processing = true,
      no_biometric_processing = true,
      no_name_processing = true,
      no_augmentation_status_processing = true,
    },
    privacy_weight = 1.00,
    service_weight = 1.00,
  },
  [4] = {
    name = "Declared Identity Acknowledgement Protocol",
    required = {
      self_declaration_accepted = true,
      no_challenge_or_scoring = true,
      local_storage_only = true,
      baseline_service_unconditional = true,
    },
    privacy_weight = 0.95,
    service_weight = 0.85,
  },
  [5] = {
    name = "Private Credential Issuance Portal",
    required = {
      functional_need_basis = true,
      diagnosis_not_required = true,
      device_details_not_required = true,
      augmentation_status_not_required = true,
      issues_minimized_credential = true,
    },
    privacy_weight = 0.95,
    service_weight = 0.95,
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

local function score_required(configuration, requirements)
  local total = 0
  local met = 0
  local missing = {}

  for requirement, expected in pairs(requirements) do
    total = total + 1
    local actual = normalize_boolean(configuration[requirement])

    if actual == expected then
      met = met + 1
    else
      missing[#missing + 1] = requirement
    end
  end

  return met / total, missing
end

local function contains_sensitive_collection(configuration)
  local prohibited = {
    "collects_real_name",
    "collects_biometrics",
    "collects_medical_data",
    "collects_did",
    "collects_augmentation_status",
    "centralized_identity_lookup",
  }

  local findings = {}

  for _, field in ipairs(prohibited) do
    if normalize_boolean(configuration[field]) == true then
      findings[#findings + 1] = field
    end
  end

  return findings
end

local function make_assessment(object_id, configuration)
  local definition = OBJECTS[object_id]
  assert(definition, "object_id must be an integer from 1 through 5")
  require_table(configuration, "configuration")

  local requirement_score, missing = score_required(configuration, definition.required)
  local sensitive_collection = contains_sensitive_collection(configuration)
  local sensitive_penalty = #sensitive_collection / 6

  local privacy_score = clamp(
    requirement_score * definition.privacy_weight - sensitive_penalty,
    0,
    1
  )

  local service_score = clamp(
    requirement_score * definition.service_weight,
    0,
    1
  )

  local knowledge_inputs = {
    "policy_documented",
    "data_schema_documented",
    "retention_period_documented",
    "independent_review_completed",
    "resident_redress_available",
  }

  local documented = 0
  for _, field in ipairs(knowledge_inputs) do
    if normalize_boolean(configuration[field]) == true then
      documented = documented + 1
    end
  end

  local knowledge_factor = documented / #knowledge_inputs

  local eco_impact_value = clamp(
    0.35 * privacy_score +
    0.35 * service_score +
    0.30 * normalize_boolean(configuration.supports_low_energy_local_processing) and 1 or 0,
    0,
    1
  )

  local harm_risk = clamp(
    (1 - requirement_score) * 0.55 +
    sensitive_penalty * 0.35 +
    (normalize_boolean(configuration.external_data_transfer) == true and 0.10 or 0),
    0,
    1
  )

  local status
  if harm_risk <= 0.15 and privacy_score >= 0.85 and service_score >= 0.80 then
    status = "privacy-preserving design candidate"
  elseif harm_risk <= 0.40 then
    status = "conditional: resolve safeguards before deployment"
  else
    status = "not suitable: material identity or data-rights risk"
  end

  return {
    object_id = object_id,
    object_name = definition.name,
    status = status,
    requirement_score = requirement_score,
    privacy_score = privacy_score,
    service_access_score = service_score,
    knowledge_factor = knowledge_factor,
    eco_impact_value = eco_impact_value,
    harm_risk = harm_risk,
    unmet_requirements = missing,
    sensitive_collection_findings = sensitive_collection,
  }
end

local function format_percent(value)
  return string.format("%.1f%%", value * 100)
end

local function join_or_none(values)
  if #values == 0 then
    return "none"
  end
  return table.concat(values, ", ")
end

function M.assess(object_id, configuration)
  return make_assessment(object_id, configuration)
end

function M.render_report(result)
  require_table(result, "result")

  local lines = {
    "Identity and Data-Rights Assessment",
    "Object: " .. result.object_id .. " — " .. result.object_name,
    "Status: " .. result.status,
    "Requirement coverage: " .. format_percent(result.requirement_score),
    "Privacy score: " .. format_percent(result.privacy_score),
    "Service-access score: " .. format_percent(result.service_access_score),
    "knowledge_factor: " .. format_percent(result.knowledge_factor),
    "eco_impact_value: " .. format_percent(result.eco_impact_value),
    "harm_risk: " .. format_percent(result.harm_risk),
    "Unmet requirements: " .. join_or_none(result.unmet_requirements),
    "Sensitive-collection findings: " .. join_or_none(result.sensitive_collection_findings),
    "Scope: Offline decision support only; this report does not verify credentials or identities.",
  }

  return table.concat(lines, "\n")
end

function M.parse_key_value_file(path)
  assert(type(path) == "string" and path ~= "", "path must be a non-empty string")

  local file, open_error = io.open(path, "r")
  assert(file, "cannot open configuration file: " .. tostring(open_error))

  local configuration = {}

  for line in file:lines() do
    local stripped = trim(line)

    if stripped ~= "" and stripped:sub(1, 1) ~= "#" then
      local key, value = stripped:match("^([%a_][%w_]*)%s*=%s*(.-)%s*$")
      assert(key and value, "invalid configuration line: " .. line)

      local parsed_boolean = normalize_boolean(value)
      configuration[key] = parsed_boolean ~= nil and parsed_boolean or value
    end
  end

  file:close()
  return configuration
end

local function usage()
  io.stderr:write(
    "Usage: lua identity_rights_assessor.lua <object-id:1-5> <config-file>\n" ..
    "Config format: key=true or key=false, one entry per line.\n"
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
    local configuration = M.parse_key_value_file(config_path)
    local result = M.assess(object_id, configuration)
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
