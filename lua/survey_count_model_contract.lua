local M = {}

local function text(value, name)
    if type(value) ~= "string" or not value:match("%S") or #value > 4096 then
        error(name .. " must be non-empty text within the limit", 3)
    end
end

local function integer(value, name, minimum)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value % 1 ~= 0 or value < minimum then
        error(name .. " must be an integer within the declared range", 3)
    end
end

local function text_array(values, name)
    if type(values) ~= "table" then
        error(name .. " must be a dense text array", 3)
    end
    local n = 0
    for key in pairs(values) do
        integer(key, name .. " index", 1)
        n = n + 1
    end
    local seen = {}
    for i = 1, n do
        text(values[i], name)
        if seen[values[i]] then
            error(name .. " must not contain duplicates", 3)
        end
        seen[values[i]] = true
    end
    return n
end

function M.validate_anchor(a)
    if type(a) ~= "table" then
        error("Provide an anchor specification", 2)
    end
    for _, field in ipairs({
        "question", "low_anchor", "middle_anchor",
        "high_anchor", "instrument_revision"
    }) do
        text(a[field], field)
    end
    if a.scale_min ~= 0 or a.scale_max ~= 10 then
        error("This instrument uses the declared zero-to-ten scale", 2)
    end
    if a.assessment_time == "current" then
        if a.recall_period_days ~= nil then
            error("Current capability does not use a retrospective recall period", 2)
        end
    elseif a.assessment_time == "retrospective" then
        integer(a.recall_period_days, "Recall period", 1)
    else
        error("Declare current or retrospective assessment", 2)
    end
    return {
        status = "structurally_valid_requires_comprehension_review",
        validated_scale = false,
        competence_inferred = false
    }
end

function M.validate_contact_count(record)
    if type(record) ~= "table" then
        error("Provide a contact-count record", 2)
    end
    local allowed = {
        period_bucket = true,
        recall_period_days = true,
        definition_revision = true,
        response_state = true,
        count = true
    }
    for key in pairs(record) do
        if not allowed[key] then
            error("Unexpected field; contact identities and content are excluded", 2)
        end
    end
    text(record.period_bucket, "Coarse period bucket")
    text(record.definition_revision, "Counting definition revision")
    integer(record.recall_period_days, "Recall period", 1)

    if record.response_state == "reported" then
        integer(record.count, "Meaningful-contact count", 0)
    elseif record.response_state == "recall_uncertain"
        or record.response_state == "declined"
        or record.response_state == "missing" then
        if record.count ~= nil then
            error("Non-reported responses cannot carry a count", 2)
        end
    else
        error("Unsupported contact-count response state", 2)
    end
    return {
        status = "participant_report_not_independent_verification",
        identity_required = false,
        zero_is_participant_failure = false
    }
end

function M.validate_model(plan)
    if type(plan) ~= "table" then
        error("Provide a model specification", 2)
    end
    for _, field in ipairs({
        "endpoint", "estimand", "missingness_policy",
        "diagnostic_plan", "sensitivity_plan", "plan_revision"
    }) do
        text(plan[field], field)
    end
    if text_array(plan.fixed_effects, "Fixed effects") == 0 then
        error("Declare fixed effects, including an intercept if intended", 2)
    end
    if text_array(plan.random_effects, "Random effects") == 0 then
        error("A mixed model requires a declared random-effects structure", 2)
    end

    if plan.outcome_type == "ordinal_rating" then
        if plan.family ~= "cumulative_logit"
            or plan.link ~= "logit"
            or plan.offset ~= "none" then
            error("Declare the baseline ordinal cumulative-logit model", 2)
        end
    elseif plan.outcome_type == "count" then
        if plan.link ~= "log" then
            error("The declared count models require a log link", 2)
        end
        if plan.family ~= "poisson" and plan.family ~= "negative_binomial_nb2" then
            error("Unsupported baseline count family", 2)
        end
        if plan.offset ~= "none" and plan.offset ~= "log_observed_days" then
            error("Declare no offset or a reviewed observed-days offset", 2)
        end
        if plan.offset == "log_observed_days" then
            text(plan.exposure_justification, "Exposure justification")
        end
    else
        error("Declare an ordinal-rating or count endpoint", 2)
    end

    return {
        status = "model_contract_complete_requires_statistical_review",
        model_fitted = false,
        assumptions_verified = false,
        preregistration_completed = false,
        causal_effect_established = false
    }
end

return M
