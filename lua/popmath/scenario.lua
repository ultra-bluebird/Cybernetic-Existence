local scenario = {}

local allowed_categories = {
    WaterResilience = true,
    EnergyResilience = true,
    EcologicalRestoration = true,
    MobilityPlanning = true,
    InfrastructureMaintenance = true,
    PublicServiceCapacity = true,
    ContinuityPlanning = true
}

local function require_nonempty_string(value, label)
    if type(value) ~= "string" or value == "" then
        error(label .. " must be a non-empty string", 3)
    end

    return value
end

local function require_table(value, label)
    if type(value) ~= "table" then
        error(label .. " must be a table", 3)
    end

    return value
end

local function require_scenario_id(value)
    require_nonempty_string(value, "scenario_id")

    if not value:match("^[A-Za-z0-9][A-Za-z0-9._-]*$") then
        error("scenario_id contains unsupported characters", 3)
    end

    return value
end

function scenario.new(input)
    require_table(input, "input")

    local scenario_id = require_scenario_id(input.scenario_id)
    local purpose = require_table(input.purpose, "purpose")
    local assumptions = require_table(input.assumptions, "assumptions")
    local payload = require_table(input.payload, "payload")

    local category = require_nonempty_string(purpose.category, "purpose.category")

    if not allowed_categories[category] then
        error("purpose.category is not supported", 2)
    end

    local description = require_nonempty_string(
        purpose.description,
        "purpose.description"
    )

    if #assumptions == 0 then
        error("assumptions must contain at least one entry", 2)
    end

    for index, assumption in ipairs(assumptions) do
        require_table(assumption, "assumptions[" .. index .. "]")
        require_nonempty_string(
            assumption.name,
            "assumptions[" .. index .. "].name"
        )
        require_nonempty_string(
            assumption.basis,
            "assumptions[" .. index .. "].basis"
        )
    end

    local output = {
        schema_version = "1.0",
        scenario_id = scenario_id,
        purpose = {
            category = category,
            description = description
        },
        assumptions = assumptions,
        payload = payload
    }

    if input.seed ~= nil then
        if type(input.seed) ~= "number" or input.seed % 1 ~= 0 then
            error("seed must be an integer when present", 2)
        end

        if input.seed < 0 or input.seed > 4294967295 then
            error("seed must be within the unsigned 32-bit range", 2)
        end

        output.seed = input.seed
    end

    return output
end

return scenario
