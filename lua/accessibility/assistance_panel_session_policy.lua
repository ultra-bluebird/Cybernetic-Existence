local AssistancePanelSessionPolicy = {}
AssistancePanelSessionPolicy.__index = AssistancePanelSessionPolicy

local VALID_INPUT_MODALITIES = {
    touch = true,
    physical_buttons = true,
    local_voice = true,
    headphone_audio = true,
}

local VALID_PREFERENCES = {
    step_free = true,
    quieter = true,
    shaded = true,
    fewer_turns = true,
    simpler_crossings = true,
    rest_opportunities = true,
    lower_exposure = true,
}

local VALID_CONDITION_STATES = {
    clear = true,
    restricted = true,
    blocked = true,
    inspection_required = true,
    unknown = true,
}

local function assert_table(value, name)
    if type(value) ~= "table" then
        error(name .. " must be a table", 3)
    end
end

local function assert_boolean(value, name, expected)
    if value ~= expected then
        error(name .. " must be " .. tostring(expected), 3)
    end
end

local function assert_integer(value, name, minimum, maximum)
    if type(value) ~= "number" or value % 1 ~= 0 or value < minimum or value > maximum then
        error(name .. " must be an integer from " .. tostring(minimum) .. " through " .. tostring(maximum), 3)
    end
end

local function assert_non_empty_string(value, name, maximum_length)
    if type(value) ~= "string" or value == "" then
        error(name .. " must be a non-empty string", 3)
    end

    if #value > maximum_length then
        error(name .. " exceeds the maximum length", 3)
    end
end

local function copy_array(values)
    local result = {}
    for index, value in ipairs(values) do
        result[index] = value
    end
    return result
end

function AssistancePanelSessionPolicy.new(policy)
    assert_table(policy, "policy")

    if policy.schema ~= "javasphere.assistance-panel-session-policy/v1" then
        error("Unsupported policy schema.", 2)
    end

    assert_integer(policy.session_timeout_seconds, "policy.session_timeout_seconds", 30, 900)

    assert_boolean(
        policy.proximity_creates_identity_record,
        "policy.proximity_creates_identity_record",
        false
    )
    assert_boolean(
        policy.persistent_preference_profiles_enabled,
        "policy.persistent_preference_profiles_enabled",
        false
    )
    assert_boolean(
        policy.raw_voice_audio_retained,
        "policy.raw_voice_audio_retained",
        false
    )
    assert_boolean(
        policy.speech_transcripts_retained,
        "policy.speech_transcripts_retained",
        false
    )
    assert_boolean(
        policy.route_history_retained,
        "policy.route_history_retained",
        false
    )
    assert_boolean(
        policy.external_session_export_allowed,
        "policy.external_session_export_allowed",
        false
    )
    assert_boolean(
        policy.manual_activation_available,
        "policy.manual_activation_available",
        true
    )
    assert_boolean(
        policy.device_free_interaction_available,
        "policy.device_free_interaction_available",
        true
    )

    assert_table(policy.supported_input_modalities, "policy.supported_input_modalities")

    local modalities = {}
    for _, modality in ipairs(policy.supported_input_modalities) do
        if not VALID_INPUT_MODALITIES[modality] then
            error("Unsupported input modality: " .. tostring(modality), 2)
        end
        modalities[modality] = true
    end

    if not modalities.touch or not modalities.physical_buttons or not modalities.headphone_audio then
        error("Touch, physical buttons, and headphone audio are required.", 2)
    end

    return setmetatable({
        policy = policy,
    }, AssistancePanelSessionPolicy)
end

function AssistancePanelSessionPolicy:validate_preferences(preferences)
    assert_table(preferences, "preferences")

    local normalized = {}

    for _, preference in ipairs(preferences) do
        assert_non_empty_string(preference, "preference", 64)

        if not VALID_PREFERENCES[preference] then
            error("Unsupported session-only route preference: " .. preference, 2)
        end

        normalized[preference] = true
    end

    local result = {}
    for preference, _ in pairs(normalized) do
        table.insert(result, preference)
    end

    table.sort(result)
    return result
end

function AssistancePanelSessionPolicy:validate_route_condition(condition)
    assert_table(condition, "condition")

    if not VALID_CONDITION_STATES[condition.condition_state] then
        error("Unsupported route condition state.", 2)
    end

    assert_non_empty_string(condition.condition_class, "condition.condition_class", 128)
    assert_non_empty_string(condition.source_class, "condition.source_class", 128)
    assert_non_empty_string(condition.observed_at, "condition.observed_at", 64)
    assert_non_empty_string(condition.expires_at, "condition.expires_at", 64)

    if condition.condition_state == "blocked" and condition.alternate_accessible_route_confirmed ~= true then
        return {
            usable_for_accessible_routing = false,
            explanation = "A blocked route segment has no confirmed accessible alternate route.",
        }
    end

    return {
        usable_for_accessible_routing = condition.condition_state == "clear" or
            condition.condition_state == "restricted",
        explanation = "The route condition may be considered with its declared restrictions and freshness.",
    }
end

function AssistancePanelSessionPolicy:create_session(session)
    assert_table(session, "session")
    assert_non_empty_string(session.session_id, "session.session_id", 96)
    assert_non_empty_string(session.started_at, "session.started_at", 64)

    if session.origin_panel_class ~= "public-assistance-panel" then
        error("Only public assistance-panel origins are supported.", 2)
    end

    local preferences = self:validate_preferences(session.preferences or {})

    return {
        schema = "javasphere.assistance-panel-routing-session/v1",
        session_id = session.session_id,
        started_at = session.started_at,
        expires_after_seconds = self.policy.session_timeout_seconds,
        origin_panel_class = "public-assistance-panel",
        preferences = copy_array(preferences),
        identity_data_stored = false,
        route_history_stored = false,
        raw_audio_stored = false,
        external_export_allowed = false,
    }
end

return AssistancePanelSessionPolicy
