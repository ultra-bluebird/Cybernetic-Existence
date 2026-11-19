-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: local artifact-lineage impact planner.
-- No raw observations, filesystem, network, or actual deletion.
-- References are local labels; lineage and recomputability are supplied.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local classes = {
    raw_observation = true,
    composition_match = true,
    preprocessing_parameter = true,
    training_snapshot = true,
    calibration_parameter = true,
    derived_estimate = true,
    structured_summary = true,
    rendered_text = true,
    cached_derivative = true,
    shared_projection = true,
    execution_receipt = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, allowed)
    if not plain(value) then return false end
    local count = 0
    for key in next, value do
        count = count + 1
        if count > 16 or not allowed[key] then return false end
    end
    return true
end

local function sequence(value, maximum)
    if not plain(value) then return nil end
    local count = 0
    for key in next, value do
        if type(key) ~= "number" or key % 1 ~= 0
            or key < 1 or key > maximum then
            return nil
        end
        count = count + 1
    end
    for index = 1, count do
        if rawget(value, index) == nil then return nil end
    end
    return count
end

local function reference(value)
    return type(value) == "string" and #value <= 128
        and value:match("^local:[A-Za-z0-9_-]+$") ~= nil
end

local function unavailable(reason)
    return {
        schema_version = "deletion-impact-v1",
        status = "unavailable",
        reason = reason,
        deletion_performed = false
    }
end

function M.plan(input)
    if not shape(input, {
        schema_version = true,
        root_reference = true,
        artifacts = true
    }) then
        return unavailable("invalid_input_shape")
    end

    if rawget(input, "schema_version") ~= "deletion-impact-input-v1" then
        return unavailable("unsupported_schema")
    end

    local root = rawget(input, "root_reference")
    local artifacts = rawget(input, "artifacts")
    local count = sequence(artifacts, 1000)
    if not reference(root) or count == nil then
        return unavailable("invalid_root_or_artifact_sequence")
    end

    local records, children = {}, {}

    for index = 1, count do
        local item = rawget(artifacts, index)
        if not shape(item, {
            artifact_reference = true,
            artifact_class = true,
            dependencies = true,
            recomputation_supported = true
        }) then
            return unavailable("invalid_artifact_record")
        end

        local name = rawget(item, "artifact_reference")
        local class = rawget(item, "artifact_class")
        local dependencies = rawget(item, "dependencies")
        local recomputable = rawget(item, "recomputation_supported")

        if not reference(name) or records[name] ~= nil
            or type(class) ~= "string" or not classes[class]
            or sequence(dependencies, 64) == nil
            or type(recomputable) ~= "boolean" then
            return unavailable("invalid_artifact_fields")
        end

        records[name] = {
            class = class,
            dependencies = dependencies,
            recomputable = recomputable
        }
        children[name] = {}
    end

    if records[root] == nil then
        return unavailable("root_not_in_registry")
    end

    local names = {}
    for name in next, records do names[#names + 1] = name end
    table.sort(names)

    for _, name in ipairs(names) do
        local seen_dependencies = {}
        for _, dependency in ipairs(records[name].dependencies) do
            if not reference(dependency) or records[dependency] == nil then
                return unavailable("unresolved_dependency_reference")
            end
            if seen_dependencies[dependency] then
                return unavailable("duplicate_dependency")
            end
            seen_dependencies[dependency] = true
            children[dependency][#children[dependency] + 1] = name
        end
    end

    local queue, visited = { root }, { [root] = true }
    local cursor = 1
    while cursor <= #queue do
        local current = queue[cursor]
        cursor = cursor + 1
        for _, child in ipairs(children[current]) do
            if not visited[child] then
                visited[child] = true
                queue[#queue + 1] = child
            end
        end
    end

    table.sort(queue)
    local actions = {}

    for _, name in ipairs(queue) do
        local record = records[name]
        local followup

        if name == root then
            followup = "storage_deletion_required"
        elseif record.class == "shared_projection" then
            followup = "local_removal_and_recipient_scope_review"
        elseif record.class == "execution_receipt" then
            followup = "minimal_receipt_retention_review"
        elseif record.recomputable then
            followup = "refit_or_recompute_from_remaining_permitted_inputs"
        else
            followup = "retire_or_keep_unavailable_pending_review"
        end

        actions[#actions + 1] = {
            artifact_reference = name,
            artifact_class = record.class,
            immediate_action = "invalidate_and_block_new_use",
            followup = followup
        }
    end

    return {
        schema_version = "deletion-impact-v1",
        status = "impact_plan_produced",
        actions = actions,
        lineage_verification = "not_performed",
        registry_completeness = "not_established",
        cycle_assessment = "not_performed",
        deletion_performed = false,
        mathematical_unlearning_claimed = false,
        external_copies_recalled = false
    }
end

return M
