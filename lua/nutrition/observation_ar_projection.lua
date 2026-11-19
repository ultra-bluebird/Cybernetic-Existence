-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: private aggregate projection of observation_access output.
-- No raw events, coordinates, food recognition, physiology, or device control.
-- Display-surface and permission declarations are not independently verified.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function finite_nonnegative(value)
    return type(value) == "number"
        and value == value
        and value >= 0 and value < math.huge
end

local function count_value(value)
    return finite_nonnegative(value)
        and value % 1 == 0 and value <= 1000
end

local function shape(value, allowed)
    if not plain(value) then return false end
    local count = 0
    for key in next, value do
        count = count + 1
        if count > 32 or not allowed[key] then return false end
    end
    return true
end

local function copy_proposals(result, output)
    local proposals = rawget(result, "proposals")
    if not plain(proposals) then return end

    local count = 0
    for key in next, proposals do
        if type(key) ~= "number" or key % 1 ~= 0
            or key < 1 or key > 16 then
            return
        end
        count = count + 1
    end
    for index = 1, count do
        if rawget(proposals, index) == nil then return end
    end

    local copied = {}
    for index = 1, count do
        local proposal = rawget(proposals, index)
        if not plain(proposal) then return end

        local kind = rawget(proposal, "kind")
        if kind ~= "food" and kind ~= "water"
            and kind ~= "human_help" and kind ~= "optional_check_in" then
            return
        end

        copied[#copied + 1] = {
            kind = kind,
            external_action_requires_approval = true
        }
    end
    output.proposals = copied
end

local function valid_accounting(accounting)
    if not shape(accounting, {
        scope = true, event_count = true,
        intake_event_count = true, fluid_event_count = true,
        known_water_ml = true, known_dietary_energy_kcal = true,
        unknown_water_events = true, unknown_energy_events = true,
        fluid_by_direction = true
    }) then
        return false
    end

    if rawget(accounting, "scope") ~= "submitted_events_only" then
        return false
    end

    for _, name in ipairs({
        "event_count", "intake_event_count", "fluid_event_count",
        "unknown_water_events", "unknown_energy_events"
    }) do
        if not count_value(rawget(accounting, name)) then return false end
    end

    local intake_count = rawget(accounting, "intake_event_count")
    local fluid_count = rawget(accounting, "fluid_event_count")

    if rawget(accounting, "event_count") ~= intake_count + fluid_count
        or rawget(accounting, "unknown_water_events") > intake_count
        or rawget(accounting, "unknown_energy_events") > intake_count then
        return false
    end

    for _, name in ipairs({ "known_water_ml", "known_dietary_energy_kcal" }) do
        if not finite_nonnegative(rawget(accounting, name)) then
            return false
        end
    end

    if rawget(accounting, "unknown_water_events") == intake_count
        and rawget(accounting, "known_water_ml") ~= 0 then
        return false
    end
    if rawget(accounting, "unknown_energy_events") == intake_count
        and rawget(accounting, "known_dietary_energy_kcal") ~= 0 then
        return false
    end

    local fluids = rawget(accounting, "fluid_by_direction")
    if not shape(fluids, {
        inflow = true, outflow = true, unspecified = true
    }) then
        return false
    end

    local unknown_total = 0
    for _, direction in ipairs({ "inflow", "outflow", "unspecified" }) do
        local bucket = rawget(fluids, direction)
        if not shape(bucket, { known_ml = true, unknown_events = true })
            or not finite_nonnegative(rawget(bucket, "known_ml"))
            or not count_value(rawget(bucket, "unknown_events")) then
            return false
        end
        unknown_total = unknown_total + rawget(bucket, "unknown_events")
        if fluid_count == 0 and rawget(bucket, "known_ml") ~= 0 then
            return false
        end
    end

    return unknown_total <= fluid_count
end

function M.project(result, presentation)
    local output = {
        schema_version = "observation-ar-projection-v1",
        status = "no_numeric_summary",
        primary_route = "text",
        ar_mode = "off",
        association = "none",
        rows = {},
        proposals = {},
        findings = {},
        source_verification = "not_performed",
        physiological_interpretation = "not_performed"
    }

    if not plain(result) then
        output.findings[1] = "plain_observation_result_required"
        return output
    end

    -- Assistance projection is independent of numeric-summary presentation.
    copy_proposals(result, output)

    if not shape(presentation, {
        consent_display = true,
        surface = true,
        ar_opt_in = true,
        visible_numeric_rows = true
    }) then
        output.findings[1] = "invalid_presentation_record"
        return output
    end

    if rawget(presentation, "consent_display") ~= true then
        output.status = "not_processed_without_display_permission"
        return output
    end

    local surface = rawget(presentation, "surface")
    if surface ~= "personal" and surface ~= "shared" then
        output.findings[1] = "explicit_surface_required"
        return output
    end
    if surface == "shared" then
        output.status = "numeric_summary_not_projected_to_shared_surface"
        return output
    end

    if rawget(result, "accounting_status") ~= "summarized_in_memory" then
        output.status = "accounting_unavailable"
        return output
    end

    local accounting = rawget(result, "intake_accounting")
    if not valid_accounting(accounting) then
        output.findings[1] = "invalid_aggregate_accounting"
        return output
    end

    local capacity = rawget(presentation, "visible_numeric_rows")
    if not count_value(capacity) or capacity < 5 then
        output.status = "text_detail_required"
        output.notice =
            "Open the text detail to view subtotals and unknown counts together."
        return output
    end

    local function row(label, amount, unit, unknown)
        output.rows[#output.rows + 1] = {
            label = label,
            known_subtotal = amount,
            unit = unit,
            unknown_contributors = unknown,
            scope = "submitted_events_only"
        }
    end

    row("Intake water content",
        accounting.known_water_ml, "mL",
        accounting.unknown_water_events)
    row("Reported dietary energy",
        accounting.known_dietary_energy_kcal, "kcal_th",
        accounting.unknown_energy_events)

    for _, direction in ipairs({ "inflow", "outflow", "unspecified" }) do
        local bucket = accounting.fluid_by_direction[direction]
        row("Fluid observations: " .. direction,
            bucket.known_ml, "mL", bucket.unknown_events)
    end

    output.status = "private_aggregate_summary"
    output.notice =
        "Known subtotals over submitted events only. "
        .. "Unknown counts are not zero-valued observations. "
        .. "No complete daily intake or body-state assessment is implied."

    local ar = rawget(presentation, "ar_opt_in")
    if ar == true then
        output.ar_mode = "optional_unanchored_panel"
        output.association = "aggregate_not_associated_with_a_food"
    elseif ar ~= nil and type(ar) ~= "boolean" then
        output.findings[#output.findings + 1] = "invalid_ar_preference"
    end

    return output
end

return M
