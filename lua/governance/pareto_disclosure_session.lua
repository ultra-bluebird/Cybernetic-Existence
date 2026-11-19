-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit and workstream metadata only.
-- No verified identity, consent, capability authority, or execution evidence.
--
-- Research-only, process-local session.
-- No network, file, device, cryptography, or persistence operations.
--
-- Bootstrap must keep the authority interface separate from the planner.
-- Opaque handles are local capabilities, not signed portable tokens.
-- Lua 5.1+.

local M = {}

local DIMENSIONS = {
    "identity", "health", "location", "linkability", "inner_state"
}

local SCHEMA = {
    sensitivity = {"ordinary", "sensitive", "unknown"},
    effect = {
        "requested_assistance", "adverse_decision",
        "coercive_manipulation", "unknown"
    },
    permission = {"granted", "absent", "unknown"},
    evidence = {"adequate", "inadequate", "unknown"}
}

local MAX_ITEMS = 128
local MAX_INTEGER = 1000000000
local MAX_TIME = 1000000000000

local function plain(value)
    assert(type(value) == "table"
        and getmetatable(value) == nil, "plain table required")
end

local function text(value)
    assert(type(value) == "string"
        and #value > 0 and #value <= 128
        and value:match("%S")
        and not value:find("[%z\1-\31\127]"),
        "bounded text required")
    return value
end

local function integer(value, maximum)
    assert(type(value) == "number"
        and value == value
        and value >= 0 and value <= maximum
        and value % 1 == 0, "bounded integer required")
    return value
end

local function array_length(value)
    plain(value)
    local count, maximum = 0, 0

    for key in next, value do
        count = count + 1
        assert(count <= MAX_ITEMS
            and type(key) == "number"
            and key >= 1 and key <= MAX_ITEMS
            and key % 1 == 0, "invalid array")
        maximum = math.max(maximum, key)
    end

    assert(count == maximum, "array gaps prohibited")
    return count
end

local function member(value, choices)
    for i = 1, #choices do
        if value == choices[i] then
            return true
        end
    end
    return false
end

local function vector(value)
    plain(value)
    local result, count = {}, 0

    for key in next, value do
        count = count + 1
        assert(member(key, DIMENSIONS), "unknown vector dimension")
    end
    assert(count == #DIMENSIONS, "complete vector required")

    for i = 1, #DIMENSIONS do
        local key = DIMENSIONS[i]
        result[key] = integer(value[key], MAX_INTEGER)
    end
    return result
end

local function copy_vector(value)
    local result = {}
    for i = 1, #DIMENSIONS do
        local key = DIMENSIONS[i]
        result[key] = value[key]
    end
    return result
end

local function dominates(left, right)
    local strictly_less = false

    for i = 1, #DIMENSIONS do
        local key = DIMENSIONS[i]
        if left[key] > right[key] then
            return false
        end
        if left[key] < right[key] then
            strictly_less = true
        end
    end

    return strictly_less
end

local function validate_inference(spec)
    plain(spec)
    local result = {}

    for field, choices in next, SCHEMA do
        assert(member(spec[field], choices), "invalid inference enum")
        result[field] = spec[field]
    end

    for key in next, spec do
        assert(SCHEMA[key], "unknown inference field")
    end

    return result
end

local function classify(spec)
    local prohibited =
        spec.effect == "coercive_manipulation"
        or (spec.sensitivity == "sensitive"
            and spec.effect == "adverse_decision")
        or spec.permission == "absent"

    if prohibited then
        return "prohibited"
    end

    local policy_clear =
        spec.sensitivity ~= "unknown"
        and spec.effect == "requested_assistance"
        and spec.permission == "granted"

    if not policy_clear then
        return "review_required"
    end

    if spec.evidence ~= "adequate" then
        return "evidence_gate_unresolved"
    end

    return "eligible_for_planning"
end

local function protect(fn)
    local ok, result = pcall(fn)
    if ok then
        return result
    end
    return {status = "malformed_input"}
end

function M.conformance_corpus()
    local rows = {}

    for _, sensitivity in ipairs(SCHEMA.sensitivity) do
        for _, effect in ipairs(SCHEMA.effect) do
            for _, permission in ipairs(SCHEMA.permission) do
                for _, evidence in ipairs(SCHEMA.evidence) do
                    local spec = {
                        sensitivity = sensitivity,
                        effect = effect,
                        permission = permission,
                        evidence = evidence
                    }

                    -- Independent tabular oracle; not a classifier call.
                    local expected
                    if effect == "coercive_manipulation"
                        or permission == "absent"
                        or (sensitivity == "sensitive"
                            and effect == "adverse_decision") then
                        expected = "prohibited"
                    elseif sensitivity == "unknown"
                        or effect ~= "requested_assistance"
                        or permission ~= "granted" then
                        expected = "review_required"
                    elseif evidence ~= "adequate" then
                        expected = "evidence_gate_unresolved"
                    else
                        expected = "eligible_for_planning"
                    end

                    rows[#rows + 1] = {
                        input = spec,
                        expected = expected
                    }
                end
            end
        end
    end

    return rows
end

function M.new(config)
    plain(config)
    local coalition = text(config.coalition)
    local policy_version = text(config.policy_version)
    local declared_by = text(config.history_declared_by)
    local exposure = vector(config.initial_exposure)
    local ceiling = vector(config.ceiling)

    plain(config.workflow)
    local workflow = {
        owner = text(config.workflow.owner),
        deadline = integer(config.workflow.deadline, MAX_TIME),
        confirmations = {}
    }

    local version = 0
    local assessments = {}
    local tickets = {}
    local receipts = {}
    local issued = 0
    local plans = 0
    local last_time = 0

    local authority, planner, reviewer = {}, {}, {}

    local function clock(now)
        integer(now, MAX_TIME)
        assert(now >= last_time, "regressed session clock")
        last_time = now
        return now
    end

    function authority.issue(spec)
        return protect(function()
            plain(spec)
            assert(issued < MAX_ITEMS, "assessment quota exceeded")
            assert(spec.coalition == coalition, "coalition mismatch")
            assert(spec.policy_version == policy_version,
                "policy mismatch")
            assert(spec.version == version, "stale assessment")

            local record = {
                label = text(spec.label),
                version = version,
                inference = validate_inference(spec.inference),
                contribution = vector(spec.contribution),
                adequacy = spec.adequacy,
                authorization = spec.authorization
            }

            assert(member(record.adequacy,
                {"adequate", "inadequate", "unknown"}), "invalid adequacy")
            assert(member(record.authorization,
                {"granted", "absent", "unknown"}), "invalid authorization")

            local handle = {}
            assessments[handle] = record
            issued = issued + 1

            return {status = "assessment_issued", handle = handle}
        end)
    end

    function planner.plan(handles, expected_version, now)
        return protect(function()
            clock(now)
            integer(expected_version, MAX_INTEGER)

            if expected_version ~= version then
                return {status = "stale_version"}
            end
            if now > workflow.deadline then
                return {status = "workflow_deadline_breached"}
            end

            assert(plans < MAX_ITEMS, "plan quota exceeded")
            local n = array_length(handles)
            local eligible, labels = {}, {}

            for i = 1, n do
                local record = assessments[handles[i]]
                assert(record, "authority-issued assessment required")
                assert(not labels[record.label], "duplicate candidate label")
                labels[record.label] = true

                if record.version ~= version then
                    return {status = "stale_assessment"}
                end

                local fits = true
                for j = 1, #DIMENSIONS do
                    local key = DIMENSIONS[j]
                    if record.contribution[key]
                        > ceiling[key] - exposure[key] then
                        fits = false
                    end
                end

                if classify(record.inference) == "eligible_for_planning"
                    and record.adequacy == "adequate"
                    and record.authorization == "granted"
                    and fits then
                    eligible[#eligible + 1] = record
                end
            end

            local front = {}
            for i = 1, #eligible do
                local dominated = false
                for j = 1, #eligible do
                    if i ~= j and dominates(
                        eligible[j].contribution,
                        eligible[i].contribution
                    ) then
                        dominated = true
                        break
                    end
                end
                if not dominated then
                    front[#front + 1] = eligible[i]
                end
            end

            table.sort(front, function(a, b)
                return a.label < b.label
            end)

            local ticket = {}
            tickets[ticket] = {
                version = version,
                front = front,
                consumed = false
            }
            plans = plans + 1

            local names = {}
            for i = 1, #front do
                names[i] = front[i].label
            end

            return {
                status = #front == 0 and "supported_workflow_required"
                    or (#front == 1 and "single_pareto_candidate"
                    or "selection_policy_required"),
                ticket = ticket,
                version = version,
                candidates = names,
                workflow_owner = workflow.owner,
                workflow_deadline = workflow.deadline
            }
        end)
    end

    function authority.account_selection(ticket, label, selection_policy, now)
        return protect(function()
            clock(now)
            text(label)
            text(selection_policy)

            local plan = tickets[ticket]
            assert(plan, "unknown plan")
            if plan.consumed or plan.version ~= version then
                return {status = "stale_or_consumed_plan"}
            end
            if now > workflow.deadline then
                return {status = "workflow_deadline_breached"}
            end

            local chosen
            for i = 1, #plan.front do
                if plan.front[i].label == label then
                    chosen = plan.front[i]
                end
            end
            assert(chosen, "selection must belong to Pareto front")

            for i = 1, #DIMENSIONS do
                local key = DIMENSIONS[i]
                exposure[key] = exposure[key] + chosen.contribution[key]
            end

            version = version + 1
            plan.consumed = true

            local receipt = {}
            receipts[receipt] = {
                version = version,
                candidate = label,
                selection_policy = selection_policy
            }

            return {
                status = "exposure_accounted_before_release",
                receipt = receipt,
                version = version
            }
        end)
    end

    function authority.confirm_workflow(record, now)
        return protect(function()
            clock(now)
            plain(record)
            assert(#workflow.confirmations < MAX_ITEMS,
                "confirmation quota exceeded")

            local stored = {
                actor = text(record.actor),
                outcome = text(record.outcome),
                evidence_reference = text(record.evidence_reference),
                time = now
            }

            workflow.confirmations[#workflow.confirmations + 1] = stored
            return {status = "confirmation_recorded"}
        end)
    end

    function reviewer.inspect()
        return {
            version = version,
            coalition = coalition,
            policy_version = policy_version,
            unit = "integer_exposure_accounting_units",
            exposure = copy_vector(exposure),
            history_declaration = {
                declared_by = declared_by,
                declaration_version = 0,
                coverage = "initial declaration plus this session's accounting",
                completeness_independently_verified = false
            },
            workflow_owner = workflow.owner,
            workflow_deadline = workflow.deadline,
            confirmation_count = #workflow.confirmations,
            accounting_semantics = "conservative_no_subtraction"
        }
    end

    return authority, planner, reviewer
end

function M.self_test()
    local checks = 0
    local function expect(value)
        assert(value, "conformance test failed")
        checks = checks + 1
    end

    local corpus = M.conformance_corpus()
    expect(#corpus == 108)
    for i = 1, #corpus do
        expect(classify(corpus[i].input) == corpus[i].expected)
    end

    local function v(a, b)
        return {
            identity = a, health = b, location = 0,
            linkability = 0, inner_state = 0
        }
    end

    local authority, planner, reviewer = M.new({
        coalition = "synthetic_review_coalition",
        policy_version = "research-1",
        history_declared_by = "synthetic_history_steward",
        initial_exposure = v(0, 0),
        ceiling = v(10, 10),
        workflow = {owner = "synthetic_review_owner", deadline = 100}
    })

    local function issue(label, contribution)
        return authority.issue({
            label = label,
            coalition = "synthetic_review_coalition",
            policy_version = "research-1",
            version = 0,
            contribution = contribution,
            adequacy = "adequate",
            authorization = "granted",
            inference = {
                sensitivity = "sensitive",
                effect = "requested_assistance",
                permission = "granted",
                evidence = "adequate"
            }
        }).handle
    end

    local a = issue("option_a", v(1, 3))
    local b = issue("option_b", v(3, 1))
    local c = issue("option_c", v(4, 4))

    local plan = planner.plan({a, b, c}, 0, 10)
    expect(plan.status == "selection_policy_required")
    expect(#plan.candidates == 2)

    local accounted = authority.account_selection(
        plan.ticket, "option_a", "explicit-choice-policy-1", 11
    )
    expect(accounted.status == "exposure_accounted_before_release")
    expect(planner.plan({b}, 0, 12).status == "stale_version")
    expect(reviewer.inspect().exposure.health == 3)
    expect(planner.plan({{}}, 1, 13).status == "malformed_input")

    return {
        status = "passed",
        checks = checks,
        scope = "generated enum cases and synthetic session checks",
        formal_proof = false
    }
end

return M
