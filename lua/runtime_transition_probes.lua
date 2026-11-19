-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Fixed transition probes for trusted Lua 5.4/5.5 test hosts.
-- No arbitrary source input, I/O, network, or external actions.
--
-- _VERSION identifies the language family, not the patch/build.
-- Build provenance is caller-supplied and marked unverified.
-- pcall is not a resource-containment mechanism.

local M = { VERSION = "1.0.0" }

local function values(...)
    return table.pack(...)
end

local fixtures = {
    {
        name = "closure_capture",
        source = [[
            local x = 1
            local f = function() return x end
            x = 2
            return f()
        ]],
        expected = {
            ["Lua 5.4"] = { status = "completed", values = values(2) },
            ["Lua 5.5"] = { status = "completed", values = values(2) },
        },
    },
    {
        name = "multiple_result_arity",
        source = [[
            local function f() return 1, nil, 3 end
            return f()
        ]],
        expected = {
            ["Lua 5.4"] = { status = "completed", values = values(1, nil, 3) },
            ["Lua 5.5"] = { status = "completed", values = values(1, nil, 3) },
        },
    },
    {
        name = "explicit_global_declaration",
        source = "global x; x = 7; return x",
        expected = {
            ["Lua 5.4"] = { status = "compile_error" },
            ["Lua 5.5"] = { status = "completed", values = values(7) },
        },
    },
    {
        name = "declared_global_rejects_free_name",
        source = "global x; return undeclared",
        expected = {
            ["Lua 5.4"] = { status = "compile_error" },
            ["Lua 5.5"] = { status = "compile_error" },
        },
    },
    {
        name = "numeric_loop_variable_assignment",
        source = "for i = 1, 1 do i = 2 end; return true",
        expected = {
            ["Lua 5.4"] = { status = "completed", values = values(true) },
            ["Lua 5.5"] = { status = "compile_error" },
        },
    },
    {
        name = "nil_error_payload",
        source = [[
            local ok, payload = pcall(error, nil)
            return ok, type(payload)
        ]],
        expected = {
            ["Lua 5.4"] = { status = "completed", values = values(false, "nil") },
            ["Lua 5.5"] = { status = "completed", values = values(false, "string") },
        },
    },
    {
        name = "table_preallocation_function",
        source = "return type(table.create)",
        expected = {
            ["Lua 5.4"] = { status = "completed", values = values("nil") },
            ["Lua 5.5"] = { status = "completed", values = values("function") },
        },
    },
    {
        name = "signed_zero_transport",
        source = [[
            return string.pack(">d", 0.0) == string.pack(">d", -0.0)
        ]],
        expected = {
            ["Lua 5.4"] = { status = "completed", values = values(false) },
            ["Lua 5.5"] = { status = "completed", values = values(false) },
        },
    },
}

local function execute(source)
    local environment = {
        type = type,
        pcall = pcall,
        error = error,
        table = { create = table.create },
        string = { pack = string.pack },
    }

    local chunk = load(source, "=transition_fixture", "t", environment)
    if not chunk then return { status = "compile_error" } end

    local result = table.pack(pcall(chunk))
    if not result[1] then return { status = "runtime_error" } end

    local returned = { n = result.n - 1 }
    for index = 2, result.n do returned[index - 1] = result[index] end
    return { status = "completed", values = returned }
end

local function matches(expected, actual)
    if actual.status ~= expected.status then return false end
    if expected.status ~= "completed" then return true end
    if actual.values.n ~= expected.values.n then return false end
    for index = 1, expected.values.n do
        local observed = actual.values[index]
        local wanted = expected.values[index]
        if type(observed) ~= type(wanted) or observed ~= wanted then
            return false
        end
    end
    return true
end

function M.run(build_reference)
    if _VERSION ~= "Lua 5.4" and _VERSION ~= "Lua 5.5" then
        return nil, {
            status = "unsupported",
            code = "language_profile",
        }
    end
    if type(build_reference) ~= "string" or #build_reference > 256
        or not build_reference:find("%S") then
        return nil, {
            status = "invalid_request",
            code = "build_reference",
        }
    end

    local report = {
        version = M.VERSION,
        observed_language = _VERSION,
        build_reference = build_reference,
        build_reference_authenticated = false,
        cases = {},
        passed = 0,
        failed = 0,
        complete_conformance = false,
    }

    for index, fixture in ipairs(fixtures) do
        local actual = execute(fixture.source)
        local passed = matches(fixture.expected[_VERSION], actual)
        report.cases[index] = {
            name = fixture.name,
            status = passed and "pass" or "fail",
            observed_outcome = actual.status,
        }
        if passed then report.passed = report.passed + 1
        else report.failed = report.failed + 1 end
    end

    return report
end

return M
