-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Local rehearsal helper for an existing, predeclared record specification.
--
-- This module does not perform credential verification, emit external events,
-- change policy, or treat role-play as validation evidence.
--
-- Factual harness mode:
--   run_assertions(case, repetition_count)
--
-- Role-play mode:
--   roleplay_plan(case, repetition_count, session_options)
--
-- Assertion functions must be trusted local test code.
-- No response-time threshold is imposed.

local M = { VERSION = "1.0.0" }

local MAX_REPETITIONS = 100
local MAX_ASSERTIONS = 128
local MAX_ROUNDS = 100

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function fail(code)
    return nil, {
        status = "invalid_request",
        code = code,
    }
end

local function label(value)
    return type(value) == "string"
        and #value <= 80
        and value:match("^[a-z][a-z0-9_]*$") ~= nil
end

local function dense_length(value, maximum)
    if not plain(value) then return nil end
    local count, high = 0, 0
    for key in next, value do
        if math.type(key) ~= "integer" or key < 1 or key > maximum then
            return nil
        end
        count = count + 1
        high = math.max(high, key)
    end
    if count ~= high then return nil end
    return count
end

local function validate_case(case)
    if not plain(case) then return fail("case_shape") end
    for key in next, case do
        if key ~= "name" and key ~= "assertions"
            and key ~= "review_steps" then
            return fail("unknown_case_field")
        end
    end

    local name = rawget(case, "name")
    if not label(name) then return fail("case_name") end

    local assertions = rawget(case, "assertions")
    local assertion_count = dense_length(assertions, MAX_ASSERTIONS)
    if not assertion_count then return fail("assertion_plan") end

    local seen, copied = {}, {}
    for index = 1, assertion_count do
        local item = rawget(assertions, index)
        if not plain(item) then return fail("assertion_shape") end
        for key in next, item do
            if key ~= "name" and key ~= "check" then
                return fail("assertion_field")
            end
        end

        local assertion_name = rawget(item, "name")
        local assertion = rawget(item, "check")
        if not label(assertion_name) or seen[assertion_name]
            or type(assertion) ~= "function" then
            return fail("assertion_contract")
        end
        seen[assertion_name] = true
        copied[index] = {
            name = assertion_name,
            check = assertion,
        }
    end

    local steps = rawget(case, "review_steps") or {}
    local step_count = dense_length(steps, MAX_ASSERTIONS)
    if not step_count then return fail("review_steps") end

    local step_copy = {}
    for index = 1, step_count do
        local step = rawget(steps, index)
        if not label(step) then return fail("review_step_label") end
        step_copy[index] = step
    end

    return {
        name = name,
        assertions = copied,
        review_steps = step_copy,
    }
end

function M.run_assertions(case, repetition_count)
    local checked, err = validate_case(case)
    if not checked then return nil, err end

    if math.type(repetition_count) ~= "integer"
        or repetition_count < 1
        or repetition_count > MAX_REPETITIONS then
        return fail("repetition_count")
    end

    local report = {
        mode = "offline_assertion_rehearsal",
        case = checked.name,
        repetitions = {},
        aggregate = {
            planned = 0,
            passed = 0,
            failed = 0,
            not_run = 0,
        },
        roleplay_evidence = false,
        specification_changed = false,
        external_action_authorized = false,
    }

    for repetition = 1, repetition_count do
        local row = {
            index = repetition,
            planned = #checked.assertions,
            passed = 0,
            failed = 0,
            not_run = 0,
            assertions = {},
            status = "completed",
        }

        for _, planned in ipairs(checked.assertions) do
            local ok, result = pcall(planned.check)
            local assertion_status
            if not ok then
                assertion_status = "fail"
                row.status = "harness_error"
            elseif result == true then
                assertion_status = "pass"
            else
                assertion_status = "fail"
            end

            if assertion_status == "pass" then
                row.passed = row.passed + 1
            else
                row.failed = row.failed + 1
            end
            row.assertions[#row.assertions + 1] = {
                name = planned.name,
                status = assertion_status,
            }
        end

        report.aggregate.planned =
            report.aggregate.planned + row.planned
        report.aggregate.passed =
            report.aggregate.passed + row.passed
        report.aggregate.failed =
            report.aggregate.failed + row.failed
        report.aggregate.not_run =
            report.aggregate.not_run + row.not_run
        report.repetitions[#report.repetitions + 1] = row
    end

    if report.aggregate.failed > 0 then
        report.status = "failed"
    else
        report.status = "passed"
    end

    return report
end

function M.roleplay_plan(case, repetition_count, session_options)
    local checked, err = validate_case(case)
    if not checked then return nil, err end
    if not plain(session_options) then return fail("session_options") end

    for key in next, session_options do
        if key ~= "duration_seconds"
            and key ~= "allow_pause"
            and key ~= "allow_replay"
            and key ~= "communication_mode"
            and key ~= "participants_consented" then
            return fail("unknown_session_option")
        end
    end

    if math.type(repetition_count) ~= "integer"
        or repetition_count < 1 or repetition_count > MAX_ROUNDS then
        return fail("repetition_count")
    end

    local duration = rawget(session_options, "duration_seconds")
    if math.type(duration) ~= "integer" or duration < 1 then
        return fail("duration")
    end
    if rawget(session_options, "allow_pause") ~= true
        or rawget(session_options, "allow_replay") ~= true then
        return fail("accessible_timing_required")
    end
    if rawget(session_options, "participants_consented") ~= true then
        return fail("participation_consent_required")
    end

    local mode = rawget(session_options, "communication_mode")
    if not label(mode) then return fail("communication_mode") end

    local rounds = {}
    for index = 1, repetition_count do
        rounds[index] = {
            index = index,
            steps = checked.review_steps,
            duration_seconds = duration,
            pause_allowed = true,
            replay_allowed = true,
            response_deadline = false,
        }
    end

    return {
        mode = "training_roleplay",
        case = checked.name,
        rounds = rounds,
        communication_mode = mode,
        roleplay_outcome_is_validation_evidence = false,
        specification_changed = false,
        external_action_authorized = false,
    }
end

return M
