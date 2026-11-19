-- Lua 5.4.
-- Pure claim-record checks and action-cycle accounting.
-- No I/O, publication, source retrieval, or external actions.
-- Import: local cycle = require("cybermind.claims_and_action_cycle")
-- Tests: assert(cycle.self_test())
--
-- The caller must supply a consistently scoped, deduplicated action cohort.
-- All timestamps use one declared integer time domain.

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local LABELS = {
    finding = true, law = true, proposal = true,
    hypothesis = true, fiction = true, composite = true
}
local REVIEWS = {
    reviewed = true, unreviewed = true, disputed = true
}
local TRI = {yes = true, no = true, unknown = true}

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
    if type(value) ~= "string" or #value > 16384
        or not value:match("%S") or value:find("%z") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function timestamp(value, path, maximum)
    if type(value) ~= "number" or math.type(value) ~= "integer"
        or value < 0 or value > maximum then
        fail("INVALID_TIME", path, "Expected bounded nonnegative integer")
    end
    return value
end

local function choice(value, vocabulary, path)
    if type(value) ~= "string" or not vocabulary[value] then
        fail("INVALID_ENUM", path, "Unknown vocabulary value")
    end
    return value
end

local function length(value)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_ARRAY", "actions", "Expected a plain array")
    end
    local count, maximum = 0, 0
    for key in next, value do
        if type(key) ~= "number" or math.type(key) ~= "integer" or key < 1 then
            fail("INVALID_ARRAY_KEY", "actions",
                "Expected consecutive positive integer keys")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum or count > 100000 then
        fail("INVALID_ARRAY_SIZE", "actions", "Array is sparse or too large")
    end
    return count
end

local function ratio(numerator, denominator)
    local result = {
        numerator = numerator,
        denominator = denominator,
        status = denominator > 0 and "descriptive" or "not_estimable"
    }
    if denominator > 0 then result.value = numerator / denominator end
    return result
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

function M.claim_check(record)
    return protect(function()
        fields(record, {
            statement = true, label = true, scope = true,
            limitations = true, source_description = true,
            source_class = true, review_status = true,
            jurisdiction = true, legal_instrument = true,
            legal_status = true
        }, "claim")

        text(record.statement, "statement")
        text(record.scope, "scope")
        text(record.limitations, "limitations")
        local label = choice(record.label, LABELS, "label")
        local review = choice(record.review_status, REVIEWS, "review_status")
        local source = choice(record.source_class, {
            primary = true, secondary = true, none = true
        }, "source_class")

        if record.source_description ~= nil then
            text(record.source_description, "source_description")
        end
        if source ~= "none" and record.source_description == nil then
            fail("SOURCE_DESCRIPTION_REQUIRED", "source_description",
                "Declared source class requires a description")
        end

        local result = M.metadata()
        result.label = label
        result.issues = {}

        if (label == "finding" or label == "law") and source == "none" then
            result.issues[#result.issues + 1] = "supporting_source_not_recorded"
        end
        if (label == "finding" or label == "law") and review ~= "reviewed" then
            result.issues[#result.issues + 1] = "substantive_review_not_established"
        end

        if label == "law" then
            text(record.jurisdiction, "jurisdiction")
            text(record.legal_instrument, "legal_instrument")
            local legal = choice(record.legal_status, {
                in_force = true, not_yet_effective = true,
                historical = true, disputed = true, unknown = true
            }, "legal_status")
            if source ~= "primary" then
                result.issues[#result.issues + 1] =
                    "primary_legal_source_not_recorded"
            end
            if legal == "unknown" or legal == "disputed" then
                result.issues[#result.issues + 1] =
                    "legal_status_requires_explicit_qualification"
            end
            result.declared_legal_status = legal
        elseif record.jurisdiction ~= nil
            or record.legal_instrument ~= nil
            or record.legal_status ~= nil then
            fail("INAPPLICABLE_LEGAL_FIELDS", "claim",
                "This schema reserves legal-status fields for law claims")
        end

        result.result = #result.issues == 0
            and "structural_label_requirements_satisfied"
            or "qualification_or_review_required"
        result.publication_authority = "none"
        result.scope =
            "Record checks only; no source verification, truth finding, "
            .. "current-law verification, or publication permission."
        return result
    end)
end

function M.action_dashboard(actions, cutoff)
    return protect(function()
        timestamp(cutoff, "cutoff", math.maxinteger)
        local count = length(actions)
        local due, verified_due = 0, 0
        local completed, retested, improved, ready = 0, 0, 0, 0
        local completed_retests_due, completed_retests_met = 0, 0

        for position = 1, count do
            local row = actions[position]
            local path = "actions[" .. position .. "]"
            fields(row, {
                accepted_at = true, original_due_at = true,
                owner_role = true, ownership_accepted = true,
                resources_available = true, retest_due_at = true,
                completed_at = true, verification = true,
                retested_at = true, improvement = true
            }, path)

            local accepted = timestamp(row.accepted_at,
                path .. ".accepted_at", cutoff)
            local deadline = timestamp(row.original_due_at,
                path .. ".original_due_at", math.maxinteger)
            if deadline < accepted then
                fail("INVALID_ORDER", path, "Deadline precedes acceptance")
            end

            if row.owner_role ~= nil then text(row.owner_role, path .. ".owner_role") end
            local ownership = choice(row.ownership_accepted,
                TRI, path .. ".ownership_accepted")
            local resources = choice(row.resources_available,
                TRI, path .. ".resources_available")
            local verification = choice(row.verification, {
                confirmed = true, not_confirmed = true, unknown = true
            }, path .. ".verification")
            local improvement = choice(row.improvement, {
                supported = true, not_supported = true,
                uncertain = true, not_assessed = true
            }, path .. ".improvement")

            local retest_due = row.retest_due_at
            if retest_due ~= nil then
                timestamp(retest_due, path .. ".retest_due_at", math.maxinteger)
                if retest_due < accepted then
                    fail("INVALID_ORDER", path, "Retest plan precedes acceptance")
                end
            end

            if ownership == "yes" and row.owner_role == nil then
                fail("OWNER_REQUIRED", path, "Accepted ownership requires a role")
            end
            if ownership == "yes" and resources == "yes"
                and retest_due ~= nil then
                ready = ready + 1
            end

            local finished = row.completed_at
            local retest = row.retested_at

            if finished ~= nil then
                timestamp(finished, path .. ".completed_at", cutoff)
                if finished < accepted then
                    fail("INVALID_ORDER", path, "Completion precedes acceptance")
                end
                completed = completed + 1

                if retest_due ~= nil and retest_due <= cutoff then
                    completed_retests_due = completed_retests_due + 1
                    if retest ~= nil and retest <= retest_due then
                        completed_retests_met = completed_retests_met + 1
                    end
                end
            elseif verification ~= "unknown" or retest ~= nil
                or improvement ~= "not_assessed" then
                fail("INCONSISTENT_ACTION", path,
                    "Completion evidence is required for subsequent assessments")
            end

            if retest ~= nil then
                timestamp(retest, path .. ".retested_at", cutoff)
                if retest < finished then
                    fail("INVALID_ORDER", path, "Retest precedes completion")
                end
                retested = retested + 1
                if improvement == "not_assessed" then
                    fail("RETEST_RESULT_REQUIRED", path,
                        "Recorded retest needs a result, including uncertain")
                end
                if improvement == "supported" then improved = improved + 1 end
            elseif improvement ~= "not_assessed" then
                fail("RETEST_REQUIRED", path,
                    "Improvement assessment requires a recorded retest")
            end

            if deadline <= cutoff then
                due = due + 1
                if finished ~= nil and verification == "confirmed" then
                    verified_due = verified_due + 1
                end
            end
        end

        local result = M.metadata()
        result.cutoff = cutoff
        result.accepted_actions = count
        result.verified_completion = ratio(verified_due, due)
        result.planning_readiness = ratio(ready, count)
        result.retest_coverage = ratio(retested, completed)
        result.improvement_among_retested = ratio(improved, retested)
        result.on_time_retest_of_completed_due_actions =
            ratio(completed_retests_met, completed_retests_due)
        result.scope =
            "Descriptive supplied-cohort accounting only; no deduplication, "
            .. "causal attribution, participant satisfaction, or public release."
        return result
    end)
end

function M.self_test()
    local claim = {
        statement = "Synthetic continuity proposal",
        label = "proposal",
        scope = "Local pilot only",
        limitations = "Not adopted or empirically validated",
        source_class = "none",
        review_status = "unreviewed"
    }
    assert(assert(M.claim_check(claim)).result ==
        "structural_label_requirements_satisfied")

    claim.label = "finding"
    assert(assert(M.claim_check(claim)).result ==
        "qualification_or_review_required")

    local actions = {
        {
            accepted_at = 0,
            original_due_at = 5,
            owner_role = "Accessibility coordinator",
            ownership_accepted = "yes",
            resources_available = "yes",
            retest_due_at = 8,
            completed_at = 4,
            verification = "confirmed",
            retested_at = 7,
            improvement = "supported"
        },
        {
            accepted_at = 1,
            original_due_at = 6,
            ownership_accepted = "unknown",
            resources_available = "unknown",
            verification = "unknown",
            improvement = "not_assessed"
        }
    }

    local dashboard = assert(M.action_dashboard(actions, 10))
    assert(dashboard.verified_completion.value == 0.5)
    assert(dashboard.retest_coverage.value == 1)
    assert(dashboard.improvement_among_retested.value == 1)

    local empty = assert(M.action_dashboard({}, 0))
    assert(empty.verified_completion.status == "not_estimable")

    dashboard.verified_completion.value = 0
    assert(assert(M.action_dashboard(actions, 10))
        .verified_completion.value == 0.5)

    return true
end

return M
