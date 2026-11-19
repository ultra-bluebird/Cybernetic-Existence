-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only, not identity, consent, or execution authority.
--
-- Synthetic research counterpart. Not executed in this response.
-- No network, file, device, persistence, or sensor operations.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"

local FIELDS = {
    "acquisition", "recording", "inference", "transmission"
}

local DECLARED = {
    active_only = true,
    inactive_only = true,
    either = true,
    unspecified = true
}

local OBSERVED = {
    active = true,
    inactive = true,
    unverified = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function valid_record(record, values)
    if not plain(record) then return false end

    local allowed = {}
    for i = 1, #FIELDS do
        allowed[FIELDS[i]] = true
    end

    for key in next, record do
        if not allowed[key] then return false end
    end

    for i = 1, #FIELDS do
        local value = record[FIELDS[i]]
        if type(value) ~= "string" or not values[value] then
            return false
        end
    end

    return true
end

function M.compare(declared, observed)
    if not valid_record(declared, DECLARED)
        or not valid_record(observed, OBSERVED) then
        return {
            status = "validation_error",
            implementation_version = VERSION
        }
    end

    local findings = {}
    local mismatches, unresolved = 0, 0

    for i = 1, #FIELDS do
        local field = FIELDS[i]
        local d, o = declared[field], observed[field]

        if d == "unspecified" or o == "unverified" then
            findings[field] = "unresolved"
            unresolved = unresolved + 1
        elseif d == "either"
            or (d == "active_only" and o == "active")
            or (d == "inactive_only" and o == "inactive") then
            findings[field] = "not_contradicted"
        else
            findings[field] = "mismatch"
            mismatches = mismatches + 1
        end
    end

    local status
    if mismatches > 0 then
        status = "mismatch_detected"
    elseif unresolved > 0 then
        status = "comparison_incomplete"
    else
        status = "not_contradicted_in_observations"
    end

    return {
        status = status,
        implementation_version = VERSION,
        findings = findings,
        mismatch_count = mismatches,
        unresolved_count = unresolved
    }
end

function M.self_test()
    local declared = {
        acquisition = "inactive_only",
        recording = "inactive_only",
        inference = "inactive_only",
        transmission = "inactive_only"
    }

    local observed = {
        acquisition = "inactive",
        recording = "inactive",
        inference = "unverified",
        transmission = "active"
    }

    local result = M.compare(declared, observed)
    assert(result.status == "mismatch_detected")
    assert(result.findings.transmission == "mismatch")
    assert(result.findings.inference == "unresolved")
    assert(result.mismatch_count == 1)
    assert(result.unresolved_count == 1)

    observed.transmission = "inactive"
    assert(M.compare(declared, observed).status
        == "comparison_incomplete")

    observed.inference = "inactive"
    assert(M.compare(declared, observed).status
        == "not_contradicted_in_observations")

    observed.private_notes = "not accepted"
    assert(M.compare(declared, observed).status == "validation_error")

    return {
        status = "self_checks_passed",
        scope = "synthetic_comparison_cases"
    }
end

return M
