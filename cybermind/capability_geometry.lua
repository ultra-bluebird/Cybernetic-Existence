-- Lua 5.4.
-- Logical capability-mediation layout; not anatomical or clinical geometry.
-- No I/O, hardware access, decoding, external actions, or runtime authorization.
-- Import: local geometry = require("cybermind.capability_geometry")
-- Tests: assert(geometry.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local ORDER = {
    "input",
    "candidate",
    "private_display",
    "approved_expression",
    "external_action"
}

local ZONES = {
    input = "authorized_processing",
    candidate = "private_processing",
    private_display = "private_presentation",
    approved_expression = "approved_communication",
    external_action = "separate_action_boundary"
}

local GUARDS = {
    input = {
        target = "candidate",
        guard = "authorized_processing"
    },
    candidate = {
        target = "private_display",
        guard = "authorized_private_display"
    },
    private_display = {
        target = "approved_expression",
        guard = "user_expression_approval"
    },
    approved_expression = {
        target = "external_action",
        guard = "separate_action_authorization"
    }
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

local function coordinate(value, path)
    if type(value) ~= "number" or value ~= value
        or value < -1 or value > 1 then
        fail("INVALID_COORDINATE", path,
            "Expected finite normalized coordinate in [-1, 1]")
    end
    return value
end

local function array_length(value, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_ARRAY", path, "Expected a plain array")
    end
    local count, maximum = 0, 0
    for key in next, value do
        if type(key) ~= "number"
            or math.type(key) ~= "integer" or key < 1 then
            fail("INVALID_ARRAY_KEY", path,
                "Expected consecutive positive integer keys")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum then
        fail("SPARSE_ARRAY", path, "Array contains missing positions")
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

local function metadata()
    return {
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope =
            "Credit and workstream metadata only; not identity, consent, "
            .. "authorization, execution evidence, or authority.",
        geometry_kind = "logical_capability_mediation",
        units = "normalized_diagram_coordinates",
        anatomical_meaning = false
    }
end

function M.default_layout()
    local result = metadata()
    result.nodes = {}
    result.edges = {}

    for position, stage in ipairs(ORDER) do
        result.nodes[stage] = {
            x = -1 + (position - 1) * 0.5,
            y = 0,
            zone = ZONES[stage]
        }
        local rule = GUARDS[stage]
        if rule then
            result.edges[#result.edges + 1] = {
                from = stage,
                to = rule.target,
                guard = rule.guard
            }
        end
    end
    return result
end

function M.validate(layout)
    return protect(function()
        fields(layout, {
            schema_version = true,
            attribution = true,
            attribution_scope = true,
            geometry_kind = true,
            units = true,
            anatomical_meaning = true,
            nodes = true,
            edges = true
        }, "layout")

        local expected = metadata()
        for key, value in next, expected do
            if layout[key] ~= value then
                fail("METADATA_MISMATCH", key,
                    "Metadata must match the declared logical layout")
            end
        end

        local allowed_nodes = {}
        for _, stage in ipairs(ORDER) do allowed_nodes[stage] = true end
        fields(layout.nodes, allowed_nodes, "nodes")

        local normalized = metadata()
        normalized.nodes = {}
        normalized.edges = {}
        local occupied = {}

        for _, stage in ipairs(ORDER) do
            local node = layout.nodes[stage]
            fields(node, {x = true, y = true, zone = true}, "nodes." .. stage)
            local x = coordinate(node.x, "nodes." .. stage .. ".x")
            local y = coordinate(node.y, "nodes." .. stage .. ".y")

            if node.zone ~= ZONES[stage] then
                fail("ZONE_MISMATCH", "nodes." .. stage .. ".zone",
                    "Stage is assigned to the wrong privacy zone")
            end

            -- At most five nodes; direct comparison avoids float string keys.
            for _, prior in ipairs(occupied) do
                if prior.x == x and prior.y == y then
                    fail("OVERLAPPING_NODES", "nodes." .. stage,
                        "Distinct stages require distinct diagram positions")
                end
            end
            occupied[#occupied + 1] = {x = x, y = y}
            normalized.nodes[stage] = {x = x, y = y, zone = node.zone}
        end

        if array_length(layout.edges, "edges") ~= 4 then
            fail("EDGE_COUNT", "edges",
                "This reference layout requires exactly four guarded edges")
        end

        local seen = {}
        for position, edge in ipairs(layout.edges) do
            local path = "edges[" .. position .. "]"
            fields(edge, {from = true, to = true, guard = true}, path)

            if type(edge.from) ~= "string" then
                fail("INVALID_SOURCE", path, "Expected a declared source stage")
            end
            local rule = GUARDS[edge.from]
            if not rule or edge.to ~= rule.target then
                fail("FORBIDDEN_CONNECTION", path,
                    "Skipping, reverse, or undeclared connections are prohibited")
            end
            if edge.guard ~= rule.guard then
                fail("GUARD_MISMATCH", path,
                    "Connection requires its declared authorization guard")
            end
            if seen[edge.from] then
                fail("DUPLICATE_CONNECTION", path,
                    "Each reference connection may appear only once")
            end
            seen[edge.from] = true
        end

        for _, stage in ipairs(ORDER) do
            local rule = GUARDS[stage]
            if rule then
                if not seen[stage] then
                    fail("MISSING_CONNECTION", stage,
                        "Required guarded connection is absent")
                end
                normalized.edges[#normalized.edges + 1] = {
                    from = stage,
                    to = rule.target,
                    guard = rule.guard
                }
            end
        end

        return {
            layout = normalized,
            interpretation =
                "Validated logical topology and presentation only; guards "
                .. "are declared requirements, not verified runtime approvals."
        }
    end)
end

function M.self_test()
    local layout = M.default_layout()
    local checked = assert(M.validate(layout))
    assert(#checked.layout.edges == 4)
    assert(checked.layout.anatomical_meaning == false)

    layout = M.default_layout()
    layout.edges[2].to = "external_action"
    local value, err = M.validate(layout)
    assert(value == nil and err.code == "FORBIDDEN_CONNECTION")

    layout = M.default_layout()
    layout.edges[4].guard = "user_expression_approval"
    value, err = M.validate(layout)
    assert(value == nil and err.code == "GUARD_MISMATCH")

    layout = M.default_layout()
    layout.nodes.candidate.x = layout.nodes.input.x
    value, err = M.validate(layout)
    assert(value == nil and err.code == "OVERLAPPING_NODES")

    layout = M.default_layout()
    layout.nodes.input.x = math.huge
    value, err = M.validate(layout)
    assert(value == nil and err.code == "INVALID_COORDINATE")

    layout = M.default_layout()
    checked = assert(M.validate(layout))
    checked.layout.nodes.input.x = 0.25
    assert(layout.nodes.input.x == -1)

    assert(assert(M.validate(M.default_layout()))
        .layout.nodes.input.x == -1)

    return true
end

return M
