-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Structural validation only. Source, revision, and known-state are claims.

local C = require("lua.nutrition.portion_constants").get()
local M = {}

function M.add(findings, code, field)
    findings[#findings + 1] = {
        code = code, field = field, severity = "error"
    }
end

function M.text(value)
    return type(value) == "string" and #value > 0 and #value <= 160
end

function M.finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge and value < math.huge
end

function M.normalize_zero(value)
    if value == 0 then return 0.0 end
    return value
end

function M.shape(value, fields, findings, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        M.add(findings, "plain_record_required", path)
        return false
    end

    local allowed, required = {}, {}
    for _, field in ipairs(fields) do
        allowed[field] = true
        required[#required + 1] = field
    end

    local unexpected, invalid_key = {}, false
    local count = 0
    for key in next, value do
        count = count + 1
        if count > C.MAX_RECORD_FIELDS then
            M.add(findings, "field_budget_exceeded", path)
            return false
        end
        if type(key) ~= "string" or #key > 96 then
            invalid_key = true
        elseif not allowed[key] then
            unexpected[#unexpected + 1] = key
        end
    end

    if invalid_key then M.add(findings, "invalid_field_key", path) end
    table.sort(unexpected)
    for _, field in ipairs(unexpected) do
        M.add(findings, "unexpected_field", path .. "." .. field)
    end

    table.sort(required)
    for _, field in ipairs(required) do
        if rawget(value, field) == nil then
            M.add(findings, "required_field_missing", path .. "." .. field)
        end
    end
    return true
end

local fields = {
    "schema_version", "source", "release", "record_revision",
    "food_reference", "preparation_state", "nutrient_name",
    "nutrient_unit", "nutrient_known", "nutrient_per_100g"
}

function M.validate(record, findings, path)
    local initial_count = #findings
    if not M.shape(record, fields, findings, path) then return nil end

    if rawget(record, "schema_version") ~= C.SCHEMA_VERSIONS.composition then
        M.add(findings, "unsupported_composition_schema",
            path .. ".schema_version")
    end

    for _, field in ipairs({
        "source", "release", "record_revision", "food_reference"
    }) do
        local value = rawget(record, field)
        if value ~= nil and not M.text(value) then
            M.add(findings, "invalid_text", path .. "." .. field)
        end
    end

    local preparation = rawget(record, "preparation_state")
    if preparation ~= nil and
        (type(preparation) ~= "string"
            or not C.PREPARATION_STATES[preparation]) then
        M.add(findings, "unsupported_preparation_state",
            path .. ".preparation_state")
    end

    local name = rawget(record, "nutrient_name")
    local spec
    if type(name) == "string" then spec = C.NUTRIENTS[name] end
    if name ~= nil and spec == nil then
        M.add(findings, "unsupported_nutrient", path .. ".nutrient_name")
    end

    local unit = rawget(record, "nutrient_unit")
    if unit ~= nil and
        (type(unit) ~= "string" or not C.NUTRIENT_UNITS[unit]) then
        M.add(findings, "unsupported_nutrient_unit", path .. ".nutrient_unit")
    elseif spec and unit ~= nil and unit ~= spec.unit then
        M.add(findings, "nutrient_unit_mismatch", path .. ".nutrient_unit")
    end

    local known = rawget(record, "nutrient_known")
    if known ~= nil and type(known) ~= "boolean" then
        M.add(findings, "nutrient_known_not_boolean", path .. ".nutrient_known")
    elseif known == false then
        M.add(findings, "nutrient_value_unknown", path .. ".nutrient_known")
    end

    local value = rawget(record, "nutrient_per_100g")
    if value ~= nil then
        if not M.finite(value) then
            M.add(findings, "nutrient_value_nonfinite",
                path .. ".nutrient_per_100g")
        elseif value < 0 then
            M.add(findings, "nutrient_value_negative",
                path .. ".nutrient_per_100g")
        elseif spec and value > spec.maximum_per_100g then
            M.add(findings, "nutrient_value_outside_profile",
                path .. ".nutrient_per_100g")
        end
    end

    if #findings ~= initial_count then return nil end

    local snapshot = {}
    for _, field in ipairs(fields) do
        snapshot[field] = rawget(record, field)
    end
    snapshot.nutrient_per_100g = M.normalize_zero(value)
    return snapshot
end

function M.unavailable(operation, findings)
    local reason = "validation_failed"
    if findings[1] then reason = findings[1].code end
    return {
        kind = "unavailable",
        schema_version = C.SCHEMA_VERSIONS.unavailable_output,
        operation = operation,
        status = "unavailable",
        reason = reason,
        findings = findings,
        evidence_verification = "not_performed"
    }
end

return M
