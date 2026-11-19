-- Lua 5.4. Pure local catalog-admission checks.
-- No I/O, publication, reviewer authentication, or external actions.
-- Import: local admission = require("cybermind.catalog_admission")
-- Tests: assert(admission.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local STAGES = {
    "label",
    "mechanism",
    "rival_explanations",
    "normative_empirical_split",
    "investigation",
    "actionable_output",
    "responsibility_retest"
}

local PROVENANCE = {
    fictional = true,
    composite = true,
    participant_reported = true,
    exercise_observed = true,
    documentary = true,
    directly_measured = true
}

local CLAIMS = {
    possibility = true,
    research_question = true,
    proposed_requirement = true,
    empirical_finding = true
}

local BASES = {
    narrative_only = true,
    logical_argument = true,
    participant_account = true,
    exercise_observation = true,
    documentary_evidence = true,
    measurement = true
}

local REVIEWS = {
    adequate = true,
    needs_revision = true,
    unable_to_assess = true
}

local PUBLICATION = {
    cleared = true,
    restricted = true,
    pending = true
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

local function integer(value, path)
    if type(value) ~= "number"
        or math.type(value) ~= "integer" or value < 0 then
        fail("INVALID_INTEGER", path, "Expected nonnegative integer")
    end
    return value
end

local function enumeration(value, vocabulary, path)
    if type(value) ~= "string" or not vocabulary[value] then
        fail("INVALID_ENUM", path, "Value outside declared vocabulary")
    end
    return value
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

function M.evaluate(record)
    return protect(function()
        fields(record, {
            title = true,
            revision = true,
            provenance = true,
            claim_kind = true,
            evidence_basis = true,
            scope_note = true,
            residual_uncertainty = true,
            stages = true,
            review = true
        }, "record")

        text(record.title, "title")
        local revision = integer(record.revision, "revision")
        local provenance = enumeration(
            record.provenance, PROVENANCE, "provenance"
        )
        local claim = enumeration(
            record.claim_kind, CLAIMS, "claim_kind"
        )
        local basis = enumeration(
            record.evidence_basis, BASES, "evidence_basis"
        )
        text(record.scope_note, "scope_note")
        text(record.residual_uncertainty, "residual_uncertainty")

        local allowed = {}
        for _, stage in ipairs(STAGES) do allowed[stage] = true end
        fields(record.stages, allowed, "stages")

        local result = M.metadata()
        result.missing_stages = {}
        result.revision_stages = {}
        result.unassessed_stages = {}
        result.reasons = {}
        result.publication_status = "not_reviewed"
        result.admission = "candidate"
        result.scope =
            "Structure and supplied review declarations only; "
            .. "not authenticated curation, truth, utility, or publication."

        for _, stage in ipairs(STAGES) do
            if record.stages[stage] == nil then
                result.missing_stages[#result.missing_stages + 1] = stage
            else
                text(record.stages[stage], "stages." .. stage)
            end
        end

        result.structurally_complete = #result.missing_stages == 0

        if claim == "empirical_finding"
            and (basis == "narrative_only" or basis == "logical_argument") then
            result.reasons[#result.reasons + 1] =
                "empirical_claim_without_empirical_basis"
        end

        if record.review == nil then
            result.reasons[#result.reasons + 1] = "review_not_recorded"
            return result
        end

        fields(record.review, {
            reviewed_revision = true,
            reviewer_role = true,
            conflict_status = true,
            dispositions = true,
            publication_status = true,
            review_note = true
        }, "review")

        local reviewed_revision = integer(
            record.review.reviewed_revision, "review.reviewed_revision"
        )
        text(record.review.reviewer_role, "review.reviewer_role")
        text(record.review.review_note, "review.review_note")

        local conflict = enumeration(record.review.conflict_status, {
            cleared = true, unresolved = true
        }, "review.conflict_status")

        result.publication_status = enumeration(
            record.review.publication_status,
            PUBLICATION, "review.publication_status"
        )
        fields(record.review.dispositions, allowed, "review.dispositions")

        for _, stage in ipairs(STAGES) do
            local disposition = record.review.dispositions[stage]
            if disposition == nil then
                result.unassessed_stages[
                    #result.unassessed_stages + 1
                ] = stage
            else
                enumeration(disposition, REVIEWS,
                    "review.dispositions." .. stage)
                if disposition == "needs_revision" then
                    result.revision_stages[
                        #result.revision_stages + 1
                    ] = stage
                elseif disposition == "unable_to_assess" then
                    result.unassessed_stages[
                        #result.unassessed_stages + 1
                    ] = stage
                end
            end
        end

        if reviewed_revision ~= revision then
            result.reasons[#result.reasons + 1] = "review_is_stale"
        end
        if conflict ~= "cleared" then
            result.reasons[#result.reasons + 1] = "review_conflict_unresolved"
        end

        if #result.revision_stages > 0
            or #result.reasons > 0
            or not result.structurally_complete then
            result.admission = "needs_revision_or_review"
        elseif #result.unassessed_stages > 0 then
            result.admission = "review_pending"
        else
            result.admission = "admission_recommended"
        end

        result.publication =
            result.admission == "admission_recommended"
            and result.publication_status == "cleared"
            and "eligible_for_separate_publication_decision"
            or "not_cleared_for_publication"

        return result
    end)
end

local function fixture()
    local record = {
        title = "Synthetic complaint-access scenario",
        revision = 1,
        provenance = "fictional",
        claim_kind = "research_question",
        evidence_basis = "narrative_only",
        scope_note = "Invented example, not an incident allegation",
        residual_uncertainty = "Real process performance remains unknown",
        stages = {},
        review = {
            reviewed_revision = 1,
            reviewer_role = "Scenario reviewer",
            conflict_status = "cleared",
            dispositions = {},
            publication_status = "restricted",
            review_note = "Synthetic review fixture, not actual attestation"
        }
    }
    for _, stage in ipairs(STAGES) do
        record.stages[stage] = "Synthetic content for " .. stage
        record.review.dispositions[stage] = "adequate"
    end
    return record
end

function M.self_test()
    local record = fixture()
    local result = assert(M.evaluate(record))
    assert(result.admission == "admission_recommended")
    assert(result.publication == "not_cleared_for_publication")

    record = fixture()
    record.claim_kind = "empirical_finding"
    assert(assert(M.evaluate(record)).admission ==
        "needs_revision_or_review")

    record = fixture()
    record.review.reviewed_revision = 0
    assert(assert(M.evaluate(record)).admission ==
        "needs_revision_or_review")

    record = fixture()
    record.review.dispositions.mechanism = "unable_to_assess"
    assert(assert(M.evaluate(record)).admission == "review_pending")

    record = fixture()
    record.stages.investigation = nil
    assert(not assert(M.evaluate(record)).structurally_complete)

    record = fixture()
    record.review = nil
    assert(assert(M.evaluate(record)).admission == "candidate")

    record = fixture()
    local first = assert(M.evaluate(record))
    first.reasons[1] = "Caller edit"
    assert(#assert(M.evaluate(record)).reasons == 0)
    assert(record.review.dispositions.mechanism == "adequate")

    return true
end

return M
