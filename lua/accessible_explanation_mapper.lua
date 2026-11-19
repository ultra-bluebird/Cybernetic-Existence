local M = {}

local FALLBACK = {
    code = "GENERIC_SERVICE_EXPLANATION",
    text = "This service needs review before it can continue. You can ask for help, an accessible explanation, or a review of the decision.",
    reading_level = "plain_language",
}

local EXPLANATIONS = {
    COOLING_CENTER_SUPPLY_SHORTFALL = {
        code = "COOLING_CENTER_SUPPLY_SHORTFALL",
        text = "The cooling center does not have enough cooling right now. Staff must review the problem and provide the safest available alternative.",
        reading_level = "plain_language",
    },

    FLEXIBLE_WORKLOAD_MUST_NOT_INTERRUPT_COOLING_CENTER_SUPPLY = {
        code = "FLEXIBLE_WORKLOAD_MUST_NOT_INTERRUPT_COOLING_CENTER_SUPPLY",
        text = "A flexible computer task cannot reduce cooling-center service. The cooling center must be protected first.",
        reading_level = "plain_language",
    },

    PUBLIC_RESERVE_ALLOCATION_APPROVED = {
        code = "PUBLIC_RESERVE_ALLOCATION_APPROVED",
        text = "Your public-interest computing request was approved. The service will provide the next access details.",
        reading_level = "plain_language",
    },

    ACCESS_DEADLINE_MISSED_HUMAN_REMEDY_REQUIRED = {
        code = "ACCESS_DEADLINE_MISSED_HUMAN_REMEDY_REQUIRED",
        text = "Your request has waited too long. A person must review the delay and provide a next step.",
        reading_level = "plain_language",
    },

    ECO_BENEFIT_ADDITIONALITY_NOT_DEMONSTRATED = {
        code = "ECO_BENEFIT_ADDITIONALITY_NOT_DEMONSTRATED",
        text = "The available measurements do not yet show that this project created an environmental benefit beyond what would have happened anyway.",
        reading_level = "plain_language",
    },
}

function M.explain(explanation_code)
    if type(explanation_code) ~= "string" or explanation_code == "" then
        return FALLBACK
    end

    return EXPLANATIONS[explanation_code] or FALLBACK
end

return M
