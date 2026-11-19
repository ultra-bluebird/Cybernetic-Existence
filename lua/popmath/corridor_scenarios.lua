local corridor_scenarios = {}

local function assert_number(value, label)
    if type(value) ~= "number" or value ~= value then
        error(label .. " must be a finite number", 3)
    end

    if value == math.huge or value == -math.huge then
        error(label .. " must be finite", 3)
    end

    return value
end

local function assert_string(value, label)
    if type(value) ~= "string" or value == "" then
        error(label .. " must be a non-empty string", 3)
    end

    return value
end

local function escape_json(value)
    return value
        :gsub("\\", "\\\\")
        :gsub("\"", "\\\"")
        :gsub("\b", "\\b")
        :gsub("\f", "\\f")
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
end

local function encode_json(value)
    local value_type = type(value)

    if value_type == "nil" then
        return "null"
    end

    if value_type == "boolean" then
        return value and "true" or "false"
    end

    if value_type == "number" then
        assert_number(value, "JSON number")
        return string.format("%.12g", value)
    end

    if value_type == "string" then
        return "\"" .. escape_json(value) .. "\""
    end

    if value_type ~= "table" then
        error("unsupported JSON value type: " .. value_type, 3)
    end

    local is_array = true
    local highest_index = 0

    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            is_array = false
            break
        end

        highest_index = math.max(highest_index, key)
    end

    if is_array then
        local values = {}

        for index = 1, highest_index do
            values[#values + 1] = encode_json(value[index])
        end

        return "[" .. table.concat(values, ",") .. "]"
    end

    local keys = {}

    for key, _ in pairs(value) do
        if type(key) ~= "string" then
            error("JSON object keys must be strings", 3)
        end

        keys[#keys + 1] = key
    end

    table.sort(keys)

    local fields = {}

    for _, key in ipairs(keys) do
        fields[#fields + 1] =
            encode_json(key) .. ":" .. encode_json(value[key])
    end

    return "{" .. table.concat(fields, ",") .. "}"
end

local function create_rng(seed)
    assert_number(seed, "seed")

    local state = math.floor(seed) % 2147483647

    if state <= 0 then
        state = 1
    end

    return function()
        state = (state * 48271) % 2147483647
        return state / 2147483647
    end
end

local function condition_adjustment(condition)
    local adjustments = {
        normal = {
            environmental = 0.0,
            noise = 0.0,
            emi = 0.0
        },
        snow = {
            environmental = 0.30,
            noise = -2.0,
            emi = 0.05
        },
        heatwave = {
            environmental = 0.45,
            noise = 3.0,
            emi = 0.10
        },
        heavy_rain = {
            environmental = 0.25,
            noise = 1.5,
            emi = 0.08
        }
    }

    local value = adjustments[condition]

    if value == nil then
        error("unsupported synthetic condition: " .. condition, 3)
    end

    return value
end

local function window(kind, start_seconds, end_seconds, evidence, available)
    return {
        kind = kind,
        window = {
            start_seconds_since_epoch = start_seconds,
            end_seconds_since_epoch = end_seconds
        },
        evidence = evidence,
        available = available
    }
end

function corridor_scenarios.generate(options)
    if type(options) ~= "table" then
        error("options must be a table", 2)
    end

    local scenario_id = assert_string(options.scenario_id, "scenario_id")
    local condition = assert_string(options.condition, "condition")
    local start_seconds = assert_number(options.start_seconds, "start_seconds")
    local window_seconds = assert_number(options.window_seconds, "window_seconds")
    local step_seconds = assert_number(options.step_seconds, "step_seconds")
    local seed = assert_number(options.seed, "seed")

    if window_seconds <= 0 or step_seconds <= 0 then
        error("window_seconds and step_seconds must be greater than zero", 2)
    end

    if window_seconds % step_seconds ~= 0 then
        error("window_seconds must be evenly divisible by step_seconds", 2)
    end

    local adjustment = condition_adjustment(condition)
    local random = create_rng(seed)
    local capability_windows = {}
    local end_seconds = start_seconds + window_seconds
    local environmental_threshold = assert_number(
        options.environmental_threshold,
        "environmental_threshold"
    )
    local noise_threshold = assert_number(
        options.noise_threshold or 45.0,
        "noise_threshold"
    )
    local emi_threshold = assert_number(
        options.emi_threshold,
        "emi_threshold"
    )
    local environmental_baseline = assert_number(
        options.environmental_baseline,
        "environmental_baseline"
    )
    local noise_baseline = assert_number(
        options.noise_baseline,
        "noise_baseline"
    )
    local emi_baseline = assert_number(
        options.emi_baseline,
        "emi_baseline"
    )

    for segment_start = start_seconds, end_seconds - step_seconds, step_seconds do
        local segment_end = segment_start + step_seconds
        local environmental_value =
            environmental_baseline
            + adjustment.environmental
            + ((random() - 0.5) * 0.10)

        local noise_value =
            noise_baseline
            + adjustment.noise
            + ((random() - 0.5) * 2.0)

        local emi_value =
            emi_baseline
            + adjustment.emi
            + ((random() - 0.5) * 0.04)

        capability_windows[#capability_windows + 1] = window(
            "EnvironmentalCompatibility",
            segment_start,
            segment_end,
            "Verified",
            environmental_value <= environmental_threshold
        )

        capability_windows[#capability_windows + 1] = window(
            "LowNoiseEnvironment",
            segment_start,
            segment_end,
            "Verified",
            noise_value <= noise_threshold
        )

        capability_windows[#capability_windows + 1] = window(
            "ElectromagneticInterferenceLow",
            segment_start,
            segment_end,
            "Verified",
            emi_value <= emi_threshold
        )
    end

    return {
        schema_version = "1.0",
        scenario_id = scenario_id,
        purpose = {
            category = "ContinuityPlanning",
            description = "Deterministic synthetic corridor continuity scenario."
        },
        assumptions = {
            {
                name = "Synthetic condition",
                basis = condition
            },
            {
                name = "Deterministic seed",
                basis = tostring(math.floor(seed))
            }
        },
        seed = math.floor(seed),
        payload = {
            continuity = {
                requested_window = {
                    start_seconds_since_epoch = start_seconds,
                    end_seconds_since_epoch = end_seconds
                },
                requirements = {
                    all = {
                        {
                            requirement = {
                                kind = "EnvironmentalCompatibility",
                                minimum_availability = 0.99,
                                maximum_gap_seconds = step_seconds,
                                required_evidence = "Verified"
                            }
                        },
                        {
                            requirement = {
                                kind = "LowNoiseEnvironment",
                                minimum_availability = 0.99,
                                maximum_gap_seconds = step_seconds,
                                required_evidence = "Verified"
                            }
                        },
                        {
                            requirement = {
                                kind = "ElectromagneticInterferenceLow",
                                minimum_availability = 0.99,
                                maximum_gap_seconds = step_seconds,
                                required_evidence = "Verified"
                            }
                        }
                    }
                },
                capability_windows = capability_windows
            }
        }
    }
end

function corridor_scenarios.write_json(path, scenario)
    assert_string(path, "path")

    if type(scenario) ~= "table" then
        error("scenario must be a table", 2)
    end

    local file, open_error = io.open(path, "wb")

    if file == nil then
        error("unable to open output path: " .. tostring(open_error), 2)
    end

    local ok, write_error = file:write(encode_json(scenario))

    if not ok then
        file:close()
        error("unable to write scenario JSON: " .. tostring(write_error), 2)
    end

    file:close()
end

return corridor_scenarios
