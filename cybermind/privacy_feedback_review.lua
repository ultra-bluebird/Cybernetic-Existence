-- Lua 5.4.
-- Pure review helpers; no token generation, content inspection, or deletion.
-- No I/O, external actions, identity inference, or persistent case storage.
-- Import: local review = require("cybermind.privacy_feedback_review")
-- Tests: assert(review.self_test())

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local TRI = {yes = true, no = true, unknown = true}
local DELETE_STATES = {
    erased = true,
    beyond_use = true,
    retained_exception = true,
    pending = true,
    unknown = true,
    not_applicable = true
}
local LOCATIONS = {
    "live", "indexes", "caches", "replicas",
    "backups", "derived_records", "exports"
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
    if type(value) ~= "string" or #value > 4096
        or not value:match("%S") or value:find("%c") then
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

local function choice(value, vocabulary, path)
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

function M.moderation(input)
    return protect(function()
        fields(input, {
            relevant_criticism = true,
            private_information_exposed = true,
            threat_concern = true,
            targeted_abuse = true,
            participation_disruption = true,
            reviewer_conflict = true
        }, "moderation")

        local values = {}
        for _, name in ipairs({
            "relevant_criticism",
            "private_information_exposed",
            "threat_concern",
            "targeted_abuse",
            "participation_disruption",
            "reviewer_conflict"
        }) do
            values[name] = choice(input[name], TRI, name)
        end

        local result = M.metadata()
        result.routes = {}
        result.underlying_feedback = "preserve_accessible_review_route"
        result.legal_finding = "not_determined"
        result.execution = "none"

        if values.reviewer_conflict ~= "no" then
            result.routes[#result.routes + 1] =
                "independent_reviewer_assignment_needed"
        end
        if values.private_information_exposed == "yes" then
            result.routes[#result.routes + 1] =
                "review_redaction_or_temporary_limit_of_specific_material"
        end
        if values.threat_concern == "yes" then
            result.routes[#result.routes + 1] =
                "qualified_human_safety_review"
        end
        if values.targeted_abuse == "yes" then
            result.routes[#result.routes + 1] =
                "contextual_proportionality_review"
        end
        if values.participation_disruption == "yes" then
            result.routes[#result.routes + 1] =
                "accessible_clarification_or_narrow_rate_management_review"
        end

        if #result.routes == 0 then
            result.routes[1] = "no_restriction_recommended_by_this_rubric"
        end

        result.criticism_standing =
            values.relevant_criticism == "yes"
            and "retain_substantive_criticism"
            or "relevance_not_established"

        result.scope =
            "Routing from supplied assessments only; no content classifier, "
            .. "intent finding, legal determination, or moderation action."
        return result
    end)
end

function M.deletion_check(input, now)
    return protect(function()
        fields(input, {
            inventory_review = true,
            restore_test = true,
            locations = true
        }, "deletion")

        integer(now, "now")
        local inventory = choice(input.inventory_review, {
            reviewed = true, unreviewed = true
        }, "inventory_review")
        local restore = choice(input.restore_test, {
            passed = true, failed = true, not_run = true
        }, "restore_test")

        local allowed = {}
        for _, location in ipairs(LOCATIONS) do allowed[location] = true end
        fields(input.locations, allowed, "locations")

        local result = M.metadata()
        result.unresolved = {}
        result.retained = {}
        result.backup_expiry_overdue = false

        if inventory ~= "reviewed" then
            result.unresolved[#result.unresolved + 1] =
                "inventory_scope_not_reviewed"
        end

        local backups_applicable = true

        for _, location in ipairs(LOCATIONS) do
            local row = input.locations[location]
            if row == nil then
                result.unresolved[#result.unresolved + 1] =
                    location .. ":missing_assessment"
            else
                local path = "locations." .. location
                fields(row, {
                    state = true,
                    basis = true,
                    verified_at = true,
                    expiry_at = true,
                    restoration_filter = true
                }, path)

                local state = choice(row.state, DELETE_STATES, path .. ".state")
                text(row.basis, path .. ".basis")

                if row.verified_at ~= nil then
                    integer(row.verified_at, path .. ".verified_at")
                    if row.verified_at > now then
                        fail("FUTURE_VERIFICATION", path .. ".verified_at",
                            "Verification cannot follow assessment time")
                    end
                end

                if state == "erased" or state == "not_applicable" then
                    if row.verified_at == nil then
                        fail("VERIFICATION_REQUIRED", path,
                            "Erased or not-applicable status requires verification time")
                    end
                else
                    result.unresolved[#result.unresolved + 1] =
                        location .. ":" .. state
                end

                if state == "beyond_use" or state == "retained_exception" then
                    result.retained[#result.retained + 1] = location
                end

                if row.expiry_at ~= nil then
                    integer(row.expiry_at, path .. ".expiry_at")
                end
                if row.restoration_filter ~= nil then
                    choice(row.restoration_filter, {
                        verified = true, unknown = true
                    }, path .. ".restoration_filter")
                end

                if location == "backups" then
                    backups_applicable = state ~= "not_applicable"
                    if state == "beyond_use" then
                        if row.expiry_at == nil
                            or row.restoration_filter == nil then
                            fail("BACKUP_CONTROLS_REQUIRED", path,
                                "Beyond-use backups require expiry and restore-filter status")
                        end
                        if row.restoration_filter ~= "verified" then
                            result.unresolved[#result.unresolved + 1] =
                                "backups:restoration_filter_not_verified"
                        end
                        result.backup_expiry_overdue = now >= row.expiry_at
                    end
                end
            end
        end

        if backups_applicable and restore ~= "passed" then
            result.unresolved[#result.unresolved + 1] =
                "backup_restoration_test_not_passed"
        end
        if result.backup_expiry_overdue then
            result.unresolved[#result.unresolved + 1] =
                "backup_expiry_requires_follow_up"
        end

        result.checklist_result = #result.unresolved == 0
            and "supplied_checklist_satisfied"
            or "deletion_not_fully_established"
        result.scope =
            "Supplied inventory and verification assertions only; "
            .. "no deletion performed, physical completeness proven, "
            .. "or legal compliance determined."
        return result
    end)
end

local function deletion_fixture()
    local input = {
        inventory_review = "reviewed",
        restore_test = "passed",
        locations = {}
    }
    for _, location in ipairs(LOCATIONS) do
        input.locations[location] = {
            state = "erased",
            basis = "Synthetic verification fixture",
            verified_at = 1
        }
    end
    return input
end

function M.self_test()
    local input = deletion_fixture()
    assert(assert(M.deletion_check(input, 2)).checklist_result ==
        "supplied_checklist_satisfied")

    input = deletion_fixture()
    input.locations.backups = {
        state = "beyond_use",
        basis = "Synthetic delayed-overwrite fixture",
        expiry_at = 10,
        restoration_filter = "verified"
    }
    local result = assert(M.deletion_check(input, 2))
    assert(result.checklist_result == "deletion_not_fully_established")
    assert(#result.retained == 1)

    input = deletion_fixture()
    input.locations.exports = nil
    assert(assert(M.deletion_check(input, 2)).checklist_result ==
        "deletion_not_fully_established")

    local moderation = {
        relevant_criticism = "yes",
        private_information_exposed = "no",
        threat_concern = "no",
        targeted_abuse = "no",
        participation_disruption = "no",
        reviewer_conflict = "no"
    }
    result = assert(M.moderation(moderation))
    assert(result.routes[1] ==
        "no_restriction_recommended_by_this_rubric")
    assert(result.criticism_standing == "retain_substantive_criticism")

    moderation.private_information_exposed = "yes"
    result = assert(M.moderation(moderation))
    assert(result.underlying_feedback == "preserve_accessible_review_route")

    input = deletion_fixture()
    input.locations.live.verified_at = 3
    local value, err = M.deletion_check(input, 2)
    assert(value == nil and err.code == "FUTURE_VERIFICATION")

    return true
end

return M
