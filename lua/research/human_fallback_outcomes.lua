-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only, not identity, consent, or execution authority.
--
-- Arithmetic over supplied service-restoration case assessments.
-- No network, file, device, persistence, or support operations.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"
local MAX_CASES = 4096

local DIMENSIONS = {
    "human_reached",
    "communication_effective",
    "authority_sufficient",
    "action_completed",
    "restoration_effective"
}

local STATES = {
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
        return {status = "not_assessed", denominator = 0}
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

    local allowed, counts = {}, {}
    for i = 1, #DIMENSIONS do
        local field = DIMENSIONS[i]
        allowed[field] = true
        counts[field] = {confirmed = 0, failed = 0, unresolved = 0}
    end

    local qualified, any_failed, any_unresolved = 0, 0, 0

    for i = 1, n do
        local case = cases[i]
        if not plain(case) then return invalid("plain_case_required") end

        for key in next, case do
            if not allowed[key] then return invalid("unknown_case_field") end
        end

        local all_confirmed, failed, unresolved = true, false, false

        for j = 1, #DIMENSIONS do
            local field = DIMENSIONS[j]
            local state = case[field]

            if type(state) ~= "string" or not STATES[state] then
                return invalid("invalid_or_missing_dimension")
            end

            counts[field][state] = counts[field][state] + 1

            if state ~= "confirmed" then all_confirmed = false end
            if state == "failed" then failed = true end
            if state == "unresolved" then unresolved = true end
        end

        if all_confirmed then qualified = qualified + 1 end
        if failed then any_failed = any_failed + 1 end
        if unresolved then any_unresolved = any_unresolved + 1 end
    end

    return {
        status = n > 0 and "computed" or "not_assessed",
        implementation_version = VERSION,
        scope = "supplied_service_restoration_cases",
        case_count = n,
        qualified_restoration = ratio(qualified, n),
        cases_with_failure = any_failed,
        cases_with_unresolved_dimension = any_unresolved,
        per_dimension = counts,
        evidence_limits = {
            source_provenance = "not_verified",
            cohort_completeness = "not_verified",
            actual_restoration = "not_verified_by_this_utility",
            sampling_uncertainty = "not_computed"
        }
    }
end

function M.self_test()
    local function complete()
        local case = {}
        for i = 1, #DIMENSIONS do
            case[DIMENSIONS[i]] = "confirmed"
        end
        return case
    end

    local success = complete()
    local nominal = complete()
    nominal.authority_sufficient = "failed"
    nominal.restoration_effective = "unresolved"

    local result = M.summarize({success, nominal})
    assert(result.qualified_restoration.numerator == 1)
    assert(result.qualified_restoration.denominator == 2)
    assert(result.cases_with_failure == 1)
    assert(result.cases_with_unresolved_dimension == 1)

    local empty = M.summarize({})
    assert(empty.qualified_restoration.status == "not_assessed")

    local malformed = complete()
    malformed.restoration_effective = nil
    assert(M.summarize({malformed}).status == "validation_error")

    return {
        status = "self_checks_passed",
        scope = "synthetic_fallback_summary_cases"
    }
end

return M
