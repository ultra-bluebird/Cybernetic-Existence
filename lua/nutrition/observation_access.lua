-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: local observation accounting and assistance proposals.
-- No filesystem, network, clock, device access, or physiological inference.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
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

local function amount(value)
    assert(type(value) == "number"
        and value == value and value >= 0 and value < math.huge,
        "invalid_amount")
    if value == 0 then return 0.0 end
    return value + 0.0
end

local function accumulate(total, value)
    local result = total + amount(value)
    assert(result < math.huge, "amount_overflow")
    return result
end

local function sequence(value)
    assert(plain(value), "invalid_events")
    local count = 0
    for key in next, value do
        assert(type(key) == "number"
            and key % 1 == 0 and key >= 1 and key <= 1000,
            "invalid_event_key")
        count = count + 1
    end
    for index = 1, count do
        assert(rawget(value, index) ~= nil, "sparse_events")
    end
    return count
end

local function observations(events)
    local count = sequence(events)
    local result = {
        scope = "submitted_events_only",
        event_count = count,
        intake_event_count = 0,
        fluid_event_count = 0,
        known_water_ml = 0.0,
        known_dietary_energy_kcal = 0.0,
        unknown_water_events = 0,
        unknown_energy_events = 0,
        fluid_by_direction = {
            inflow = { known_ml = 0.0, unknown_events = 0 },
            outflow = { known_ml = 0.0, unknown_events = 0 },
            unspecified = { known_ml = 0.0, unknown_events = 0 }
        }
    }

    for index = 1, count do
        local event = rawget(events, index)
        assert(plain(event), "invalid_event")
        local kind = rawget(event, "kind")

        if kind == "food" or kind == "drink" then
            assert(shape(event, {
                kind = true, water_ml = true, dietary_energy_kcal = true
            }), "invalid_intake_fields")

            result.intake_event_count = result.intake_event_count + 1
            local water = rawget(event, "water_ml")
            local energy = rawget(event, "dietary_energy_kcal")

            if water == nil then
                result.unknown_water_events =
                    result.unknown_water_events + 1
            else
                result.known_water_ml =
                    accumulate(result.known_water_ml, water)
            end

            if energy == nil then
                result.unknown_energy_events =
                    result.unknown_energy_events + 1
            else
                result.known_dietary_energy_kcal =
                    accumulate(result.known_dietary_energy_kcal, energy)
            end

        elseif kind == "fluid_observation" then
            assert(shape(event, {
                kind = true, fluid_ml = true, direction = true
            }), "invalid_fluid_fields")

            local direction = rawget(event, "direction")
            assert(direction == "inflow" or direction == "outflow"
                or direction == "unspecified", "invalid_direction")

            result.fluid_event_count = result.fluid_event_count + 1
            local bucket = result.fluid_by_direction[direction]
            local volume = rawget(event, "fluid_ml")

            if volume == nil then
                bucket.unknown_events = bucket.unknown_events + 1
            else
                bucket.known_ml = accumulate(bucket.known_ml, volume)
            end
        else
            error("unsupported_event_kind")
        end
    end

    return result
end

local function preference(value, allowed, fallback)
    if value == nil then return fallback, true end
    if type(value) == "string" and allowed[value] then
        return value, true
    end
    return fallback, false
end

function M.evaluate(input)
    local output = {
        schema_version = "nutrition-observation-access-v1",
        accounting_status = "not_requested",
        findings = {},
        proposals = {},
        access = {
            food_supported = true,
            water_supported = true,
            human_fallback_supported = true,
            logging_required = false,
            bci_disclosure_required = false,
            human_fallback_route = "application_provided"
        },
        bci_access = {
            mode = "text",
            pacing = "user_led",
            sensory = "quiet",
            continuity = "preserve"
        },
        evidence_verification = "not_performed",
        physiological_inference_performed = false,
        persistence_performed = false,
        external_action_performed = false
    }

    local function finding(code, field)
        output.findings[#output.findings + 1] = {
            code = code, field = field
        }
    end

    local function propose(kind, message)
        output.proposals[#output.proposals + 1] = {
            kind = kind,
            message = message,
            external_action_requires_approval = true
        }
    end

    if not plain(input) then
        finding("plain_input_required", "input")
        return output
    end

    -- Resolve requests before optional accounting validation.
    local request = rawget(input, "request")
    if shape(request, { food = true, water = true, human_help = true }) then
        for _, name in ipairs({ "food", "water", "human_help" }) do
            local value = rawget(request, name)
            if value ~= nil and type(value) ~= "boolean" then
                finding("request_boolean_required", "request." .. name)
            elseif value == true then
                propose(name, name .. " assistance requested.")
            end
        end
    elseif request ~= nil then
        finding("invalid_request_record", "request")
    end

    if not shape(input, {
        request = true, consent = true, bci_dimensions = true,
        events = true, reminder_due = true
    }) then
        finding("unsupported_top_level_fields", "input")
    end

    local preferences = rawget(input, "bci_dimensions")
    if preferences ~= nil then
        if shape(preferences, {
            mode = true, pacing = true,
            sensory = true, continuity = true
        }) then
            local specs = {
                { "mode", {
                    text = true, assistive = true, human = true,
                    audio = true, visual = true
                }, "text" },
                { "pacing", {
                    user_led = true, extended = true
                }, "user_led" },
                { "sensory", {
                    quiet = true, standard = true
                }, "quiet" },
                { "continuity", {
                    preserve = true, pause_on_request = true
                }, "preserve" }
            }
            for _, spec in ipairs(specs) do
                local selected, valid = preference(
                    rawget(preferences, spec[1]), spec[2], spec[3])
                output.bci_access[spec[1]] = selected
                if not valid then
                    finding("invalid_preference", "bci_dimensions." .. spec[1])
                end
            end
            if output.bci_access.mode == "human"
                and not (plain(request)
                    and rawget(request, "human_help") == true) then
                propose("human_help", "Human communication assistance requested.")
            end
        else
            finding("invalid_preferences", "bci_dimensions")
        end
    end

    local consent = rawget(input, "consent")
    local logging, reminders = false, false

    if consent ~= nil then
        if shape(consent, { logging = true, reminders = true }) then
            for _, name in ipairs({ "logging", "reminders" }) do
                local value = rawget(consent, name)
                if value ~= nil and type(value) ~= "boolean" then
                    finding("permission_boolean_required", "consent." .. name)
                end
            end
            logging = rawget(consent, "logging") == true
            reminders = rawget(consent, "reminders") == true
        else
            finding("invalid_consent_record", "consent")
        end
    end

    local due = rawget(input, "reminder_due")
    if due ~= nil and type(due) ~= "boolean" then
        finding("reminder_boolean_required", "reminder_due")
    end
    if reminders and due == true then
        propose("optional_check_in",
            "Would you like food, water, rest, or assistance? "
            .. "No response is required.")
    end

    local events = rawget(input, "events")
    if events ~= nil then
        if not logging then
            output.accounting_status = "not_processed_without_permission"
        else
            local ok, result = pcall(observations, events)
            if ok then
                output.accounting_status = "summarized_in_memory"
                output.intake_accounting = result
            else
                output.accounting_status = "unavailable_invalid_events"
                finding("event_validation_failed", "events")
            end
        end
    end

    return output
end

return M
