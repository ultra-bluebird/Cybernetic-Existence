local corridor_scenarios = require("popmath.corridor_scenarios")

local base_options = {
    start_seconds = 0,
    window_seconds = 3600,
    step_seconds = 300,
    seed = 2026,
    environmental_baseline = 0.35,
    environmental_threshold = 0.80,
    noise_baseline = 42.0,
    noise_threshold = 45.0,
    emi_baseline = 0.15,
    emi_threshold = 0.25
}

local conditions = {
    "normal",
    "snow",
    "heatwave",
    "heavy_rain"
}

for index, condition in ipairs(conditions) do
    local options = {}

    for key, value in pairs(base_options) do
        options[key] = value
    end

    options.condition = condition
    options.scenario_id = "corridor-" .. condition .. "-" .. tostring(index)
    options.seed = base_options.seed + index

    local scenario = corridor_scenarios.generate(options)
    local output_path = "examples/scenarios/" .. options.scenario_id .. ".json"

    corridor_scenarios.write_json(output_path, scenario)
end
