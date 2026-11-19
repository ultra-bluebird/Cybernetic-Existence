-- SOVEREIGN-ATTRIBUTION
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Attribution is credit and workstream metadata only.
-- No verified identity, consent, capability, execution evidence,
-- or authority over another person or system is established.
--
-- Research kernel: no network, file, hardware, or persistence operations.
-- Inputs are not mutated or retained. Returned tables are caller-owned,
-- mutable snapshots, not immutable authorization tokens.
-- Compatible with Lua 5.1+.

local M = {}

local LIMIT = {
    clauses = 128,
    conflicts = 32,
    members = 32,
    text_bytes = 256
}

local ALLOWED = {
    applicability = {
        applicable = true,
        not_applicable = true,
        unknown = true
    },
    interpretation = {
        settled = true,
        ambiguous = true
    },
    evidence = {
        supported = true,
        unknown = true,
        disputed = true
    },
    conclusion = {
        satisfied = true,
        violated = true,
        unknown = true
    }
}

local ROOT_FIELDS = {
    operation_label = true,
    scope = true,
    clauses = true,
    conflicts = true
}

local CLAUSE_FIELDS = {
    name = true,
    policy_version = true,
    scope = true,
    owner = true,
    provenance = true,
    reviewed_by = true,
    issued_at = true,
    expires_at = true,
    applicability = true,
    interpretation = true,
    evidence = true,
    conclusion = true
}

local CONFLICT_FIELDS = {
    name = true,
    declared_by = true,
    provenance = true,
    members = true
}

local FORBIDDEN_USE = {
    participant_eligibility = true,
    participant_credibility = true,
    participant_dangerousness = true,
    identity_verification = true,
    automatic_execution_authorization = true
}

local PERMITTED_USE = {
    operation_review_routing = true,
    operation_explanation = true,
    redacted_operation_audit = true
}

local function invalid()
    error("invalid_policy_input", 0)
end

local function plain_table(value)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        invalid()
    end
end

local function text(value)
    if type(value) ~= "string"
        or #value == 0
        or #value > LIMIT.text_bytes
        or not value:match("%S")
        or value:find("[%z\1-\31\127]") then
        invalid()
    end
end

local function integer(value)
    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge
        or value < 0
        or value > 9007199254740991
        or value % 1 ~= 0 then
        invalid()
    end
end

local function fields(record, allowed, maximum)
    plain_table(record)
    local count = 0

    for key in next, record do
        count = count + 1
        if count > maximum
            or type(key) ~= "string"
            or not allowed[key] then
            invalid()
        end
    end
end

local function array_length(value, maximum)
    plain_table(value)

    local count = 0
    local largest = 0

    for key in next, value do
        count = count + 1
        if count > maximum
            or type(key) ~= "number"
            or key ~= key
            or key < 1
            or key > maximum
            or key % 1 ~= 0 then
            invalid()
        end

        if key > largest then
            largest = key
        end
    end

    if largest ~= count then
        invalid()
    end

    return count
end

local function enum(value, choices)
    if type(value) ~= "string" or not choices[value] then
        invalid()
    end
end

local function validate(policy, now)
    integer(now)
    fields(policy, ROOT_FIELDS, 4)
    text(policy.operation_label)
    text(policy.scope)

    local count = array_length(policy.clauses, LIMIT.clauses)
    if count == 0 then
        invalid()
    end

    local names = {}

    for index = 1, count do
        local clause = policy.clauses[index]
        fields(clause, CLAUSE_FIELDS, 13)

        text(clause.name)
        text(clause.policy_version)
        text(clause.scope)
        text(clause.owner)
        text(clause.provenance)
        text(clause.reviewed_by)

        if names[clause.name] or clause.scope ~= policy.scope then
            invalid()
        end
        names[clause.name] = true

        integer(clause.issued_at)
        integer(clause.expires_at)
        if clause.expires_at <= clause.issued_at then
            invalid()
        end

        enum(clause.applicability, ALLOWED.applicability)
        enum(clause.interpretation, ALLOWED.interpretation)
        enum(clause.evidence, ALLOWED.evidence)
        enum(clause.conclusion, ALLOWED.conclusion)
    end

    local conflict_count =
        array_length(policy.conflicts, LIMIT.conflicts)
    local conflict_names = {}

    for index = 1, conflict_count do
        local conflict = policy.conflicts[index]
        fields(conflict, CONFLICT_FIELDS, 4)
        text(conflict.name)
        text(conflict.declared_by)
        text(conflict.provenance)

        if conflict_names[conflict.name] then
            invalid()
        end
        conflict_names[conflict.name] = true

        local member_count =
            array_length(conflict.members, LIMIT.members)
        if member_count < 2 then
            invalid()
        end

        local seen = {}
        for member_index = 1, member_count do
            local member = conflict.members[member_index]
            text(member)
            if not names[member] or seen[member] then
                invalid()
            end
            seen[member] = true
        end
    end
end

local function snapshot()
    return {
        tag = "operation_assessment",
        contract_version = "1.0.0",
        primary = nil,
        findings = {},
        rights_gate_passed = false,
        automatic_execution_authorized = false,
        person_level_scoring_prohibited = true,
        formal_proof_claimed = false,
        legal_validation_claimed = false,
        empirical_fairness_proven = false,
        essential_access_verified = false,
        provenance_authenticity_verified = false,
        review_delivery_verified = false
    }
end

function M.evaluate(policy, now)
    local output = snapshot()
    local valid = pcall(validate, policy, now)

    if not valid then
        output.primary = "malformed_input"
        output.findings[1] = {
            tag = "malformed_input",
            explanation = "Input rejected; no participant inference allowed."
        }
        return output
    end

    local flags = {
        known_false = false,
        conflicting_constraints = false,
        ambiguous_policy = false,
        unknown_evidence = false
    }

    local applicable_count = 0
    local all_inapplicable = true

    local function finding(tag, name, reason)
        output.findings[#output.findings + 1] = {
            tag = tag,
            clause_name = name,
            reason = reason
        }
    end

    for index = 1, #policy.clauses do
        local clause = policy.clauses[index]
        local current =
            clause.issued_at <= now and now < clause.expires_at

        if clause.applicability ~= "not_applicable" then
            all_inapplicable = false
        end

        if not current then
            flags.unknown_evidence = true
            finding("unknown_evidence", clause.name,
                "Policy assertion is not current.")
        end

        if clause.applicability == "unknown"
            or clause.interpretation == "ambiguous" then
            flags.ambiguous_policy = true
            finding("ambiguous_policy", clause.name,
                "Applicability or interpretation is unresolved.")
        end

        if clause.applicability == "not_applicable" then
            finding("not_applicable", clause.name,
                "Explicitly asserted inapplicable; not a permission grant.")
        elseif clause.applicability == "applicable" then
            applicable_count = applicable_count + 1

            if clause.evidence ~= "supported"
                or clause.conclusion == "unknown" then
                flags.unknown_evidence = true
                finding("unknown_evidence", clause.name,
                    "Evidence or substantive conclusion is unresolved.")
            end

            if current
                and clause.interpretation == "settled"
                and clause.evidence == "supported"
                and clause.conclusion == "violated" then
                flags.known_false = true
                finding("known_false", clause.name,
                    "Current settled supported violation is asserted.")
            end
        end
    end

    for index = 1, #policy.conflicts do
        flags.conflicting_constraints = true
        finding("conflicting_constraints", policy.conflicts[index].name,
            "Declared conflict requires review; not proved by this kernel.")
    end

    if flags.known_false then
        output.primary = "known_false"
    elseif flags.conflicting_constraints then
        output.primary = "conflicting_constraints"
    elseif flags.ambiguous_policy then
        output.primary = "ambiguous_policy"
    elseif flags.unknown_evidence then
        output.primary = "unknown_evidence"
    elseif all_inapplicable then
        output.primary = "not_applicable"
    elseif applicable_count > 0 then
        output.primary = "rights_satisfied"
        output.rights_gate_passed = true
    else
        output.primary = "unknown_evidence"
    end

    table.sort(output.findings, function(left, right)
        if left.tag ~= right.tag then
            return left.tag < right.tag
        end
        if left.clause_name ~= right.clause_name then
            return left.clause_name < right.clause_name
        end
        return left.reason < right.reason
    end)

    return output
end

function M.check_downstream_use(use)
    if type(use) ~= "string" then
        return false, "invalid_use"
    end

    if FORBIDDEN_USE[use] then
        return false, "prohibited_downstream_use"
    end

    if PERMITTED_USE[use] then
        return true, "permitted_contract_use"
    end

    return false, "unrecognized_use_requires_review"
end

function M.self_test()
    local checks = 0

    local function expect(condition)
        assert(condition, "kernel acceptance test failed")
        checks = checks + 1
    end

    local function policy()
        return {
            operation_label = "synthetic_summary_operation",
            scope = "synthetic_research",
            clauses = {{
                name = "purpose_limitation",
                policy_version = "research-1",
                scope = "synthetic_research",
                owner = "synthetic_policy_steward",
                provenance = "synthetic_fixture_not_real_evidence",
                reviewed_by = "synthetic_reviewer",
                issued_at = 10,
                expires_at = 100,
                applicability = "applicable",
                interpretation = "settled",
                evidence = "supported",
                conclusion = "satisfied"
            }},
            conflicts = {}
        }
    end

    local p = policy()
    local result = M.evaluate(p, 50)
    expect(result.primary == "rights_satisfied")
    expect(not result.automatic_execution_authorized)

    p = policy()
    p.clauses[1].conclusion = "violated"
    expect(M.evaluate(p, 50).primary == "known_false")

    p.clauses[1].evidence = "disputed"
    expect(M.evaluate(p, 50).primary == "unknown_evidence")

    p = policy()
    p.clauses[1].conclusion = "violated"
    expect(M.evaluate(p, 100).primary == "unknown_evidence")

    p = policy()
    p.clauses[1].applicability = "unknown"
    expect(M.evaluate(p, 50).primary == "ambiguous_policy")

    p = policy()
    p.clauses[1].applicability = "not_applicable"
    result = M.evaluate(p, 50)
    expect(result.primary == "not_applicable")
    expect(not result.rights_gate_passed)

    p = policy()
    p.clauses[2] = {}
    expect(M.evaluate(p, 50).primary == "malformed_input")

    p = policy()
    p.clauses[2] = p.clauses[1]
    expect(M.evaluate(p, 50).primary == "malformed_input")

    p = policy()
    setmetatable(p, {})
    expect(M.evaluate(p, 50).primary == "malformed_input")

    local permitted = M.check_downstream_use("participant_eligibility")
    expect(not permitted)

    permitted = M.check_downstream_use("operation_review_routing")
    expect(permitted)

    p = policy()
    for _, applicability in ipairs({
        "applicable", "not_applicable", "unknown"
    }) do
        for _, interpretation in ipairs({"settled", "ambiguous"}) do
            for _, evidence in ipairs({
                "supported", "unknown", "disputed"
            }) do
                for _, conclusion in ipairs({
                    "satisfied", "violated", "unknown"
                }) do
                    local clause = p.clauses[1]
                    clause.applicability = applicability
                    clause.interpretation = interpretation
                    clause.evidence = evidence
                    clause.conclusion = conclusion
                    result = M.evaluate(p, 50)

                    expect(not result.automatic_execution_authorized)
                    expect(not result.rights_gate_passed
                        or (applicability == "applicable"
                            and interpretation == "settled"
                            and evidence == "supported"
                            and conclusion == "satisfied"))
                end
            end
        end
    end

    return {
        status = "passed",
        checks = checks,
        scope = "embedded synthetic tests only",
        formal_proof = false
    }
end

return M
