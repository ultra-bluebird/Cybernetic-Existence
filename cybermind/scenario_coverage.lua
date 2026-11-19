-- Lua 5.4. Pure local pairwise coverage analysis.
-- No I/O, external actions, recursion, or dynamic loading.
-- Import: local coverage = require("cybermind.scenario_coverage")
-- Tests: assert(coverage.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local function fail(code, path, message)
    error({code = code, path = path, message = message}, 0)
end

local function plain(value, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_TABLE", path, "Expected a plain table")
    end
end

local function text(value, path)
    if type(value) ~= "string" or #value > 256
        or not value:match("%S") or value:find("%c") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function length(value, path, limit)
    plain(value, path)
    local count, maximum = 0, 0
    for key in next, value do
        if type(key) ~= "number"
            or math.type(key) ~= "integer" or key < 1 then
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

local function keys(value)
    local result = {}
    for key in next, value do result[#result + 1] = key end
    table.sort(result)
    return result
end

local function encode(value)
    return tostring(#value) .. ":" .. value
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

local function model(factors)
    plain(factors, "factors")
    local names, domains = {}, {}
    for name, levels in next, factors do
        text(name, "factor name")
        names[#names + 1] = name
        local count = length(levels, "factor levels", 64)
        if count == 0 then
            fail("EMPTY_DOMAIN", name, "Factor requires at least one level")
        end
        local domain = {}
        for position = 1, count do
            local level = text(levels[position], "factor level")
            if domain[level] then
                fail("DUPLICATE_LEVEL", name, "Repeated factor level")
            end
            domain[level] = true
        end
        domains[name] = domain
    end
    if #names < 2 or #names > 16 then
        fail("FACTOR_COUNT", "factors", "Expected between 2 and 16 factors")
    end
    table.sort(names)
    return names, domains
end

local function configuration(source, names, domains)
    plain(source, "configuration")
    local count = 0
    for name in next, source do
        if type(name) ~= "string" or not domains[name] then
            fail("UNKNOWN_FACTOR", "configuration", "Unexpected factor")
        end
        count = count + 1
    end
    if count ~= #names then
        fail("INCOMPLETE_CONFIGURATION", "configuration",
            "Every declared factor must be assigned")
    end

    local copy, fragments = {}, {}
    for _, name in ipairs(names) do
        local level = text(source[name], "configuration." .. name)
        if not domains[name][level] then
            fail("UNKNOWN_LEVEL", name, "Value is outside the factor domain")
        end
        copy[name] = level
        fragments[#fragments + 1] = encode(name) .. encode(level)
    end
    return copy, table.concat(fragments)
end

local function interactions(row, names)
    local result = {}
    for first = 1, #names - 1 do
        for second = first + 1, #names do
            local a, b = names[first], names[second]
            local key = encode(a) .. encode(row[a])
                .. encode(b) .. encode(row[b])
            result[key] = {
                first_factor = a,
                first_level = row[a],
                second_factor = b,
                second_level = row[b]
            }
        end
    end
    return result
end

local function prepare(factors, feasible)
    local names, domains = model(factors)
    local count = length(feasible, "feasible", 5000)
    if count == 0 then
        fail("EMPTY_FEASIBLE_SET", "feasible",
            "Supply at least one reviewed feasible configuration")
    end

    local rows, registry, universe = {}, {}, {}
    local unique_interactions = 0

    for position = 1, count do
        local copy, key = configuration(feasible[position], names, domains)
        if registry[key] then
            fail("DUPLICATE_CONFIGURATION", "feasible",
                "Repeated feasible configuration")
        end
        local pairs = interactions(copy, names)
        local row = {configuration = copy, key = key, interactions = pairs}
        rows[#rows + 1] = row
        registry[key] = row

        for pair_key, pair in next, pairs do
            if not universe[pair_key] then
                unique_interactions = unique_interactions + 1
                if unique_interactions > 200000 then
                    fail("INTERACTION_LIMIT", "feasible",
                        "Pairwise universe exceeds configured limit")
                end
                universe[pair_key] = pair
            end
        end
    end
    table.sort(rows, function(a, b) return a.key < b.key end)
    return names, domains, rows, registry, universe
end

local function summary(universe, covered)
    local uncovered, total, exercised = {}, 0, 0
    for _, key in ipairs(keys(universe)) do
        total = total + 1
        if covered[key] then
            exercised = exercised + 1
        else
            uncovered[#uncovered + 1] = universe[key]
        end
    end
    return {
        eligible_interactions = total,
        exercised_interactions = exercised,
        coverage_fraction = exercised / total,
        uncovered = uncovered
    }
end

local function metadata()
    return {
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope =
            "Credit and workstream metadata only; not identity, consent, "
            .. "authorization, execution evidence, or authority.",
        scope =
            "Pairwise coverage of supplied feasible configurations only; "
            .. "not real-world hazard completeness or evidence of incidents."
    }
end

function M.evaluate(factors, feasible, exercised)
    return protect(function()
        local names, domains, _, registry, universe =
            prepare(factors, feasible)
        local count = length(exercised, "exercised", 5000)
        local covered, seen = {}, {}

        for position = 1, count do
            local _, key = configuration(exercised[position], names, domains)
            if not registry[key] then
                fail("NOT_FEASIBLE", "exercised",
                    "Configuration is outside the supplied feasible set")
            end
            if seen[key] then
                fail("DUPLICATE_CONFIGURATION", "exercised",
                    "Repeated exercise does not increase configuration coverage")
            end
            seen[key] = true
            for pair_key in next, registry[key].interactions do
                covered[pair_key] = true
            end
        end

        local result = metadata()
        result.summary = summary(universe, covered)
        result.configuration_count = count
        return result
    end)
end

function M.select(factors, feasible, budget)
    return protect(function()
        if type(budget) ~= "number" or math.type(budget) ~= "integer"
            or budget < 0 or budget > 5000 then
            fail("INVALID_BUDGET", "budget", "Expected integer from 0 to 5000")
        end
        local _, _, rows, _, universe = prepare(factors, feasible)
        local covered, used, selected = {}, {}, {}

        for _ = 1, math.min(budget, #rows) do
            local best, best_gain = nil, 0
            for _, row in ipairs(rows) do
                if not used[row.key] then
                    local gain = 0
                    for key in next, row.interactions do
                        if not covered[key] then gain = gain + 1 end
                    end
                    if gain > best_gain then
                        best, best_gain = row, gain
                    end
                end
            end
            if not best then break end
            used[best.key] = true
            selected[#selected + 1] = best.configuration
            for key in next, best.interactions do covered[key] = true end
        end

        local result = metadata()
        result.selected = selected
        result.summary = summary(universe, covered)
        result.method = "deterministic_greedy_new_pair_coverage"
        result.cost_model = "one unit per configuration"
        result.optimality_claim = "none"
        return result
    end)
end

function M.self_test()
    local factors = {
        channel = {"text", "voice"},
        situation = {"routine", "outage"}
    }
    local feasible = {
        {channel = "text", situation = "routine"},
        {channel = "text", situation = "outage"},
        {channel = "voice", situation = "routine"},
        {channel = "voice", situation = "outage"}
    }

    local result = assert(M.evaluate(factors, feasible, {feasible[1]}))
    assert(result.summary.eligible_interactions == 4)
    assert(result.summary.exercised_interactions == 1)
    assert(result.summary.coverage_fraction == 0.25)

    local selected = assert(M.select(factors, feasible, 4))
    assert(#selected.selected == 4)
    assert(selected.summary.coverage_fraction == 1)

    local empty = assert(M.select(factors, feasible, 0))
    assert(#empty.selected == 0)
    assert(empty.summary.coverage_fraction == 0)

    local value, err = M.evaluate(
        factors, feasible, {feasible[1], feasible[1]}
    )
    assert(value == nil and err.code == "DUPLICATE_CONFIGURATION")

    local restricted = {feasible[1], feasible[2]}
    value, err = M.evaluate(factors, restricted, {feasible[3]})
    assert(value == nil and err.code == "NOT_FEASIBLE")

    selected.selected[1].channel = "Caller edit"
    assert(feasible[1].channel == "text")
    assert(assert(M.select(factors, feasible, 4))
        .summary.coverage_fraction == 1)

    return true
end

return M
