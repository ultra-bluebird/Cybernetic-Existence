-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/eco_restoration/inclusive_community_mobility_metrics.lua
-- Destination: lua/eco_restoration/

local Metrics = {}

local GATHERING_HUB_FEATURES = {
    "universal_seating",
    "sensory_quiet_zone",
    "multilingual_signage",
    "tactile_paths",
    "gender_neutral_restrooms",
}

local ASSISTANCE_MODALITIES = {
    "audio",
    "visual",
    "haptic",
    "text",
    "sign_language_video",
}

local function is_finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

local function require_table(value, name)
    assert(type(value) == "table", name .. " must be a table")
end

local function require_boolean(value, name)
    assert(type(value) == "boolean", name .. " must be a boolean")
end

local function require_unit_interval(value, name)
    assert(is_finite_number(value), name .. " must be a finite number")
    assert(value >= 0 and value <= 1, name .. " must be within [0, 1]")
end

local function require_nonnegative(value, name)
    assert(is_finite_number(value), name .. " must be a finite number")
    assert(value >= 0, name .. " must be non-negative")
end

local function average(values)
    assert(#values > 0, "values must not be empty")

    local total = 0.0

    for _, value in ipairs(values) do
        total = total + value
    end

    return total / #values
end

local function copy_list(values)
    local result = {}

    for index, value in ipairs(values) do
        result[index] = value
    end

    return result
end

--- SC-019: Scores documented inclusive design features. The score concerns
--- physical/service design features only; it does not collect or infer any
--- visitor's protected attributes, identity, disability, gender, language, or
--- health information.
---@param features table
---@return table
function Metrics.gathering_hub_inclusive_design(features)
    require_table(features, "gathering_hub_features")

    local available_count = 0
    local missing_features = {}
    local documented_features = {}

    for _, feature in ipairs(GATHERING_HUB_FEATURES) do
        local available = features[feature]
        require_boolean(available, "gathering_hub_features." .. feature)

        documented_features[feature] = available

        if available then
            available_count = available_count + 1
        else
            table.insert(missing_features, feature)
        end
    end

    local score = available_count / #GATHERING_HUB_FEATURES

    return {
        object_id = "sc-019",
        name = "GatheringHubInclusiveDesign",
        inclusive_design_score = score,
        available_feature_count = available_count,
        assessed_feature_count = #GATHERING_HUB_FEATURES,
        documented_features = documented_features,
        missing_features = missing_features,
        protected_attribute_collection = false,
        knowledge_factor = 0.75,
        eco_impact_value = 0.20,
        harm_risk = clamp(1.0 - score, 0.0, 1.0),
        authority_effect = "none",
        interpretation =
            "Feature-availability audit only. A high score indicates documented inclusive "
            .. "design provisions, not lived-experience validation or universal accessibility.",
    }
end

--- SC-020: Evaluates a supplied transit-priority scenario using non-negative
--- objective terms. The model has no signaling, routing, surveillance, or
--- actuation capability. Equity and heat constraints are evaluated before a
--- scenario is considered suitable for human review.
---@param input table
---@param weights table|nil
---@return table
function Metrics.transit_signal_priority_equity(input, weights)
    require_table(input, "transit_priority_input")

    local bunching_index = input.bunching_index
    local heat_exposure_index = input.heat_exposure_index
    local equity_gap = input.equity_gap
    local baseline_equity_gap = input.baseline_equity_gap
    local shade_infrastructure_priority = input.shade_infrastructure_priority

    require_unit_interval(bunching_index, "transit_priority_input.bunching_index")
    require_unit_interval(
        heat_exposure_index,
        "transit_priority_input.heat_exposure_index"
    )
    require_unit_interval(equity_gap, "transit_priority_input.equity_gap")
    require_unit_interval(
        baseline_equity_gap,
        "transit_priority_input.baseline_equity_gap"
    )
    require_boolean(
        shade_infrastructure_priority,
        "transit_priority_input.shade_infrastructure_priority"
    )

    weights = weights or {
        bunching = 1.0,
        heat_exposure = 1.0,
        equity_gap = 1.0,
    }

    require_table(weights, "transit_priority_weights")
    require_nonnegative(weights.bunching, "transit_priority_weights.bunching")
    require_nonnegative(
        weights.heat_exposure,
        "transit_priority_weights.heat_exposure"
    )
    require_nonnegative(weights.equity_gap, "transit_priority_weights.equity_gap")

    local weight_total =
        weights.bunching + weights.heat_exposure + weights.equity_gap

    assert(weight_total > 0, "transit_priority_weights must have positive total")

    local normalized_bunching_weight = weights.bunching / weight_total
    local normalized_heat_weight = weights.heat_exposure / weight_total
    local normalized_equity_weight = weights.equity_gap / weight_total

    local objective =
        normalized_bunching_weight * bunching_index
        + normalized_heat_weight * heat_exposure_index
        + normalized_equity_weight * equity_gap

    local equity_constraint_satisfied = equity_gap <= baseline_equity_gap
    local shade_constraint_satisfied = shade_infrastructure_priority

    local eligible_for_human_review =
        equity_constraint_satisfied and shade_constraint_satisfied

    local failed_constraints = {}

    if not equity_constraint_satisfied then
        table.insert(failed_constraints, "equity_gap_must_not_increase")
    end

    if not shade_constraint_satisfied then
        table.insert(
            failed_constraints,
            "heat_exposure_must_include_shade_infrastructure_priority"
        )
    end

    return {
        object_id = "sc-020",
        name = "TransitSignalPriorityEquity",
        objective_score = objective,
        objectives = {
            bunching_index = bunching_index,
            heat_exposure_index = heat_exposure_index,
            equity_gap = equity_gap,
        },
        normalized_weights = {
            bunching = normalized_bunching_weight,
            heat_exposure = normalized_heat_weight,
            equity_gap = normalized_equity_weight,
        },
        constraints = {
            equity_gap_must_not_increase = equity_constraint_satisfied,
            shade_infrastructure_priority = shade_constraint_satisfied,
        },
        eligible_for_human_review = eligible_for_human_review,
        failed_constraints = failed_constraints,
        knowledge_factor = 0.65,
        eco_impact_value = clamp(
            (1.0 - heat_exposure_index) * 0.60
                + (1.0 - bunching_index) * 0.20
                + (1.0 - equity_gap) * 0.20,
            0.0,
            1.0
        ),
        harm_risk = clamp(
            math.max(
                0.0,
                equity_gap - baseline_equity_gap
            )
                + (shade_infrastructure_priority and 0.0 or 0.35),
            0.0,
            1.0
        ),
        authority_effect = "none",
        interpretation =
            "Scenario evaluation for planning review. It does not operate traffic signals, "
            .. "track passengers, assign priorities, or make service eligibility decisions.",
    }
end

--- SC-021: Calculates equal-weight average task completion across documented
--- interface modalities. Missing modalities are reported as evidence gaps and
--- do not become zero-valued observations unless explicitly measured as zero.
---@param completion_by_modality table
---@return table
function Metrics.assistance_panel_multimodal(completion_by_modality)
    require_table(completion_by_modality, "completion_by_modality")

    local completion_values = {}
    local missing_modalities = {}
    local documented_completion = {}

    for _, modality in ipairs(ASSISTANCE_MODALITIES) do
        local completion_rate = completion_by_modality[modality]

        if completion_rate == nil then
            table.insert(missing_modalities, modality)
        else
            require_unit_interval(
                completion_rate,
                "completion_by_modality." .. modality
            )
            documented_completion[modality] = completion_rate
            table.insert(completion_values, completion_rate)
        end
    end

    local average_completion = 0.0

    if #completion_values > 0 then
        average_completion = average(completion_values)
    end

    local minimum_completion = 0.0
    local maximum_completion = 0.0

    if #completion_values > 0 then
        minimum_completion = completion_values[1]
        maximum_completion = completion_values[1]

        for _, value in ipairs(completion_values) do
            minimum_completion = math.min(minimum_completion, value)
            maximum_completion = math.max(maximum_completion, value)
        end
    end

    local modality_gap = maximum_completion - minimum_completion
    local modality_coverage = #completion_values / #ASSISTANCE_MODALITIES

    return {
        object_id = "sc-021",
        name = "AssistancePanelMultimodal",
        average_task_completion_rate = average_completion,
        minimum_documented_completion_rate = minimum_completion,
        maximum_documented_completion_rate = maximum_completion,
        modality_completion_gap = modality_gap,
        documented_modality_coverage = modality_coverage,
        documented_completion = documented_completion,
        missing_modalities = missing_modalities,
        modalities = copy_list(ASSISTANCE_MODALITIES),
        knowledge_factor = modality_coverage,
        eco_impact_value = 0.10,
        harm_risk = clamp(
            (1.0 - minimum_completion) * 0.60
                + modality_gap * 0.25
                + (1.0 - modality_coverage) * 0.15,
            0.0,
            1.0
        ),
        authority_effect = "none",
        interpretation =
            "Aggregate interface-quality measure. It does not identify users, infer disability, "
            .. "or grant access; low-performing or undocumented modalities should be investigated through inclusive testing.",
    }
end

return Metrics
