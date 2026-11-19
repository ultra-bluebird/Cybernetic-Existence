local M = {}
local VERSION = "1.0"

local function finite(x)
    return type(x) == "number" and x == x
        and x ~= math.huge and x ~= -math.huge
end

local function text(x, name)
    if type(x) ~= "string" or not x:match("%S") or #x > 4096 then
        error(name .. " must be non-empty text within 4096 bytes", 3)
    end
end

local function count(x, name)
    if not finite(x) or x < 0 or x % 1 ~= 0 or x > 1000000000 then
        error(name .. " must be a bounded non-negative integer", 3)
    end
end

local function dense_size(values)
    if type(values) ~= "table" then
        error("Provide a dense array", 3)
    end
    local n = 0
    for key in pairs(values) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            error("Invalid array index", 3)
        end
        n = n + 1
    end
    for i = 1, n do
        if values[i] == nil then error("Array contains a gap", 3) end
    end
    return n
end

function M.public_benefit_change(record)
    if type(record) ~= "table" then
        error("Provide a criterion record", 2)
    end
    for _, field in ipairs({
        "criterion", "criterion_revision", "domain",
        "unit", "scope", "comparability_evidence",
        "community_review_state", "limitations"
    }) do text(record[field], field) end

    if record.preferred_direction ~= "higher"
        and record.preferred_direction ~= "lower" then
        error("Declare higher or lower as the preferred direction", 2)
    end
    if record.baseline ~= nil and not finite(record.baseline) then
        error("Baseline must be finite or unavailable", 2)
    end
    if record.post ~= nil and not finite(record.post) then
        error("Post value must be finite or unavailable", 2)
    end

    local assessable = record.baseline ~= nil
        and record.post ~= nil
        and record.comparability_reviewed == true
    local delta = nil
    if assessable then
        delta = record.post - record.baseline
        if not finite(delta) then
            error("Change exceeds numeric range", 2)
        end
    end

    return {
        contract_version = VERSION,
        status = assessable
            and "descriptive_criterion_specific_change"
            or "change_not_assessable",
        criterion = record.criterion,
        criterion_revision = record.criterion_revision,
        domain = record.domain,
        unit = record.unit,
        baseline = record.baseline,
        post = record.post,
        raw_change = delta,
        preferred_direction = record.preferred_direction,
        community_review_state = record.community_review_state,
        limitations = record.limitations,
        causal_benefit_established = false,
        cross_domain_score = false,
        release_approved = false
    }
end

function M.contrast_variability(values, config)
    local n = dense_size(values)
    if type(config) ~= "table" then
        error("Provide a declared contrast configuration", 2)
    end
    for _, field in ipairs({
        "task_class", "stratum", "unit", "contrast_definition",
        "limitations", "unobserved_cases"
    }) do text(config[field], field) end
    count(config.unevaluable_count, "Unevaluable count")
    if not finite(config.negligible_band) or config.negligible_band < 0 then
        error("Declare a finite non-negative negligible band", 2)
    end

    local mean, m2 = 0, 0
    local minimum, maximum = nil, nil
    local below, negligible, above = 0, 0, 0

    for i = 1, n do
        local value = values[i]
        if not finite(value) then error("Contrasts must be finite", 2) end
        local difference = value - mean
        mean = mean + difference / i
        m2 = m2 + difference * (value - mean)
        if not finite(mean) or not finite(m2) then
            error("Contrast arithmetic exceeds numeric range", 2)
        end
        minimum = minimum == nil and value or math.min(minimum, value)
        maximum = maximum == nil and value or math.max(maximum, value)
        if value < -config.negligible_band then
            below = below + 1
        elseif value > config.negligible_band then
            above = above + 1
        else
            negligible = negligible + 1
        end
    end

    return {
        contract_version = VERSION,
        status = "observed_contrast_variability_not_causal_effect_variance",
        task_class = config.task_class,
        stratum = config.stratum,
        unit = config.unit,
        assessed_count = n,
        unevaluable_count = config.unevaluable_count,
        mean_contrast = n > 0 and mean or nil,
        sample_variance = n > 1 and math.max(0, m2 / (n - 1)) or nil,
        observed_minimum = minimum,
        observed_maximum = maximum,
        below_negligible_band = below,
        within_negligible_band = negligible,
        above_negligible_band = above,
        negligible_band = config.negligible_band,
        limitations = config.limitations,
        unobserved_cases = config.unobserved_cases,
        universal_gain_established = false,
        participant_ranking_authorized = false,
        release_approved = false
    }
end

function M.attribution_statement(record)
    if type(record) ~= "table" then
        error("Provide a structured attribution record", 2)
    end
    for _, field in ipairs({
        "design", "estimand", "allocation_evidence",
        "confounding_risk", "alternative_explanations",
        "missingness_policy", "protocol_changes", "limitations"
    }) do text(record[field], field) end

    local preregistration = {
        not_started = true, pending = true, registered = true,
        changed_after_registration = true
    }
    if not preregistration[record.preregistration_state] then
        error("Declare an accurate preregistration state", 2)
    end
    local claim_types = {
        descriptive = true,
        associational = true,
        causal_under_stated_assumptions = true
    }
    if not claim_types[record.claim_type] then
        error("Declare a supported claim type", 2)
    end
    if record.claim_type == "causal_under_stated_assumptions" then
        text(record.identification_assumptions, "Identification assumptions")
        text(record.authorized_analysis_review, "Analysis review reference")
    end

    return {
        contract_version = VERSION,
        status = "statement_complete_requires_evidence_review",
        declared_claim_type = record.claim_type,
        design = record.design,
        estimand = record.estimand,
        allocation_evidence = record.allocation_evidence,
        confounding_risk = record.confounding_risk,
        alternative_explanations = record.alternative_explanations,
        preregistration_state = record.preregistration_state,
        missingness_policy = record.missingness_policy,
        protocol_changes = record.protocol_changes,
        identification_assumptions = record.identification_assumptions,
        limitations = record.limitations,
        numerical_attribution_confidence = nil,
        causal_claim_independently_verified = false,
        external_action_authorized = false
    }
end

return M
