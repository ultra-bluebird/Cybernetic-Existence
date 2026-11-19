local M = {}
local VERSION = "1.0"

local function finite(x)
    return type(x) == "number" and x == x
        and x ~= math.huge and x ~= -math.huge
end

local function count(x, name)
    if not finite(x) or x < 0 or x % 1 ~= 0 or x > 1000000000 then
        error(name .. " must be a bounded non-negative integer", 3)
    end
end

local function score(x, name)
    if not finite(x) or x < 0 or x > 1 then
        error(name .. " must be finite and within zero to one", 3)
    end
end

local function text(x, name)
    if type(x) ~= "string" or not x:match("%S") or #x > 4096 then
        error(name .. " must be non-empty text within 4096 bytes", 3)
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

local function fraction(a, b)
    if b == 0 then return nil end
    return a / b
end

local function summary(values)
    local n = #values
    if n == 0 then return {count = 0} end
    local copy, total = {}, 0
    for i, value in ipairs(values) do
        copy[i] = value
        total = total + value
    end
    table.sort(copy)
    local middle = math.floor(n / 2)
    local med = n % 2 == 1
        and copy[middle + 1]
        or (copy[middle] + copy[middle + 1]) / 2
    return {
        count = n,
        mean = total / n,
        median = med,
        minimum = copy[1],
        maximum = copy[n]
    }
end

local function coordination_period(p)
    if type(p) ~= "table" then error("Provide a period summary", 3) end
    for _, key in ipairs({
        "eligible", "applied", "closed_without_application",
        "pending", "unknown"
    }) do count(p[key], key) end
    if p.applied + p.closed_without_application
        + p.pending + p.unknown ~= p.eligible then
        error("Coordination states must partition eligible opportunities", 3)
    end
    return {
        eligible = p.eligible,
        applied = p.applied,
        closed_without_application = p.closed_without_application,
        pending = p.pending,
        unknown = p.unknown,
        application_coverage = fraction(p.applied, p.eligible),
        possible_coverage_upper_bound =
            fraction(p.applied + p.pending + p.unknown, p.eligible)
    }
end

function M.coordination_change(baseline, post, opportunity_definition)
    text(opportunity_definition, "Opportunity definition")
    local a = coordination_period(baseline)
    local b = coordination_period(post)
    local delta = nil
    if a.application_coverage ~= nil and b.application_coverage ~= nil then
        delta = b.application_coverage - a.application_coverage
    end
    return {
        contract_version = VERSION,
        status = "descriptive_coordination_change",
        opportunity_definition = opportunity_definition,
        baseline = a,
        post = b,
        coverage_change = delta,
        previously_unserved_cohort_followed = false,
        causal_effect_established = false,
        release_approved = false
    }
end

function M.learning_change(pairs, task_class, criterion_revision)
    text(task_class, "Task class")
    text(criterion_revision, "Criterion revision")
    local n = dense_size(pairs)
    local changes, retained, post_to_delayed = {}, {}, {}
    local skipped = 0
    local transitions = {
        newly_met = 0, maintained = 0,
        not_maintained = 0, neither_met = 0
    }

    for i = 1, n do
        local p = pairs[i]
        if type(p) ~= "table" then error("Provide a task pair", 2) end
        if p.task_class ~= task_class
            or p.criterion_revision ~= criterion_revision then
            error("Do not pool different task classes or criteria", 2)
        end
        for _, key in ipairs({
            "participant_approved", "equivalence_reviewed",
            "baseline_access_preserved", "experimental_assistance_absent"
        }) do
            if type(p[key]) ~= "boolean" then
                error("Declare every comparison safeguard", 2)
            end
        end

        if p.pre ~= nil then score(p.pre, "Pre score") end
        if p.post ~= nil then score(p.post, "Post score") end
        if p.delayed ~= nil then score(p.delayed, "Delayed score") end
        if p.delayed ~= nil then
            if not finite(p.delay_days) or p.delay_days < 7 then
                error("Delayed observations require a declared delay of seven days or more", 2)
            end
        end

        local eligible = p.participant_approved and p.equivalence_reviewed
            and p.baseline_access_preserved
            and p.experimental_assistance_absent

        if eligible and p.pre ~= nil and p.post ~= nil then
            changes[#changes + 1] = p.post - p.pre
            if (p.pre == 0 or p.pre == 1) and (p.post == 0 or p.post == 1) then
                local key = p.pre == 0 and p.post == 1 and "newly_met"
                    or p.pre == 1 and p.post == 1 and "maintained"
                    or p.pre == 1 and p.post == 0 and "not_maintained"
                    or "neither_met"
                transitions[key] = transitions[key] + 1
            end
            if p.delayed ~= nil then
                retained[#retained + 1] = p.delayed - p.pre
                post_to_delayed[#post_to_delayed + 1] = p.delayed - p.post
            end
        else
            skipped = skipped + 1
        end
    end

    return {
        contract_version = VERSION,
        status = "internal_paired_task_change_not_person_ranking",
        task_class = task_class,
        criterion_revision = criterion_revision,
        immediate_change = summary(changes),
        delayed_change_from_pre = summary(retained),
        post_to_delayed_change = summary(post_to_delayed),
        binary_transition_counts = transitions,
        unevaluable_pair_count = skipped,
        causal_effect_established = false,
        release_approved = false
    }
end

local function continuity_period(p)
    if type(p) ~= "table" then error("Provide a continuity summary", 3) end
    for _, key in ipairs({"eligible", "successful", "unsuccessful", "unknown"}) do
        count(p[key], key)
    end
    if p.successful + p.unsuccessful + p.unknown ~= p.eligible then
        error("Continuity outcomes must partition eligible opportunities", 3)
    end
    return {
        eligible = p.eligible,
        successful = p.successful,
        unsuccessful = p.unsuccessful,
        unknown = p.unknown,
        assessed_success_fraction =
            fraction(p.successful, p.successful + p.unsuccessful),
        success_coverage = fraction(p.successful, p.eligible)
    }
end

function M.continuity_change(baseline, post, criterion)
    text(criterion, "Continuity success criterion")
    local a = continuity_period(baseline)
    local b = continuity_period(post)
    local assessed_delta, coverage_delta = nil, nil
    if a.assessed_success_fraction ~= nil
        and b.assessed_success_fraction ~= nil then
        assessed_delta = b.assessed_success_fraction - a.assessed_success_fraction
    end
    if a.success_coverage ~= nil and b.success_coverage ~= nil then
        coverage_delta = b.success_coverage - a.success_coverage
    end
    return {
        contract_version = VERSION,
        status = "descriptive_continuity_change",
        criterion = criterion,
        baseline = a,
        post = b,
        assessed_success_change = assessed_delta,
        success_coverage_change = coverage_delta,
        interruption_injected = false,
        causal_effect_established = false,
        release_approved = false
    }
end

return M
