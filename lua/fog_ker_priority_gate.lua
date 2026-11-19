local FogKerPriorityGate = {}

local function finite_unit_interval(value, name)
    assert(type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge,
        name .. " must be finite")

    assert(value >= 0 and value <= 1,
        name .. " must be within [0, 1]")
end

function FogKerPriorityGate.validate_weights(weights)
    assert(type(weights) == "table", "weights must be a table")

    finite_unit_interval(weights.low_knowledge_weight,
        "low_knowledge_weight")
    finite_unit_interval(weights.ecological_value_weight,
        "ecological_value_weight")
    finite_unit_interval(weights.risk_weight, "risk_weight")

    local sum =
        weights.low_knowledge_weight
        + weights.ecological_value_weight
        + weights.risk_weight

    assert(math.abs(sum - 1.0) < 0.000000001,
        "weights must sum to 1.0")

    assert(weights.advisory_only == true,
        "KER priority must be advisory_only")

    assert(weights.prevents_automatic_clear == true,
        "KER priority must not clear a FOG result")

    assert(weights.prohibits_individual_ranking == true,
        "individual ranking is prohibited")

    assert(weights.prohibits_community_ranking == true,
        "community ranking is prohibited")

    assert(weights.prohibits_resource_allocation == true,
        "resource allocation is prohibited")

    return true
end

function FogKerPriorityGate.validate_item(item)
    assert(type(item) == "table", "item must be a table")
    assert(type(item.queue_id) == "string" and #item.queue_id > 0,
        "queue_id is required")
    assert(item.human_review_required == true,
        "only human-review-required FOG items may be prioritized")

    finite_unit_interval(item.knowledge_factor, "knowledge_factor")
    finite_unit_interval(item.ecological_value, "ecological_value")
    finite_unit_interval(item.risk_factor, "risk_factor")
    finite_unit_interval(item.fog_uncertainty, "fog_uncertainty")

    assert(item.contains_personal_data ~= true,
        "priority items must not contain personal data")
    assert(item.contains_community_ranking_data ~= true,
        "priority items must not contain community-ranking data")
    assert(item.contains_resource_allocation_data ~= true,
        "priority items must not contain resource-allocation data")

    return true
end

return FogKerPriorityGate
