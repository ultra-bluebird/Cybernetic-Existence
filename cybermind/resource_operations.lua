-- Lua 5.4.
-- Requires cybermind/resource_dimensions.lua from the preceding artifact.
-- No I/O, JSON parser, cryptography, or external actions.
-- Import: local r = require("cybermind.resource_operations")
-- Tests: assert(r.self_test())
--
-- Approximate floating-point accounting, not exact integer arithmetic.
-- Export returns a JSON-compatible table, not canonical JSON bytes.

local core = require("cybermind.resource_dimensions")
local M = {}

local VERSION = "1.0.0"
local BASIS_VERSION = "resource-six-dimensions-v1"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
local SCOPE =
    "Dimensional accounting only; not measurement verification, capability, "
    .. "feasibility, resource entitlement, or access authorization."

local BASES = {"flop", "seconds", "joules", "bytes", "usd", "kg_co2e"}
local BASE_UNITS = {"FLOP", "s", "J", "bytes", "USD", "kgCO2e"}
local UNIT_NAMES = {
    "1", "FLOP", "FLOP/s", "GB", "J", "MWh", "MW", "TB",
    "USD", "USD/MWh", "W", "bytes", "bytes/s", "day", "h",
    "kWh", "kW", "kgCO2e", "kgCO2e/kWh", "s"
}

local function fail(code, path, message)
    error({code = code, path = path, message = message}, 0)
end

local function must(value, err)
    if value == nil then error(err, 0) end
    return value
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

local function finite(value, path)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or math.abs(value) > 1e300 then
        fail("INVALID_NUMBER", path, "Expected bounded finite number")
    end
    return value + 0.0
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

local function length(value, path, limit)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_ARRAY", path, "Expected a plain array")
    end
    local count, maximum = 0, 0
    for key in next, value do
        if type(key) ~= "number" or math.type(key) ~= "integer" or key < 1 then
            fail("INVALID_ARRAY_KEY", path,
                "Expected consecutive positive integer keys")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum or count > limit then
        fail("INVALID_ARRAY_SIZE", path, "Array is sparse or exceeds limit")
    end
    return count
end

local function describe(handle)
    return must(core.describe(handle))
end

local function signature_of(handle)
    local dimensions = describe(handle).dimensions
    local fragments = {}
    for _, name in ipairs(BASES) do
        local exponent = dimensions[name] or 0
        if exponent ~= 0 then
            fragments[#fragments + 1] = name .. "^" .. tostring(exponent)
        end
    end
    return #fragments == 0 and "1" or table.concat(fragments, "*")
end

local function float_quantity(handle)
    local one = must(core.quantity(1.0, "1"))
    return must(core.divide(handle, one))
end

local function matching(a, b)
    if signature_of(a) ~= signature_of(b) then
        fail("DIMENSION_MISMATCH", "quantities",
            "Operation requires matching dimensions")
    end
end

local function quantity(value, unit)
    return must(core.quantity(finite(value, "value"), unit))
end

local function multiply(a, b)
    return must(core.multiply(float_quantity(a), float_quantity(b)))
end

local function divide(a, b)
    return must(core.divide(float_quantity(a), float_quantity(b)))
end

local function power(handle, exponent)
    if type(exponent) ~= "number" or math.type(exponent) ~= "integer"
        or exponent < -32 or exponent > 32 then
        fail("INVALID_EXPONENT", "exponent",
            "Expected an integer exponent from -32 to 32")
    end

    local value = float_quantity(handle)
    if exponent < 0 then
        value = divide(quantity(1, "1"), value)
        exponent = -exponent
    end

    local result = quantity(1, "1")
    for _ = 1, exponent do
        result = multiply(result, value)
    end
    return result
end

function M.quantity(value, unit)
    return protect(function() return quantity(value, unit) end)
end

function M.add(a, b)
    return protect(function()
        return must(core.add(float_quantity(a), float_quantity(b)))
    end)
end

function M.subtract(a, b)
    return protect(function()
        return must(core.subtract(float_quantity(a), float_quantity(b)))
    end)
end

function M.multiply(a, b)
    return protect(function() return multiply(a, b) end)
end

function M.divide(a, b)
    return protect(function() return divide(a, b) end)
end

function M.pow(handle, exponent)
    return protect(function() return power(handle, exponent) end)
end

function M.abs(handle)
    return protect(function()
        local value = float_quantity(handle)
        if describe(value).base_value < 0 then
            return multiply(value, quantity(-1, "1"))
        end
        return value
    end)
end

function M.signature(handle)
    return protect(function() return signature_of(handle) end)
end

function M.is_dimensionless(handle)
    return protect(function() return signature_of(handle) == "1" end)
end

function M.equal(a, b)
    return protect(function()
        return signature_of(a) == signature_of(b)
            and describe(a).base_value == describe(b).base_value
    end)
end

function M.approximately_equal(a, b, options)
    return protect(function()
        fields(options, {relative = true, absolute = true}, "tolerance")
        matching(a, b)

        local relative = finite(options.relative, "tolerance.relative")
        if relative < 0 or relative > 1 then
            fail("INVALID_TOLERANCE", "tolerance.relative",
                "Relative tolerance must be in [0, 1]")
        end

        matching(a, options.absolute)
        local absolute = describe(options.absolute).base_value
        if absolute < 0 then
            fail("INVALID_TOLERANCE", "tolerance.absolute",
                "Absolute tolerance must be nonnegative")
        end

        local left = describe(a).base_value
        local right = describe(b).base_value
        return math.abs(left - right)
            <= math.max(absolute, relative * math.max(math.abs(left), math.abs(right)))
    end)
end

local function aggregate(values, mode)
    local count = length(values, "quantities", 10000)
    if count == 0 then
        fail("EMPTY_AGGREGATE", "quantities",
            "A nonempty list is required to establish dimensions")
    end

    local result = float_quantity(values[1])
    for position = 2, count do
        local candidate = float_quantity(values[position])
        matching(result, candidate)

        if mode == "sum" then
            result = must(core.add(result, candidate))
        else
            local a = describe(result).base_value
            local b = describe(candidate).base_value
            if (mode == "max" and b > a) or (mode == "min" and b < a) then
                result = candidate
            end
        end
    end
    return result
end

function M.sum(values)
    return protect(function() return aggregate(values, "sum") end)
end

function M.max(values)
    return protect(function() return aggregate(values, "max") end)
end

function M.min(values)
    return protect(function() return aggregate(values, "min") end)
end

function M.convert(handle, unit)
    return protect(function()
        return must(core.convert(float_quantity(handle), unit))
    end)
end

function M.unit_names()
    local copy = {}
    for position, name in ipairs(UNIT_NAMES) do copy[position] = name end
    return copy
end

function M.export(handle)
    return protect(function()
        local value = describe(handle)
        local exponents = {}
        for _, name in ipairs(BASES) do
            exponents[#exponents + 1] = value.dimensions[name] or 0
        end
        return {
            schema_version = VERSION,
            basis_version = BASIS_VERSION,
            attribution = ATTRIBUTION,
            attribution_scope =
                "Credit and workstream metadata only; not identity, consent, "
                .. "authorization, execution evidence, or authority.",
            base_value = value.base_value,
            dimension_exponents = exponents,
            base_unit_expression = signature_of(handle),
            interpretation = "formal_accounting_quantity",
            not_a_capability_claim = true,
            scope = SCOPE
        }
    end)
end

function M.import(payload)
    return protect(function()
        fields(payload, {
            schema_version = true,
            basis_version = true,
            attribution = true,
            attribution_scope = true,
            base_value = true,
            dimension_exponents = true,
            base_unit_expression = true,
            interpretation = true,
            not_a_capability_claim = true,
            scope = true
        }, "payload")

        if payload.schema_version ~= VERSION
            or payload.basis_version ~= BASIS_VERSION
            or payload.attribution ~= ATTRIBUTION
            or payload.attribution_scope ~=
                "Credit and workstream metadata only; not identity, consent, "
                .. "authorization, execution evidence, or authority."
            or payload.interpretation ~= "formal_accounting_quantity"
            or payload.not_a_capability_claim ~= true
            or payload.scope ~= SCOPE then
            fail("SERIALIZATION_CONTRACT", "payload",
                "Version or boundary metadata does not match")
        end

        if length(payload.dimension_exponents, "dimension_exponents", 6) ~= 6 then
            fail("BASIS_LENGTH", "dimension_exponents",
                "Expected the declared six-dimensional basis")
        end

        local result = quantity(payload.base_value, "1")
        for position, unit in ipairs(BASE_UNITS) do
            local exponent = payload.dimension_exponents[position]
            if type(exponent) ~= "number"
                or math.type(exponent) ~= "integer"
                or exponent < -32 or exponent > 32 then
                fail("INVALID_EXPONENT", "dimension_exponents",
                    "Expected bounded integer exponents")
            end
            if exponent ~= 0 then
                result = multiply(result, power(quantity(1, unit), exponent))
            end
        end

        if payload.base_unit_expression ~= signature_of(result) then
            fail("SIGNATURE_MISMATCH", "base_unit_expression",
                "Signature does not match the exponent vector")
        end
        return result
    end)
end

function M.self_test()
    local energy = assert(M.quantity(1, "MWh"))
    local same = assert(M.quantity(1000, "kWh"))
    assert(assert(M.equal(energy, same)))

    local other = assert(M.quantity(1, "MW"))
    local equal, err = M.equal(energy, other)
    assert(equal == false and err == nil)

    local duration = assert(M.quantity(2, "h"))
    local product = assert(M.multiply(other, duration))
    assert(assert(M.convert(product, "MWh")) == 2)

    local total = assert(M.sum({energy, same}))
    assert(assert(M.convert(total, "MWh")) == 2)
    assert(assert(M.equal(assert(M.max({energy, total})), total)))

    local squared = assert(M.pow(energy, 2))
    assert(assert(M.signature(squared)) == "seconds^0" == false)

    local ratio = assert(M.divide(energy, same))
    assert(assert(M.is_dimensionless(ratio)))

    local payload = assert(M.export(product))
    local restored = assert(M.import(payload))
    assert(assert(M.equal(product, restored)))

    payload.dimension_exponents[1] = 1
    local value, failure = M.import(payload)
    assert(value == nil and failure.code == "SIGNATURE_MISMATCH")

    value, failure = M.sum({})
    assert(value == nil and failure.code == "EMPTY_AGGREGATE")

    for _, unit in ipairs(M.unit_names()) do
        local q = assert(M.quantity(1.25, unit))
        local returned = assert(M.convert(q, unit))
        assert(math.abs(returned - 1.25) < 1e-12)
    end

    return true
end

return M
