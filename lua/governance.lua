local M = {}

local function copy_table(value)
    local copy = {}

    for key, nested_value in pairs(value) do
        copy[key] = nested_value
    end

    return copy
end

function M.standard_block()
    return {
        scope = "aggregate_environmental_decision_support_only",
        individual_profiling = "prohibited",
        automated_adverse_action = "prohibited",
        external_action = "not_performed",
    }
end

function M.normalize_coverage_status(result)
    if type(result) ~= "table" then
        return result
    end

    if result.coverage_status == "insufficient" then
        result.coverage_status = "insufficient_coverage"
    end

    return result
end

function M.attach(response)
    assert(type(response) == "table", "response must be a table")

    local enriched = copy_table(response)
    local result = enriched.result

    if type(result) == "table" then
        enriched.result = M.normalize_coverage_status(result)
    end

    enriched.decision_support_only = true
    enriched.aggregate_environmental_only = true
    enriched.person_level_inference_prohibited = true
    enriched.automated_adverse_action_prohibited = true
    enriched.governance = M.standard_block()

    return enriched
end

function M.is_standard(block)
    return type(block) == "table"
        and block.scope == "aggregate_environmental_decision_support_only"
        and block.individual_profiling == "prohibited"
        and block.automated_adverse_action == "prohibited"
        and block.external_action == "not_performed"
end

return M
