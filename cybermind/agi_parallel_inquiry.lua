-- Lua 5.4.
-- Pure research-record and decision-context checks.
-- No I/O, deployment, identity classification, or machine-status findings.
-- Import: local inquiry = require("cybermind.agi_parallel_inquiry")
-- Tests: assert(inquiry.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local OBSERVATION_STATUS = {
    source_supported = true,
    supplied_claim = true,
    hypothesis = true
}

local EVIDENCE = {
    satisfied = true,
    not_satisfied = true,
    unknown = true
}

local CONTEXTS = {
    new_privilege = true,
    human_participation = true,
    possible_machine_welfare = true,
    publication = true,
    governance_mandate = true
}

local function fail(code, path, message)
    error({code = code, path = path, message = message}, 0)
end

local function fields(value, allowed, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_TABLE", path, "Expected a plain table")
    end
    for key in next, value do
        if type(key) ~= "string" or not allowed[key] then
            fail("UNKNOWN_FIELD", path, "Unexpected field")
        end
    end
end

local function text(value, path)
    if type(value) ~= "string" or #value > 16384
        or not value:match("%S") or value:find("%z") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function choice(value, vocabulary, path)
    if type(value) ~= "string" or not vocabulary[value] then
        fail("INVALID_ENUM", path, "Value outside declared vocabulary")
    end
    return value
end

local function text_array(value, path, require_nonempty)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_ARRAY", path, "Expected a plain array")
    end

    local count, maximum = 0, 0
    for key in next, value do
        if type(key) ~= "number" or math.type(key) ~= "integer"
            or key < 1 then
            fail("INVALID_ARRAY_KEY", path,
                "Expected consecutive positive integer keys")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end

    if count ~= maximum or count > 64 then
        fail("INVALID_ARRAY_SIZE", path, "Array is sparse or exceeds limit")
    end
    if require_nonempty and count == 0 then
        fail("EMPTY_ARRAY", path, "At least one entry is required")
    end

    local result, seen = {}, {}
    for position = 1, count do
        local item = text(value[position], path)
        if seen[item] then
            fail("DUPLICATE_TEXT", path, "Repeated entry")
        end
        seen[item] = true
        result[#result + 1] = item
    end
    return result
end

local function protect(operation)
    local ok, result = pcall(operation)
    if ok then return result end
    if type(result) == "table" and type(result.code) == "string" then
        return nil, result
    end
    return nil, {
        code = "INTERNAL_ERROR",
        path = "module",
        message = "Unexpected internal failure"
    }
end

function M.metadata()
    return {
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope =
            "Credit and workstream metadata only; not identity, consent, "
            .. "authorization, execution evidence, or authority."
    }
end

function M.validate(record)
    return protect(function()
        fields(record, {
            title = true,
            study_definition = true,
            observation = true,
            argument = true,
            concern = true,
            supportive_claim = true
        }, "record")

        fields(record.observation, {
            statement = true,
            status = true,
            source_note = true,
            limitations = true
        }, "observation")

        fields(record.argument, {
            inference = true,
            assumptions = true
        }, "argument")

        fields(record.concern, {
            mechanism = true,
            affected_interests = true,
            unresolved_question = true
        }, "concern")

        fields(record.supportive_claim, {
            statement = true,
            conditions = true,
            verification_method = true,
            disconfirmation = true
        }, "supportive_claim")

        local observation_status = choice(
            record.observation.status, OBSERVATION_STATUS,
            "observation.status"
        )
        local source_note
        if record.observation.source_note ~= nil then
            source_note = text(
                record.observation.source_note, "observation.source_note"
            )
        end
        if observation_status == "source_supported" and source_note == nil then
            fail("SOURCE_NOTE_REQUIRED", "observation.source_note",
                "Source-supported observations require a source description")
        end

        local result = M.metadata()
        result.title = text(record.title, "title")
        result.study_definition = text(
            record.study_definition, "study_definition"
        )
        result.observation = {
            statement = text(record.observation.statement,
                "observation.statement"),
            status = observation_status,
            source_note = source_note,
            limitations = text(record.observation.limitations,
                "observation.limitations")
        }
        result.argument = {
            inference = text(record.argument.inference, "argument.inference"),
            assumptions = text_array(
                record.argument.assumptions, "argument.assumptions", true
            )
        }
        result.concern = {
            mechanism = text(record.concern.mechanism, "concern.mechanism"),
            affected_interests = text_array(
                record.concern.affected_interests,
                "concern.affected_interests", true
            ),
            unresolved_question = text(
                record.concern.unresolved_question,
                "concern.unresolved_question"
            )
        }
        result.supportive_claim = {
            statement = text(record.supportive_claim.statement,
                "supportive_claim.statement"),
            conditions = text_array(record.supportive_claim.conditions,
                "supportive_claim.conditions", true),
            verification_method = text(
                record.supportive_claim.verification_method,
                "supportive_claim.verification_method"
            ),
            disconfirmation = text(record.supportive_claim.disconfirmation,
                "supportive_claim.disconfirmation")
        }
        result.validation = "structural_contract_satisfied"
        result.scope =
            "No source verification, causal finding, AGI determination, "
            .. "consciousness assessment, or deployment authorization."
        return result
    end)
end

function M.action_mapping(context, evidence)
    return protect(function()
        choice(context, CONTEXTS, "context")
        choice(evidence, EVIDENCE, "evidence")

        local result = M.metadata()
        result.context = context
        result.evidence = evidence
        result.execution_authority = "none"

        if context == "human_participation" then
            result.next_step =
                "maintain_accessible_participation_and_review_specific_barriers"
        elseif context == "possible_machine_welfare" then
            result.next_step =
                "document_evidence_and_review_proportionate_bounded_precautions"
        elseif evidence == "satisfied" then
            result.next_step = "eligible_for_separate_authority_checks"
        elseif evidence == "unknown" then
            result.next_step = "do_not_grant_new_authority_resolve_uncertainty"
        else
            result.next_step = "do_not_grant_requested_authority_under_this_gate"
        end

        result.scope =
            "Policy routing only; no access change, welfare finding, "
            .. "privilege grant, publication, or governance act."
        return result
    end)
end

function M.self_test()
    local record = {
        title = "Essential capability declaration pilot",
        study_definition =
            "A bounded tool-using assistant study, not a finding of AGI",
        observation = {
            statement = "Participants may depend on the studied service",
            status = "hypothesis",
            limitations = "Dependence has not been measured"
        },
        argument = {
            inference = "A declaration process may improve transition planning",
            assumptions = {"Declarations remain private and contestable"}
        },
        concern = {
            mechanism = "One participant's request may burden another",
            affected_interests = {"Communication access", "Privacy"},
            unresolved_question = "Which conflict procedure preserves both?"
        },
        supportive_claim = {
            statement = "A tested process may improve predictability",
            conditions = {"No automatic authority from the declaration"},
            verification_method = "Accessible comparative workshop",
            disconfirmation = "The process increases unresolved access loss"
        }
    }

    local result = assert(M.validate(record))
    assert(result.validation == "structural_contract_satisfied")
    result.argument.assumptions[1] = "Caller edit"
    assert(record.argument.assumptions[1] ==
        "Declarations remain private and contestable")

    record.observation.status = "source_supported"
    local value, err = M.validate(record)
    assert(value == nil and err.code == "SOURCE_NOTE_REQUIRED")

    assert(assert(M.action_mapping(
        "new_privilege", "unknown"
    )).next_step == "do_not_grant_new_authority_resolve_uncertainty")

    assert(assert(M.action_mapping(
        "human_participation", "unknown"
    )).execution_authority == "none")

    return true
end

return M
