local AssistancePanel = {}

local essential_function_names = {
    emergency_help = true,
    general_assistance = true,
    wayfinding = true,
    public_service_hours = true,
    transit_information = true,
    cooling_information = true,
    water_information = true,
    accessibility_support = true,
    grievance_and_appeal_information = true
}

local function result(output_state, reason_codes, values)
    return {
        output_state = output_state,
        reason_codes = reason_codes or {},
        values = values or {},
        local_first = true,
        advisory_only = true,
        identity_required = false,
        biometric_processing_permitted = false,
        cybernetic_status_disclosure_required = false,
        person_assessment_performed = false,
        automated_service_denial_permitted = false
    }
end

local function contains(values, expected)
    if type(values) ~= "table" then
        return false
    end

    for _, value in ipairs(values) do
        if value == expected then
            return true
        end
    end

    return false
end

local function modality_requirements_met(input)
    local has_essential_button = contains(
        input.input_modalities,
        "physical_essential_function_button"
    )

    local has_non_touch_input = contains(
        input.input_modalities,
        "physical_keypad"
    ) or contains(
        input.input_modalities,
        "voice_input_local_only"
    ) or contains(
        input.input_modalities,
        "written_language_input"
    ) or contains(
        input.input_modalities,
        "accessible_assistance_switch"
    )

    local has_visual_output = contains(
        input.output_modalities,
        "high_contrast_visual_display"
    )

    local has_audio_output = contains(
        input.output_modalities,
        "local_audio_output"
    )

    local has_tactile_support = contains(
        input.output_modalities,
        "braille_or_tactile_labels"
    ) or contains(
        input.output_modalities,
        "haptic_feedback"
    )

    return has_essential_button
        and has_non_touch_input
        and has_visual_output
        and has_audio_output
        and has_tactile_support
end

local function essential_function_is_accessible(function_spec)
    return type(function_spec) == "table"
        and essential_function_names[function_spec.function_name] == true
        and function_spec.offline_available == true
        and function_spec.identity_required == false
        and function_spec.personal_status_disclosure_required == false
        and function_spec.accessible_explanation_available == true
        and function_spec.physical_button_available == true
        and function_spec.non_touch_alternative_available == true
        and function_spec.visual_output_available == true
        and function_spec.audio_output_available == true
end

function AssistancePanel.evaluate(input)
    if type(input) ~= "table"
        or type(input.input_modalities) ~= "table"
        or type(input.output_modalities) ~= "table"
        or type(input.essential_functions) ~= "table"
        or #input.essential_functions == 0 then
        return result(
            "insufficient_evidence",
            { "assistance_panel_assessment_incomplete" }
        )
    end

    if input.identity_required == true
        or input.biometric_processing_permitted == true
        or input.cybernetic_status_disclosure_required == true
        or input.personalization_identity_required == true
        or input.persistent_preferences_default == true
        or input.requests_person_assessment == true
        or input.requests_identity_resolution == true
        or input.requests_cybernetic_status_assessment == true then
        return result(
            "blocked_by_policy",
            { "identity_biometric_or_status_disclosure_not_permitted" }
        )
    end

    if input.offline_mode_available ~= true then
        return result(
            "essential_function_gap",
            { "offline_essential_functionality_required" }
        )
    end

    if input.non_digital_escalation_available ~= true then
        return result(
            "essential_function_gap",
            { "non_digital_escalation_required" }
        )
    end

    if not modality_requirements_met(input) then
        return result(
            "accessible_with_review_needed",
            { "multimodal_input_output_and_tactile_support_required" }
        )
    end

    for _, function_spec in ipairs(input.essential_functions) do
        if not essential_function_is_accessible(function_spec) then
            return result(
                "essential_function_gap",
                {
                    "essential_function_requires_offline_non_identifying_multimodal_access"
                },
                {
                    function_name = function_spec.function_name
                }
            )
        end
    end

    if input.local_information_cache_state == "unavailable" then
        return result(
            "essential_function_gap",
            { "local_essential_information_cache_required" }
        )
    end

    if input.local_information_cache_state == "stale_with_visible_timestamp"
        or input.local_information_cache_state == "limited_essential_information_only" then
        return result(
            "accessible_with_review_needed",
            {
                "local_information_cache_requires_refresh_or_scope_review"
            }
        )
    end

    return result(
        "fully_accessible_offline",
        {
            "essential_functions_available_without_identity_or_connectivity",
            "session_local_optional_personalization_only",
            "no_biometric_or_cybernetic_status_processing"
        }
    )
end

return AssistancePanel
