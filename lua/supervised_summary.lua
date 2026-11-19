-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Supervisor-owned final summary evidence for a trusted Lua 5.4 host.
--
-- Trusted host code alone may register, commit, and confirm stopped.
-- No worker control, randomness implementation, I/O, authentication,
-- durable replay store, or external actions.
--
-- issue_correlation() must return 32 reviewed host-generated random bytes.
-- Synthetic generators are suitable only for tests.
--
-- Registry entries are retained until this supervisor object is released.
-- Capacity is bounded; entries are not evicted and silently reused.

local M = {
    VERSION = "1.0.0",
    INPUT_FORMAT_VERSION = 2,
    SUMMARY_FORMAT_VERSION = 2,
}

local INPUT_SCHEMA = "supervised_execution_input"
local OUTPUT_SCHEMA = "supervised_execution_summary"
local MAX_ATTEMPTS = 128
local MAX_COUNT = 1000000

local outcomes = {
    completed = {
        execution = "completed",
        label = "Termination reason: not applicable",
    },
    language_error = {
        execution = "language_error",
        label = "Termination reason: not applicable",
    },
    cancelled = {
        execution = "terminated",
        reason = "cancelled",
        label = "Termination reason: cancelled",
    },
    deadline = {
        execution = "terminated",
        reason = "deadline",
        label = "Termination reason: deadline exceeded",
    },
    resource_terminated = {
        execution = "terminated",
        reason = "budget_exhausted",
        label = "Termination reason: resource budget exhausted",
    },
    host_error = {
        execution = "terminated",
        reason = "host_error",
        label = "Termination reason: host failure",
    },
    worker_lost = {
        execution = "terminated",
        reason = "unknown",
        label = "Termination reason: unavailable after worker loss",
    },
}

local review_states = {
    not_assessed = true,
    caller_asserted = true,
    external_review_reported = true,
}

local fields = {
    "schema", "input_format_version", "execution_state",
    "termination_reason", "claimed_review",
    "planned", "passed", "failed", "not_run",
}
local known = {}
for _, field in ipairs(fields) do known[field] = true end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function fail(code)
    return nil, { status = "rejected", code = code }
end

local function count(value)
    return math.type(value) == "integer"
        and value >= 0 and value <= MAX_COUNT
end

local function decimal(value)
    if value == 0 then return "0" end
    local digits, reversed, result = "0123456789", {}, {}
    while value > 0 do
        local digit = value % 10
        reversed[#reversed + 1] = digits:sub(digit + 1, digit + 1)
        value = value // 10
    end
    for index = #reversed, 1, -1 do
        result[#result + 1] = reversed[index]
    end
    return table.concat(result)
end

function M.negotiate(expected_version, advertised_version)
    if advertised_version == nil then return fail("format_version_missing") end
    if math.type(advertised_version) ~= "integer"
        or math.type(expected_version) ~= "integer"
        or advertised_version ~= expected_version then
        return fail("format_version_unsupported")
    end
    return true
end

function M.new(issue_correlation)
    if type(issue_correlation) ~= "function" then
        return fail("correlation_generator")
    end

    local attempts, used = {}, {}
    local total = 0
    local api = {}

    local function owned(handle)
        if type(handle) ~= "table" then return nil end
        return attempts[handle]
    end

    local function copy_summary(record)
        local result = {}
        for key, value in pairs(record) do result[key] = value end
        return result
    end

    function api.register_attempt()
        if total >= MAX_ATTEMPTS then return fail("attempt_capacity") end

        local ok, correlation = pcall(issue_correlation)
        if not ok or type(correlation) ~= "string" or #correlation ~= 32 then
            return fail("correlation_generator_result")
        end
        if used[correlation] then return fail("correlation_reuse") end

        local handle = {}
        attempts[handle] = {
            correlation = correlation,
            stopped = false,
        }
        used[correlation] = true
        total = total + 1
        return handle
    end

    function api.commit(handle, outcome)
        local attempt = owned(handle)
        if not attempt then return fail("foreign_attempt") end
        if type(outcome) ~= "string" or not outcomes[outcome] then
            return fail("outcome_value")
        end
        if attempt.outcome ~= nil then return fail("outcome_already_committed") end
        attempt.outcome = outcome
        return true
    end

    function api.confirm_stopped(handle)
        local attempt = owned(handle)
        if not attempt then return fail("foreign_attempt") end
        if attempt.outcome == nil then attempt.outcome = "worker_lost" end
        attempt.stopped = true
        return true
    end

    function api.summarize(handle, input)
        local attempt = owned(handle)
        if not attempt then return fail("foreign_attempt") end
        if not plain(input) then return fail("input_shape") end

        -- Correlation comes only from the private supervisor registry.
        if rawget(input, "correlation_id") ~= nil
            or rawget(input, "correlation_reference") ~= nil then
            return fail("correlation_field_forbidden")
        end

        local negotiated, err = M.negotiate(
            2, rawget(input, "input_format_version")
        )
        if not negotiated then return nil, err end
        if rawget(input, "schema") ~= INPUT_SCHEMA then
            return fail("schema_family_unsupported")
        end
        for key in next, input do
            if not known[key] then return fail("unknown_field") end
        end

        if attempt.outcome == nil then return fail("outcome_uncommitted") end
        if not attempt.stopped then return fail("worker_stop_unconfirmed") end

        local expected = outcomes[attempt.outcome]
        if rawget(input, "execution_state") ~= expected.execution then
            return fail("lifecycle_outcome_mismatch")
        end
        if rawget(input, "termination_reason") ~= expected.reason then
            return fail("termination_reason_mismatch")
        end

        local review = rawget(input, "claimed_review")
        if type(review) ~= "string" or not review_states[review] then
            return fail("review_state")
        end

        local checked = {}
        for _, field in ipairs({ "planned", "passed", "failed", "not_run" }) do
            local value = rawget(input, field)
            if not count(value) then return fail("assertion_count") end
            checked[field] = value
        end
        if checked.passed + checked.failed + checked.not_run ~= checked.planned then
            return fail("assertion_partition")
        end

        local result = {
            schema = OUTPUT_SCHEMA,
            summary_format_version = 2,
            producer_version = "1.0.0",
            correlation_format = "opaque32_v1",
            correlation_reference = attempt.correlation,
            committed_outcome = attempt.outcome,
            execution_state = expected.execution,
            termination_reason = expected.reason,
            termination_label = expected.label,
            worker_stop_confirmed = true,
            claimed_review = review,
            planned = checked.planned,
            passed = checked.passed,
            failed = checked.failed,
            not_run = checked.not_run,
            assertion_provenance = "caller_supplied",
            scientific_validation = "not_established",
            external_action_authorized = false,
        }

        if attempt.summary then
            for key, value in pairs(result) do
                if attempt.summary[key] ~= value then
                    return fail("summary_revision_requires_correction")
                end
            end
            return copy_summary(attempt.summary)
        end

        attempt.summary = result
        return copy_summary(result)
    end

    function api.render(handle, input)
        local result, err = api.summarize(handle, input)
        if not result then return nil, err end

        local assertion_label
        if result.planned == 0 then
            assertion_label = "no assertions planned"
        elseif result.failed > 0 and result.not_run > 0 then
            assertion_label = "failures recorded; some assertions not run"
        elseif result.failed > 0 then
            assertion_label = "failures recorded"
        elseif result.not_run > 0 then
            assertion_label = "some planned assertions not run"
        else
            assertion_label = "all planned assertions recorded as passed"
        end

        local lines = {
            "Supervised execution summary | Format: 2",
            "Execution: " .. result.execution_state,
            result.termination_label,
            "Worker stop: confirmed by supervisor",
            "Assertions: " .. assertion_label,
            "Planned: " .. decimal(result.planned),
            "Passed: " .. decimal(result.passed),
            "Failed: " .. decimal(result.failed),
            "Not run: " .. decimal(result.not_run),
            "Correlation: supervisor-bound; private bytes omitted",
            "Assertion provenance: caller-supplied",
            "Scientific validation: not established",
        }
        if result.committed_outcome ~= "completed" then
            lines[#lines + 1] =
                "Warning: passing assertions do not establish run completion."
        end
        return table.concat(lines, "\n") .. "\n"
    end

    return api
end

return M
