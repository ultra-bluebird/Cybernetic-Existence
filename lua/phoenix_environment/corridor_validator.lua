local M = {}

local function is_finite(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function in_range(value, minimum, maximum)
    return is_finite(value) and value >= minimum and value <= maximum
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local function require_finite(table_value, field_name)
    local value = table_value[field_name]

    if not is_finite(value) then
        return nil, field_name .. " must be finite"
    end

    return value
end

function M.validate_corridor(corridor)
    if type(corridor) ~= "table" then
        return false, "corridor must be a table"
    end

    local numeric_fields = {
        "tcore0_c",
        "delta_t_amb_min_c",
        "delta_t_amb_max_c",
        "delta_t_surf_min_c",
        "delta_t_surf_max_c",
        "uhi_min",
        "uhi_max",
        "core_temp_ceiling_c",
        "skin_temp_ceiling_c",
        "u_0",
        "u_1",
        "u_2",
        "v_0",
        "v_1",
        "v_2",
        "v_3"
    }

    for _, field_name in ipairs(numeric_fields) do
        local _, err = require_finite(corridor, field_name)
        if err then
            return false, err
        end
    end

    if corridor.delta_t_amb_min_c > corridor.delta_t_amb_max_c then
        return false, "ambient delta range is invalid"
    end

    if corridor.delta_t_surf_min_c > corridor.delta_t_surf_max_c then
        return false, "surface delta range is invalid"
    end

    if corridor.uhi_min > corridor.uhi_max then
        return false, "UHI range is invalid"
    end

    if corridor.core_temp_ceiling_c <= corridor.tcore0_c then
        return false, "core temperature ceiling must exceed baseline"
    end

    if corridor.skin_temp_ceiling_c <= corridor.tcore0_c then
        return false, "skin temperature ceiling must exceed baseline"
    end

    return true
end

function M.assess_environment(corridor, observation)
    local valid, validation_error = M.validate_corridor(corridor)
    if not valid then
        return nil, validation_error
    end

    if type(observation) ~= "table" then
        return nil, "observation must be a table"
    end

    local ambient_c, ambient_error = require_finite(observation, "ambient_c")
    if ambient_error then
        return nil, ambient_error
    end

    local surface_c, surface_error = require_finite(observation, "surface_c")
    if surface_error then
        return nil, surface_error
    end

    local uhi_index, uhi_error = require_finite(observation, "uhi_index")
    if uhi_error then
        return nil, uhi_error
    end

    local data_quality = observation.data_quality
    if not in_range(data_quality, 0.0, 1.0) then
        return nil, "data_quality must be within [0, 1]"
    end

    local ambient_delta = clamp(
        ambient_c - corridor.tcore0_c,
        corridor.delta_t_amb_min_c,
        corridor.delta_t_amb_max_c
    )

    local surface_delta = clamp(
        surface_c - corridor.tcore0_c,
        corridor.delta_t_surf_min_c,
        corridor.delta_t_surf_max_c
    )

    local uhi = clamp(
        uhi_index,
        corridor.uhi_min,
        corridor.uhi_max
    )

    local core_delta_limit = math.min(
        corridor.u_0 + corridor.u_1 * ambient_delta + corridor.u_2 * uhi,
        corridor.core_temp_ceiling_c - corridor.tcore0_c
    )

    local skin_delta_limit = math.min(
        corridor.v_0
            + corridor.v_1 * ambient_delta
            + corridor.v_2 * surface_delta
            + corridor.v_3 * uhi,
        corridor.skin_temp_ceiling_c - corridor.tcore0_c
    )

    local uncertainty_penalty = 1.0 - data_quality
    local conservative_core_limit = math.max(
        0.0,
        core_delta_limit * (1.0 - uncertainty_penalty)
    )

    local conservative_skin_limit = math.max(
        0.0,
        skin_delta_limit * (1.0 - uncertainty_penalty)
    )

    local class = "acceptable"

    if data_quality < 0.30 then
        class = "insufficient-data"
    elseif ambient_c >= corridor.core_temp_ceiling_c
        or surface_c >= corridor.skin_temp_ceiling_c then
        class = "elevated-environmental-load"
    elseif uhi >= corridor.uhi_max then
        class = "elevated-environmental-load"
    end

    return {
        classification = class,
        ambient_delta_c = ambient_delta,
        surface_delta_c = surface_delta,
        uhi_index_clamped = uhi,
        core_delta_limit_c = core_delta_limit,
        skin_delta_limit_c = skin_delta_limit,
        conservative_core_delta_limit_c = conservative_core_limit,
        conservative_skin_delta_limit_c = conservative_skin_limit,
        data_quality = data_quality,
        boundary = "advisory environmental assessment only; not medical telemetry or device control"
    }
end

return M
