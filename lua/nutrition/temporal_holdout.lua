-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: chronological research split planner.
-- All times are seconds on one caller-declared common time axis.
-- dependency_group labels shared observation-specific information.
-- No model fitting, nutrition values, persistence, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge and value < math.huge
end

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

local function sequence(value)
    if not plain(value) then return nil end
    local count = 0
    for key in next, value do
        if type(key) ~= "number" or key % 1 ~= 0
            or key < 1 or key > 10000 then
            return nil
        end
        count = count + 1
    end
    for index = 1, count do
        if rawget(value, index) == nil then return nil end
    end
    return count
end

local function fail(reason)
    return {
        schema_version = "temporal-holdout-result-v1",
        status = "unavailable",
        reason = reason
    }
end

function M.plan(input)
    if not shape(input, {
        schema_version = true,
        cutoff_s = true,
        gap_s = true,
        test_end_s = true,
        windows = true
    }) then
        return fail("invalid_input_shape")
    end

    if rawget(input, "schema_version") ~= "temporal-holdout-input-v1" then
        return fail("unsupported_schema")
    end

    local cutoff = rawget(input, "cutoff_s")
    local gap = rawget(input, "gap_s")
    local test_end = rawget(input, "test_end_s")

    if not finite(cutoff) or not finite(gap) or gap < 0
        or not finite(test_end) then
        return fail("invalid_time_parameters")
    end

    local test_start = (cutoff + 0.0) + (gap + 0.0)
    if not finite(test_start) or test_end <= test_start then
        return fail("invalid_test_interval")
    end

    local windows = rawget(input, "windows")
    local count = sequence(windows)
    if count == nil then return fail("invalid_window_sequence") end

    local candidates, test, excluded = {}, {}, {}
    local test_groups = {}

    for index = 1, count do
        local window = rawget(windows, index)
        if not shape(window, {
            origin_s = true,
            label_start_s = true,
            label_end_s = true,
            available_s = true,
            dependency_group = true
        }) then
            return fail("invalid_window_shape")
        end

        local origin = rawget(window, "origin_s")
        local start_s = rawget(window, "label_start_s")
        local end_s = rawget(window, "label_end_s")
        local available = rawget(window, "available_s")
        local group = rawget(window, "dependency_group")

        if not finite(origin) or not finite(start_s)
            or not finite(end_s) or not finite(available)
            or start_s < origin or end_s <= start_s
            or available < end_s then
            return fail("invalid_window_timing")
        end

        if type(group) ~= "string" or #group == 0 or #group > 128 then
            return fail("dependency_group_required")
        end

        if end_s <= cutoff and available <= cutoff then
            candidates[#candidates + 1] = {
                index = index, group = group
            }
        elseif origin >= test_start and origin < test_end
            and end_s <= test_end then
            test[#test + 1] = index
            test_groups[group] = true
        else
            excluded[#excluded + 1] = {
                index = index,
                reason = "outside_fold_or_not_available_at_cutoff"
            }
        end
    end

    local train = {}
    for _, candidate in ipairs(candidates) do
        if test_groups[candidate.group] then
            excluded[#excluded + 1] = {
                index = candidate.index,
                reason = "dependency_shared_with_test"
            }
        else
            train[#train + 1] = candidate.index
        end
    end

    table.sort(excluded, function(a, b) return a.index < b.index end)

    local status = "planned"
    if #train == 0 or #test == 0 then status = "insufficient_fold" end

    return {
        schema_version = "temporal-holdout-result-v1",
        status = status,
        train_indices = train,
        test_indices = test,
        excluded = excluded,
        cutoff_s = cutoff,
        test_start_s = test_start,
        test_end_s = test_end,
        dependency_evidence = "caller_supplied_not_verified",
        preprocessing_leakage_assessment = "not_performed",
        feature_availability_assessment = "not_performed",
        generalization_scope = "future_period_in_declared_local_setting"
    }
end

return M
