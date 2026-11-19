-- Lua 5.4.
-- Executes local contract tests against caller-supplied module tables.
-- No repository discovery, I/O, publication, or external-system access.
--
-- Usage:
-- local harness = require("cybermind.synthetic_baseline_harness")
-- local result = assert(harness.run({
--     research = require("cybermind.research_manifest"),
--     feedback = require("cybermind.feedback_outcomes"),
--     report = require("cybermind.synthetic_pilot_report")
-- }))

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local function fail(code, path, message)
    error({code = code, path = path, message = message}, 0)
end

local function require_function(module, name, path)
    if type(module) ~= "table" or type(module[name]) ~= "function" then
        fail("MISSING_INTERFACE", path .. "." .. name,
            "Expected supplied module function")
    end
end

local function check(condition, message)
    if not condition then
        fail("TEST_ASSERTION_FAILED", "test", message)
    end
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
        code = "HARNESS_ERROR",
        path = "harness",
        message = "Unexpected harness failure"
    }
end

local function feedback_fixture()
    return {
        {
            received_at = 0,
            acknowledgement_due_at = 5,
            acknowledged_at = 4,
            disclosure_review = "not_reviewed"
        }
    }
end

function M.run(modules)
    return protect(function()
        if type(modules) ~= "table" then
            fail("INVALID_MODULES", "modules",
                "Supply the local module tables explicitly")
        end

        require_function(modules.research, "manifest", "research")
        require_function(modules.research, "plan", "research")
        require_function(modules.feedback, "dashboard", "feedback")
        require_function(modules.report, "compile", "report")

        local results = {}
        local passed, failed = 0, 0

        local function test(name, operation)
            local ok, failure = pcall(operation)
            local entry = {
                name = name,
                executed = true,
                result = ok and "passed" or "failed"
            }

            if ok then
                passed = passed + 1
            else
                failed = failed + 1
                entry.error_code = type(failure) == "table"
                    and type(failure.code) == "string"
                    and failure.code or "UNSTRUCTURED_TEST_FAILURE"
            end
            results[#results + 1] = entry
        end

        test("Manifest contains the declared research inventory", function()
            local manifest = modules.research.manifest()
            check(manifest.topic_count == 50, "Expected fifty topics")
            check(#manifest.workstreams == 9, "Expected nine workstreams")
        end)

        test("Empty readiness plan exposes four hundred gaps", function()
            local plan = must(modules.research.plan({}))
            local total = 0
            check(#plan.topic_reviews == 50, "Expected fifty topic reviews")
            for _, topic in ipairs(plan.topic_reviews) do
                total = total + #topic.gaps
            end
            check(total == 400, "Expected eight unknown checks per topic")
        end)

        test("Invalid readiness status is rejected", function()
            local value, err = modules.research.plan({
                ["Evidence register schema and provenance"] = {
                    specification = {
                        status = "finding",
                        basis = "Synthetic invalid-status fixture"
                    }
                }
            })
            check(value == nil and err.code == "INVALID_STATUS",
                "Expected readiness-schema rejection")
        end)

        test("Empty dashboard is not perfect performance", function()
            local dashboard = must(modules.feedback.dashboard({}, {}, 0))
            local metric = dashboard.verified_completion_of_due_actions
            check(metric.status == "not_estimable",
                "Zero denominator must remain not estimable")
            check(metric.value == nil, "No ratio value expected")
        end)

        test("Completed action without confirmed verification is not counted",
            function()
                local dashboard = must(modules.feedback.dashboard({}, {
                    {
                        accepted_at = 0,
                        original_due_at = 5,
                        completed_at = 4,
                        verification = "unknown",
                        benefit = "not_assessed"
                    }
                }, 10))
                local metric = dashboard.verified_completion_of_due_actions
                check(metric.numerator == 0 and metric.denominator == 1,
                    "Unverified action must not count as verified")
            end
        )

        test("Unsupported closure field is rejected structurally", function()
            local value, err = modules.feedback.dashboard({}, {
                {
                    accepted_at = 0,
                    original_due_at = 5,
                    verification = "unknown",
                    benefit = "not_assessed",
                    status = "closed"
                }
            }, 10)
            check(value == nil and err.code == "UNKNOWN_FIELD",
                "Expected unknown-field rejection, not closure enforcement")
        end)

        test("Unexpected structured feedback content is rejected", function()
            local records = feedback_fixture()
            records[1].private_content = "Synthetic marker, not personal data"
            local value, err = modules.feedback.dashboard(records, {}, 10)
            check(value == nil and err.code == "UNKNOWN_FIELD",
                "Expected closed-schema rejection")
        end)

        test("Compiler counts supplied results rather than executing them",
            function()
                local report = must(modules.report.compile({
                    readiness_records = {},
                    feedback_records = {},
                    actions = {},
                    cutoff = 0,
                    adversarial_results = {"matched_expectation"}
                }))
                check(report.adversarial_results.matched_expectation == 1,
                    "Expected supplied classification to be counted")
                check(report.publication_authority == "none",
                    "Report must not claim publication authority")
            end
        )

        test("Dependency errors are not automatically not-executed results",
            function()
                local value, err = modules.report.compile({
                    readiness_records = {},
                    feedback_records = {},
                    actions = {
                        {
                            accepted_at = 0,
                            original_due_at = 5,
                            verification = "unknown",
                            benefit = "not_assessed",
                            status = "closed"
                        }
                    },
                    cutoff = 10,
                    adversarial_results = {}
                })
                check(value == nil and err.code == "UNKNOWN_FIELD",
                    "Expected propagated dependency error")
            end
        )

        return {
            schema_version = VERSION,
            attribution = ATTRIBUTION,
            attribution_scope =
                "Credit and workstream metadata only; not identity, consent, "
                .. "authorization, execution evidence, or authority.",
            execution_environment = _VERSION,
            tests = results,
            executed_count = #results,
            passed_count = passed,
            failed_count = failed,
            broader_safeguards_not_established = {
                "Participant non-disclosure neutrality",
                "Expression approval expiry and recipient binding",
                "Policy-service outage isolation",
                "Case-closure enforcement",
                "Fiction-label preservation through summaries",
                "Free-text privacy and report linkability",
                "Action-level accepted ownership and resources"
            },
            scope =
                "Local supplied-module contract tests only; no end-to-end "
                .. "safeguard certification, causal benefit, or public release."
        }
    end)
end

return M
