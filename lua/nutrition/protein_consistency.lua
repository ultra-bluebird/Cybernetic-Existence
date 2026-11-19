-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: descriptive protein consistency over admitted observed days.
-- No imputation, usual-intake inference, persistence, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local completeness_states = {
    complete_day = true,
    partial_day = true,
    unknown_completeness = true
}

local value_states = {
    known = true,
    unknown = true,
    not_collected = true,
    not_applicable = true
}

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge and value < math.huge
end

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 128
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function sequence(value)
    if not plain(value) then return nil end
    local count = 0
    for key in next, value do
        if type(key) ~= "number" or key % 1 ~= 0
            or key < 1 or key > 366 then
            return nil
        end
        count = count + 1
    end
    for index = 1, count do
        if rawget(value, index) == nil then return nil end
    end
    return count
end

local function finding(output, code, index, severity)
    output.est_findings[#output.est_findings + 1] = {
        code = code,
        schedule_index = index,
        severity = severity
    }
end

function M.evaluate(days, minimum_admitted_days)
    local output = {
        schema_version = "protein-consistency-v1",
        est_status = "unavailable",
        est_target = "admitted_observed_days",
        est_imputation_performed = false,
        est_completeness_verification = "not_performed",
        est_findings = {},
        est_excluded_days = {},
        est_admitted_day_count = 0,
        est_known_zero_day_count = 0
    }

    if math.type(minimum_admitted_days) ~= "integer"
        or minimum_admitted_days < 2
        or minimum_admitted_days > 366 then
        finding(output, "invalid_minimum_day_threshold", nil, "error")
        return output
    end

    local scheduled = sequence(days)
    if scheduled == nil then
        finding(output, "invalid_day_sequence", nil, "error")
        return output
    end

    local allowed = {
        obs_day_label = true,
        obs_completeness_state = true,
        obs_protein_value_state = true,
        obs_protein_g = true,
        comp_protein_contributors_covered = true
    }

    local seen = {}
    local values = {}
    local invalid = false

    for index = 1, scheduled do
        local day = rawget(days, index)
        local valid = plain(day)

        if valid then
            for key in next, day do
                if not allowed[key] then valid = false end
            end
        end

        if not valid then
            invalid = true
            finding(output, "invalid_day_record", index, "error")
        else
            local label = rawget(day, "obs_day_label")
            local completeness = rawget(day, "obs_completeness_state")
            local state = rawget(day, "obs_protein_value_state")
            local amount = rawget(day, "obs_protein_g")
            local covered =
                rawget(day, "comp_protein_contributors_covered")

            local valid_label = text(label)
            if not valid_label or seen[label] then
                valid = false
            else
                seen[label] = true
            end

            if type(completeness) ~= "string"
                or not completeness_states[completeness]
                or type(state) ~= "string"
                or not value_states[state]
                or type(covered) ~= "boolean" then
                valid = false
            end

            if state == "known" then
                if not finite(amount) or amount < 0 then
                    valid = false
                end
            elseif amount ~= nil then
                valid = false
            end

            if not valid then
                invalid = true
                finding(output, "invalid_day_fields", index, "error")
            else
                local reason
                if completeness ~= "complete_day" then
                    reason = "day_not_declared_complete"
                elseif state ~= "known" then
                    reason = "protein_" .. state
                elseif not covered then
                    reason = "protein_contributors_incomplete"
                end

                if reason then
                    output.est_excluded_days[
                        #output.est_excluded_days + 1] = {
                        schedule_index = index,
                        reason = reason,
                        protein_value_state = state,
                        completeness_state = completeness
                    }
                else
                    values[#values + 1] = amount + 0.0
                    if amount == 0 then
                        output.est_known_zero_day_count =
                            output.est_known_zero_day_count + 1
                    end
                end
            end
        end
    end

    if invalid then return output end

    local n = #values
    output.est_scheduled_day_count = scheduled
    output.est_admitted_day_count = n
    output.est_excluded_day_count = scheduled - n
    output.est_minimum_admitted_days = minimum_admitted_days

    if scheduled > 0 then
        output.est_scheduled_day_admission_fraction = n / scheduled
    end

    if n == 0 then
        finding(output, "no_admitted_days", nil, "warning")
        return output
    end

    local mean, m2 = 0.0, 0.0
    for index, value in ipairs(values) do
        local delta = value - mean
        mean = mean + delta / index
        m2 = m2 + delta * (value - mean)
        if not finite(mean) or not finite(m2) then
            finding(output, "numeric_overflow", nil, "error")
            return output
        end
    end

    output.est_mean_protein_g_per_day = mean
    output.est_status = "mean_only"

    if n < minimum_admitted_days then
        finding(output, "insufficient_admitted_days", nil, "warning")
        return output
    end

    if m2 < 0 then
        finding(output, "internal_variance_invariant_failed", nil, "error")
        output.est_status = "unavailable"
        output.est_mean_protein_g_per_day = nil
        return output
    end

    local sd = math.sqrt(m2 / (n - 1))
    output.est_sample_sd_protein_g_per_day = sd

    if mean == 0 then
        finding(output, "cv_zero_denominator", nil, "warning")
        output.est_status = "cv_unavailable"
        return output
    end

    local cv = sd / mean
    if not finite(cv) then
        finding(output, "numeric_overflow", nil, "error")
        output.est_status = "cv_unavailable"
        return output
    end

    output.est_observed_day_protein_cv = cv
    output.est_status = "descriptive_cv_available"
    output.est_cv_precision = "not_quantified"
    return output
end

return M
