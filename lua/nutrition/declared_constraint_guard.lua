-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: candidate-estimate compatibility with declared hard bounds.
-- Quantities are interval totals. No diagnosis, clamping, or prescription.
-- Source and provenance fields are supplied claims, not verified guidance.
-- No persistence, network, clock, device access, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local metric_units = {
    total_fluid_ml = "ml",
    total_water_ml = "ml",
    dietary_protein_g = "g",
    dietary_sodium_mg = "mg",
    dietary_energy_kcal = "kcal"
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge and value < math.huge
end

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 160
end

local function shape(value, allowed)
    if not plain(value) then return false end
    local count = 0
    for key in next, value do
        count = count + 1
        if count > 24 or not allowed[key] then return false end
    end
    return true
end

function M.check(candidate, constraint, expected_constraint_revision)
    local output = {
        schema_version = "declared-constraint-review-v1",
        status = "unresolved",
        candidate_target_presentation = "withhold_pending_review",
        findings = {},
        evidence_verification = "not_performed",
        diagnosis_inferred = false,
        constraint_modified = false,
        service_access_decision = "outside_this_module"
    }

    local function add(code, field)
        output.findings[#output.findings + 1] = {
            code = code, field = field
        }
    end

    if not shape(candidate, {
        schema_version = true, metric = true, unit = true,
        accounting_scope = true,
        interval_start_s = true, interval_end_s = true,
        low = true, high = true, model_revision = true
    }) then
        add("invalid_candidate_shape", "candidate")
        return output
    end

    if not shape(constraint, {
        schema_version = true, metric = true, unit = true,
        accounting_scope = true,
        interval_start_s = true, interval_end_s = true,
        minimum = true, maximum = true,
        revision = true, declaration_basis = true,
        source_reference = true
    }) then
        add("constraint_record_required", "constraint")
        return output
    end

    if rawget(candidate, "schema_version") ~= "constraint-candidate-v1" then
        add("unsupported_candidate_schema", "candidate.schema_version")
    end
    if rawget(constraint, "schema_version") ~= "declared-bound-v1" then
        add("unsupported_constraint_schema", "constraint.schema_version")
    end

    local revision = rawget(constraint, "revision")
    if not text(expected_constraint_revision)
        or not text(revision)
        or revision ~= expected_constraint_revision then
        add("constraint_revision_unresolved", "constraint.revision")
    end

    local metric = rawget(candidate, "metric")
    local expected_unit
    if type(metric) == "string" then expected_unit = metric_units[metric] end

    if expected_unit == nil then
        add("unsupported_metric", "candidate.metric")
    elseif rawget(candidate, "unit") ~= expected_unit
        or rawget(constraint, "unit") ~= expected_unit then
        add("unit_mismatch", "unit")
    end

    if metric ~= rawget(constraint, "metric") then
        add("metric_mismatch", "metric")
    end

    local scope = rawget(candidate, "accounting_scope")
    if not text(scope) or scope ~= rawget(constraint, "accounting_scope") then
        add("accounting_scope_unresolved", "accounting_scope")
    end

    for _, pair in ipairs({
        { candidate, "candidate" }, { constraint, "constraint" }
    }) do
        local start_s = rawget(pair[1], "interval_start_s")
        local end_s = rawget(pair[1], "interval_end_s")
        if not finite(start_s) or not finite(end_s) or end_s <= start_s then
            add("invalid_interval", pair[2])
        end
    end

    if rawget(candidate, "interval_start_s") ~=
            rawget(constraint, "interval_start_s")
        or rawget(candidate, "interval_end_s") ~=
            rawget(constraint, "interval_end_s") then
        add("interval_mismatch", "interval")
    end

    local low = rawget(candidate, "low")
    local high = rawget(candidate, "high")
    if not finite(low) or not finite(high) or low < 0 or high < low then
        add("invalid_candidate_bounds", "candidate")
    end

    local minimum = rawget(constraint, "minimum")
    local maximum = rawget(constraint, "maximum")
    if minimum == nil and maximum == nil then
        add("declared_bound_required", "constraint")
    end
    if minimum ~= nil and (not finite(minimum) or minimum < 0) then
        add("invalid_minimum", "constraint.minimum")
    end
    if maximum ~= nil and (not finite(maximum) or maximum < 0) then
        add("invalid_maximum", "constraint.maximum")
    end
    if finite(minimum) and finite(maximum) and minimum > maximum then
        add("inverted_constraint", "constraint")
    end

    local basis = rawget(constraint, "declaration_basis")
    if basis ~= "user_declared"
        and basis ~= "user_reported_clinician_guidance" then
        add("declaration_basis_required", "constraint.declaration_basis")
    end

    if not text(rawget(constraint, "source_reference")) then
        add("source_reference_required", "constraint.source_reference")
    end
    if not text(rawget(candidate, "model_revision")) then
        add("model_revision_required", "candidate.model_revision")
    end

    if #output.findings > 0 then return output end

    local conflict = false
    if minimum ~= nil and low < minimum then
        conflict = true
        add("candidate_extends_below_declared_minimum", "candidate.low")
    end
    if maximum ~= nil and high > maximum then
        conflict = true
        add("candidate_extends_above_declared_maximum", "candidate.high")
    end

    output.constraint_revision = revision
    output.model_revision = rawget(candidate, "model_revision")

    if conflict then
        output.status = "declared_constraint_conflict"
        output.candidate_target_presentation = "withhold_as_actionable_target"
    else
        output.status = "within_supplied_declared_bounds"
        output.candidate_target_presentation =
            "requires_other_applicability_and_evidence_checks"
    end

    return output
end

return M
