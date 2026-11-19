-- Lua 5.4.
-- Pure module: no file access, network access, code loading, or recursion.
-- Import with require("cybermind.typed_dependency_model").
-- Tests: local m = require(...); assert(m.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
local SCOPE =
    "Credit and workstream metadata only; not identity, consent, "
    .. "authorization, execution evidence, or authority over others."

local function enum(...)
    local result = {}
    for _, value in ipairs({...}) do
        result[value] = true
    end
    return result
end

local NODE_KINDS = enum("research", "capacity", "external", "proposal")
local STATES = enum(
    "unknown", "not_started", "in_progress", "satisfied", "unavailable"
)
local EDGE_KINDS = enum(
    "definitional", "data", "institutional", "review", "output"
)
local STATUSES = enum("canonical", "proposed", "deprecated", "waived")
local SEMANTICS = enum(
    "requires_completion", "requires_availability", "co_design"
)

local LIMIT_NODES = 10000
local LIMIT_EDGES = 100000

local function fail(code, path, message)
    error({code = code, path = path, message = message}, 0)
end

local function text(value, path)
    if type(value) ~= "string"
        or #value > 4096
        or not value:match("%S")
        or value:find("%c") then
        fail("INVALID_TEXT", path,
            "Expected nonblank text without control characters, up to 4096 bytes")
    end
    return value
end

local function plain(value, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_TABLE", path, "Expected a plain table")
    end
end

local function fields(value, allowed, path)
    plain(value, path)
    for key in next, value do
        if type(key) ~= "string" or not allowed[key] then
            fail("UNKNOWN_FIELD", path, "Unexpected field")
        end
    end
end

local function choice(value, allowed, path)
    if type(value) ~= "string" or not allowed[value] then
        fail("INVALID_ENUM", path, "Value is outside the declared vocabulary")
    end
    return value
end

local function array(value, path, limit)
    plain(value, path)
    local count, maximum = 0, 0
    for key in next, value do
        if type(key) ~= "number"
            or math.type(key) ~= "integer"
            or key < 1 then
            fail("INVALID_ARRAY_KEY", path,
                "Expected positive consecutive integer keys")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum then
        fail("SPARSE_ARRAY", path, "Array contains missing positions")
    end
    if count > limit then
        fail("LIMIT_EXCEEDED", path, "Configured collection limit exceeded")
    end
    return count
end

local NODE_FIELDS = enum("name", "kind", "state", "evidence")
local EDGE_FIELDS = enum(
    "dependent", "prerequisite", "kind", "status",
    "semantics", "rationale", "review_note"
)
local ROOT_FIELDS = enum(
    "schema_version", "attribution", "attribution_scope", "nodes", "edges"
)

local function edge_less(a, b)
    local keys = {
        "dependent", "prerequisite", "kind", "semantics",
        "status", "rationale", "review_note"
    }
    for _, key in ipairs(keys) do
        local left, right = a[key] or "", b[key] or ""
        if left ~= right then
            return left < right
        end
    end
    return false
end

local function copy_edge(edge)
    return {
        dependent = edge.dependent,
        prerequisite = edge.prerequisite,
        kind = edge.kind,
        status = edge.status,
        semantics = edge.semantics,
        rationale = edge.rationale,
        review_note = edge.review_note
    }
end

local function normalize(input)
    fields(input, ROOT_FIELDS, "model")
    if input.schema_version ~= VERSION then
        fail("SCHEMA_VERSION", "schema_version",
            "Unsupported schema version")
    end
    if input.attribution ~= ATTRIBUTION
        or input.attribution_scope ~= SCOPE then
        fail("ATTRIBUTION_SCOPE", "attribution",
            "Expected configured credit and metadata-only scope")
    end

    local node_count = array(input.nodes, "nodes", LIMIT_NODES)
    local edge_count = array(input.edges, "edges", LIMIT_EDGES)
    local nodes, edges, by_name = {}, {}, {}

    for position = 1, node_count do
        local source = input.nodes[position]
        local path = "nodes[" .. position .. "]"
        fields(source, NODE_FIELDS, path)

        local node = {
            name = text(source.name, path .. ".name"),
            kind = choice(source.kind, NODE_KINDS, path .. ".kind"),
            state = choice(source.state, STATES, path .. ".state")
        }
        if source.evidence ~= nil then
            node.evidence = text(source.evidence, path .. ".evidence")
        end
        if by_name[node.name] then
            fail("DUPLICATE_NODE", path .. ".name", "Name already exists")
        end
        if node.state == "satisfied" and not node.evidence then
            fail("EVIDENCE_REQUIRED", path .. ".evidence",
                "Satisfied state requires a review note")
        end
        by_name[node.name] = node
        nodes[#nodes + 1] = node
    end

    for position = 1, edge_count do
        local source = input.edges[position]
        local path = "edges[" .. position .. "]"
        fields(source, EDGE_FIELDS, path)

        local edge = {
            dependent = text(source.dependent, path .. ".dependent"),
            prerequisite = text(source.prerequisite, path .. ".prerequisite"),
            kind = choice(source.kind, EDGE_KINDS, path .. ".kind"),
            status = choice(source.status, STATUSES, path .. ".status"),
            semantics = choice(
                source.semantics, SEMANTICS, path .. ".semantics"
            ),
            rationale = text(source.rationale, path .. ".rationale")
        }
        if source.review_note ~= nil then
            edge.review_note = text(source.review_note, path .. ".review_note")
        end
        if not by_name[edge.dependent] or not by_name[edge.prerequisite] then
            fail("UNKNOWN_ENDPOINT", path,
                "Both endpoints must name declared nodes")
        end
        if (edge.status == "waived" or edge.status == "deprecated")
            and not edge.review_note then
            fail("REVIEW_NOTE_REQUIRED", path,
                "Waived or deprecated relationships require reasons")
        end

        local prerequisite_kind = by_name[edge.prerequisite].kind
        if edge.semantics == "requires_completion"
            and prerequisite_kind ~= "research"
            and prerequisite_kind ~= "proposal" then
            fail("SEMANTIC_KIND_MISMATCH", path,
                "Capacity and external conditions require availability semantics")
        end
        edges[#edges + 1] = edge
    end

    table.sort(nodes, function(a, b) return a.name < b.name end)
    table.sort(edges, edge_less)

    for position = 2, #edges do
        local a, b = edges[position - 1], edges[position]
        if a.dependent == b.dependent
            and a.prerequisite == b.prerequisite
            and a.kind == b.kind
            and a.semantics == b.semantics then
            fail("DUPLICATE_RELATIONSHIP", "edges",
                "One relationship cannot carry multiple lifecycle statuses")
        end
    end

    return {
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope = SCOPE,
        nodes = nodes,
        edges = edges
    }
end

local function protected(operation)
    local ok, result = pcall(operation)
    if ok then
        return result
    end
    if type(result) == "table"
        and type(result.code) == "string" then
        return nil, result
    end
    return nil, {
        code = "INTERNAL_ERROR",
        path = "module",
        message = "Unexpected internal failure"
    }
end

function M.validate(input)
    return protected(function() return normalize(input) end)
end

local function filter_set(value, vocabulary, path, fallback)
    if value == nil then
        return fallback
    end
    local count = array(value, path, 100)
    local result = {}
    for position = 1, count do
        local item = choice(value[position], vocabulary, path)
        if result[item] then
            fail("DUPLICATE_FILTER", path, "Filter values must be unique")
        end
        result[item] = true
    end
    return result
end

function M.project(input, options)
    return protected(function()
        local model = normalize(input)
        options = options or {}
        fields(options, enum("statuses", "kinds", "semantics"), "projection")

        local statuses = filter_set(
            options.statuses, STATUSES, "projection.statuses",
            {canonical = true}
        )
        local kinds = filter_set(
            options.kinds, EDGE_KINDS, "projection.kinds", EDGE_KINDS
        )
        local semantics = filter_set(
            options.semantics, SEMANTICS, "projection.semantics", SEMANTICS
        )

        local selected, excluded = {}, {}
        for _, edge in ipairs(model.edges) do
            local destination = excluded
            if statuses[edge.status]
                and kinds[edge.kind]
                and semantics[edge.semantics] then
                destination = selected
            end
            destination[#destination + 1] = copy_edge(edge)
        end

        return {
            schema_version = VERSION,
            attribution = ATTRIBUTION,
            attribution_scope = SCOPE,
            nodes = model.nodes,
            edges = selected,
            excluded_edges = excluded,
            interpretation =
                "Structural projection only; not readiness or authorization"
        }
    end)
end

function M.direct_readiness(input, name)
    return protected(function()
        local model = normalize(input)
        text(name, "name")

        local by_name, subject = {}, nil
        for _, node in ipairs(model.nodes) do
            by_name[node.name] = node
            if node.name == name then subject = node end
        end
        if not subject then
            fail("UNKNOWN_NODE", "name", "Node is not declared")
        end

        local result = {
            schema_version = VERSION,
            attribution = ATTRIBUTION,
            attribution_scope = SCOPE,
            name = name,
            subject_kind = subject.kind,
            subject_state = subject.state,
            research_blockers = {},
            capacity_blockers = {},
            external_blockers = {},
            proposal_blockers = {},
            coordination = {},
            canonical_self_references = {},
            unresolved_proposals = {},
            waived = {},
            status = "no_recorded_direct_blocker",
            scope =
                "Direct declared requirements only; not transitive readiness, "
                .. "evidence verification, safety approval, or access eligibility"
        }

        local blockers = {
            research = result.research_blockers,
            capacity = result.capacity_blockers,
            external = result.external_blockers,
            proposal = result.proposal_blockers
        }

        for _, edge in ipairs(model.edges) do
            if edge.dependent == name then
                local prerequisite = by_name[edge.prerequisite]
                local entry = {
                    prerequisite = prerequisite.name,
                    kind = prerequisite.kind,
                    state = prerequisite.state,
                    semantics = edge.semantics,
                    rationale = edge.rationale
                }

                if edge.status == "proposed" then
                    result.unresolved_proposals[
                        #result.unresolved_proposals + 1
                    ] = entry
                elseif edge.status == "waived" then
                    entry.review_note = edge.review_note
                    result.waived[#result.waived + 1] = entry
                elseif edge.status == "canonical" then
                    if edge.dependent == edge.prerequisite then
                        result.canonical_self_references[
                            #result.canonical_self_references + 1
                        ] = entry
                    elseif edge.semantics == "co_design" then
                        result.coordination[#result.coordination + 1] = entry
                    elseif prerequisite.state ~= "satisfied" then
                        local bucket = blockers[prerequisite.kind]
                        bucket[#bucket + 1] = entry
                    end
                end
            end
        end

        local total = 0
        for _, bucket in next, blockers do total = total + #bucket end
        if total > 0 then
            result.status = "recorded_direct_blockers"
        elseif #result.coordination > 0
            or #result.canonical_self_references > 0 then
            result.status = "coordination_or_semantic_review_required"
        end
        return result
    end)
end

function M.metadata()
    return {
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope = SCOPE
    }
end

function M.self_test()
    local model = M.metadata()
    model.nodes = {
        {name = "Participation protocol", kind = "research",
            state = "in_progress"},
        {name = "Reviewer availability", kind = "capacity",
            state = "unknown"},
        {name = "Evidence vocabulary", kind = "research",
            state = "satisfied", evidence = "Local fixture assertion"}
    }
    model.edges = {
        {
            dependent = "Participation protocol",
            prerequisite = "Reviewer availability",
            kind = "institutional",
            status = "canonical",
            semantics = "requires_availability",
            rationale = "Review requires available personnel"
        },
        {
            dependent = "Participation protocol",
            prerequisite = "Evidence vocabulary",
            kind = "definitional",
            status = "canonical",
            semantics = "co_design",
            rationale = "Interface definitions need joint review"
        },
        {
            dependent = "Evidence vocabulary",
            prerequisite = "Participation protocol",
            kind = "review",
            status = "proposed",
            semantics = "co_design",
            rationale = "Candidate feedback relationship"
        }
    }

    local checked = assert(M.validate(model))
    assert(#checked.nodes == 3 and #checked.edges == 3)

    local canonical = assert(M.project(model))
    assert(#canonical.edges == 2 and #canonical.excluded_edges == 1)

    local experimental = assert(M.project(model, {
        statuses = {"canonical", "proposed"}
    }))
    assert(#experimental.edges == 3)

    local readiness = assert(M.direct_readiness(
        model, "Participation protocol"
    ))
    assert(#readiness.capacity_blockers == 1)
    assert(#readiness.research_blockers == 0)
    assert(#readiness.coordination == 1)

    checked.nodes[1].name = "Changed returned copy"
    assert(model.nodes[3].name == "Evidence vocabulary")
    assert(assert(M.validate(model)).nodes[1].name == "Evidence vocabulary")

    local invalid = M.metadata()
    invalid.nodes = {[2] = model.nodes[1]}
    invalid.edges = {}
    local value, err = M.validate(invalid)
    assert(value == nil and err.code == "SPARSE_ARRAY")

    local cyclic = M.metadata()
    cyclic.nodes = {cyclic}
    cyclic.edges = {}
    value, err = M.validate(cyclic)
    assert(value == nil and type(err.code) == "string")

    local duplicate = assert(M.validate(model))
    duplicate.edges[#duplicate.edges + 1] = duplicate.edges[1]
    value, err = M.validate(duplicate)
    assert(value == nil and err.code == "DUPLICATE_RELATIONSHIP")

    local bad_semantics = assert(M.validate(model))
    for _, edge in ipairs(bad_semantics.edges) do
        if edge.prerequisite == "Reviewer availability" then
            edge.semantics = "requires_completion"
        end
    end
    value, err = M.validate(bad_semantics)
    assert(value == nil and err.code == "SEMANTIC_KIND_MISMATCH")

    return true
end

return M
