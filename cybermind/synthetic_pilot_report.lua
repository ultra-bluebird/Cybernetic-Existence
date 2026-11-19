-- Lua 5.4.
-- Requires:
--   cybermind/research_manifest.lua
--   cybermind/feedback_outcomes.lua
--
-- No I/O, publication, test execution, or external actions.
-- Import: local report = require("cybermind.synthetic_pilot_report")
-- Tests: assert(report.self_test())

local research = require("cybermind.research_manifest")
local feedback = require("cybermind.feedback_outcomes")
local M = {}

local VERSION = "1.0.0"

local RESULTS = {
    matched_expectation = true,
    differed_from_expectation = true,
    not_executed = true,
    inconclusive = true
}

local function fail(code, path, message)
    error({code = code, path = path, message = message}, 0)
end

local function plain(value, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_TABLE", path, "Expected a plain table")
    end
end

local function fields(value, allowed, path)
    plain(value, path)
    for key in next, value do
        if type(key) ~= "string" or not allowed[key] then
            fail("UNKNOWN_FIELD", path, "Unexpected field")
        end
    end
end

local function array_length(value, path)
    plain(value, path)
    local count, maximum = 0, 0
    for key in next, value do
        if type(key) ~= "number" or math.type(key) ~= "integer" or key < 1 then
            fail("INVALID_ARRAY_KEY", path,
                "Expected consecutive positive integer keys")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum or count > 1000 then
        fail("INVALID_ARRAY_SIZE", path, "Array is sparse or exceeds limit")
    end
    return count
end

local function must(value, err)
    if value == nil then error(err, 0) end
    return value
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

function M.compile(input)
    return protect(function()
        fields(input, {
            readiness_records = true,
            feedback_records = true,
            actions = true,
            cutoff = true,
            adversarial_results = true
        }, "pilot")

        local plan = must(research.plan(input.readiness_records))
        local dashboard = must(feedback.dashboard(
            input.feedback_records, input.actions, input.cutoff
        ))

        local tests = {
            matched_expectation = 0,
            differed_from_expectation = 0,
            not_executed = 0,
            inconclusive = 0
        }
        local count = array_length(
            input.adversarial_results, "adversarial_results"
        )

        for position = 1, count do
            local value = input.adversarial_results[position]
            if type(value) ~= "string" or not RESULTS[value] then
                fail("INVALID_RESULT", "adversarial_results",
                    "Expected a declared test-result category")
            end
            tests[value] = tests[value] + 1
        end

        local readiness = {
            topics = #plan.topic_reviews,
            topics_with_gaps = 0,
            recorded_gaps = 0,
            declared_exemptions = 0
        }

        for _, topic in ipairs(plan.topic_reviews) do
            if #topic.gaps > 0 then
                readiness.topics_with_gaps =
                    readiness.topics_with_gaps + 1
            end
            readiness.recorded_gaps =
                readiness.recorded_gaps + #topic.gaps
            readiness.declared_exemptions =
                readiness.declared_exemptions + #topic.exemptions
        end

        local result = research.manifest()
        result.workstreams = nil
        result.schema_version = VERSION
        result.report_kind = "synthetic_pilot_aggregate"
        result.readiness = readiness
        result.adversarial_results = tests
        result.feedback_metrics = {
            acknowledgement_on_time = dashboard.acknowledgement_on_time,
            verified_completion = dashboard.verified_completion_of_due_actions,
            disclosure_review_coverage = dashboard.disclosure_review_coverage,
            benefit_assessment_coverage = dashboard.benefit_assessment_coverage,
            benefit_support_among_assessed =
                dashboard.benefit_support_among_assessed
        }

        if count == 0 then
            result.test_summary = "no_adversarial_results_supplied"
        elseif tests.differed_from_expectation > 0 then
            result.test_summary = "observed_mismatches_require_examination"
        elseif tests.not_executed > 0 or tests.inconclusive > 0 then
            result.test_summary = "test_evidence_incomplete"
        else
            result.test_summary = "supplied_results_match_recorded_expectations"
        end

        result.publication_authority = "none"
        result.scope =
            "Aggregation of supplied synthetic records only; no test execution, "
            .. "expectation validation, anonymity guarantee, launch approval, "
            .. "causal finding, or public-release authorization."
        return result
    end)
end

function M.self_test()
    local input = {
        readiness_records = {},
        feedback_records = {},
        actions = {},
        cutoff = 0,
        adversarial_results = {
            "matched_expectation",
            "differed_from_expectation",
            "not_executed"
        }
    }

    local result = assert(M.compile(input))
    assert(result.readiness.topics == 50)
    assert(result.readiness.topics_with_gaps == 50)
    assert(result.adversarial_results.not_executed == 1)
    assert(result.test_summary ==
        "observed_mismatches_require_examination")
    assert(result.feedback_metrics.verified_completion.status ==
        "not_estimable")
    assert(result.workstreams == nil)

    result.readiness.topics = 0
    assert(assert(M.compile(input)).readiness.topics == 50)

    input.adversarial_results = {}
    assert(assert(M.compile(input)).test_summary ==
        "no_adversarial_results_supplied")

    return true
end

return M
