-- Lua 5.4.
-- Pure local accounting; no network, persistence, identity inference, or action.
-- Import: local tally = require("cybermind.mandate_tally")
-- Tests: assert(tally.self_test())
-- All time values use a caller-defined common integer unit.

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local CHOICES = {
    support = true,
    oppose = true,
    abstain = true,
    recuse = true
}
local REVIEWS = {
    reviewed = true,
    unknown = true,
    disputed = true
}

local function fail(code, path, message)
    error({code = code, path = path, message = message}, 0)
end

local function fields(value, allowed, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_TABLE", path, "Expected a plain table")
    end
    for key in next, value do
        if type(key) ~= "string" or not allowed[key] then
            fail("UNKNOWN_FIELD", path, "Unexpected field")
        end
    end
end

local function text(value, path)
    if type(value) ~= "string" or #value > 4096
        or not value:match("%S") or value:find("%c") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function integer(value, path, minimum, maximum)
    if type(value) ~= "number" or math.type(value) ~= "integer"
        or value < minimum or value > maximum then
        fail("INVALID_INTEGER", path, "Integer outside declared range")
    end
    return value
end

local function enumeration(value, vocabulary, path)
    if type(value) ~= "string" or not vocabulary[value] then
        fail("INVALID_ENUM", path, "Unknown vocabulary value")
    end
    return value
end

local function array_length(value, path, limit)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_ARRAY", path, "Expected a plain array")
    end
    local count, maximum = 0, 0
    for key in next, value do
        if type(key) ~= "number" or math.type(key) ~= "integer"
            or key < 1 then
            fail("INVALID_ARRAY_KEY", path,
                "Expected consecutive positive integer keys")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum then
        fail("SPARSE_ARRAY", path, "Array has missing positions")
    end
    if count > limit then
        fail("LIMIT_EXCEEDED", path, "Collection exceeds configured limit")
    end
    return count
end

local function protect(operation)
    local ok, result = pcall(operation)
    if ok then return result end
    if type(result) == "table" and type(result.code) == "string" then
        return nil, result
    end
    return nil, {
        code = "INTERNAL_ERROR",
        path = "module",
        message = "Unexpected internal failure"
    }
end

function M.metadata()
    return {
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope =
            "Credit and workstream metadata only; not identity, consent, "
            .. "authorization, execution evidence, or authority."
    }
end

function M.tally(charter, ballots, now)
    return protect(function()
        fields(charter, {
            revision = true,
            expected_revision = true,
            total_weight = true,
            quorum_weight = true,
            support_weight = true,
            constituencies = true
        }, "charter")

        integer(now, "now", 0, math.maxinteger)
        local revision = integer(charter.revision,
            "charter.revision", 0, math.maxinteger)
        local expected = integer(charter.expected_revision,
            "charter.expected_revision", 0, math.maxinteger)
        if revision ~= expected then
            fail("REVISION_MISMATCH", "charter",
                "Tally must use the expected charter revision")
        end

        local total = integer(charter.total_weight,
            "charter.total_weight", 1, 1000000000)
        local quorum = integer(charter.quorum_weight,
            "charter.quorum_weight", 1, total)
        local required_support = integer(charter.support_weight,
            "charter.support_weight", 1, total)

        if required_support <= total // 2 then
            fail("INVALID_SUPPORT_THRESHOLD", "charter.support_weight",
                "This pilot requires support exceeding half the full charter")
        end

        local count = array_length(
            charter.constituencies, "charter.constituencies", 1000
        )
        local registry, ordered, allocated = {}, {}, 0

        for position = 1, count do
            local source = charter.constituencies[position]
            local path = "charter.constituencies[" .. position .. "]"
            fields(source, {
                constituency = true,
                weight = true,
                interest_scope = true,
                accountability_route = true,
                mandate_review = true,
                valid_from = true,
                valid_until = true
            }, path)

            local name = text(source.constituency, path .. ".constituency")
            if registry[name] then
                fail("DUPLICATE_CONSTITUENCY", path,
                    "Charter contains a repeated constituency")
            end

            local weight = integer(source.weight,
                path .. ".weight", 1, 1000000)
            if weight * 2 >= total then
                fail("DOMINATING_ALLOCATION", path .. ".weight",
                    "No single constituency may hold half or more")
            end

            local first = integer(source.valid_from,
                path .. ".valid_from", 0, math.maxinteger)
            local last = integer(source.valid_until,
                path .. ".valid_until", 0, math.maxinteger)
            if last <= first then
                fail("INVALID_TERM", path, "Mandate term must be positive")
            end

            local entry = {
                constituency = name,
                weight = weight,
                interest_scope = text(
                    source.interest_scope, path .. ".interest_scope"
                ),
                accountability_route = text(
                    source.accountability_route, path .. ".accountability_route"
                ),
                mandate_review = enumeration(
                    source.mandate_review, REVIEWS, path .. ".mandate_review"
                ),
                valid_from = first,
                valid_until = last
            }
            registry[name] = entry
            ordered[#ordered + 1] = name
            allocated = allocated + weight
        end

        if allocated ~= total then
            fail("ALLOCATION_MISMATCH", "charter.total_weight",
                "Constituency allocations must equal the declared total")
        end
        table.sort(ordered)

        local ballot_count = array_length(ballots, "ballots", 1000)
        local selected = {}

        for position = 1, ballot_count do
            local ballot = ballots[position]
            local path = "ballots[" .. position .. "]"
            fields(ballot, {constituency = true, choice = true}, path)
            local name = text(ballot.constituency, path .. ".constituency")
            if not registry[name] then
                fail("UNKNOWN_CONSTITUENCY", path,
                    "Ballot does not belong to the supplied charter")
            end
            if selected[name] then
                fail("DUPLICATE_BALLOT", path,
                    "Only one aggregate ballot per constituency is accepted")
            end
            selected[name] = enumeration(ballot.choice, CHOICES, path .. ".choice")
        end

        local result = M.metadata()
        result.charter_revision = revision
        result.total_weight = total
        result.support = 0
        result.oppose = 0
        result.abstain = 0
        result.recused = 0
        result.absent = 0
        result.unavailable_mandate = 0
        result.participating_weight = 0
        result.issues = {}

        for _, name in ipairs(ordered) do
            local entry = registry[name]
            local current = now >= entry.valid_from
                and now < entry.valid_until
                and entry.mandate_review == "reviewed"
            local vote = selected[name]

            if not current then
                result.unavailable_mandate =
                    result.unavailable_mandate + entry.weight
                result.issues[#result.issues + 1] = {
                    constituency = name,
                    reason = "mandate_not_current_and_reviewed"
                }
            elseif vote == nil then
                result.absent = result.absent + entry.weight
            elseif vote == "recuse" then
                result.recused = result.recused + entry.weight
            else
                result[vote] = result[vote] + entry.weight
                result.participating_weight =
                    result.participating_weight + entry.weight
            end
        end

        result.quorum_met = result.participating_weight >= quorum
        result.support_threshold_met = result.support >= required_support

        if result.quorum_met and result.support_threshold_met then
            result.outcome = "charter_thresholds_met"
            result.next_step = "separate_rights_and_authority_review"
        elseif not result.quorum_met then
            result.outcome = "quorum_not_met"
            result.next_step = "accessible_participation_and_mandate_review"
        else
            result.outcome = "support_threshold_not_met"
            result.next_step = "ordinary_reconsideration_or_bounded_deadlock_review"
        end

        result.denominator_policy =
            "Full charter allocation; absence, recusal, and unavailable "
            .. "mandates do not shrink the support denominator"
        result.scope =
            "Accounting under supplied charter only; no authentication, "
            .. "mandate-independence finding, rights override, or execution."
        return result
    end)
end

local function fixture()
    local charter = {
        revision = 1,
        expected_revision = 1,
        total_weight = 300,
        quorum_weight = 200,
        support_weight = 201,
        constituencies = {}
    }
    for _, name in ipairs({
        "Communication access",
        "Continuity and repair",
        "Privacy and accountability"
    }) do
        charter.constituencies[#charter.constituencies + 1] = {
            constituency = name,
            weight = 100,
            interest_scope = name,
            accountability_route = "Accessible constituent review",
            mandate_review = "reviewed",
            valid_from = 0,
            valid_until = 100
        }
    end
    return charter, {
        {constituency = "Communication access", choice = "support"},
        {constituency = "Continuity and repair", choice = "support"},
        {constituency = "Privacy and accountability", choice = "support"}
    }
end

function M.self_test()
    local charter, ballots = fixture()
    local result = assert(M.tally(charter, ballots, 1))
    assert(result.outcome == "charter_thresholds_met")
    assert(result.support == 300)

    charter, ballots = fixture()
    ballots[3].choice = "recuse"
    result = assert(M.tally(charter, ballots, 1))
    assert(result.quorum_met)
    assert(not result.support_threshold_met)
    assert(result.total_weight == 300)

    charter, ballots = fixture()
    ballots[#ballots + 1] = {
        constituency = "Communication access", choice = "support"
    }
    local value, err = M.tally(charter, ballots, 1)
    assert(value == nil and err.code == "DUPLICATE_BALLOT")

    charter, ballots = fixture()
    result = assert(M.tally(charter, ballots, 100))
    assert(result.unavailable_mandate == 300)
    assert(not result.quorum_met)

    charter, ballots = fixture()
    ballots[1].replica_count = 1000000
    value, err = M.tally(charter, ballots, 1)
    assert(value == nil and err.code == "UNKNOWN_FIELD")

    charter, ballots = fixture()
    result = assert(M.tally(charter, ballots, 1))
    result.issues[1] = {reason = "Caller modification"}
    assert(#assert(M.tally(charter, ballots, 1)).issues == 0)
    assert(charter.constituencies[1].weight == 100)

    return true
end

return M
