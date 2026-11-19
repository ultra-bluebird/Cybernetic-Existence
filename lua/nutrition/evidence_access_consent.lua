-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: evidence projection, improvement review, permission eligibility.
-- Supplied states are claims; no independent verification is performed.
-- No I/O, persistence, identity inference, device control, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local axes = {
    { "parse", {
        not_started = true, passed = true, failed = true
    } },
    { "execution", {
        not_started = true, in_progress = true, completed = true,
        terminated = true, outcome_lost = true
    } },
    { "observation", {
        reported = true, instrument_recorded = true,
        derived = true, unavailable = true
    } },
    { "assessment", {
        not_assessed = true, supported = true, contradicted = true,
        conflicted = true, inconclusive = true
    } },
    { "authority", {
        not_assessed = true, authorized_for_scope = true,
        unauthorized_for_scope = true
    } },
    { "authenticity", {
        not_assessed = true, checked = true, check_failed = true
    } }
}

local permissions = {
    local_processing = true,
    persistence = true,
    reminders = true,
    research_use = true,
    external_disclosure = true
}

local consent_states = {
    absent = true, granted = true, declined = true,
    withdrawn = true, expired = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, allowed)
    if not plain(value) then return false end
    local count = 0
    for key in next, value do
        count = count + 1
        if count > 32 or not allowed[key] then return false end
    end
    return true
end

local function label(value)
    return type(value) == "string" and #value > 0 and #value <= 128
        and value:match("^[A-Za-z0-9_-]+$") ~= nil
end

function M.project(evidence)
    local allowed = {}
    for _, spec in ipairs(axes) do allowed[spec[1]] = true end

    if not shape(evidence, allowed) then
        return nil, "invalid_evidence_record"
    end

    local output = {}
    for _, spec in ipairs(axes) do
        local state = rawget(evidence, spec[1])
        if type(state) ~= "string" or not spec[2][state] then
            return nil, "invalid_or_missing_axis"
        end
        output[#output + 1] = spec[1] .. ": " .. state
    end
    return output
end

function M.check_projection(evidence, projection)
    local expected, reason = M.project(evidence)
    if expected == nil then return false, reason end
    if not plain(projection) then return false, "invalid_projection" end

    local count = 0
    for key in next, projection do
        if type(key) ~= "number" or key % 1 ~= 0
            or key < 1 or key > #expected then
            return false, "unexpected_projection_field"
        end
        count = count + 1
    end

    if count ~= #expected then return false, "incomplete_projection" end
    for index, text in ipairs(expected) do
        if rawget(projection, index) ~= text then
            return false, "projection_claim_mismatch"
        end
    end
    return true
end

function M.improvement(record)
    local output = {
        schema_version = "nutrition-improvement-review-v1",
        status = "unresolved",
        status_basis = "invalid_comparison_record",
        gaps = {},
        violations = {},
        evidence_verification = "not_performed"
    }

    if not shape(record, {
        quality = true, access = true,
        continuity = true, rights = true, privacy = true
    }) then
        return output
    end

    local better = false
    for _, name in ipairs({ "quality", "access" }) do
        local state = rawget(record, name)
        if state == "worse" then
            output.violations[#output.violations + 1] = name
        elseif state == "better" then
            better = true
        elseif state ~= "same" then
            output.gaps[#output.gaps + 1] = name
        end
    end

    for _, name in ipairs({ "continuity", "rights", "privacy" }) do
        local state = rawget(record, name)
        if state == "violated" then
            output.violations[#output.violations + 1] = name
        elseif state ~= "satisfied" then
            output.gaps[#output.gaps + 1] = name
        end
    end

    if #output.violations > 0 then
        output.status = "not_supported"
        output.status_basis = "known_regression_or_constraint_violation"
    elseif #output.gaps > 0 then
        output.status_basis = "required_comparison_gap"
    elseif better then
        output.status = "supported_within_declared_comparison"
        output.status_basis = "noncompensatory_conditions_satisfied"
    else
        output.status = "no_demonstrated_improvement"
        output.status_basis = "no_strict_improvement"
    end

    return output
end

function M.permission(record, operation)
    local output = {
        schema_version = "nutrition-permission-check-v1",
        status = "unavailable",
        eligible_for_scoped_processing = false,
        external_action_authorized = false,
        evidence_verification = "not_performed"
    }

    if not shape(operation, {
        permission = true, purpose = true, scope = true
    }) then
        return output
    end

    local permission = rawget(operation, "permission")
    local purpose = rawget(operation, "purpose")
    local scope = rawget(operation, "scope")

    if type(permission) ~= "string" or not permissions[permission]
        or not label(purpose) or not label(scope) then
        return output
    end

    if record == nil then
        output.status = "absent"
        return output
    end

    if not shape(record, {
        permission = true, purpose = true, scope = true, state = true
    }) then
        return output
    end

    local state = rawget(record, "state")
    if type(state) ~= "string" or not consent_states[state] then
        return output
    end

    if rawget(record, "permission") ~= permission
        or rawget(record, "purpose") ~= purpose
        or rawget(record, "scope") ~= scope then
        output.status = "scope_mismatch"
        return output
    end

    output.status = state
    output.eligible_for_scoped_processing = state == "granted"
    return output
end

return M
