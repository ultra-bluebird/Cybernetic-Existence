local M = {}
local VERSION = "1.0"
local ORDER = {"opportunity", "capability", "coordination", "beneficiary"}

local function finite(x)
    return type(x) == "number" and x == x
        and x ~= math.huge and x ~= -math.huge
end

local function bounded(x, name)
    if not finite(x) or x < 0 or x > 1 then
        error(name .. " must be finite and within zero to one", 3)
    end
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

local function validate_factor(f)
    if type(f) ~= "table" then
        error("Provide a factor record", 3)
    end
    local allowed = {
        value = true, lower = true, upper = true,
        definition = true, normalization = true, evidence_basis = true
    }
    for key in pairs(f) do
        if not allowed[key] then error("Unexpected factor field", 3) end
    end
    text(f.definition, "Factor definition")
    text(f.normalization, "Normalization rule")
    text(f.evidence_basis, "Evidence basis")
    if f.value ~= nil then bounded(f.value, "Factor value") end
    if (f.lower == nil) ~= (f.upper == nil) then
        error("Supply both bounds or neither", 3)
    end
    if f.lower ~= nil then
        bounded(f.lower, "Lower bound")
        bounded(f.upper, "Upper bound")
        if f.lower > f.upper then error("Bounds are reversed", 3) end
        if f.value ~= nil
            and (f.value < f.lower or f.value > f.upper) then
            error("Point value falls outside declared bounds", 3)
        end
    end
end

function M.plan(factors)
    if type(factors) ~= "table" then
        error("Provide the four-factor registry", 2)
    end
    local allowed = {}
    for _, name in ipairs(ORDER) do allowed[name] = true end
    for key in pairs(factors) do
        if not allowed[key] then error("Unexpected planning factor", 2) end
    end

    local missing, snapshot = {}, {}
    local lower_product, upper_product = 1, 1
    local all_bounds = true

    for _, name in ipairs(ORDER) do
        local f = factors[name]
        validate_factor(f)
        snapshot[name] = {
            value = f.value, lower = f.lower, upper = f.upper,
            definition = f.definition, normalization = f.normalization,
            evidence_basis = f.evidence_basis
        }
        if f.value == nil then missing[#missing + 1] = name end
        if f.lower == nil then
            all_bounds = false
        else
            lower_product = lower_product * f.lower
            upper_product = upper_product * f.upper
        end
    end

    local result = {
        contract_version = VERSION,
        status = "planning_model_not_calibrated",
        factors = snapshot,
        unmeasured_factors = missing,
        product = nil,
        bounding_interval = all_bounds
            and {lower = lower_product, upper = upper_product} or nil,
        person_ranking_authorized = false,
        external_action_authorized = false
    }
    if #missing > 0 then
        result.status = "point_product_not_assessable"
        return result
    end

    local product, minimum = 1, math.huge
    for _, name in ipairs(ORDER) do
        product = product * factors[name].value
        minimum = math.min(minimum, factors[name].value)
    end

    local lowest, sensitivity = {}, {}
    for _, name in ipairs(ORDER) do
        if factors[name].value == minimum then lowest[#lowest + 1] = name end
        local derivative = 1
        for _, other in ipairs(ORDER) do
            if other ~= name then
                derivative = derivative * factors[other].value
            end
        end
        sensitivity[name] = derivative
    end

    local robust_lowest = nil
    if all_bounds then
        for _, name in ipairs(ORDER) do
            local strictly_lowest = true
            for _, other in ipairs(ORDER) do
                if other ~= name
                    and factors[name].upper >= factors[other].lower then
                    strictly_lowest = false
                end
            end
            if strictly_lowest then robust_lowest = name end
        end
    end

    result.product = product
    result.lowest_point_factors = lowest
    result.absolute_change_sensitivity = sensitivity
    result.uniquely_lowest_under_bounds = robust_lowest
    result.bottleneck_ordering_uncertain =
        all_bounds and robust_lowest == nil or not all_bounds
    return result
end

function M.access_leap(record)
    if type(record) ~= "table" then
        error("Provide a baseline-cohort summary", 2)
    end
    local allowed = {
        baseline_excluded = true, newly_possible = true,
        still_inaccessible = true, not_assessed = true,
        new_barriers_observed = true, previously_available_lost = true
    }
    for key in pairs(record) do
        if not allowed[key] then error("Unexpected access field", 2) end
    end
    for key in pairs(allowed) do count(record[key], key) end
    if record.newly_possible + record.still_inaccessible
        + record.not_assessed ~= record.baseline_excluded then
        error("Follow-up states must partition the fixed baseline cohort", 2)
    end

    local n = record.baseline_excluded
    return {
        contract_version = VERSION,
        status = n > 0
            and "descriptive_fixed_cohort_access_change"
            or "not_assessable_empty_baseline",
        baseline_excluded_opportunities = n,
        newly_possible = record.newly_possible,
        still_inaccessible = record.still_inaccessible,
        not_assessed = record.not_assessed,
        confirmed_fraction = n > 0 and record.newly_possible / n or nil,
        missing_assessment_upper_bound = n > 0
            and (record.newly_possible + record.not_assessed) / n or nil,
        new_barriers_observed = record.new_barriers_observed,
        previously_available_lost = record.previously_available_lost,
        causal_effect_established = false,
        participant_identity_required = false,
        release_approved = false
    }
end

return M
