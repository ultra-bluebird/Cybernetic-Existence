-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only; no identity, consent, or execution authority.
--
-- Four-criterion interpretation-review partition.
-- Pure classifier. No network, file, device, persistence, or inference
-- beyond the four supplied criterion states.
-- Lua 5.1+.

local M = {}

local CRITERIA = {
    "rule_basis",
    "functional_request",
    "supported_arrangement",
    "review_pathway"
}

local STATES = { met = true, not_met = true, unresolved = true }

local function validate(record)
    if type(record) ~= "table" or getmetatable(record) ~= nil then
        return nil, "plain_record_required"
    end
    for i = 1, #CRITERIA do
        local name = CRITERIA[i]
        if not STATES[record[name]] then
            return nil, "invalid_state_" .. name
        end
    end
    return record
end

local function classify(record)
    local has_not_met, has_unresolved = false, false
    for i = 1, #CRITERIA do
        local s = record[CRITERIA[i]]
        if s == "not_met" then has_not_met = true end
        if s == "unresolved" then has_unresolved = true end
    end
    if has_not_met then return "nonconforming" end
    if has_unresolved then return "review" end
    return "documented"
end

function M.evaluate(record)
    local valid, err = validate(record)
    if not valid then
        return { status = "validation_error", reason = err }
    end
    local findings = {}
    for i = 1, #CRITERIA do
        local name = CRITERIA[i]
        findings[#findings + 1] = { criterion = name, state = record[name] }
    end
    return {
        status = "assessed",
        disposition = classify(record),
        findings = findings,
        target = "institutional_interpretation_record"
    }
end

function M.enumerate()
    local states = { "met", "not_met", "unresolved" }
    local counts = { documented = 0, nonconforming = 0, review = 0 }
    local total, partition_violations = 0, 0

    for a = 1, 3 do for b = 1, 3 do for c = 1, 3 do for d = 1, 3 do
        total = total + 1
        local record = {
            rule_basis = states[a],
            functional_request = states[b],
            supported_arrangement = states[c],
            review_pathway = states[d]
        }
        local r = M.evaluate(record)
        if r.status ~= "assessed" then
            partition_violations = partition_violations + 1
        else
            counts[r.disposition] = counts[r.disposition] + 1
        end
    end end end end

    return { total = total, counts = counts,
             partition_violations = partition_violations }
end

return M
