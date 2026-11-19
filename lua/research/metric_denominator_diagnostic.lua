-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only, not identity, consent, or execution authority.
--
-- Arithmetic over supplied synthetic case classifications.
-- No network, file, device, persistence, or participant inference.
-- Does not authenticate cohort completeness or establish intent.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"
local MAX_CASES = 4096

local QUALITY = {
    confirmed = true,
    failed = true,
    unresolved = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function length(array)
    if not plain(array) then return nil end
    local count, maximum = 0, 0

    for key in next, array do
        count = count + 1
        if count > MAX_CASES
            or type(key) ~= "number"
            or key < 1 or key > MAX_CASES
            or key % 1 ~= 0 then
            return nil
        end
        maximum = math.max(maximum, key)
    end

    if count ~= maximum then return nil end
    return count
end

local function ratio(numerator, denominator)
    if denominator == 0 then
        return {status = "not_applicable", denominator = 0}
    end

    return {
        status = "computed",
        numerator = numerator,
        denominator = denominator,
        value = numerator / denominator
    }
end

local function invalid(reason)
    return {
        status = "validation_error",
        implementation_version = VERSION,
        reason = reason
    }
end

function M.summarize(cases)
    local n = length(cases)
    if n == nil then
        return invalid("bounded_dense_case_array_required")
    end

    local due, included, closed_included = 0, 0, 0
    local qualified, quality_failed, quality_unknown = 0, 0, 0
    local closed_without_confirmed_quality = 0

    local allowed = {
        due = true,
        closed = true,
        qualified_completion = true,
        dashboard_included = true
    }

    for i = 1, n do
        local case = cases[i]
        if not plain(case) then return invalid("plain_case_required") end

        for key in next, case do
            if not allowed[key] then
                return invalid("unknown_case_field")
            end
        end

        if type(case.due) ~= "boolean"
            or type(case.closed) ~= "boolean"
            or type(case.dashboard_included) ~= "boolean"
            or type(case.qualified_completion) ~= "string"
            or not QUALITY[case.qualified_completion] then
            return invalid("invalid_case_classification")
        end

        if case.due then
            due = due + 1

            if case.dashboard_included then
                included = included + 1
                if case.closed then
                    closed_included = closed_included + 1
                end
            end

            if case.qualified_completion == "confirmed" then
                qualified = qualified + 1
            elseif case.qualified_completion == "failed" then
                quality_failed = quality_failed + 1
            else
                quality_unknown = quality_unknown + 1
            end

            if case.closed
                and case.qualified_completion ~= "confirmed" then
                closed_without_confirmed_quality =
                    closed_without_confirmed_quality + 1
            end
        end
    end

    return {
        status = "computed",
        implementation_version = VERSION,
        scope = "supplied_due_case_inventory",
        supplied_due_cases = due,
        excluded_due_cases = due - included,
        closure_based_headline = ratio(closed_included, included),
        qualified_completion = ratio(qualified, due),
        dashboard_coverage = ratio(included, due),
        quality_failure_count = quality_failed,
        unresolved_quality_count = quality_unknown,
        closed_without_confirmed_quality =
            closed_without_confirmed_quality,
        evidence_limits = {
            cohort_completeness = "not_verified",
            due_classification = "not_verified",
            quality_assessment = "not_verified",
            strategic_intent = "not_assessed"
        }
    }
end

function M.self_test()
    local report = M.summarize({
        {
            due = true,
            closed = true,
            qualified_completion = "failed",
            dashboard_included = true
        },
        {
            due = true,
            closed = true,
            qualified_completion = "confirmed",
            dashboard_included = false
        },
        {
            due = true,
            closed = false,
            qualified_completion = "unresolved",
            dashboard_included = false
        }
    })

    assert(report.closure_based_headline.numerator == 1)
    assert(report.closure_based_headline.denominator == 1)
    assert(report.qualified_completion.numerator == 1)
    assert(report.qualified_completion.denominator == 3)
    assert(report.excluded_due_cases == 2)
    assert(report.closed_without_confirmed_quality == 1)

    local empty = M.summarize({})
    assert(empty.qualified_completion.status == "not_applicable")

    local invalid_case = M.summarize({
        {
            due = true,
            closed = true,
            qualified_completion = "probably",
            dashboard_included = true
        }
    })
    assert(invalid_case.status == "validation_error")

    return {
        status = "self_checks_passed",
        scope = "synthetic_denominator_and_quality_cases"
    }
end

return M
