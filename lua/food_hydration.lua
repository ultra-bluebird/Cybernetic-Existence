-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Local, non-actuating food/hydration decision support.
-- Lua 5.4. No filesystem, network, clock, or device access.

local M = {}

local function record(value, name, allowed)
    assert(type(value) == "table", name .. " must be a table")
    assert(getmetatable(value) == nil, name .. " must be a plain table")
    for key in pairs(value) do
        assert(allowed[key], name .. " contains an unsupported field")
    end
end

local function boolean(value, name)
    assert(type(value) == "boolean", name .. " must be boolean")
end

local function number(value, name)
    assert(type(value) == "number"
        and value == value
        and value >= 0
        and value < math.huge,
        name .. " must be finite and nonnegative")
end

local function choice(value, name, allowed, default)
    if value == nil then
        return default
    end
    assert(type(value) == "string" and allowed[value],
        name .. " has an unsupported value")
    return value
end

local function sequence(value, maximum)
    assert(type(value) == "table" and getmetatable(value) == nil,
        "events must be a plain table")

    local count = 0
    for key in pairs(value) do
        assert(type(key) == "number"
            and key % 1 == 0
            and key >= 1
            and key <= maximum,
            "events must use bounded positive integer keys")
        count = count + 1
    end

    for index = 1, count do
        assert(rawget(value, index) ~= nil, "events must be contiguous")
    end
    return count
end

local function observations(events)
    local count = sequence(events, 1000)
    local result = {
        event_count = count,
        reported_water_ml = 0,
        reported_energy_kcal = 0,
        unknown_water_events = 0,
        unknown_energy_events = 0
    }

    for index = 1, count do
        local event = events[index]
        record(event, "event", {
            kind = true, water_ml = true, energy_kcal = true
        })
        assert(event.kind == "food" or event.kind == "drink",
            "event kind must be food or drink")

        if event.water_ml == nil then
            result.unknown_water_events =
                result.unknown_water_events + 1
        else
            number(event.water_ml, "water_ml")
            result.reported_water_ml =
                result.reported_water_ml + event.water_ml
            number(result.reported_water_ml, "water total")
        end

        if event.energy_kcal == nil then
            result.unknown_energy_events =
                result.unknown_energy_events + 1
        else
            number(event.energy_kcal, "energy_kcal")
            result.reported_energy_kcal =
                result.reported_energy_kcal + event.energy_kcal
            number(result.reported_energy_kcal, "energy total")
        end
    end

    return result
end

function M.evaluate(input)
    record(input, "input", {
        request = true, consent = true, bci_dimensions = true,
        events = true, reminder_due = true
    })

    record(input.request, "request", {
        food = true, water = true, human_help = true
    })
    for _, key in ipairs({ "food", "water", "human_help" }) do
        boolean(input.request[key], "request." .. key)
    end

    record(input.consent, "consent", {
        log_intake = true, reminders = true
    })
    boolean(input.consent.log_intake, "consent.log_intake")
    boolean(input.consent.reminders, "consent.reminders")

    if input.reminder_due ~= nil then
        boolean(input.reminder_due, "reminder_due")
    end

    local bci = input.bci_dimensions or {}
    record(bci, "bci_dimensions", {
        communication = true, pacing = true,
        sensory = true, continuity = true
    })

    local interaction = {
        communication = choice(bci.communication, "communication",
            { text = true, assistive = true, human = true }, "text"),
        pacing = choice(bci.pacing, "pacing",
            { user_led = true, extended = true }, "user_led"),
        sensory = choice(bci.sensory, "sensory",
            { quiet = true, standard = true }, "quiet"),
        continuity = choice(bci.continuity, "continuity",
            { preserve = true, pause_on_request = true }, "preserve"),
        response_deadline_seconds = nil,
        interrupt_active_session = false
    }

    local result = {
        mode = "local_advisory",
        interaction = interaction,
        access = {
            food_supported = true,
            water_supported = true,
            human_fallback_supported = true,
            identity_disclosure_required = false,
            bci_disclosure_required = false,
            logging_required = false
        },
        proposals = {},
        logging = "not_requested",
        persistence_performed = false,
        external_actions_performed = false,
        physiological_inference_performed = false
    }

    local function propose(kind, message)
        result.proposals[#result.proposals + 1] = {
            kind = kind,
            message = message,
            external_action_requires_approval = true
        }
    end

    if input.request.food then
        propose("food_access", "Food requested; offer available options.")
    end
    if input.request.water then
        propose("water_access", "Water requested; offer accessible access.")
    end
    if input.request.human_help or interaction.communication == "human" then
        propose("human_help", "Human assistance requested.")
    end

    if input.consent.reminders and input.reminder_due == true then
        propose("optional_check_in",
            "Would you like food, water, rest, or assistance? No response required.")
    end

    if input.events ~= nil then
        if input.consent.log_intake then
            result.observations = observations(input.events)
            result.logging = "summarized_in_memory"
        else
            -- Do not inspect or copy unconsented event contents.
            result.logging = "ignored_without_permission"
        end
    end

    return result
end

return M
