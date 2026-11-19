-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only; no identity, consent, or execution authority.
--
-- Arithmetic over supplied categorical audit observations.
-- No network, file, device, persistence, or live-audit operations.
-- Not a public-release mechanism or population accessibility estimate.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"
local MAX_RECORDS = 4096

local FIELDS = {
    channel = true,
    method = true,
    support = true,
    task = true,
    outcome = true
}

local OUTCOMES = {
    confirmed_success = true,
    confirmed_failure = true,
    unresolved = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function category(value)
    return type(value) == "string"
        and #value > 0
        and #value <= 64
        and value:match("^[A-Za-z0-9_-]+$") ~= nil
end

local function length(array)
    if not plain(array) then return nil end

    local count, maximum = 0, 0
    for key in next, array do
        count = count + 1
        if count > MAX_RECORDS
            or type(key) ~= "number"
            or key < 1 or key > MAX_RECORDS
            or key % 1 ~= 0 then
            return nil
        end
        maximum = math.max(maximum, key)
    end

    if count ~= maximum then return nil end
    return count
end

local function invalid(reason)
    return {
        status = "validation_error",
        implementation_version = VERSION,
        reason = reason
    }
end

local function new_counts()
    return {
        total = 0,
        confirmed_success = 0,
        confirmed_failure = 0,
        unresolved = 0
    }
end

local function add(counts, outcome)
    counts.total = counts.total + 1
    counts[outcome] = counts[outcome] + 1
end

local function finish(counts)
    local result = {
        status = counts.total > 0 and "computed" or "not_assessed",
        total = counts.total,
        confirmed_success = counts.confirmed_success,
        confirmed_failure = counts.confirmed_failure,
        unresolved = counts.unresolved
    }

    if counts.total > 0 then
        result.completion_bounds = {
            status = "computed",
            lower_numerator = counts.confirmed_success,
            upper_numerator =
                counts.confirmed_success + counts.unresolved,
            denominator = counts.total,
            lower = counts.confirmed_success / counts.total,
            upper =
                (counts.confirmed_success + counts.unresolved) / counts.total
        }
    else
        result.completion_bounds = {status = "not_assessed"}
    end

    return result
end

function M.summarize(records)
    local n = length(records)
    if n == nil then
        return invalid("bounded_dense_record_array_required")
    end

    local overall = new_counts()
    local cells = {}

    for i = 1, n do
        local record = records[i]
        if not plain(record) then
            return invalid("plain_record_required")
        end

        for key in next, record do
            if not FIELDS[key] then
                return invalid("unknown_record_field")
            end
        end

        for _, field in ipairs({"channel", "method", "support", "task"}) do
            if not category(record[field]) then
                return invalid("invalid_category")
            end
        end

        if type(record.outcome) ~= "string"
            or not OUTCOMES[record.outcome] then
            return invalid("invalid_outcome")
        end

        -- "|" cannot occur in a validated category.
        local cell_key = table.concat({
            record.channel, record.method, record.support, record.task
        }, "|")

        if not cells[cell_key] then
            cells[cell_key] = {
                channel = record.channel,
                method = record.method,
                support = record.support,
                task = record.task,
                counts = new_counts()
            }
        end

        add(cells[cell_key].counts, record.outcome)
        add(overall, record.outcome)
    end

    local output_cells = {}
    for cell_key, cell in pairs(cells) do
        output_cells[cell_key] = {
            channel = cell.channel,
            method = cell.method,
            support = cell.support,
            task = cell.task,
            result = finish(cell.counts)
        }
    end

    return {
        status = n > 0 and "computed" or "not_assessed",
        implementation_version = VERSION,
        scope = "supplied_audit_observation_arithmetic",
        overall = finish(overall),
        cells = output_cells,
        evidence_limits = {
            observation_provenance = "not_verified",
            actual_accessibility = "not_established",
            sampling_uncertainty = "not_computed",
            public_release_privacy = "not_assessed"
        }
    }
end

function M.self_test()
    local function record(method, outcome)
        return {
            channel = "text",
            method = method,
            support = "self_selected",
            task = "correct_record",
            outcome = outcome
        }
    end

    local result = M.summarize({
        record("keyboard", "confirmed_success"),
        record("AAC_text", "confirmed_failure"),
        record("AAC_text", "unresolved")
    })

    assert(result.overall.total == 3)
    assert(result.overall.completion_bounds.lower_numerator == 1)
    assert(result.overall.completion_bounds.upper_numerator == 2)

    local aac = result.cells[
        "text|AAC_text|self_selected|correct_record"
    ].result

    assert(aac.confirmed_failure == 1)
    assert(aac.unresolved == 1)
    assert(aac.completion_bounds.lower_numerator == 0)
    assert(aac.completion_bounds.upper_numerator == 1)
    assert(aac.completion_bounds.denominator == 2)

    local empty = M.summarize({})
    assert(empty.status == "not_assessed")
    assert(empty.overall.completion_bounds.status == "not_assessed")

    local malformed = M.summarize({
        record("AAC|text", "confirmed_success")
    })
    assert(malformed.reason == "invalid_category")

    local unsupported = record("keyboard", "confirmed_success")
    unsupported.private_notes = "not accepted"
    assert(M.summarize({unsupported}).reason == "unknown_record_field")

    return {
        status = "self_checks_passed",
        scope = "synthetic_arithmetic_and_validation_cases"
    }
end

return M
