local M = {}

local MAX_SAFE_INTEGER = 9007199254740991

local function is_integer(value)
    return type(value) == "number"
        and value == value
        and value >= 0
        and value <= MAX_SAFE_INTEGER
        and value % 1 == 0
end

local function is_text(value)
    return type(value) == "string"
        and #value > 0
        and #value <= 256
        and not value:find("[%z\1-\31\127]")
end

local function is_digest(value)
    return type(value) == "string"
        and #value == 64
        and value:match("^[0-9a-f]+$") ~= nil
end

local function result(status, prefix_preserved, review_required)
    return {
        status = status,
        anchored_prefix_preserved = prefix_preserved,
        human_review_required = review_required,
        authentication_verified_by_this_module = false,
        freshness_verified_by_this_module = false,
        links_verified_by_this_module = false,
        external_action_authorized = false
    }
end

local function valid_common(value)
    return type(value) == "table"
        and is_integer(value.length)
        and is_text(value.schema_version)
        and is_text(value.canonical_profile)
        and is_text(value.local_context)
        and is_digest(value.head)
end

function M.compare(anchor, observation)
    if not valid_common(anchor)
        or not is_integer(anchor.generation) then
        return result("INVALID_ANCHOR", false, true)
    end

    if not valid_common(observation)
        or not is_integer(observation.anchor_length) then
        return result("INVALID_OBSERVATION", false, true)
    end

    if anchor.schema_version ~= observation.schema_version
        or anchor.canonical_profile ~= observation.canonical_profile
        or anchor.local_context ~= observation.local_context then
        return result("CONTEXT_MISMATCH", false, true)
    end

    if observation.anchor_length ~= anchor.length then
        return result("WRONG_PREFIX_POSITION", false, true)
    end

    if observation.length < anchor.length then
        return result("TRUNCATED_BELOW_ANCHOR", false, true)
    end

    if not is_digest(observation.head_at_anchor) then
        return result("MISSING_RECOMPUTED_PREFIX_HEAD", false, true)
    end

    if observation.head_at_anchor ~= anchor.head then
        return result("ANCHORED_HISTORY_MISMATCH", false, true)
    end

    if observation.length == anchor.length then
        if observation.head ~= observation.head_at_anchor then
            return result("INCONSISTENT_OBSERVATION", false, true)
        end
        return result("EXACT_ANCHOR_MATCH", true, false)
    end

    return result("PREFIX_MATCH_UNCHECKPOINTED_SUFFIX", true, true)
end

local function copy(source)
    local target = {}
    for key, value in pairs(source) do
        target[key] = value
    end
    return target
end

function M.self_test()
    local h = string.rep("a", 64)
    local other = string.rep("b", 64)

    local anchor = {
        length = 10,
        generation = 3,
        head = h,
        schema_version = "1",
        canonical_profile = "jcs-preserve-unicode-safeint",
        local_context = "synthetic-local-evidence"
    }

    local observation = {
        length = 10,
        anchor_length = 10,
        head = h,
        head_at_anchor = h,
        schema_version = anchor.schema_version,
        canonical_profile = anchor.canonical_profile,
        local_context = anchor.local_context
    }

    local function expect(a, o, expected)
        local value = M.compare(a, o)
        assert(value.status == expected)
        assert(value.external_action_authorized == false)
        assert(value.authentication_verified_by_this_module == false)
        assert(value.freshness_verified_by_this_module == false)
        assert(value.links_verified_by_this_module == false)
    end

    expect(anchor, observation, "EXACT_ANCHOR_MATCH")

    local changed = copy(observation)
    changed.length = 9
    expect(anchor, changed, "TRUNCATED_BELOW_ANCHOR")

    changed = copy(observation)
    changed.head_at_anchor = other
    expect(anchor, changed, "ANCHORED_HISTORY_MISMATCH")

    changed = copy(observation)
    changed.length = 11
    changed.head = other
    expect(anchor, changed, "PREFIX_MATCH_UNCHECKPOINTED_SUFFIX")

    changed = copy(observation)
    changed.head = other
    expect(anchor, changed, "INCONSISTENT_OBSERVATION")

    changed = copy(observation)
    changed.schema_version = "2"
    expect(anchor, changed, "CONTEXT_MISMATCH")

    changed = copy(observation)
    changed.anchor_length = 8
    expect(anchor, changed, "WRONG_PREFIX_POSITION")

    changed = copy(observation)
    changed.head_at_anchor = nil
    expect(anchor, changed, "MISSING_RECOMPUTED_PREFIX_HEAD")

    changed = copy(observation)
    changed.length = 0 / 0
    expect(anchor, changed, "INVALID_OBSERVATION")

    expect({}, observation, "INVALID_ANCHOR")

    return {
        test_cases_completed = 10,
        synthetic_inputs_only = true,
        cryptographic_conformance_tested = false
    }
end

return M
