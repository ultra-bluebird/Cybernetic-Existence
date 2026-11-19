-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: canonical nutritional presentation comparison.
-- No raw events, sensors, physiology, persistence, network, or device access.
-- Observations must come from independently instrumented renderer tests.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local row_specs = {
    { name = "intake_water_content", unit = "mL" },
    { name = "reported_dietary_energy", unit = "kcal_th" },
    { name = "fluid_observation_inflow", unit = "mL" },
    { name = "fluid_observation_outflow", unit = "mL" },
    { name = "fluid_observation_unspecified", unit = "mL" }
}

local NOTICE =
    "Known subtotals over submitted events only. "
    .. "Unknown counts are not zero-valued observations. "
    .. "No complete daily intake or body-state assessment is implied."

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

local function finite_nonnegative(value)
    return type(value) == "number"
        and value == value
        and value >= 0 and value < math.huge
end

local function five_rows(value)
    if not plain(value) then return false end

    local count = 0
    for key in next, value do
        if type(key) ~= "number" or key % 1 ~= 0
            or key < 1 or key > 5 then
            return false
        end
        count = count + 1
    end

    if count ~= 5 then return false end
    for index = 1, 5 do
        if rawget(value, index) == nil then return false end
    end
    return true
end

local function validate(record)
    if not shape(record, {
        schema_version = true,
        scope = true,
        association = true,
        notice = true,
        rows = true
    }) then
        return false
    end

    if rawget(record, "schema_version") ~= "nutrition-semantic-view-v1"
        or rawget(record, "scope") ~= "submitted_events_only"
        or rawget(record, "association") ~= "unanchored_aggregate"
        or rawget(record, "notice") ~= NOTICE then
        return false
    end

    local rows = rawget(record, "rows")
    if not five_rows(rows) then return false end

    for index, spec in ipairs(row_specs) do
        local row = rawget(rows, index)
        if not shape(row, {
            name = true, unit = true,
            known_subtotal = true, unknown_contributors = true
        }) then
            return false
        end

        local unknown = rawget(row, "unknown_contributors")
        if rawget(row, "name") ~= spec.name
            or rawget(row, "unit") ~= spec.unit
            or not finite_nonnegative(rawget(row, "known_subtotal"))
            or not finite_nonnegative(unknown)
            or unknown % 1 ~= 0 or unknown > 1000 then
            return false
        end
    end

    return true
end

function M.notice()
    return NOTICE
end

function M.compare(canonical, text_observation, ar_observation)
    local output = {
        schema_version = "presentation-comparison-v1",
        status = "unavailable",
        findings = {},
        renderer_execution_verified = false,
        user_comprehension_assessed = false,
        assistance_reachability_assessed = false
    }

    if not validate(canonical) then
        output.findings[1] = {
            code = "invalid_canonical_specimen",
            route = "canonical"
        }
        return output
    end

    for _, item in ipairs({
        { route = "text", value = text_observation },
        { route = "ar", value = ar_observation }
    }) do
        local observation = item.value

        if not validate(observation) then
            output.findings[#output.findings + 1] = {
                code = "invalid_presentation_observation",
                route = item.route
            }
        else
            for index = 1, 5 do
                local expected = canonical.rows[index]
                local actual = observation.rows[index]

                for _, field in ipairs({
                    "known_subtotal", "unknown_contributors"
                }) do
                    if rawget(actual, field) ~= rawget(expected, field) then
                        output.findings[#output.findings + 1] = {
                            code = "semantic_value_mismatch",
                            route = item.route,
                            row = index,
                            field = field
                        }
                    end
                end
            end
        end
    end

    if #output.findings == 0 then
        output.status = "supplied_semantic_records_match"
    else
        output.status = "semantic_equivalence_not_established"
    end

    return output
end

return M
