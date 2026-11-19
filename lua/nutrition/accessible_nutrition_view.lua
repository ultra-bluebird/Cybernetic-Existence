-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: stateless semantic preparation for text and optional AR.
-- No sensing, estimation, physiology, persistence, network, or device access.
-- Summary completeness, sources, and permissions are supplied claims.
-- Aggregate summaries never acquire food-specific spatial meaning.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local NOTICE =
    "Known subtotal from submitted entries only. "
    .. "Not absorbed energy, body reserves, or a personal requirement."

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge and value < math.huge
end

local function count_value(value)
    return finite(value) and value >= 0
        and value % 1 == 0 and value <= 1000
end

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 256
end

local function shape(value, allowed)
    if not plain(value) then return false end
    local count = 0
    for key in next, value do
        count = count + 1
        if count > 24 or not allowed[key] then return false end
    end
    return true
end

function M.build(input)
    local output = {
        schema_version = "accessible-nutrition-view-v2",
        view_status = "no_summary",
        primary_route = "text_and_table",
        ar_presentation = "off",
        association = "none",
        proposals = {},
        findings = {},
        evidence_verification = "not_performed",
        physiological_interpretation = "not_performed"
    }

    local function finding(code, field)
        output.findings[#output.findings + 1] = {
            code = code, field = field
        }
    end

    if not plain(input) then
        finding("plain_input_required", "input")
        return output
    end

    -- Recognized assistance requests survive optional-content errors.
    local request = rawget(input, "access_request")
    if request ~= nil then
        if plain(request) then
            for _, name in ipairs({ "food", "water", "human_help" }) do
                local value = rawget(request, name)
                if value == true then
                    output.proposals[#output.proposals + 1] = {
                        kind = name,
                        external_action_requires_approval = true
                    }
                elseif value ~= nil and type(value) ~= "boolean" then
                    finding("request_boolean_required",
                        "access_request." .. name)
                end
            end
            if not shape(request, {
                food = true, water = true, human_help = true
            }) then
                finding("unsupported_request_fields", "access_request")
            end
        else
            finding("plain_request_required", "access_request")
        end
    end

    if not shape(input, {
        access_request = true,
        consent_summary_display = true,
        ar_opt_in = true,
        session_hidden = true,
        summary = true
    }) then
        finding("unsupported_input_fields", "input")
        return output
    end

    local permission = rawget(input, "consent_summary_display")
    if permission ~= true then
        if permission ~= nil and type(permission) ~= "boolean" then
            finding("display_permission_boolean_required",
                "consent_summary_display")
        end
        output.view_status = "not_processed_without_display_permission"
        return output
    end

    local hidden = rawget(input, "session_hidden")
    if hidden ~= nil and type(hidden) ~= "boolean" then
        finding("session_hidden_boolean_required", "session_hidden")
        return output
    end
    if hidden == true then
        output.view_status = "hidden_for_session"
        return output
    end

    local ar = rawget(input, "ar_opt_in")
    if ar ~= nil and type(ar) ~= "boolean" then
        finding("ar_preference_boolean_required", "ar_opt_in")
        return output
    end

    local summary = rawget(input, "summary")
    if not shape(summary, {
        known_energy_kcal = true,
        known_energy_contributors = true,
        unknown_energy_contributors = true,
        interval_label = true,
        completeness = true,
        source_revision = true
    }) then
        finding("invalid_summary_shape", "summary")
        return output
    end

    local energy = rawget(summary, "known_energy_kcal")
    local known = rawget(summary, "known_energy_contributors")
    local unknown = rawget(summary, "unknown_energy_contributors")
    local completeness = rawget(summary, "completeness")

    if not finite(energy) or energy < 0
        or not count_value(known) or not count_value(unknown)
        or known + unknown > 1000
        or not text(rawget(summary, "interval_label"))
        or not text(rawget(summary, "source_revision"))
        or (completeness ~= "complete_report"
            and completeness ~= "partial_report"
            and completeness ~= "unknown_completeness") then
        finding("invalid_summary_values", "summary")
        return output
    end

    if known == 0 and energy ~= 0 then
        finding("subtotal_without_known_contributors", "summary")
        return output
    end

    local value_state = "known_subtotal"
    if known == 0 then
        value_state = "no_known_contributions"
    end
    if energy == 0 then energy = 0.0 end

    output.view_status = "summary_available"
    output.semantic_summary = {
        title = "Reported dietary energy",
        value_state = value_state,
        known_subtotal = energy,
        unit = "kcal_th",
        scope = "submitted_entries_only",
        known_contributors = known,
        unknown_contributors = unknown,
        reporting_completeness = completeness,
        interval_label = rawget(summary, "interval_label"),
        source_revision = rawget(summary, "source_revision"),
        notice = NOTICE
    }

    if ar == true then
        output.ar_presentation = "optional_unanchored_panel"
        output.association = "aggregate_not_food_specific"
    end

    return output
end

function M.self_test()
    local sentinel = setmetatable({}, {
        __index = function() error("must not inspect summary") end,
        __pairs = function() error("must not inspect summary") end
    })

    local result = M.build({
        access_request = { water = true, human_help = true },
        consent_summary_display = false,
        summary = sentinel
    })
    assert(#result.proposals == 2)
    assert(result.semantic_summary == nil)

    result = M.build({
        access_request = { food = true },
        consent_summary_display = true,
        ar_opt_in = true,
        summary = {
            known_energy_kcal = 120,
            known_energy_contributors = 1,
            unknown_energy_contributors = 1,
            interval_label = "Synthetic submitted interval",
            completeness = "partial_report",
            source_revision = "synthetic-source"
        }
    })
    assert(result.view_status == "summary_available")
    assert(result.semantic_summary.unknown_contributors == 1)
    assert(result.ar_presentation == "optional_unanchored_panel")
    assert(#result.proposals == 1)

    result = M.build({
        access_request = { water = true },
        consent_summary_display = true,
        session_hidden = true,
        summary = sentinel
    })
    assert(result.view_status == "hidden_for_session")
    assert(#result.proposals == 1)
    assert(result.semantic_summary == nil)

    return {
        status = "passed",
        scope = "embedded_synthetic_assertions"
    }
end

return M
