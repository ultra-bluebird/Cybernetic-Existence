-- Lua 5.4
-- Run tests: lua cybermind/dependency_graph.lua --self-test
-- Import: local graph = require("cybermind.dependency_graph")

local M = {}

M.attribution =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

M.attribution_scope =
    "Document credit and workstream metadata only; not identity, consent, "
    .. "authorization, execution evidence, or authority over others."

local function sorted_keys(value)
    local result = {}
    for key in pairs(value) do
        result[#result + 1] = key
    end
    table.sort(result)
    return result
end

local function valid_name(value)
    return type(value) == "string" and value:match("%S") ~= nil
end

local function read_list(list, context)
    if type(list) ~= "table" then
        error(context .. " must be an array", 3)
    end

    local count = 0
    for key in pairs(list) do
        if type(key) ~= "number"
            or key < 1
            or key % 1 ~= 0 then
            error(context .. " must have consecutive integer keys", 3)
        end
        count = count + 1
    end

    local seen = {}
    for index = 1, count do
        local name = list[index]
        if not valid_name(name) then
            error(context .. " contains a missing or invalid name", 3)
        end
        if seen[name] then
            error(context .. " contains duplicate name: " .. name, 3)
        end
        seen[name] = true
    end
    return seen
end

function M.validate(graph)
    if type(graph) ~= "table" then
        error("graph must map names to prerequisite arrays", 2)
    end

    local names = {}
    for name in pairs(graph) do
        if not valid_name(name) then
            error("every graph key must be a nonblank string", 2)
        end
        names[#names + 1] = name
    end
    table.sort(names)

    for _, name in ipairs(names) do
        local dependencies = read_list(
            graph[name], "prerequisites for " .. name
        )
        for dependency in pairs(dependencies) do
            if graph[dependency] == nil then
                error("unknown prerequisite: " .. dependency, 2)
            end
        end
    end

    return names
end

function M.reverse(graph)
    local names = M.validate(graph)
    local reverse = {}

    for _, name in ipairs(names) do
        reverse[name] = {}
    end

    for _, name in ipairs(names) do
        for _, dependency in ipairs(graph[name]) do
            local entries = reverse[dependency]
            entries[#entries + 1] = name
        end
    end

    for _, name in ipairs(names) do
        table.sort(reverse[name])
    end
    return reverse
end

function M.analyze(graph)
    local names = M.validate(graph)
    local reverse = M.reverse(graph)
    local visited, order = {}, {}

    -- Iterative depth-first traversal avoids recursive stack limits.
    for _, start in ipairs(names) do
        if not visited[start] then
            visited[start] = true
            local stack = {{ name = start, next_edge = 1 }}

            while #stack > 0 do
                local frame = stack[#stack]
                local dependency = graph[frame.name][frame.next_edge]

                if dependency then
                    frame.next_edge = frame.next_edge + 1
                    if not visited[dependency] then
                        visited[dependency] = true
                        stack[#stack + 1] = {
                            name = dependency,
                            next_edge = 1
                        }
                    end
                else
                    order[#order + 1] = frame.name
                    stack[#stack] = nil
                end
            end
        end
    end

    local assigned, groups = {}, {}

    for index = #order, 1, -1 do
        local start = order[index]
        if not assigned[start] then
            local members = {}
            local stack = {start}
            assigned[start] = true

            while #stack > 0 do
                local name = table.remove(stack)
                members[#members + 1] = name

                for _, dependent in ipairs(reverse[name]) do
                    if not assigned[dependent] then
                        assigned[dependent] = true
                        stack[#stack + 1] = dependent
                    end
                end
            end

            table.sort(members)
            groups[#groups + 1] = members
        end
    end

    table.sort(groups, function(left, right)
        return left[1] < right[1]
    end)

    local membership, components = {}, {}
    for _, members in ipairs(groups) do
        local component = {
            members = members,
            prerequisites = {},
            dependents = {},
            tier = 0,
            cyclic = #members > 1
        }
        components[#components + 1] = component
        for _, name in ipairs(members) do
            membership[name] = component
        end
    end

    local edge_sets = {}
    for _, component in ipairs(components) do
        edge_sets[component] = {}
    end

    for _, name in ipairs(names) do
        local source = membership[name]
        for _, dependency in ipairs(graph[name]) do
            local target = membership[dependency]
            if source == target then
                if name == dependency then
                    source.cyclic = true
                end
            else
                edge_sets[source][target] = true
            end
        end
    end

    for _, component in ipairs(components) do
        for prerequisite in pairs(edge_sets[component]) do
            component.prerequisites[#component.prerequisites + 1] =
                prerequisite
            prerequisite.dependents[#prerequisite.dependents + 1] =
                component
        end
    end

    local function component_less(left, right)
        return left.members[1] < right.members[1]
    end

    local pending, queue = {}, {}
    for _, component in ipairs(components) do
        table.sort(component.prerequisites, component_less)
        table.sort(component.dependents, component_less)
        pending[component] = #component.prerequisites
        if pending[component] == 0 then
            queue[#queue + 1] = component
        end
    end

    local position, processed = 1, 0
    while position <= #queue do
        local component = queue[position]
        position = position + 1
        processed = processed + 1

        for _, dependent in ipairs(component.dependents) do
            dependent.tier = math.max(
                dependent.tier, component.tier + 1
            )
            pending[dependent] = pending[dependent] - 1
            if pending[dependent] == 0 then
                queue[#queue + 1] = dependent
            end
        end
    end

    assert(processed == #components, "invalid condensation graph")

    local nodes = {}
    for _, name in ipairs(names) do
        local reachable = {[name] = true}
        local stack = {name}
        local total = 0

        while #stack > 0 do
            local current = table.remove(stack)
            for _, dependent in ipairs(reverse[current]) do
                if not reachable[dependent] then
                    reachable[dependent] = true
                    total = total + 1
                    stack[#stack + 1] = dependent
                end
            end
        end

        nodes[name] = {
            tier = membership[name].tier,
            component_members = membership[name].members,
            cyclic = membership[name].cyclic,
            direct_prerequisites = #graph[name],
            direct_dependents = #reverse[name],
            transitive_dependents = total
        }
    end

    local report_components = {}
    for _, component in ipairs(components) do
        local prerequisites = {}
        for _, prerequisite in ipairs(component.prerequisites) do
            prerequisites[#prerequisites + 1] = prerequisite.members
        end
        report_components[#report_components + 1] = {
            members = component.members,
            tier = component.tier,
            cyclic = component.cyclic,
            prerequisite_components = prerequisites
        }
    end

    return {
        attribution = M.attribution,
        attribution_scope = M.attribution_scope,
        edge_convention = "dependent -> prerequisite",
        nodes = nodes,
        components = report_components,
        derived_dependents = reverse
    }
end

function M.compare_reverse(graph, supplied)
    local expected = M.reverse(graph)
    if type(supplied) ~= "table" then
        error("supplied reverse relationships must be a table", 2)
    end

    for name in pairs(supplied) do
        if expected[name] == nil then
            error("unknown reverse-list name: " .. tostring(name), 2)
        end
    end

    local issues = {}
    for _, name in ipairs(sorted_keys(expected)) do
        if supplied[name] == nil then
            issues[#issues + 1] = {
                kind = "missing_reverse_list",
                name = name
            }
        else
            local actual = read_list(
                supplied[name], "reverse relationships for " .. name
            )
            local wanted = read_list(expected[name], "derived reverse")

            for dependent in pairs(actual) do
                if graph[dependent] == nil then
                    error("unknown dependent: " .. dependent, 2)
                end
                if not wanted[dependent] then
                    issues[#issues + 1] = {
                        kind = "extra_reverse_relationship",
                        name = name,
                        dependent = dependent
                    }
                end
            end

            for dependent in pairs(wanted) do
                if not actual[dependent] then
                    issues[#issues + 1] = {
                        kind = "missing_reverse_relationship",
                        name = name,
                        dependent = dependent
                    }
                end
            end
        end
    end

    table.sort(issues, function(left, right)
        local a = left.name .. "\0" .. left.kind
            .. "\0" .. (left.dependent or "")
        local b = right.name .. "\0" .. right.kind
            .. "\0" .. (right.dependent or "")
        return a < b
    end)

    return issues
end

function M.self_test()
    local graph = {
        ["Evidence register"] = {"Scenario pipeline"},
        ["Scenario pipeline"] = {"Evidence register"},
        ["Inference gate"] = {"Evidence register"},
        ["Private draft"] = {"Inference gate"},
        ["Independent review"] = {}
    }

    local result = M.analyze(graph)
    assert(result.nodes["Evidence register"].cyclic)
    assert(result.nodes["Evidence register"].tier == 0)
    assert(result.nodes["Inference gate"].tier == 1)
    assert(result.nodes["Private draft"].tier == 2)
    assert(result.nodes["Evidence register"].transitive_dependents == 3)
    assert(result.nodes["Independent review"].direct_dependents == 0)

    local reverse = M.reverse(graph)
    assert(#M.compare_reverse(graph, reverse) == 0)
    reverse["Inference gate"] = {}
    assert(#M.compare_reverse(graph, reverse) == 1)

    local self_loop = M.analyze({["Review"] = {"Review"}})
    assert(self_loop.nodes["Review"].cyclic)

    local bad = pcall(M.analyze, {
        ["Review"] = {"Unknown prerequisite"}
    })
    assert(not bad)

    local sparse = pcall(M.analyze, {
        ["Review"] = {[2] = "Review"}
    })
    assert(not sparse)

    assert(#M.analyze({}).components == 0)
    return true
end

if ... == "--self-test" then
    M.self_test()
    io.write("Dependency graph self-tests passed.\n")
end

return M
