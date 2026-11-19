-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and workstream metadata only.
-- No identity verification, consent, capability, or execution authority.
-- Pure research utilities: no network, file, device, or persistence access.
-- Inputs are not mutated. Returned records are mutable snapshots.

local M = {}

local MAX_ITEMS = 128
local MAX_TEXT = 128

local PRIORITY = {
    malformed_input = 1,
    known_false = 2,
    conflicting_constraints = 3,
    ambiguous_policy = 4,
    unknown_evidence = 5,
    not_applicable = 6,
    rights_satisfied = 7
}

local ROUTES = {
    evidence_gap = "evidence_steward",
    policy_ambiguity = "authorized_policy_interpreter",
    evidence_dispute = "independent_evidence_reviewer",
    stale_assertion = "policy_custodian",
    constraint_conflict = "conflict_resolution_authority",
    malformed_input = "integration_maintainer"
}

local function finite(x)
    assert(type(x) == "number"
        and x == x
        and x ~= math.huge
        and x ~= -math.huge, "finite number required")
    return x
end

local function nonnegative(x)
    finite(x)
    assert(x >= 0, "nonnegative number required")
    return x
end

local function text(x)
    assert(type(x) == "string"
        and #x > 0
        and #x <= MAX_TEXT
        and x:match("%S")
        and not x:find("[%z\1-\31\127]"),
        "bounded nonempty text required")
    return x
end

local function length(array)
    assert(type(array) == "table"
        and getmetatable(array) == nil, "plain array required")

    local count, maximum = 0, 0
    for key in next, array do
        count = count + 1
        assert(count <= MAX_ITEMS
            and type(key) == "number"
            and key >= 1
            and key <= MAX_ITEMS
            and key % 1 == 0, "invalid array")
        maximum = math.max(maximum, key)
    end
    assert(count == maximum, "array gaps prohibited")
    return count
end

function M.merge_findings(left, right)
    local seen, result = {}, {}

    local function append(array)
        local n = length(array)
        for i = 1, n do
            local outcome = array[i]
            assert(PRIORITY[outcome], "unrecognized outcome")
            if not seen[outcome] then
                seen[outcome] = true
                result[#result + 1] = outcome
            end
        end
    end

    append(left)
    append(right)

    table.sort(result, function(a, b)
        return PRIORITY[a] < PRIORITY[b]
    end)

    return {
        findings = result,
        primary = result[1],
        assessed = #result > 0,
        automatic_execution_authorized = false
    }
end

function M.review_obligations(issues, intake_time, response_budget)
    nonnegative(intake_time)
    nonnegative(response_budget)
    assert(response_budget > 0, "positive response budget required")

    local deadline = finite(intake_time + response_budget)
    local n = length(issues)
    local seen, result = {}, {}

    for i = 1, n do
        local issue = issues[i]
        assert(type(issue) == "string" and ROUTES[issue],
            "unrecognized issue class")

        if not seen[issue] then
            seen[issue] = true
            result[#result + 1] = {
                issue_class = issue,
                resolver_role = ROUTES[issue],
                response_deadline = deadline,
                accessible_intake_required = true,
                minimized_evidence_required = true,
                continuity_check_required = true,
                assigned_person_confirmed = false,
                automatic_execution_authorized = false
            }
        end
    end

    table.sort(result, function(a, b)
        return a.issue_class < b.issue_class
    end)

    return result
end

function M.interval(now, issued_at, expires_at)
    nonnegative(now)
    nonnegative(issued_at)
    nonnegative(expires_at)
    assert(issued_at < expires_at, "nonempty interval required")

    local current = issued_at <= now and now < expires_at

    return {
        current = current,
        not_yet_active = now < issued_at,
        expired = now >= expires_at,
        activation_wait = math.max(0, issued_at - now),
        expired_age = math.max(0, now - expires_at),
        remaining_lifetime =
            current and (expires_at - now) or nil,
        semantic_compatibility_established = false
    }
end

function M.deadline(now, intake_time, response_budget, responded_at)
    nonnegative(now)
    nonnegative(intake_time)
    nonnegative(response_budget)
    assert(now >= intake_time, "now precedes intake")
    assert(response_budget > 0, "positive response budget required")

    local due = finite(intake_time + response_budget)

    if responded_at ~= nil then
        nonnegative(responded_at)
        assert(responded_at >= intake_time
            and responded_at <= now, "invalid response time")
    end

    local overdue = responded_at == nil and now > due
    local late_response =
        responded_at ~= nil and responded_at > due

    return {
        response_deadline = due,
        elapsed = now - intake_time,
        overdue_unresolved = overdue,
        response_was_late = late_response,
        escalation_required = overdue or late_response,
        continuity_check_required = overdue or late_response,
        operation_authorization_changed = false,
        participant_standing_changed = false,
        remedy_completion_verified = false
    }
end

function M.wilson(successes, total, z)
    nonnegative(successes)
    nonnegative(total)
    nonnegative(z)

    assert(successes % 1 == 0
        and total % 1 == 0
        and total <= 1000000000
        and successes <= total, "invalid counts")
    assert(z > 0 and z <= 10, "z outside supported range")

    if total == 0 then
        return {
            status = "not_applicable",
            count = 0
        }
    end

    local p = successes / total
    local z2 = z * z
    local denominator = 1 + z2 / total
    local center = (p + z2 / (2 * total)) / denominator
    local half = z / denominator * math.sqrt(
        p * (1 - p) / total + z2 / (4 * total * total)
    )

    return {
        status = "computed_under_declared_binomial_model",
        count = total,
        proportion = p,
        lower = math.max(0, center - half),
        upper = math.min(1, center + half),
        sampling_assumptions_verified = false,
        effectiveness_predicate_verified = false
    }
end

function M.self_test()
    local checks = 0
    local function expect(condition)
        assert(condition, "acceptance test failed")
        checks = checks + 1
    end

    local merged = M.merge_findings(
        {"unknown_evidence", "known_false"},
        {"ambiguous_policy", "unknown_evidence"}
    )
    expect(#merged.findings == 3)
    expect(merged.primary == "known_false")

    local same = M.merge_findings(merged.findings, merged.findings)
    expect(#same.findings == #merged.findings)

    local routes = M.review_obligations(
        {"evidence_gap", "policy_ambiguity", "evidence_gap"}, 10, 20
    )
    expect(#routes == 2)
    expect(routes[1].resolver_role ~= routes[2].resolver_role)

    expect(M.interval(10, 10, 20).current)
    expect(not M.interval(20, 10, 20).current)
    expect(M.interval(20, 10, 20).expired)

    local missed = M.deadline(31, 10, 20, nil)
    expect(missed.escalation_required)
    expect(not missed.operation_authorization_changed)
    expect(not missed.participant_standing_changed)

    local w = M.wilson(0, 10, 1.959963984540054)
    expect(w.lower == 0)
    expect(w.upper > 0 and w.upper < 1)

    expect(M.wilson(0, 0, 1.959963984540054).status
        == "not_applicable")

    local accepted = pcall(function()
        M.wilson(11, 10, 1.959963984540054)
    end)
    expect(not accepted)

    return {
        status = "passed",
        checks = checks,
        scope = "embedded synthetic utility tests",
        formal_proof = false
    }
end

return M
