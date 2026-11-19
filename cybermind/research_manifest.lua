-- Lua 5.4.
-- Compiled research inventory and readiness-gap reporting.
-- No I/O, data collection, participant classification, or external actions.
-- Import: local research = require("cybermind.research_manifest")
-- Tests: assert(research.self_test())
--
-- Research group order is presentation order, not a dependency schedule.
-- Readiness values are supplied assertions, not authenticated evidence.

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local GROUPS = {
    {
        name = "Knowledge integrity and scenario practice",
        topics = {
            "Evidence register schema and provenance",
            "Fiction-to-scenario conversion",
            "Scenario coverage matrix",
            "Failure-pattern taxonomy",
            "Positive scenario library",
            "Claim-source labeling",
            "Scenario-to-action evaluation"
        }
    },
    {
        name = "Privacy and information lifecycle",
        topics = {
            "Inference gate",
            "Minimal audit design",
            "Anonymous feedback",
            "Retention and deletion",
            "Cognitive liberty and mental privacy",
            "Neural versus inferred-state gap"
        }
    },
    {
        name = "Communication and activation",
        topics = {
            "Functional accommodation intake",
            "Draft and approved expression workflow",
            "Communication fidelity",
            "Inner-speech consent architecture",
            "Thought-password limitations"
        }
    },
    {
        name = "Continuity repair and ecology",
        topics = {
            "Continuity metrics",
            "Dependency taxonomy",
            "Continuity trust structures",
            "Cross-organizational responsibility",
            "Environmental lifecycle assessment",
            "Repairability requirements",
            "Transition equivalence",
            "User-defined wellbeing"
        }
    },
    {
        name = "Justification preservation and emergencies",
        topics = {
            "Three-valued justification",
            "Emergency pathway",
            "Role-reversal test",
            "Irreversibility assessment",
            "Machine-verifiable checks",
            "Non-aggression and threat assessment"
        }
    },
    {
        name = "Feedback moderation and non-retaliation",
        topics = {
            "Closed-loop feedback metrics",
            "Retaliation review",
            "Moderation proportionality"
        }
    },
    {
        name = "Governance and representation",
        topics = {
            "Representation without substrate surveillance",
            "Copy-count prevention",
            "Deadlock breaker",
            "CyberCongress pilot charter",
            "Ostrom adaptation"
        }
    },
    {
        name = "Supported participation and legal research",
        topics = {
            "Supported participation",
            "Advocacy for uncertain interests",
            "Proportional protection",
            "Overlapping interest profiles",
            "AI legal constructs",
            "International mechanisms"
        }
    },
    {
        name = "Possible machine interests",
        topics = {
            "Self-preservation evidence protocol",
            "Machine welfare uncertainty",
            "Non-extraction boundary",
            "Sanctuary and exit"
        }
    }
}

local CHECKS = {
    {
        name = "specification",
        next_step = "Define scope, inputs, outputs, and prohibited interpretations"
    },
    {
        name = "evidence_plan",
        next_step = "Specify evidence needs, alternatives, and evaluation method"
    },
    {
        name = "privacy_review",
        next_step = "Review information classes, permissions, retention, and deletion"
    },
    {
        name = "accessibility_review",
        next_step = "Review usable participation, correction, and chosen assistance"
    },
    {
        name = "implementation_tests",
        next_step = "Execute applicable tests and retain an accurate test report"
    },
    {
        name = "resources",
        next_step = "Confirm accepted ownership, funding, personnel, and time"
    },
    {
        name = "independent_review",
        next_step = "Arrange scoped review and conflict handling"
    },
    {
        name = "empirical_evaluation",
        next_step = "Evaluate applicable claims or document why not applicable"
    }
}

local STATUS = {
    established = true,
    not_established = true,
    unknown = true,
    not_applicable = true
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

local function text(value, path)
    if type(value) ~= "string" or #value > 4096
        or not value:match("%S") or value:find("%c") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
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

function M.manifest()
    local result = {
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope =
            "Credit and workstream metadata only; not identity, consent, "
            .. "authorization, execution evidence, or authority.",
        workstreams = {},
        topic_count = 0,
        scope =
            "Research compilation, not a validated dependency schedule, "
            .. "legal status determination, or deployment authorization."
    }

    for _, group in ipairs(GROUPS) do
        local copied = {name = group.name, topics = {}}
        for _, topic in ipairs(group.topics) do
            copied.topics[#copied.topics + 1] = topic
            result.topic_count = result.topic_count + 1
        end
        result.workstreams[#result.workstreams + 1] = copied
    end
    return result
end

function M.plan(records)
    return protect(function()
        plain(records, "records")
        local known_topics = {}
        local allowed_checks = {}

        for _, group in ipairs(GROUPS) do
            for _, topic in ipairs(group.topics) do known_topics[topic] = true end
        end
        for _, check in ipairs(CHECKS) do allowed_checks[check.name] = true end

        for topic in next, records do
            if type(topic) ~= "string" or not known_topics[topic] then
                fail("UNKNOWN_TOPIC", "records", "Topic is outside this manifest")
            end
        end

        local result = M.manifest()
        result.topic_reviews = {}
        result.execution_authority = "none"

        for _, group in ipairs(GROUPS) do
            for _, topic in ipairs(group.topics) do
                local supplied = records[topic] or {}
                fields(supplied, allowed_checks, topic)

                local review = {
                    topic = topic,
                    workstream = group.name,
                    gaps = {},
                    exemptions = {},
                    condition_count = #CHECKS
                }

                for _, check in ipairs(CHECKS) do
                    local entry = supplied[check.name]
                    local status = "unknown"

                    if entry ~= nil then
                        fields(entry, {
                            status = true,
                            basis = true
                        }, topic .. "." .. check.name)
                        if type(entry.status) ~= "string"
                            or not STATUS[entry.status] then
                            fail("INVALID_STATUS", topic .. "." .. check.name,
                                "Unknown readiness status")
                        end
                        text(entry.basis, topic .. "." .. check.name .. ".basis")
                        status = entry.status
                    end

                    if status == "not_applicable" then
                        review.exemptions[#review.exemptions + 1] = {
                            condition = check.name,
                            basis = entry.basis
                        }
                    elseif status ~= "established" then
                        review.gaps[#review.gaps + 1] = {
                            condition = check.name,
                            status = status,
                            next_step = check.next_step
                        }
                    end
                end

                if #review.gaps > 0 then
                    review.result = "readiness_gaps_recorded"
                elseif #review.exemptions > 0 then
                    review.result = "supplied_conditions_with_declared_exemptions"
                else
                    review.result = "supplied_conditions_established"
                end

                review.scope =
                    "Assertions and documented exemptions only; "
                    .. "no pilot approval or participant eligibility decision."
                result.topic_reviews[#result.topic_reviews + 1] = review
            end
        end

        return result
    end)
end

function M.self_test()
    local manifest = M.manifest()
    assert(manifest.topic_count == 50)
    assert(#manifest.workstreams == 9)

    local seen = {}
    for _, group in ipairs(manifest.workstreams) do
        for _, topic in ipairs(group.topics) do
            assert(not seen[topic])
            seen[topic] = true
        end
    end

    local plan = assert(M.plan({}))
    assert(#plan.topic_reviews == 50)
    assert(#plan.topic_reviews[1].gaps == #CHECKS)
    assert(plan.execution_authority == "none")

    local records = {
        ["Evidence register schema and provenance"] = {
            specification = {
                status = "established",
                basis = "Synthetic test assertion, not an actual review"
            },
            empirical_evaluation = {
                status = "not_applicable",
                basis = "Synthetic example of an explicitly justified exemption"
            }
        }
    }
    plan = assert(M.plan(records))
    assert(#plan.topic_reviews[1].gaps == #CHECKS - 2)
    assert(#plan.topic_reviews[1].exemptions == 1)

    manifest.workstreams[1].topics[1] = "Caller modification"
    assert(M.manifest().workstreams[1].topics[1] ==
        "Evidence register schema and provenance")

    local value, err = M.plan({["Unlisted topic"] = {}})
    assert(value == nil and err.code == "UNKNOWN_TOPIC")

    return true
end

return M
