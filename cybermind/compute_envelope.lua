-- Lua 5.4.
-- Explicit-unit scenario accounting, not an AGI estimator.
-- No I/O, procurement, hardware control, or external actions.
-- Import: local compute = require("cybermind.compute_envelope")
-- Tests: assert(compute.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

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

local function number(value, path, minimum, maximum, whole)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < minimum or value > maximum
        or (whole and value % 1 ~= 0) then
        fail("INVALID_NUMBER", path, "Number violates declared bounds")
    end
    return value
end

local function note(value)
    if type(value) ~= "string" or #value > 4096
        or not value:match("%S") or value:find("%c") then
        fail("INVALID_NOTE", "assumption_note",
            "Expected bounded nonblank assumption description")
    end
    return value
end

local function finite_result(value, path)
    return number(value, path, 0, 1e308, false)
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

function M.training(input)
    return protect(function()
        fields(input, {
            active_parameters = true,
            training_tokens = true,
            algorithmic_multiplier = true,
            accelerators = true,
            peak_flop_per_second = true,
            running_mfu = true,
            calendar_availability = true,
            accelerators_per_node = true,
            node_it_kw = true,
            additional_it_kw = true,
            pue = true,
            electricity_usd_per_mwh = true,
            assumption_note = true
        }, "training")

        note(input.assumption_note)
        local parameters = number(input.active_parameters,
            "active_parameters", 1, 9e15, true)
        local tokens = number(input.training_tokens,
            "training_tokens", 1, 9e15, true)
        local multiplier = number(input.algorithmic_multiplier,
            "algorithmic_multiplier", 1, 1e6, false)
        local accelerators = number(input.accelerators,
            "accelerators", 1, 1000000000, true)
        local peak = number(input.peak_flop_per_second,
            "peak_flop_per_second", 1, 1e20, false)
        local mfu = number(input.running_mfu,
            "running_mfu", 0.000001, 1, false)
        local availability = number(input.calendar_availability,
            "calendar_availability", 0.000001, 1, false)
        local per_node = number(input.accelerators_per_node,
            "accelerators_per_node", 1, 1024, true)
        local node_kw = number(input.node_it_kw,
            "node_it_kw", 0.000001, 1000000, false)
        local additional_kw = number(input.additional_it_kw,
            "additional_it_kw", 0, 1e12, false)
        local pue = number(input.pue, "pue", 1, 10, false)
        local price = number(input.electricity_usd_per_mwh,
            "electricity_usd_per_mwh", 0, 1000000, false)

        local nodes = math.ceil(accelerators / per_node)
        local compute = finite_result(
            6 * parameters * tokens * multiplier, "training_flop"
        )
        local rate = finite_result(
            accelerators * peak * mfu * availability,
            "calendar_average_flop_per_second"
        )
        local seconds = finite_result(compute / rate, "calendar_seconds")
        local it_kw = finite_result(nodes * node_kw + additional_kw, "it_kw")
        local facility_kw = finite_result(it_kw * pue, "facility_kw")
        local energy_mwh = finite_result(
            facility_kw * seconds / 3600000, "facility_energy_mwh"
        )

        local result = M.metadata()
        result.training_flop = compute
        result.calendar_average_flop_per_second = rate
        result.calendar_days = seconds / 86400
        result.provisioned_nodes = nodes
        result.it_mw = it_kw / 1000
        result.facility_mw = facility_kw / 1000
        result.facility_energy_mwh = energy_mwh
        result.electricity_cost_usd = finite_result(
            energy_mwh * price, "electricity_cost_usd"
        )
        result.power_assumption =
            "Specified node and additional IT power held constant for "
            .. "the entire calendar duration, including modeled downtime"
        result.scope =
            "Scenario arithmetic only; no capability, AGI, cost quotation, "
            .. "cooling-water, or operational-feasibility finding."
        return result
    end)
end

function M.serving(input)
    return protect(function()
        fields(input, {
            users = true,
            visible_tokens_per_user_hour = true,
            compute_multiplier = true,
            active_parameters = true,
            effective_flop_per_second_per_accelerator = true,
            assumption_note = true
        }, "serving")

        note(input.assumption_note)
        local users = number(input.users, "users", 0, 1e12, true)
        local tokens = number(input.visible_tokens_per_user_hour,
            "visible_tokens_per_user_hour", 0, 1e9, false)
        local multiplier = number(input.compute_multiplier,
            "compute_multiplier", 1, 1e6, false)
        local parameters = number(input.active_parameters,
            "active_parameters", 1, 9e15, true)
        local rate = number(input.effective_flop_per_second_per_accelerator,
            "effective_flop_per_second_per_accelerator", 1, 1e20, false)

        local visible_rate = users * tokens / 3600
        local compute_rate = finite_result(
            visible_rate * multiplier * 2 * parameters,
            "required_flop_per_second"
        )

        local result = M.metadata()
        result.visible_tokens_per_second = visible_rate
        result.required_flop_per_second = compute_rate
        result.compute_only_accelerator_count =
            math.ceil(compute_rate / rate)
        result.scope =
            "Compute-only baseline with multiplier applied once; excludes "
            .. "memory, latency, networking, availability, and capability claims."
        return result
    end)
end

function M.self_test()
    local result = assert(M.training({
        active_parameters = 2e12,
        training_tokens = 5e13,
        algorithmic_multiplier = 1,
        accelerators = 500000,
        peak_flop_per_second = 2.25e15,
        running_mfu = 0.4,
        calendar_availability = 1,
        accelerators_per_node = 8,
        node_it_kw = 14.3,
        additional_it_kw = 0,
        pue = 1.18,
        electricity_usd_per_mwh = 50,
        assumption_note = "Supplied scenario, not a measured training run"
    }))
    assert(math.abs(result.training_flop / 6e26 - 1) < 1e-12)
    assert(math.abs(result.calendar_days - 15.4320987654) < 1e-8)
    assert(math.abs(result.facility_mw - 1054.625) < 1e-8)

    local serving = assert(M.serving({
        users = 10000000,
        visible_tokens_per_user_hour = 1000,
        compute_multiplier = 100,
        active_parameters = 2e12,
        effective_flop_per_second_per_accelerator = 9e14,
        assumption_note = "Supplied workload and throughput assumptions"
    }))
    assert(serving.compute_only_accelerator_count == 1234568)

    return true
end

return M
