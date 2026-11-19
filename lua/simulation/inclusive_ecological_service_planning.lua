local inclusive_ecological_service_planning = {}

local function is_finite(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function assert_finite(value, name)
    assert(is_finite(value), name .. " must be a finite number")
    return value
end

local function assert_nonnegative(value, name)
    assert_finite(value, name)
    assert(value >= 0, name .. " must be non-negative")
    return value
end

local function assert_positive(value, name)
    assert_nonnegative(value, name)
    assert(value > 0, name .. " must be greater than zero")
    return value
end

local function assert_unit_interval(value, name)
    assert_finite(value, name)
    assert(value >= 0 and value <= 1, name .. " must be in [0, 1]")
    return value
end

local function assert_boolean(value, name)
    assert(type(value) == "boolean", name .. " must be boolean")
    return value
end

local function assert_string(value, name)
    assert(type(value) == "string" and value ~= "", name .. " must be a non-empty string")
    return value
end

local function mean(values, name)
    assert(type(values) == "table" and #values > 0, name .. " must be a non-empty array")

    local total = 0
    for index, value in ipairs(values) do
        total = total + assert_finite(value, name .. "[" .. index .. "]")
    end
    return total / #values
end

local function sort_descending(items)
    table.sort(items, function(left, right)
        if left.score == right.score then
            return left.id < right.id
        end
        return left.score > right.score
    end)
end

function inclusive_ecological_service_planning.rank_maintenance_windows(input)
    assert(type(input) == "table", "maintenance input must be a table")
    assert(type(input.windows) == "table" and #input.windows > 0,
        "windows must be a non-empty array")
    assert(type(input.weights) == "table", "input.weights must be a table")

    local wildlife_weight = assert_nonnegative(
        input.weights.wildlife_disturbance,
        "weights.wildlife_disturbance"
    )
    local citizen_weight = assert_nonnegative(
        input.weights.citizen_disruption,
        "weights.citizen_disruption"
    )
    local heat_weight = assert_nonnegative(
        input.weights.worker_heat_safety,
        "weights.worker_heat_safety"
    )
    local water_weight = assert_nonnegative(
        input.weights.water_or_habitat_urgency,
        "weights.water_or_habitat_urgency"
    )
    local total_weight =
        wildlife_weight + citizen_weight + heat_weight + water_weight
    assert(total_weight > 0, "at least one maintenance weight must be positive")

    local ranked = {}

    for index, window in ipairs(input.windows) do
        assert(type(window) == "table", "windows[" .. index .. "] must be a table")

        local id = assert_string(window.id, "windows[" .. index .. "].id")
        local wildlife_disturbance = assert_unit_interval(
            window.wildlife_disturbance,
            "windows[" .. index .. "].wildlife_disturbance"
        )
        local citizen_disruption = assert_unit_interval(
            window.citizen_disruption,
            "windows[" .. index .. "].citizen_disruption"
        )
        local worker_heat_risk = assert_unit_interval(
            window.worker_heat_risk,
            "windows[" .. index .. "].worker_heat_risk"
        )
        local water_or_habitat_urgency = assert_unit_interval(
            window.water_or_habitat_urgency,
            "windows[" .. index .. "].water_or_habitat_urgency"
        )
        local accessible_detour_available = assert_boolean(
            window.accessible_detour_available,
            "windows[" .. index .. "].accessible_detour_available"
        )
        local human_oversight_available = assert_boolean(
            window.human_oversight_available,
            "windows[" .. index .. "].human_oversight_available"
        )

        local score = (
            wildlife_weight * (1 - wildlife_disturbance) +
            citizen_weight * (1 - citizen_disruption) +
            heat_weight * (1 - worker_heat_risk) +
            water_weight * water_or_habitat_urgency
        ) / total_weight

        if not accessible_detour_available or not human_oversight_available then
            score = 0
        end

        ranked[#ranked + 1] = {
            id = id,
            score = score,
            wildlife_disturbance = wildlife_disturbance,
            citizen_disruption = citizen_disruption,
            worker_heat_risk = worker_heat_risk,
            water_or_habitat_urgency = water_or_habitat_urgency,
            accessible_detour_available = accessible_detour_available,
            human_oversight_available = human_oversight_available,
            eligible = accessible_detour_available and human_oversight_available,
        }
    end

    sort_descending(ranked)

    return {
        ranked_windows = ranked,
        recommended_window = ranked[1],
        limitation = "This produces a schedule ranking only. It does not dispatch bots, automate work near people or animals, or replace site-specific ecological, accessibility, labor, and safety review.",
    }
end

function inclusive_ecological_service_planning.assistance_panel_profile(input)
    assert(type(input) == "table", "panel input must be a table")

    local plain_language = assert_boolean(
        input.plain_language_available,
        "plain_language_available"
    )
    local visual_mode = assert_boolean(
        input.visual_mode_available,
        "visual_mode_available"
    )
    local auditory_mode = assert_boolean(
        input.auditory_mode_available,
        "auditory_mode_available"
    )
    local tactile_mode = assert_boolean(
        input.tactile_mode_available,
        "tactile_mode_available"
    )
    local physical_input = assert_boolean(
        input.physical_or_non_touch_input_available,
        "physical_or_non_touch_input_available"
    )
    local cognitive_load = assert_unit_interval(
        input.cognitive_load,
        "cognitive_load"
    )
    local identity_required = assert_boolean(
        input.identity_required,
        "identity_required"
    )
    local health_data_required = assert_boolean(
        input.health_data_required,
        "health_data_required"
    )
    local human_fallback = assert_boolean(
        input.human_fallback_available,
        "human_fallback_available"
    )

    local multimodal_score = mean({
        plain_language and 1 or 0,
        visual_mode and 1 or 0,
        auditory_mode and 1 or 0,
        tactile_mode and 1 or 0,
        physical_input and 1 or 0,
        human_fallback and 1 or 0,
    }, "panel modes")

    local privacy_preserving = not identity_required and not health_data_required
    local adaptive_ready = multimodal_score >= 0.8
        and cognitive_load <= 0.4
        and privacy_preserving

    return {
        multimodal_score = multimodal_score,
        cognitive_load = cognitive_load,
        privacy_preserving = privacy_preserving,
        adaptive_ready = adaptive_ready,
        recommended_design = {
            "default_to_plain_language",
            "allow_user_selected_visual_auditory_and_tactile_modes",
            "offer_physical_or_non_touch_input",
            "avoid_identity_and_health_data_requests",
            "provide_immediate_human_fallback",
        },
        decision = adaptive_ready
            and "maintain user-selected modes and minimize interaction steps without storing sensitive profiles"
            or "reduce cognitive load, expand independently selectable modes, and remove unnecessary data collection before adapting service behavior",
    }
end

function inclusive_ecological_service_planning.rank_gathering_hub_layouts(input)
    assert(type(input) == "table", "hub input must be a table")
    assert(type(input.layouts) == "table" and #input.layouts > 0,
        "layouts must be a non-empty array")
    assert(type(input.weights) == "table", "input.weights must be a table")

    local shade_weight = assert_nonnegative(input.weights.shade, "weights.shade")
    local accessibility_weight = assert_nonnegative(
        input.weights.accessibility,
        "weights.accessibility"
    )
    local mixing_weight = assert_nonnegative(
        input.weights.positive_social_mixing,
        "weights.positive_social_mixing"
    )
    local habitat_weight = assert_nonnegative(
        input.weights.habitat_compatibility,
        "weights.habitat_compatibility"
    )
    local total_weight =
        shade_weight + accessibility_weight + mixing_weight + habitat_weight
    assert(total_weight > 0, "at least one hub-layout weight must be positive")

    local ranked = {}

    for index, layout in ipairs(input.layouts) do
        assert(type(layout) == "table", "layouts[" .. index .. "] must be a table")

        local id = assert_string(layout.id, "layouts[" .. index .. "].id")
        local shade = assert_unit_interval(layout.shade, "layouts[" .. index .. "].shade")
        local accessibility = assert_unit_interval(
            layout.accessibility,
            "layouts[" .. index .. "].accessibility"
        )
        local positive_mixing = assert_unit_interval(
            layout.positive_social_mixing,
            "layouts[" .. index .. "].positive_social_mixing"
        )
        local habitat_compatibility = assert_unit_interval(
            layout.habitat_compatibility,
            "layouts[" .. index .. "].habitat_compatibility"
        )
        local voluntary_aggregate_evidence = assert_boolean(
            layout.voluntary_aggregate_evidence,
            "layouts[" .. index .. "].voluntary_aggregate_evidence"
        )

        local score = (
            shade_weight * shade +
            accessibility_weight * accessibility +
            mixing_weight * positive_mixing +
            habitat_weight * habitat_compatibility
        ) / total_weight

        if not voluntary_aggregate_evidence then
            score = 0
        end

        ranked[#ranked + 1] = {
            id = id,
            score = score,
            shade = shade,
            accessibility = accessibility,
            positive_social_mixing = positive_mixing,
            habitat_compatibility = habitat_compatibility,
            voluntary_aggregate_evidence = voluntary_aggregate_evidence,
        }
    end

    sort_descending(ranked)

    return {
        ranked_layouts = ranked,
        recommended_layout = ranked[1],
        limitation = "Use voluntary, aggregate, non-identifying participation evidence. Do not infer identities, profile ages, or require social mixing from any person.",
    }
end

function inclusive_ecological_service_planning.rank_transit_options(input)
    assert(type(input) == "table", "transit input must be a table")
    assert(type(input.options) == "table" and #input.options > 0,
        "options must be a non-empty array")
    assert(type(input.weights) == "table", "input.weights must be a table")

    local frequency_weight = assert_nonnegative(
        input.weights.frequency,
        "weights.frequency"
    )
    local heat_weight = assert_nonnegative(
        input.weights.heat_exposure,
        "weights.heat_exposure"
    )
    local wait_equity_weight = assert_nonnegative(
        input.weights.wait_time_equity,
        "weights.wait_time_equity"
    )
    local energy_weight = assert_nonnegative(
        input.weights.energy_efficiency,
        "weights.energy_efficiency"
    )
    local total_weight =
        frequency_weight + heat_weight + wait_equity_weight + energy_weight
    assert(total_weight > 0, "at least one transit weight must be positive")

    local ranked = {}

    for index, option in ipairs(input.options) do
        assert(type(option) == "table", "options[" .. index .. "] must be a table")

        local id = assert_string(option.id, "options[" .. index .. "].id")
        local normalized_frequency = assert_unit_interval(
            option.normalized_frequency,
            "options[" .. index .. "].normalized_frequency"
        )
        local normalized_heat_exposure = assert_unit_interval(
            option.normalized_heat_exposure,
            "options[" .. index .. "].normalized_heat_exposure"
        )
        local wait_time_parity = assert_unit_interval(
            option.wait_time_parity,
            "options[" .. index .. "].wait_time_parity"
        )
        local energy_efficiency = assert_unit_interval(
            option.energy_efficiency,
            "options[" .. index .. "].energy_efficiency"
        )
        local accessible_continuity = assert_boolean(
            option.accessible_continuity,
            "options[" .. index .. "].accessible_continuity"
        )

        local score = (
            frequency_weight * normalized_frequency +
            heat_weight * (1 - normalized_heat_exposure) +
            wait_equity_weight * wait_time_parity +
            energy_weight * energy_efficiency
        ) / total_weight

        if not accessible_continuity then
            score = 0
        end

        ranked[#ranked + 1] = {
            id = id,
            score = score,
            normalized_frequency = normalized_frequency,
            normalized_heat_exposure = normalized_heat_exposure,
            wait_time_parity = wait_time_parity,
            energy_efficiency = energy_efficiency,
            accessible_continuity = accessible_continuity,
        }
    end

    sort_descending(ranked)

    return {
        ranked_transit_options = ranked,
        recommended_option = ranked[1],
        limitation = "This ranks policy options supplied by planners; it does not schedule transit, profile riders, or replace public process, accessibility review, labor constraints, or operational safety analysis.",
    }
end

function inclusive_ecological_service_planning.accessible_path_data_products(input)
    assert(type(input) == "table", "path-data input must be a table")

    local aggregated_slope_coverage = assert_unit_interval(
        input.aggregated_slope_coverage,
        "aggregated_slope_coverage"
    )
    local surface_condition_coverage = assert_unit_interval(
        input.surface_condition_coverage,
        "surface_condition_coverage"
    )
    local shade_and_heat_coverage = assert_unit_interval(
        input.shade_and_heat_coverage,
        "shade_and_heat_coverage"
    )
    local obstruction_coverage = assert_unit_interval(
        input.obstruction_coverage,
        "obstruction_coverage"
    )
    local curb_ramp_coverage = assert_unit_interval(
        input.curb_ramp_coverage,
        "curb_ramp_coverage"
    )
    local direct_identifiers_present = assert_boolean(
        input.direct_identifiers_present,
        "direct_identifiers_present"
    )
    local persistent_device_identifiers_present = assert_boolean(
        input.persistent_device_identifiers_present,
        "persistent_device_identifiers_present"
    )
    local aggregate_release_safe = assert_boolean(
        input.aggregate_release_safe,
        "aggregate_release_safe"
    )

    local privacy_preserving = not direct_identifiers_present
        and not persistent_device_identifiers_present
        and aggregate_release_safe

    local product_value = mean({
        aggregated_slope_coverage,
        surface_condition_coverage,
        shade_and_heat_coverage,
        obstruction_coverage,
        curb_ramp_coverage,
    }, "path product coverage")

    return {
        privacy_preserving = privacy_preserving,
        city_planning_value = product_value,
        recommended_aggregate_products = {
            "segment_level_slope_and_cross_slope_condition",
            "surface_condition_and_maintenance_priority",
            "shade_heat_and_rest_interval_coverage",
            "aggregated_obstruction_frequency",
            "curb_ramp_presence_and_condition",
            "route_continuity_and_detour_quality",
        },
        decision = privacy_preserving
            and "use coarse, aggregate path-condition products for maintenance and heat-refuge planning"
            or "remove identifiers, reduce precision where needed, and apply aggregation safeguards before releasing planning products",
        limitation = "Do not publish travel traces, device signatures, individual mobility patterns, or medical inferences. Validate path conditions through accessible community review and site inspection.",
    }
end

function inclusive_ecological_service_planning.assessment_metrics(input)
    assert(type(input) == "table", "metrics input must be a table")

    local knowledge_factor = mean({
        assert_unit_interval(input.field_validation_coverage, "field_validation_coverage"),
        assert_unit_interval(input.ecological_timing_evidence, "ecological_timing_evidence"),
        assert_unit_interval(input.accessibility_testing_coverage, "accessibility_testing_coverage"),
        assert_unit_interval(input.privacy_review_quality, "privacy_review_quality"),
    }, "knowledge inputs")

    local eco_impact_value = mean({
        assert_unit_interval(input.habitat_protection_benefit, "habitat_protection_benefit"),
        assert_unit_interval(input.cooling_benefit, "cooling_benefit"),
        assert_unit_interval(input.energy_efficiency_benefit, "energy_efficiency_benefit"),
        assert_unit_interval(input.access_continuity_benefit, "access_continuity_benefit"),
    }, "eco-impact inputs")

    local harm_risk = mean({
        assert_unit_interval(input.wildlife_disturbance_risk, "wildlife_disturbance_risk"),
        assert_unit_interval(input.heat_or_worker_safety_risk, "heat_or_worker_safety_risk"),
        assert_unit_interval(input.access_disruption_risk, "access_disruption_risk"),
        assert_unit_interval(input.privacy_risk, "privacy_risk"),
        assert_unit_interval(input.exclusion_risk, "exclusion_risk"),
    }, "harm-risk inputs")

    return {
        knowledge_factor = knowledge_factor,
        eco_impact_value = eco_impact_value,
        harm_risk = harm_risk,
    }
end

return inclusive_ecological_service_planning
