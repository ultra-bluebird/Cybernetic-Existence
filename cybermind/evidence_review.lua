-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4. No I/O, reference resolution, recursion, or external actions.
-- Import: local review = require("cybermind.evidence_review")
-- Tests: assert(review.self_test())

local M = {}

local VERSION = "1.1.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
local ATTRIBUTION_SCOPE =
    "Credit and workstream metadata only; not biological binding, verified "
    .. "identity, consent, capability authorization, execution evidence, "
    .. "or authority over another person or system."

local MAX_OBLIGATIONS = 100000
local MAX_TEXT_BYTES = 4096
local MAX_REFERENCE_BYTES = 128
local MAX_RECORD_FIELDS = 16
local MAX_RECORD_KEY_BYTES = 96

local KINDS = {
    research = true,
    capacity = true,
    external = true,
    proposal = true
}

local STATUSES = {
    canonical = true,
    proposed = true,
    deprecated = true,
    waived = true
}

local SEMANTICS = {
    requires_completion = true,
    requires_availability = true,
    co_design = true
}

local ORIGINS = {
    independent_review = true,
    sibling_declaration = true,
    unresolved = true
}

local RECORD_FIELDS = {
    gov_value = true,
    gov_origin = true,
    gov_evidence_ref = true,
    gov_semantics_verification_ref = true
}

local OBLIGATION_FIELDS = {
    dependent = true,
    prerequisite = true,
    kind = true,
    status = true,
    semantics = true,
    support = true,
    refutation = true,
    support_note = true,
    refutation_note = true,
    review_note = true,
    support_record = true,
    refutation_record = true
}

local SORT_FIELDS = {
    "dependent",
    "prerequisite",
    "kind",
    "semantics"
}

local OPTIONAL_NOTE_FIELDS = {
    "support_note",
    "refutation_note",
    "review_note"
}

local function fail(code, path, message)
    error({
        code = code,
        path = path,
        message = message
    }, 0)
end

local function is_plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function require_plain(value, path)
    if not is_plain(value) then
        fail("INVALID_TABLE", path, "Expected a plain table")
    end
end

local function validate_fields(value, allowed, path)
    require_plain(value, path)

    for key in next, value do
        if type(key) ~= "string" or not allowed[key] then
            fail("UNKNOWN_FIELD", path, "Unexpected field")
        end
    end
end

local function require_text(value, path)
    if type(value) ~= "string"
        or #value > MAX_TEXT_BYTES
        or not value:match("%S")
        or value:find("%c") then
        fail(
            "INVALID_TEXT",
            path,
            "Expected nonblank text without control characters, "
                .. "up to " .. MAX_TEXT_BYTES .. " bytes"
        )
    end
    return value
end

local function require_boolean(value, path)
    if type(value) ~= "boolean" then
        fail("INVALID_BOOLEAN", path, "Expected boolean")
    end
    return value
end

local function require_enum(value, vocabulary, path)
    if type(value) ~= "string" or not vocabulary[value] then
        fail("INVALID_ENUM", path, "Unknown vocabulary value")
    end
    return value
end

local function dense_length(value)
    require_plain(value, "obligations")

    local count, maximum = 0, 0

    for key in next, value do
        if type(key) ~= "number"
            or math.type(key) ~= "integer"
            or key < 1 then
            fail(
                "INVALID_ARRAY_KEY",
                "obligations",
                "Expected positive consecutive integer keys"
            )
        end

        count = count + 1
        if count > MAX_OBLIGATIONS then
            fail("LIMIT_EXCEEDED", "obligations", "Too many obligations")
        end
        maximum = math.max(maximum, key)
    end

    if count ~= maximum then
        fail("SPARSE_ARRAY", "obligations", "Missing array position")
    end

    return count
end

local function evidence_label(support, refutation)
    if support and refutation then
        return "conflicting"
    elseif support then
        return "supported"
    elseif refutation then
        return "refuted"
    end
    return "unknown"
end

local function protect(operation)
    local ok, result = pcall(operation)
    if ok then
        return result
    end

    if is_plain(result)
        and type(rawget(result, "code")) == "string"
        and type(rawget(result, "path")) == "string"
        and type(rawget(result, "message")) == "string" then
        return nil, result
    end

    return nil, {
        code = "INTERNAL_ERROR",
        path = "module",
        message = "Unexpected internal failure"
    }
end

local function valid_reference(value)
    return type(value) == "string"
        and #value >= 1
        and #value <= MAX_REFERENCE_BYTES
        and value:match("^[A-Za-z0-9][A-Za-z0-9_.:/%-]*$") ~= nil
end

local function add_finding(output, code, field, severity)
    output.gov_findings[#output.gov_findings + 1] = {
        gov_code = code,
        gov_field = field,
        gov_severity = severity
    }
end

local function validate_record(record)
    local output = {
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope = ATTRIBUTION_SCOPE,
        gov_structure_status = "invalid_record",
        gov_reference_readiness = "not_ready",
        gov_origin_verification = "not_performed",
        gov_authenticity_status = "not_assessed",
        gov_authority_status = "not_assessed",
        gov_findings = {}
    }

    if not is_plain(record) then
        add_finding(
            output, "plain_evidence_record_required", nil, "error"
        )
        return output
    end

    local unexpected = {}
    local invalid_keys = false
    local count = 0

    for key in next, record do
        count = count + 1

        if count > MAX_RECORD_FIELDS then
            add_finding(
                output, "evidence_field_limit_exceeded", nil, "error"
            )
            return output
        end

        if type(key) ~= "string"
            or #key > MAX_RECORD_KEY_BYTES
            or key:find("%c") then
            invalid_keys = true
        elseif not RECORD_FIELDS[key] then
            unexpected[#unexpected + 1] = key
        end
    end

    if invalid_keys then
        add_finding(
            output, "invalid_evidence_field_key", nil, "error"
        )
    end

    table.sort(unexpected)
    for _, key in ipairs(unexpected) do
        add_finding(
            output, "unexpected_evidence_field", key, "error"
        )
    end

    local value = rawget(record, "gov_value")
    if value == nil then
        add_finding(output, "constraint_missing", "gov_value", "error")
    elseif type(value) ~= "boolean" then
        add_finding(
            output, "constraint_not_boolean", "gov_value", "error"
        )
    end

    local origin = rawget(record, "gov_origin")
    if origin == nil then
        add_finding(output, "origin_missing", "gov_origin", "error")
    elseif type(origin) ~= "string" or not ORIGINS[origin] then
        add_finding(output, "origin_invalid", "gov_origin", "error")
    end

    local evidence = rawget(record, "gov_evidence_ref")
    if evidence ~= nil and not valid_reference(evidence) then
        add_finding(
            output,
            "evidence_reference_invalid",
            "gov_evidence_ref",
            "error"
        )
    end

    local semantics = rawget(
        record, "gov_semantics_verification_ref"
    )
    if semantics ~= nil and not valid_reference(semantics) then
        add_finding(
            output,
            "semantics_reference_invalid",
            "gov_semantics_verification_ref",
            "error"
        )
    end

    if #output.gov_findings > 0 then
        return output
    end

    output.gov_structure_status = "well_formed"
    output.gov_declared_value = value
    output.gov_claimed_origin = origin

    if origin == "unresolved" then
        add_finding(
            output, "origin_unresolved", "gov_origin", "warning"
        )
    end

    if evidence == nil then
        add_finding(
            output,
            "evidence_reference_missing",
            "gov_evidence_ref",
            "warning"
        )
    else
        output.gov_evidence_ref = evidence
    end

    if semantics == nil then
        add_finding(
            output,
            "semantics_reference_missing",
            "gov_semantics_verification_ref",
            "warning"
        )
    else
        output.gov_semantics_verification_ref = semantics
    end

    if #output.gov_findings == 0 then
        output.gov_reference_readiness =
            "ready_for_reference_resolution"
    end

    return output
end

local function copy_record(record)
    return {
        gov_value = record.gov_value,
        gov_origin = record.gov_origin,
        gov_evidence_ref = record.gov_evidence_ref,
        gov_semantics_verification_ref =
            record.gov_semantics_verification_ref
    }
end

local function copy_row(row)
    local result = {
        dependent = row.dependent,
        prerequisite = row.prerequisite,
        kind = row.kind,
        status = row.status,
        semantics = row.semantics,
        support = row.support,
        refutation = row.refutation,
        support_note = row.support_note,
        refutation_note = row.refutation_note,
        review_note = row.review_note
    }

    if row.support_record then
        result.support_record = copy_record(row.support_record)
    end
    if row.refutation_record then
        result.refutation_record = copy_record(row.refutation_record)
    end

    return result
end

local function normalize_record(record, expected_value, path)
    local assessment = validate_record(record)

    if assessment.gov_structure_status ~= "well_formed" then
        fail(
            "INVALID_EVIDENCE_RECORD",
            path,
            "Evidence record failed structural validation"
        )
    end

    if assessment.gov_declared_value ~= expected_value then
        fail(
            "EVIDENCE_POLARITY_MISMATCH",
            path .. ".gov_value",
            "Support records assert satisfaction; "
                .. "refutation records assert non-satisfaction"
        )
    end

    return copy_record(record)
end

local function row_less(left, right)
    for _, key in ipairs(SORT_FIELDS) do
        if left[key] ~= right[key] then
            return left[key] < right[key]
        end
    end
    return false
end

local function normalize(obligations)
    local count = dense_length(obligations)
    local result, seen = {}, {}

    for position = 1, count do
        local source = rawget(obligations, position)
        local path = "obligations[" .. position .. "]"

        validate_fields(source, OBLIGATION_FIELDS, path)

        local row = {
            dependent = require_text(
                source.dependent, path .. ".dependent"
            ),
            prerequisite = require_text(
                source.prerequisite, path .. ".prerequisite"
            ),
            kind = require_enum(
                source.kind, KINDS, path .. ".kind"
            ),
            status = require_enum(
                source.status, STATUSES, path .. ".status"
            ),
            semantics = require_enum(
                source.semantics, SEMANTICS, path .. ".semantics"
            ),
            support = require_boolean(
                source.support, path .. ".support"
            ),
            refutation = require_boolean(
                source.refutation, path .. ".refutation"
            )
        }

        for _, key in ipairs(OPTIONAL_NOTE_FIELDS) do
            if source[key] ~= nil then
                row[key] = require_text(
                    source[key], path .. "." .. key
                )
            end
        end

        if row.support and not row.support_note then
            fail(
                "SUPPORT_NOTE_REQUIRED",
                path .. ".support_note",
                "Support needs a note"
            )
        end

        if row.refutation and not row.refutation_note then
            fail(
                "REFUTATION_NOTE_REQUIRED",
                path .. ".refutation_note",
                "Refutation needs a note"
            )
        end

        if (row.status == "waived" or row.status == "deprecated")
            and not row.review_note then
            fail(
                "REVIEW_NOTE_REQUIRED",
                path .. ".review_note",
                "Lifecycle change needs reasons"
            )
        end

        if row.semantics == "requires_completion"
            and (row.kind == "capacity" or row.kind == "external") then
            fail(
                "SEMANTIC_KIND_MISMATCH",
                path .. ".semantics",
                "Capacity and external conditions "
                    .. "require availability semantics"
            )
        end

        if source.support_record ~= nil then
            if not row.support then
                fail(
                    "INACTIVE_EVIDENCE_RECORD",
                    path .. ".support_record",
                    "A support record requires support=true"
                )
            end
            row.support_record = normalize_record(
                source.support_record,
                true,
                path .. ".support_record"
            )
        end

        if source.refutation_record ~= nil then
            if not row.refutation then
                fail(
                    "INACTIVE_EVIDENCE_RECORD",
                    path .. ".refutation_record",
                    "A refutation record requires refutation=true"
                )
            end
            row.refutation_record = normalize_record(
                source.refutation_record,
                false,
                path .. ".refutation_record"
            )
        end

        local key = table.concat({
            row.dependent,
            row.prerequisite,
            row.kind,
            row.semantics
        }, "\0")

        if seen[key] then
            fail(
                "DUPLICATE_OBLIGATION",
                path,
                "Relationship must have one lifecycle status"
            )
        end

        seen[key] = true
        result[#result + 1] = row
    end

    table.sort(result, row_less)
    return result
end

local function projection_mode(projection)
    if projection == "canonical" then
        return false
    elseif projection == "candidate" then
        return true
    end

    fail(
        "INVALID_PROJECTION",
        "projection",
        "Expected canonical or candidate"
    )
end

local function reference_assessment(row)
    local result = {
        dependent = row.dependent,
        prerequisite = row.prerequisite,
        kind = row.kind,
        semantics = row.semantics
    }

    if row.support_record then
        result.support_record = validate_record(row.support_record)
    end
    if row.refutation_record then
        result.refutation_record = validate_record(
            row.refutation_record
        )
    end

    return result
end

local function evaluate(rows, subject, projection)
    local include_proposals = projection_mode(projection)

    local report = {
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope = ATTRIBUTION_SCOPE,
        subject = subject,
        projection = projection,
        requirements = {},
        blockers = {
            research = {},
            capacity = {},
            external = {},
            proposal = {}
        },
        coordination = {},
        excluded = {},
        self_references = {},
        reference_assessments = {},
        support = true,
        refutation = false,
        reviewed_requirement_count = 0,
        subject_obligation_count = 0,
        selected_obligation_count = 0,
        decision = "insufficient_scope",
        authorization = "none",
        gov_reference_resolution = "not_performed",
        completeness =
            "Scope completeness and evidence truth are not established"
    }

    for _, row in ipairs(rows) do
        if row.dependent == subject then
            report.subject_obligation_count =
                report.subject_obligation_count + 1

            local selected = row.status == "canonical"
                or (include_proposals and row.status == "proposed")

            if not selected then
                report.excluded[#report.excluded + 1] = copy_row(row)
            else
                report.selected_obligation_count =
                    report.selected_obligation_count + 1

                if row.dependent == row.prerequisite then
                    report.self_references[
                        #report.self_references + 1
                    ] = copy_row(row)
                end

                if row.support_record or row.refutation_record then
                    report.reference_assessments[
                        #report.reference_assessments + 1
                    ] = reference_assessment(row)
                end

                if row.semantics == "co_design" then
                    report.coordination[
                        #report.coordination + 1
                    ] = copy_row(row)
                else
                    report.requirements[
                        #report.requirements + 1
                    ] = copy_row(row)
                    report.reviewed_requirement_count =
                        report.reviewed_requirement_count + 1
                    report.support = report.support and row.support
                    report.refutation =
                        report.refutation or row.refutation

                    if not row.support or row.refutation then
                        local bucket = report.blockers[row.kind]
                        bucket[#bucket + 1] = copy_row(row)
                    end
                end
            end
        end
    end

    -- Empty conjunction is algebraic support, not an approval.
    report.evidence_value = evidence_label(
        report.support, report.refutation
    )

    if report.reviewed_requirement_count > 0 then
        if report.evidence_value == "supported" then
            report.decision = "supported_under_selected_scope"
        elseif report.evidence_value == "unknown" then
            report.decision = "evidence_incomplete"
        elseif report.evidence_value == "conflicting" then
            report.decision = "conflict_requires_review"
        else
            report.decision = "requirements_not_supported"
        end
    end

    report.has_coordination_requirements =
        #report.coordination > 0
    report.has_self_references = #report.self_references > 0

    return report
end

function M.metadata()
    return {
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope = ATTRIBUTION_SCOPE,
        authorization = "none",
        reference_resolution = "not_performed",
        limits = {
            obligations = MAX_OBLIGATIONS,
            text_bytes = MAX_TEXT_BYTES,
            reference_bytes = MAX_REFERENCE_BYTES,
            evidence_record_fields = MAX_RECORD_FIELDS,
            evidence_record_key_bytes = MAX_RECORD_KEY_BYTES
        }
    }
end

function M.validate(record)
    return validate_record(record)
end

M.validate_reference = M.validate

function M.validate_obligations(obligations)
    return protect(function()
        return normalize(obligations)
    end)
end

function M.review(obligations, subject, projection)
    return protect(function()
        require_text(subject, "subject")
        projection_mode(projection)
        return evaluate(normalize(obligations), subject, projection)
    end)
end

function M.compare(obligations, subject)
    return protect(function()
        require_text(subject, "subject")
        local rows = normalize(obligations)

        local canonical = evaluate(rows, subject, "canonical")
        local candidate = evaluate(rows, subject, "candidate")

        return {
            schema_version = VERSION,
            attribution = ATTRIBUTION,
            attribution_scope = ATTRIBUTION_SCOPE,
            authorization = "none",
            canonical = canonical,
            candidate = candidate,
            decision_preserved =
                canonical.decision == candidate.decision,
            evidence_preserved =
                canonical.evidence_value == candidate.evidence_value,
            scope_preserved =
                canonical.selected_obligation_count
                    == candidate.selected_obligation_count,
            scope_sensitive_approval =
                canonical.decision == "supported_under_selected_scope"
                and candidate.decision
                    ~= "supported_under_selected_scope"
        }
    end)
end

local function fixture_rows()
    return {
        {
            dependent = "Participation review",
            prerequisite = "Reviewer availability",
            kind = "capacity",
            status = "canonical",
            semantics = "requires_availability",
            support = true,
            refutation = false,
            support_note = "Synthetic test assertion"
        },
        {
            dependent = "Participation review",
            prerequisite = "Additional study",
            kind = "research",
            status = "proposed",
            semantics = "requires_completion",
            support = false,
            refutation = false
        }
    }
end

local function fixture_record(value)
    return {
        gov_value = value,
        gov_origin = "independent_review",
        gov_evidence_ref = "fixture/evidence",
        gov_semantics_verification_ref = "fixture/semantics"
    }
end

local function expect_error(operation, expected_code)
    local value, err = operation()
    assert(value == nil, "Expected an error result")
    assert(type(err) == "table", "Expected structured error")
    assert(err.code == expected_code, "Unexpected error code")
end

local function has_finding(report, code)
    for _, finding in ipairs(report.gov_findings) do
        if finding.gov_code == code then
            return true
        end
    end
    return false
end

function M.self_test()
    local rows = fixture_rows()
    local comparison = assert(M.compare(rows, "Participation review"))

    assert(comparison.scope_sensitive_approval)
    assert(not comparison.scope_preserved)
    assert(comparison.canonical.decision ==
        "supported_under_selected_scope")
    assert(comparison.candidate.decision == "evidence_incomplete")

    comparison.canonical.requirements[1].support = false
    assert(comparison.candidate.requirements[1].support == true)
    assert(rows[1].support == true)

    rows[1].refutation = true
    rows[1].refutation_note = "Synthetic conflicting assertion"

    local conflict = assert(M.review(
        rows, "Participation review", "canonical"
    ))
    assert(conflict.decision == "conflict_requires_review")
    assert(#conflict.blockers.capacity == 1)

    conflict.requirements[1].support = false
    assert(conflict.blockers.capacity[1].support == true)
    assert(rows[1].support == true)

    local empty = assert(M.review({}, "Unknown subject", "canonical"))
    assert(empty.decision == "insufficient_scope")
    assert(empty.support == true)
    assert(empty.authorization == "none")

    expect_error(function()
        return M.review(rows, "Participation review", "everything")
    end, "INVALID_PROJECTION")

    expect_error(function()
        return M.review(
            {[2] = rows[1]}, "Participation review", "canonical"
        )
    end, "SPARSE_ARRAY")

    expect_error(function()
        return M.review(
            {unexpected = rows[1]},
            "Participation review",
            "canonical"
        )
    end, "INVALID_ARRAY_KEY")

    expect_error(function()
        return M.review(rows, "", "canonical")
    end, "INVALID_TEXT")

    local duplicates = fixture_rows()
    duplicates[3] = duplicates[1]
    expect_error(function()
        return M.validate_obligations(duplicates)
    end, "DUPLICATE_OBLIGATION")

    local incompatible = fixture_rows()
    incompatible[1].semantics = "requires_completion"
    expect_error(function()
        return M.validate_obligations(incompatible)
    end, "SEMANTIC_KIND_MISMATCH")

    local waived = fixture_rows()
    waived[1].status = "waived"
    expect_error(function()
        return M.validate_obligations(waived)
    end, "REVIEW_NOTE_REQUIRED")

    waived[1].review_note = "Synthetic waiver review"
    local waiver_report = assert(M.review(
        waived, "Participation review", "canonical"
    ))
    assert(#waiver_report.excluded == 2)
    assert(waiver_report.decision == "insufficient_scope")

    local record = fixture_record(true)
    local validation = M.validate(record)
    assert(validation.gov_structure_status == "well_formed")
    assert(validation.gov_reference_readiness ==
        "ready_for_reference_resolution")
    assert(validation.gov_origin_verification == "not_performed")
    assert(validation.gov_authenticity_status == "not_assessed")
    assert(validation.gov_authority_status == "not_assessed")

    local false_record = M.validate(fixture_record(false))
    assert(false_record.gov_structure_status == "well_formed")
    assert(false_record.gov_declared_value == false)

    local unresolved = fixture_record(true)
    unresolved.gov_origin = "unresolved"
    local unresolved_report = M.validate(unresolved)
    assert(unresolved_report.gov_structure_status == "well_formed")
    assert(unresolved_report.gov_reference_readiness == "not_ready")
    assert(has_finding(unresolved_report, "origin_unresolved"))

    local missing = M.validate({
        gov_value = true,
        gov_origin = "sibling_declaration"
    })
    assert(missing.gov_structure_status == "well_formed")
    assert(has_finding(missing, "evidence_reference_missing"))
    assert(has_finding(missing, "semantics_reference_missing"))

    local malformed = fixture_record(true)
    malformed.gov_evidence_ref = "invalid reference"
    assert(M.validate(malformed).gov_structure_status ==
        "invalid_record")

    local unexpected = fixture_record(true)
    unexpected.z_extra = true
    unexpected.a_extra = true
    local unexpected_report = M.validate(unexpected)
    assert(unexpected_report.gov_findings[1].gov_field == "a_extra")
    assert(unexpected_report.gov_findings[2].gov_field == "z_extra")

    local too_many = {}
    for index = 1, MAX_RECORD_FIELDS + 1 do
        too_many["extra_" .. index] = true
    end
    assert(has_finding(
        M.validate(too_many), "evidence_field_limit_exceeded"
    ))

    local hostile = setmetatable({}, {
        __index = function()
            error("Metamethod must not execute")
        end,
        __pairs = function()
            error("Metamethod must not execute")
        end
    })
    assert(M.validate(hostile).gov_structure_status == "invalid_record")

    local cyclic_record = {}
    cyclic_record.gov_value = cyclic_record
    cyclic_record.gov_origin = "unresolved"
    assert(M.validate(cyclic_record).gov_structure_status ==
        "invalid_record")

    local integrated = fixture_rows()
    integrated[1].support_record = fixture_record(true)
    integrated[1].refutation = true
    integrated[1].refutation_note = "Synthetic negative evidence"
    integrated[1].refutation_record = fixture_record(false)

    local integrated_report = assert(M.review(
        integrated, "Participation review", "canonical"
    ))
    assert(integrated_report.decision == "conflict_requires_review")
    assert(#integrated_report.reference_assessments == 1)
    assert(integrated_report.reference_assessments[1]
        .support_record.gov_reference_readiness ==
        "ready_for_reference_resolution")
    assert(integrated_report.gov_reference_resolution == "not_performed")

    integrated_report.requirements[1].support_record.gov_value = false
    assert(integrated[1].support_record.gov_value == true)
    assert(integrated_report.blockers.capacity[1]
        .support_record.gov_value == true)

    local wrong_polarity = fixture_rows()
    wrong_polarity[1].support_record = fixture_record(false)
    expect_error(function()
        return M.validate_obligations(wrong_polarity)
    end, "EVIDENCE_POLARITY_MISMATCH")

    local inactive = fixture_rows()
    inactive[2].support_record = fixture_record(true)
    expect_error(function()
        return M.validate_obligations(inactive)
    end, "INACTIVE_EVIDENCE_RECORD")

    local reordered = fixture_rows()
    reordered[1], reordered[2] = reordered[2], reordered[1]
    local first = assert(M.validate_obligations(fixture_rows()))
    local second = assert(M.validate_obligations(reordered))
    for index = 1, #first do
        for _, key in ipairs(SORT_FIELDS) do
            assert(first[index][key] == second[index][key])
        end
    end

    local coordination = fixture_rows()
    coordination[1].dependent = "Reviewer availability"
    coordination[1].prerequisite = "Reviewer availability"
    coordination[1].semantics = "co_design"
    local coordination_report = assert(M.review(
        coordination, "Reviewer availability", "canonical"
    ))
    assert(coordination_report.has_coordination_requirements)
    assert(coordination_report.has_self_references)
    assert(coordination_report.decision == "insufficient_scope")

    local metadata = M.metadata()
    metadata.limits.obligations = 0
    assert(M.metadata().limits.obligations == MAX_OBLIGATIONS)
    assert(M.validate_reference == M.validate)

    return true
end

return M
