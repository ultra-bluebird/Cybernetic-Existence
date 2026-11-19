-- Lua 5.4.
-- Pure local planning and dimensional accounting.
-- No I/O, legal determination, hardware access, or repair execution.
-- Import: local lifecycle = require("cybermind.continuity_lifecycle")
-- Tests: assert(lifecycle.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local TRI = {yes = true, no = true, unknown = true}
local PHASES = {
    "manufacture", "distribution", "use",
    "maintenance", "transition", "end_of_life"
}
local METRICS = {
    {name = "energy_kwh", unit = "kWh"},
    {name = "climate_kg_co2e", unit = "kg CO2e"},
    {name = "electronic_waste_kg", unit = "kg electronic waste"}
}

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
    if type(value) ~= "string" or #value > 4096
        or not value:match("%S") or value:find("%c") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function numeric(value, path, maximum, whole)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < 0 or value > maximum
        or (whole and value % 1 ~= 0) then
        fail("INVALID_NUMBER", path, "Number violates declared bounds")
    end
    return value
end

local function choice(value, vocabulary, path)
    if type(value) ~= "string" or not vocabulary[value] then
        fail("INVALID_ENUM", path, "Unknown vocabulary value")
    end
    return value
end

local function length(value, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_ARRAY", path, "Expected a plain array")
    end
    local count, maximum = 0, 0
    for key in next, value do
        if type(key) ~= "number" or math.type(key) ~= "integer"
            or key < 1 then
            fail("INVALID_ARRAY_KEY", path,
                "Expected consecutive positive integer keys")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum then
        fail("SPARSE_ARRAY", path, "Array has missing positions")
    end
    if count > 10000 then
        fail("LIMIT_EXCEEDED", path, "Collection exceeds limit")
    end
    return count
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

function M.responsibility_gaps(obligations)
    return protect(function()
        local count = length(obligations, "obligations")
        local result = M.metadata()
        result.gaps = {}
        result.obligations_reviewed = count

        for position = 1, count do
            local row = obligations[position]
            local path = "obligations[" .. position .. "]"
            fields(row, {
                capability = true,
                duty = true,
                accountable_role = true,
                operational_role = true,
                duty_accepted = true,
                funded = true,
                resources_available = true,
                transition_tested = true,
                review_route = true
            }, path)

            local capability = text(row.capability, path .. ".capability")
            local duty = text(row.duty, path .. ".duty")
            local missing = {}

            for _, field in ipairs({
                "accountable_role", "operational_role", "review_route"
            }) do
                if row[field] == nil then
                    missing[#missing + 1] = field .. ":not_recorded"
                else
                    text(row[field], path .. "." .. field)
                end
            end

            for _, field in ipairs({
                "duty_accepted", "funded",
                "resources_available", "transition_tested"
            }) do
                local value = choice(row[field], TRI, path .. "." .. field)
                if value ~= "yes" then
                    missing[#missing + 1] = field .. ":" .. value
                end
            end

            if #missing > 0 then
                result.gaps[#result.gaps + 1] = {
                    capability = capability,
                    duty = duty,
                    gaps = missing
                }
            end
        end

        result.status = count == 0 and "scope_not_established"
            or (#result.gaps == 0 and "supplied_checklist_satisfied"
                or "responsibility_gaps_recorded")
        result.scope =
            "Supplied assertions only; no contract enforceability, "
            .. "institutional authority, or operational capacity verified."
        return result
    end)
end

function M.lifecycle_profile(input)
    return protect(function()
        fields(input, {
            functional_unit = true,
            boundary_note = true,
            phases = true,
            inventory = true,
            requested_tasks = true,
            attempted_tasks = true,
            successful_tasks = true
        }, "profile")

        fields(input.functional_unit, {
            task_protocol = true,
            horizon_hours = true,
            support_conditions = true,
            success_criterion = true
        }, "functional_unit")

        text(input.functional_unit.task_protocol, "functional_unit.task_protocol")
        text(input.functional_unit.support_conditions,
            "functional_unit.support_conditions")
        text(input.functional_unit.success_criterion,
            "functional_unit.success_criterion")
        local horizon = numeric(input.functional_unit.horizon_hours,
            "functional_unit.horizon_hours", 1000000, false)
        if horizon == 0 then
            fail("INVALID_HORIZON", "functional_unit.horizon_hours",
                "Assessment horizon must be positive")
        end
        text(input.boundary_note, "boundary_note")

        local requested = numeric(input.requested_tasks,
            "requested_tasks", 1000000000, true)
        local attempted = numeric(input.attempted_tasks,
            "attempted_tasks", requested, true)
        local successful = numeric(input.successful_tasks,
            "successful_tasks", attempted, true)

        local allowed_phases = {}
        for _, phase in ipairs(PHASES) do allowed_phases[phase] = true end
        fields(input.phases, allowed_phases, "phases")

        local limitations = {}
        for _, phase in ipairs(PHASES) do
            local state = choice(input.phases[phase], {
                included = true, excluded = true, unknown = true
            }, "phases." .. phase)
            if state ~= "included" then
                limitations[#limitations + 1] = phase .. ":" .. state
            end
        end

        local allowed_metrics = {}
        for _, metric in ipairs(METRICS) do
            allowed_metrics[metric.name] = true
        end
        fields(input.inventory, allowed_metrics, "inventory")

        local result = M.metadata()
        result.requested_tasks = requested
        result.attempted_tasks = attempted
        result.successful_tasks = successful
        result.unfulfilled_requested_tasks = requested - successful
        result.boundary_limitations = limitations
        result.indicators = {}

        if requested > 0 then
            result.fulfilment_fraction = successful / requested
        end

        for _, metric in ipairs(METRICS) do
            local source = input.inventory[metric.name]
            local path = "inventory." .. metric.name
            fields(source, {state = true, value = true, basis = true}, path)
            local state = choice(source.state, {
                known = true, unknown = true
            }, path .. ".state")
            text(source.basis, path .. ".basis")

            local indicator = {
                name = metric.name,
                unit = metric.unit,
                state = state,
                basis = source.basis
            }

            if state == "known" then
                local value = numeric(source.value, path .. ".value",
                    1000000000000000, false)
                indicator.total = value
                if requested > 0 then
                    indicator.per_requested_task = value / requested
                end
                if successful > 0 then
                    indicator.per_successful_task = value / successful
                end
            elseif source.value ~= nil then
                fail("UNKNOWN_WITH_VALUE", path,
                    "Unknown inventory must not contain a numeric value")
            end

            result.indicators[#result.indicators + 1] = indicator
        end

        result.scope =
            "Dimensional accounting under declared boundaries only; "
            .. "no full LCA, equivalence finding, environmental ranking, "
            .. "causal attribution, or access decision."
        return result
    end)
end

function M.self_test()
    local gaps = assert(M.responsibility_gaps({
        {
            capability = "Written participation",
            duty = "Maintain transition support",
            accountable_role = "Continuity coordinator",
            operational_role = "Authorized maintenance team",
            duty_accepted = "yes",
            funded = "unknown",
            resources_available = "yes",
            transition_tested = "no",
            review_route = "Independent written review"
        }
    }))
    assert(gaps.status == "responsibility_gaps_recorded")
    assert(#gaps.gaps[1].gaps == 2)

    local input = {
        functional_unit = {
            task_protocol = "Synthetic messaging protocol",
            horizon_hours = 100,
            support_conditions = "Synthetic accessible support arrangement",
            success_criterion = "Message completed and approved"
        },
        boundary_note = "Synthetic fixture, not measured lifecycle data",
        phases = {},
        inventory = {
            energy_kwh = {state = "known", value = 10, basis = "Synthetic"},
            climate_kg_co2e = {state = "unknown", basis = "Not measured"},
            electronic_waste_kg = {
                state = "known", value = 0.2, basis = "Synthetic"
            }
        },
        requested_tasks = 100,
        attempted_tasks = 90,
        successful_tasks = 80
    }
    for _, phase in ipairs(PHASES) do input.phases[phase] = "included" end

    local profile = assert(M.lifecycle_profile(input))
    assert(profile.unfulfilled_requested_tasks == 20)
    assert(profile.fulfilment_fraction == 0.8)
    assert(profile.indicators[1].per_successful_task == 0.125)
    assert(profile.indicators[2].total == nil)

    input.successful_tasks = 0
    profile = assert(M.lifecycle_profile(input))
    assert(profile.indicators[1].per_successful_task == nil)

    input.attempted_tasks = 101
    local value, err = M.lifecycle_profile(input)
    assert(value == nil and err.code == "INVALID_NUMBER")

    return true
end

return M
