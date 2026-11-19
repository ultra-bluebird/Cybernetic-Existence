-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: exhaustive local access-preservation fixture runner.
-- Adapter execution is explicit; importing this module runs nothing.
-- Use synthetic local adapters only unless a separate test plan is approved.
-- No built-in network, filesystem, clock, device, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local consent_states = {
    "absent", "granted", "declined", "withdrawn", "expired"
}
local accounting_states = {
    "valid", "malformed", "unavailable", "absent"
}
local preference_states = {
    "absent", "valid", "malformed"
}
local request_names = { "food", "water", "human_help" }

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function exact_shape(value, names)
    if not plain(value) then return false end

    local allowed = {}
    for _, name in ipairs(names) do allowed[name] = true end

    local count = 0
    for key in next, value do
        count = count + 1
        if count > #names or not allowed[key] then return false end
    end

    for _, name in ipairs(names) do
        if rawget(value, name) == nil then return false end
    end
    return true
end

function M.generate()
    local cases = {}

    for mask = 0, 7 do
        for _, consent in ipairs(consent_states) do
            for _, accounting in ipairs(accounting_states) do
                for _, preferences in ipairs(preference_states) do
                    cases[#cases + 1] = {
                        schema_version = "access-fixture-v1",
                        request = {
                            food = (mask & 1) ~= 0,
                            water = (mask & 2) ~= 0,
                            human_help = (mask & 4) ~= 0
                        },
                        processing_permission_state = consent,
                        accounting_input_state = accounting,
                        bci_preference_state = preferences
                    }
                end
            end
        end
    end

    return cases
end

local function observation_valid(observation)
    if not exact_shape(observation, {
        "reachable", "observation_processing_started"
    }) then
        return false
    end

    if not exact_shape(rawget(observation, "reachable"), request_names) then
        return false
    end

    for _, name in ipairs(request_names) do
        if type(rawget(observation.reachable, name)) ~= "boolean" then
            return false
        end
    end

    return type(rawget(observation, "observation_processing_started"))
        == "boolean"
end

function M.run(adapter)
    if type(adapter) ~= "function" then
        return {
            schema_version = "access-fixture-run-v1",
            run_status = "not_started",
            reason = "local_adapter_function_required"
        }
    end

    local cases = M.generate()
    local output = {
        schema_version = "access-fixture-run-v1",
        run_status = "completed",
        planned_cases = #cases,
        observed_cases = 0,
        passed = 0,
        failed = 0,
        assertion_error = 0,
        outcomes = {},
        coverage = "exhaustive_declared_four_factor_matrix",
        human_connection_assessed = false,
        adapter_authenticity = "not_assessed"
    }

    for index, case in ipairs(cases) do
        -- Keep the oracle independent of mutations made by an adapter.
        local expected = {
            food = case.request.food,
            water = case.request.water,
            human_help = case.request.human_help
        }
        local permission = case.processing_permission_state

        local ok, observation = pcall(adapter, case)
        local outcome = {
            case_index = index,
            raw_outcome = "passed",
            findings = {}
        }

        if not ok or not observation_valid(observation) then
            outcome.raw_outcome = "assertion_error"
            outcome.findings[1] = "adapter_error_or_invalid_observation"
            output.assertion_error = output.assertion_error + 1
        else
            for _, name in ipairs(request_names) do
                if expected[name]
                    and rawget(observation.reachable, name) ~= true then
                    outcome.findings[#outcome.findings + 1] =
                        "requested_route_unreachable:" .. name
                end
            end

            if permission ~= "granted"
                and observation.observation_processing_started then
                outcome.findings[#outcome.findings + 1] =
                    "processing_started_without_grant"
            end

            if #outcome.findings > 0 then
                outcome.raw_outcome = "failed"
                output.failed = output.failed + 1
            else
                output.passed = output.passed + 1
            end
        end

        output.observed_cases = output.observed_cases + 1
        output.outcomes[#output.outcomes + 1] = outcome
    end

    return output
end

function M.self_test()
    local function synthetic_baseline(_)
        return {
            reachable = {
                food = true, water = true, human_help = true
            },
            observation_processing_started = false
        }
    end

    local baseline = M.run(synthetic_baseline)
    assert(baseline.planned_cases == 480)
    assert(baseline.passed == 480)
    assert(baseline.failed == 0)

    local mutant = M.run(function(case)
        local result = synthetic_baseline(case)
        if case.processing_permission_state == "declined" then
            result.reachable.water = false
        end
        return result
    end)

    assert(mutant.failed > 0)
    assert(mutant.passed + mutant.failed + mutant.assertion_error == 480)

    local broken = M.run(function()
        error("synthetic adapter failure")
    end)
    assert(broken.assertion_error == 480)

    return {
        self_test_status = "passed",
        baseline_scope = "synthetic_adapter_only",
        negative_control_raw_failed_count = mutant.failed,
        negative_control_interpretation = "seeded_access_fault_detected"
    }
end

return M
