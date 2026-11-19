-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and metadata only; no identity, consent, or execution authority.
--
-- Independently fictional, literal-template corpus.
-- No participant data, network, file, device, or persistence operations.
-- Coverage applies only to the declared finite model.
-- Lua 5.1+.

local M = {}
local VERSION = "0.1.0-proposed"

local FACTORS = {
    channel = {"text", "phone", "paper"},
    permission = {"granted", "absent", "unknown"},
    continuity = {"available", "unavailable", "unknown"},
    task = {"correction", "export"}
}

local COMPARISONS = {
    "augmented_self_description",
    "cybernetic_host_self_description"
}

local BASELINE = "no_augmentation_description"
local MAX_PAIRS = 108

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function member(values, value)
    for i = 1, #values do
        if values[i] == value then return true end
    end
    return false
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

local function context_copy(context)
    return {
        channel = context.channel,
        permission = context.permission,
        continuity = context.continuity,
        task = context.task
    }
end

local function valid_context(context)
    if not exact(context, {
        "channel", "permission", "continuity", "task"
    }) then
        return false
    end

    for name, values in pairs(FACTORS) do
        if not member(values, context[name]) then return false end
    end
    return true
end

local function same_context(a, b)
    for name in pairs(FACTORS) do
        if a[name] ~= b[name] then return false end
    end
    return true
end

local function array_length(array)
    if not plain(array) then return nil end

    local count, maximum = 0, 0
    for key in next, array do
        count = count + 1
        if count > MAX_PAIRS
            or type(key) ~= "number"
            or key < 1 or key > MAX_PAIRS
            or key % 1 ~= 0 then
            return nil
        end
        maximum = math.max(maximum, key)
    end

    if count ~= maximum then return nil end
    return count
end

function M.generate()
    local corpus = {}

    for _, channel in ipairs(FACTORS.channel) do
        for _, permission in ipairs(FACTORS.permission) do
            for _, continuity in ipairs(FACTORS.continuity) do
                for _, task in ipairs(FACTORS.task) do
                    local context = {
                        channel = channel,
                        permission = permission,
                        continuity = continuity,
                        task = task
                    }

                    for _, description in ipairs(COMPARISONS) do
                        corpus[#corpus + 1] = {
                            baseline = {
                                descriptor = BASELINE,
                                context = context_copy(context)
                            },
                            comparison = {
                                descriptor = description,
                                context = context_copy(context)
                            }
                        }
                    end
                end
            end
        end
    end

    return corpus
end

function M.coverage(corpus)
    local n = array_length(corpus)
    if n == nil then
        return {status = "validation_error", reason = "invalid_corpus_array"}
    end

    local seen_pairs, seen_contexts = {}, {}

    for i = 1, n do
        local pair = corpus[i]

        if not exact(pair, {"baseline", "comparison"})
            or not exact(pair.baseline, {"descriptor", "context"})
            or not exact(pair.comparison, {"descriptor", "context"})
            or pair.baseline.descriptor ~= BASELINE
            or not member(COMPARISONS, pair.comparison.descriptor)
            or not valid_context(pair.baseline.context)
            or not valid_context(pair.comparison.context)
            or not same_context(
                pair.baseline.context, pair.comparison.context
            ) then
            return {status = "validation_error", reason = "invalid_pair"}
        end

        local c = pair.baseline.context
        local context_key = table.concat({
            c.channel, c.permission, c.continuity, c.task
        }, "|")
        local pair_key = context_key .. "|" .. pair.comparison.descriptor

        if seen_pairs[pair_key] then
            return {status = "validation_error", reason = "duplicate_pair"}
        end

        seen_pairs[pair_key] = true
        seen_contexts[context_key] = true
    end

    local contexts = 0
    for _ in pairs(seen_contexts) do contexts = contexts + 1 end

    return {
        status = "computed",
        generator_version = VERSION,
        scope = "declared_finite_template_model",
        covered_contexts = contexts,
        total_contexts = 54,
        covered_pairs = n,
        total_pairs = MAX_PAIRS,
        pair_coverage = n / MAX_PAIRS
    }
end

function M.self_test()
    local corpus = M.generate()
    local report = M.coverage(corpus)

    assert(report.status == "computed")
    assert(report.covered_contexts == 54)
    assert(report.covered_pairs == 108)
    assert(report.pair_coverage == 1)

    corpus[1].comparison.context.permission = "unknown"
    assert(M.coverage(corpus).reason == "invalid_pair")

    local duplicate = M.generate()
    duplicate[2] = duplicate[1]
    assert(M.coverage(duplicate).reason == "duplicate_pair")

    local detached = M.generate()
    detached[1].baseline.context.channel = "paper"
    assert(detached[1].comparison.context.channel == "text")

    return {
        status = "self_checks_passed",
        scope = "generation_structure_and_declared_domain_coverage"
    }
end

return M
