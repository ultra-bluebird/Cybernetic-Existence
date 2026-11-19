local FogWindowGate = {}

local function finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

function FogWindowGate.validate(config)
    assert(type(config) == "table", "config must be a table")
    assert(finite_number(config.maximum_false_withholding_rate),
        "maximum_false_withholding_rate must be finite")
    assert(finite_number(config.maximum_instability),
        "maximum_instability must be finite")
    assert(finite_number(config.minimum_coverage),
        "minimum_coverage must be finite")
    assert(finite_number(config.maximum_false_negative_rate),
        "maximum_false_negative_rate must be finite")

    assert(config.maximum_false_withholding_rate >= 0
        and config.maximum_false_withholding_rate <= 1,
        "maximum_false_withholding_rate must be within [0, 1]")

    assert(config.maximum_instability >= 0
        and config.maximum_instability <= 1,
        "maximum_instability must be within [0, 1]")

    assert(config.minimum_coverage >= 0
        and config.minimum_coverage <= 1,
        "minimum_coverage must be within [0, 1]")

    assert(config.maximum_false_negative_rate >= 0
        and config.maximum_false_negative_rate <= 1,
        "maximum_false_negative_rate must be within [0, 1]")

    return true
end

function FogWindowGate.evaluate(evaluation, config)
    FogWindowGate.validate(config)

    assert(type(evaluation) == "table", "evaluation must be a table")
    assert(type(evaluation.window_label) == "string"
        and #evaluation.window_label > 0,
        "window_label is required")

    local fields = {
        "false_withholding_rate",
        "mean_delta",
        "coverage",
        "false_negative_rate"
    }

    for _, field in ipairs(fields) do
        assert(finite_number(evaluation[field]),
            field .. " must be a finite number")
        assert(evaluation[field] >= 0 and evaluation[field] <= 1,
            field .. " must be within [0, 1]")
    end

    local reasons = {}

    if evaluation.false_withholding_rate
        > config.maximum_false_withholding_rate then
        table.insert(reasons, "false_withholding_rate_exceeded")
    end

    if evaluation.mean_delta > config.maximum_instability then
        table.insert(reasons, "window_instability_exceeded")
    end

    if evaluation.coverage < config.minimum_coverage then
        table.insert(reasons, "coverage_below_minimum")
    end

    if evaluation.false_negative_rate
        > config.maximum_false_negative_rate then
        table.insert(reasons, "false_negative_rate_exceeded")
    end

    return {
        advisory_only = true,
        window_label = evaluation.window_label,
        accepted_for_operational_use = #reasons == 0,
        requires_human_configuration_review = #reasons > 0,
        reasons = reasons
    }
end

return FogWindowGate
