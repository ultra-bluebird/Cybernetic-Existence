-- Pure governance checks. No I/O, telemetry, publication, or external actions.
-- Input is already a privacy-reviewed, task-level governance record.
local M = {}
M.version = "1.0.0"

local function fail(field, message)
    error({
        code = "invalid_governance_record",
        field = field,
        message = message
    }, 0)
end

local function check(condition, field, message)
    if not condition then
        fail(field, message)
    end
end

local function plain(value, field)
    check(type(value) == "table" and getmetatable(value) == nil,
        field, "Expected a plain table.")
end

local function text(value, field)
    check(type(value) == "string"
        and value:match("%S")
        and value == value:match("^%s*(.-)%s*$"),
        field, "Expected trimmed, nonempty text.")
end

local function boolean(value, field)
    check(type(value) == "boolean", field, "Expected a boolean.")
end

local function count(value, field)
    check(type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
        and value >= 0
        and value % 1 == 0,
        field, "Expected a finite nonnegative integer.")
end

local function dense(value, field)
    plain(value, field)
    local n = 0
    for key in pairs(value) do
        check(type(key) == "number" and key >= 1 and key % 1 == 0,
            field, "Expected positive integer keys.")
        n = n + 1
    end
    for i = 1, n do
        check(rawget(value, i) ~= nil, field, "Array has a gap.")
    end
    return n
end

local function named_set(value, field)
    local n = dense(value, field)
    local set = {}
    for i = 1, n do
        local name = rawget(value, i)
        text(name, field)
        check(not set[name], field, "Duplicate semantic requirement name.")
        set[name] = true
    end
    return set, n
end

local function validate_arm(arm, field)
    plain(arm, field)
    text(arm.condition, field .. ".condition")
    local fields = {
        "initiated", "completed", "in_progress",
        "withdrawn", "lost", "unknown"
    }
    for _, name in ipairs(fields) do
        count(arm[name], field .. "." .. name)
    end
    check(
        arm.completed + arm.in_progress + arm.withdrawn
            + arm.lost + arm.unknown == arm.initiated,
        field, "Outcome categories must partition initiated episodes."
    )
end

function M.inventory(record)
    plain(record, "inventory")
    text(record.taxonomy_version, "taxonomy_version")
    text(record.evaluated_taxonomy_version, "evaluated_taxonomy_version")
    text(record.review_role, "review_role")

    for _, field in ipairs({
        "applicability_resolved", "taxonomy_reviewed",
        "omission_tests_passed", "scope_approved"
    }) do
        boolean(record[field], field)
    end

    local applicable, total =
        named_set(record.applicable, "applicable")
    local declared = named_set(record.declared, "declared")
    local covered, missing = 0, {}

    for name in pairs(applicable) do
        if declared[name] then
            covered = covered + 1
        else
            missing[#missing + 1] = name
        end
    end
    table.sort(missing)

    local causes = {}
    if total == 0 then
        causes[#causes + 1] = "applicable_inventory_empty"
    end
    if #missing > 0 then
        causes[#causes + 1] = "inventory_incomplete"
    end
    if record.taxonomy_version ~= record.evaluated_taxonomy_version then
        causes[#causes + 1] = "taxonomy_version_requires_reevaluation"
    end
    for _, field in ipairs({
        "applicability_resolved", "taxonomy_reviewed",
        "omission_tests_passed", "scope_approved"
    }) do
        if not record[field] then
            causes[#causes + 1] = field .. "_not_satisfied"
        end
    end

    return {
        admitted = #causes == 0,
        coverage_available = total > 0,
        covered = covered,
        applicable = total,
        coverage_ratio = total > 0 and covered / total or nil,
        taxonomy_version = record.taxonomy_version,
        missing = missing,
        causes = causes,
        review_role = record.review_role
    }
end

function M.explanation(record)
    plain(record, "explanation")
    text(record.protocol_version, "protocol_version")
    text(record.review_role, "review_role")
    local causes = {}

    for _, field in ipairs({
        "typed_causes_rendered", "next_actions_rendered",
        "raw_enums_hidden", "accessible_structure_reviewed",
        "comprehension_protocol_approved", "comprehension_gate_met"
    }) do
        boolean(record[field], field)
        if not record[field] then
            causes[#causes + 1] = field .. "_not_satisfied"
        end
    end

    return {
        admitted = #causes == 0,
        causes = causes,
        protocol_version = record.protocol_version,
        review_role = record.review_role
    }
end

function M.comparison(record)
    plain(record, "comparison")
    text(record.protocol_version, "protocol_version")
    text(record.review_role, "review_role")
    text(record.selection_mechanism, "selection_mechanism")
    text(record.comparison_type, "comparison_type")

    check(record.unit == "task_episode", "unit",
        "This protocol requires task-episode outcomes.")
    check(record.claim == "operational"
        or record.claim == "demographic_equity",
        "claim", "Unrecognized claim category.")

    for _, field in ipairs({
        "predeclared", "conditions_comparable",
        "selection_addressed", "repetition_addressed",
        "order_effects_addressed", "differences_explained",
        "privacy_gate_met"
    }) do
        boolean(record[field], field)
    end

    local n = dense(record.arms, "arms")
    check(n >= 2, "arms", "At least two comparison conditions are required.")
    local names = {}
    for i = 1, n do
        local arm = rawget(record.arms, i)
        validate_arm(arm, "arm")
        check(not names[arm.condition], "arm.condition",
            "Condition names must be unique.")
        names[arm.condition] = true
    end

    local reasons = {}
    for _, field in ipairs({
        "predeclared", "conditions_comparable",
        "selection_addressed", "repetition_addressed",
        "order_effects_addressed", "differences_explained"
    }) do
        if not record[field] then
            reasons[#reasons + 1] = field .. "_not_satisfied"
        end
    end

    local prohibited = record.claim == "demographic_equity"
        or not record.privacy_gate_met

    local override = record.exploratory_override
    if override ~= nil then
        plain(override, "exploratory_override")
        text(override.review_role, "exploratory_override.review_role")
        text(override.reason, "exploratory_override.reason")
    end

    local disposition
    if prohibited then
        disposition = "blocked"
    elseif #reasons == 0 then
        disposition = "operational_comparison_admissible"
    elseif override ~= nil then
        disposition = "exploratory_description_only"
    else
        disposition = "comparability_limited"
    end

    return {
        disposition = disposition,
        reasons = reasons,
        claim_supported_by_this_protocol = not prohibited
            and #reasons == 0,
        equity_claim_authorized = false,
        protocol_version = record.protocol_version,
        review_role = record.review_role,
        limitation = "Operational comparisons do not establish "
            .. "demographic or intersectional equity."
    }
end

return M
