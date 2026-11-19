-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only, not identity, consent, or execution authority.
--
-- Pure comparison of supplied research records.
-- No network, file, device, persistence, or sensor operations.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"

local FIELDS = {
    "acquisition", "recording", "inference", "transmission"
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function exact(record, names)
    if not plain(record) then return false end
    local allowed = {}

    for i = 1, #names do allowed[names[i]] = true end
    for key in next, record do
        if not allowed[key] then return false end
    end
    for i = 1, #names do
        if rawget(record, names[i]) == nil then return false end
    end

    return true
end

local function observation(value)
    return value == "active"
        or value == "inactive"
        or value == "unverified"
end

local function declaration(value)
    if value == "unspecified" then return true end
    if not plain(value) then return false end

    local count = 0
    for key, present in next, value do
        if (key ~= "active" and key ~= "inactive") or present ~= true then
            return false
        end
        count = count + 1
    end

    return count > 0
end

function M.compare(declared, observed)
    if not exact(declared, FIELDS) or not exact(observed, FIELDS) then
        return {
            status = "validation_error",
            implementation_version = VERSION,
            reason = "complete_activity_records_required"
        }
    end

    local findings = {}
    local mismatches, unresolved = 0, 0

    for i = 1, #FIELDS do
        local field = FIELDS[i]
        local policy = declared[field]
        local value = observed[field]

        if not declaration(policy) or not observation(value) then
            return {
                status = "validation_error",
                implementation_version = VERSION,
                reason = "invalid_activity_field"
            }
        end

        if policy == "unspecified" or value == "unverified" then
            findings[field] = "unresolved"
            unresolved = unresolved + 1
        elseif not policy[value] then
            findings[field] = "mismatch"
            mismatches = mismatches + 1
        else
            findings[field] = "not_contradicted"
        end
    end

    local status
    if mismatches > 0 then
        status = "mismatch_detected"
    elseif unresolved > 0 then
        status = "comparison_incomplete"
    else
        status = "no_mismatch_detected_in_supplied_observations"
    end

    return {
        status = status,
        implementation_version = VERSION,
        findings = findings,
        mismatch_count = mismatches,
        unresolved_count = unresolved,
        scope = "categorical_activity_comparison"
    }
end

function M.self_test()
    local declared = {
        acquisition = {active = true},
        recording = {inactive = true},
        inference = {active = true, inactive = true},
        transmission = {inactive = true}
    }

    local observed = {
        acquisition = "active",
        recording = "inactive",
        inference = "active",
        transmission = "inactive"
    }

    local consistent = M.compare(declared, observed)
    assert(consistent.status
        == "no_mismatch_detected_in_supplied_observations")

    observed.transmission = "active"
    observed.inference = "unverified"

    local mixed = M.compare(declared, observed)
    assert(mixed.status == "mismatch_detected")
    assert(mixed.findings.transmission == "mismatch")
    assert(mixed.findings.inference == "unresolved")

    declared.transmission = "unspecified"
    local unknown = M.compare(declared, observed)
    assert(unknown.status == "comparison_incomplete")

    observed.acquisition = "probably_active"
    assert(M.compare(declared, observed).status == "validation_error")

    return {
        status = "self_checks_passed",
        scope = "synthetic_activity_comparison_cases"
    }
end

return M
