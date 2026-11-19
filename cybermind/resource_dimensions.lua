-- Lua 5.4.
-- Dimensional arithmetic only; no I/O or external actions.
-- Import: local units = require("cybermind.resource_dimensions")
-- Tests: assert(units.self_test())
--
-- This is an accounting type system, not a hostile-code sandbox.
-- Values are normalized internally to the declared base dimensions.

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local BASES = {
    "flop", "seconds", "joules", "bytes", "usd", "kg_co2e"
}

local UNITS = {
    ["1"] = {scale = 1, dims = {}},
    FLOP = {scale = 1, dims = {flop = 1}},
    ["FLOP/s"] = {scale = 1, dims = {flop = 1, seconds = -1}},
    s = {scale = 1, dims = {seconds = 1}},
    h = {scale = 3600, dims = {seconds = 1}},
    day = {scale = 86400, dims = {seconds = 1}},
    J = {scale = 1, dims = {joules = 1}},
    kWh = {scale = 3600000, dims = {joules = 1}},
    MWh = {scale = 3600000000, dims = {joules = 1}},
    W = {scale = 1, dims = {joules = 1, seconds = -1}},
    kW = {scale = 1000, dims = {joules = 1, seconds = -1}},
    MW = {scale = 1000000, dims = {joules = 1, seconds = -1}},
    bytes = {scale = 1, dims = {bytes = 1}},
    GB = {scale = 1000000000, dims = {bytes = 1}},
    TB = {scale = 1000000000000, dims = {bytes = 1}},
    ["bytes/s"] = {scale = 1, dims = {bytes = 1, seconds = -1}},
    USD = {scale = 1, dims = {usd = 1}},
    ["USD/MWh"] = {
        scale = 1 / 3600000000,
        dims = {usd = 1, joules = -1}
    },
    kgCO2e = {scale = 1, dims = {kg_co2e = 1}},
    ["kgCO2e/kWh"] = {
        scale = 1 / 3600000,
        dims = {kg_co2e = 1, joules = -1}
    }
}

local registry = setmetatable({}, {__mode = "k"})

local function fail(code, path, message)
    error({code = code, path = path, message = message}, 0)
end

local function finite(value, path)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or math.abs(value) > 1e300 then
        fail("INVALID_NUMBER", path, "Expected bounded finite number")
    end
    return value
end

local function copy_dimensions(source)
    local result = {}
    for _, name in ipairs(BASES) do
        local exponent = source[name] or 0
        if exponent ~= 0 then result[name] = exponent end
    end
    return result
end

local function equal_dimensions(a, b)
    for _, name in ipairs(BASES) do
        if (a[name] or 0) ~= (b[name] or 0) then
            return false
        end
    end
    return true
end

local function unit(name)
    if type(name) ~= "string" or UNITS[name] == nil then
        fail("UNKNOWN_UNIT", "unit", "Unit is not declared")
    end
    return UNITS[name]
end

local function value_of(handle)
    if type(handle) ~= "table" or registry[handle] == nil then
        fail("INVALID_QUANTITY", "quantity",
            "Expected a quantity created by this module")
    end
    return registry[handle]
end

local function create(value, dimensions)
    finite(value, "calculated_value")
    for _, name in ipairs(BASES) do
        local exponent = dimensions[name] or 0
        if math.abs(exponent) > 32 then
            fail("DIMENSION_LIMIT", name, "Exponent exceeds configured limit")
        end
    end

    local handle = {}
    registry[handle] = {
        value = value,
        dimensions = copy_dimensions(dimensions)
    }
    return handle
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

function M.quantity(value, unit_name)
    return protect(function()
        finite(value, "value")
        local definition = unit(unit_name)
        return create(value * definition.scale, definition.dims)
    end)
end

local function additive(left, right, sign)
    local a, b = value_of(left), value_of(right)
    if not equal_dimensions(a.dimensions, b.dimensions) then
        fail("DIMENSION_MISMATCH", "addition",
            "Addition and subtraction require matching dimensions")
    end
    return create(a.value + sign * b.value, a.dimensions)
end

function M.add(left, right)
    return protect(function() return additive(left, right, 1) end)
end

function M.subtract(left, right)
    return protect(function() return additive(left, right, -1) end)
end

local function multiplicative(left, right, divide)
    local a, b = value_of(left), value_of(right)
    if divide and b.value == 0 then
        fail("DIVISION_BY_ZERO", "division", "Denominator is zero")
    end

    local dimensions = {}
    for _, name in ipairs(BASES) do
        dimensions[name] = (a.dimensions[name] or 0)
            + (divide and -1 or 1) * (b.dimensions[name] or 0)
    end
    return create(
        divide and a.value / b.value or a.value * b.value,
        dimensions
    )
end

function M.multiply(left, right)
    return protect(function() return multiplicative(left, right, false) end)
end

function M.divide(left, right)
    return protect(function() return multiplicative(left, right, true) end)
end

function M.convert(handle, unit_name)
    return protect(function()
        local quantity = value_of(handle)
        local definition = unit(unit_name)
        if not equal_dimensions(quantity.dimensions, definition.dims) then
            fail("DIMENSION_MISMATCH", "conversion",
                "Requested unit has different dimensions")
        end
        return finite(quantity.value / definition.scale, "converted_value")
    end)
end

function M.describe(handle)
    return protect(function()
        local quantity = value_of(handle)
        return {
            schema_version = VERSION,
            attribution = ATTRIBUTION,
            attribution_scope =
                "Credit and workstream metadata only; not identity, consent, "
                .. "authorization, execution evidence, or authority.",
            base_value = quantity.value,
            dimensions = copy_dimensions(quantity.dimensions),
            scope =
                "Dimensional accounting only; no measurement validity, "
                .. "feasibility, capability, or causal finding."
        }
    end)
end

function M.self_test()
    local compute = assert(M.quantity(6e26, "FLOP"))
    local rate = assert(M.quantity(4.5e20, "FLOP/s"))
    local duration = assert(M.divide(compute, rate))
    assert(math.abs(assert(M.convert(duration, "day"))
        - 15.4320987654) < 1e-8)

    local value, err = M.subtract(compute, rate)
    assert(value == nil and err.code == "DIMENSION_MISMATCH")

    local squared = assert(M.multiply(compute, compute))
    assert(assert(M.describe(squared)).dimensions.flop == 2)

    local power = assert(M.quantity(1, "MW"))
    local hour = assert(M.quantity(1, "h"))
    local energy = assert(M.multiply(power, hour))
    assert(assert(M.convert(energy, "MWh")) == 1)

    local intensity = assert(M.quantity(0.5, "kgCO2e/kWh"))
    local emissions = assert(M.multiply(energy, intensity))
    assert(assert(M.convert(emissions, "kgCO2e")) == 500)

    local zero = assert(M.quantity(0, "s"))
    value, err = M.divide(compute, zero)
    assert(value == nil and err.code == "DIVISION_BY_ZERO")

    local description = assert(M.describe(duration))
    description.dimensions.seconds = 99
    assert(assert(M.describe(duration)).dimensions.seconds == 1)

    return true
end

return M
