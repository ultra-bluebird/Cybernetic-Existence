-- Lua 5.4.
-- Complaint and review-decision contracts.
-- No I/O, JSON decoding, repository access, publication, or external actions.
-- Import: local records = require("cybermind.cybercongress_records")
-- Tests: assert(records.self_test())
--
-- Input must already be a decoded data table, never executable source.
-- Optional fields are omitted, not represented by JSON-null sentinels.
-- Returned records are independent structural copies.

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
local ATTRIBUTION_SCOPE =
    "Credit and workstream metadata only; not identity, consent, "
    .. "authorization, execution evidence, or authority."
local MAX_TIME = 9007199254740991

local function fail(code, path, message)
    error({code = code, path = path, message = message}, 0)
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

local function C(value)
    return {kind = "constant", value = value}
end

local function E(...)
    local allowed = {}
    for _, value in ipairs({...}) do allowed[value] = true end
    return {kind = "enum", allowed = allowed}
end

local function O(properties, optional)
    return {
        kind = "object",
        properties = properties,
        optional = optional or {}
    }
end

local TEXT = {kind = "text"}
local TIME = {kind = "time"}
local BOOL = {kind = "boolean"}

local RETENTION = O({
    policy_version = TEXT,
    review_due_unix_s = TIME,
    delete_after_unix_s = TIME
})

local PRIVACY = O({
    purpose = C("complaint_review"),
    data_class = E("synthetic", "restricted"),
    allow_external_contact = BOOL,
    allow_public_summary = BOOL,
    retention = RETENTION
})

local SAFEGUARDS = O({
    private_inventory_not_required = C(true),
    non_retaliation_required = C(true),
    direct_participation_preserved = C(true)
})

local COMPLAINT = O({
    record_type = C("complaint"),
    schema_version = C(VERSION),
    attribution = C(ATTRIBUTION),
    attribution_scope = C(ATTRIBUTION_SCOPE),
    environment = E("synthetic", "voluntary_pilot"),
    received_at_unix_s = TIME,
    origin = E(
        "fictional_test",
        "participant_report",
        "chosen_representative_report"
    ),
    summary = TEXT,
    requested_outcome = TEXT,
    communication_mode = E(
        "asynchronous_text", "chosen_assistance", "no_return_channel"
    ),
    additional_time_requested = BOOL,
    privacy = PRIVACY,
    safeguards = SAFEGUARDS
})

local DECISION = O({
    record_type = C("review_decision"),
    schema_version = C(VERSION),
    complaint = COMPLAINT,
    recorded_at_unix_s = TIME,
    response_due_at_unix_s = TIME,
    response_recorded_at_unix_s = TIME,
    response_delivery = E("not_attempted", "confirmed", "unknown"),
    disposition = E(
        "pending", "nonbinding_recommendation",
        "declined_with_reasons", "referral_offered", "withdrawn"
    ),
    reasons = TEXT,
    reviewer_role = TEXT,
    independence = E("cleared", "unresolved", "not_assessed"),
    mandate = E("verified_assertion", "not_verified", "revoked"),
    publication_status = E(
        "not_requested", "pending_review",
        "not_cleared", "eligible_for_separate_approval"
    ),
    execution_authority = C("none")
}, {
    response_recorded_at_unix_s = true
})

local function plain(value, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_OBJECT", path, "Expected a plain data object")
    end
end

local function valid_time(value, path)
    if type(value) ~= "number" or value ~= value
        or value < 0 or value > MAX_TIME or value % 1 ~= 0 then
        fail("INVALID_TIME", path,
            "Expected a nonnegative interoperable integer timestamp")
    end
end

local function valid_text(value, path)
    if type(value) ~= "string" then
        fail("INVALID_TEXT", path, "Expected text")
    end
    local count = utf8.len(value)
    if count == nil or count < 1 or count > 4096
        or value:find("[%z\1-\31\127]")
        or not value:find("[^ ]") then
        fail("INVALID_TEXT", path,
            "Expected bounded UTF-8 text without ASCII controls")
    end
end

local function shape_copy(input, schema)
    local holder = {}
    local stack = {{
        value = input, schema = schema,
        target = holder, key = "record", path = "record"
    }}

    while #stack > 0 do
        local item = stack[#stack]
        stack[#stack] = nil
        local value, spec = item.value, item.schema

        if spec.kind == "object" then
            plain(value, item.path)

            for key in next, value do
                if type(key) ~= "string" or spec.properties[key] == nil then
                    fail("UNKNOWN_FIELD", item.path,
                        "Object contains an undeclared property")
                end
            end

            local names = {}
            for name in next, spec.properties do names[#names + 1] = name end
            table.sort(names)

            local copy = {}
            item.target[item.key] = copy

            for _, name in ipairs(names) do
                if value[name] == nil and not spec.optional[name] then
                    fail("REQUIRED_FIELD", item.path .. "." .. name,
                        "Required property is absent")
                end
            end

            for position = #names, 1, -1 do
                local name = names[position]
                if value[name] ~= nil then
                    stack[#stack + 1] = {
                        value = value[name],
                        schema = spec.properties[name],
                        target = copy,
                        key = name,
                        path = item.path .. "." .. name
                    }
                end
            end

        elseif spec.kind == "text" then
            valid_text(value, item.path)
            item.target[item.key] = value

        elseif spec.kind == "time" then
            valid_time(value, item.path)
            item.target[item.key] = value

        elseif spec.kind == "boolean" then
            if type(value) ~= "boolean" then
                fail("INVALID_BOOLEAN", item.path, "Expected boolean")
            end
            item.target[item.key] = value

        elseif spec.kind == "constant" then
            if value ~= spec.value then
                fail("CONSTANT_MISMATCH", item.path,
                    "Value differs from the declared constant")
            end
            item.target[item.key] = value

        elseif spec.kind == "enum" then
            if type(value) ~= "string" or not spec.allowed[value] then
                fail("INVALID_ENUM", item.path,
                    "Value is outside the declared vocabulary")
            end
            item.target[item.key] = value

        else
            fail("INTERNAL_SCHEMA_ERROR", item.path,
                "Unsupported internal descriptor")
        end
    end

    return holder.record
end

local function complaint_rules(record)
    local privacy = record.privacy
    local retention = privacy.retention

    if record.environment == "synthetic" then
        if record.origin ~= "fictional_test"
            or privacy.data_class ~= "synthetic" then
            fail("ENVIRONMENT_CONFLICT", "record",
                "Synthetic records require fictional origin and synthetic data")
        end
    elseif record.origin == "fictional_test"
        or privacy.data_class ~= "restricted" then
        fail("ENVIRONMENT_CONFLICT", "record",
            "Pilot records require reported origin and restricted data")
    end

    if retention.review_due_unix_s < record.received_at_unix_s
        or retention.delete_after_unix_s < retention.review_due_unix_s then
        fail("RETENTION_ORDER", "record.privacy.retention",
            "Require receipt <= retention review <= deletion endpoint")
    end
end

local function decision_rules(record)
    complaint_rules(record.complaint)
    local received = record.complaint.received_at_unix_s

    if record.recorded_at_unix_s < received
        or record.response_due_at_unix_s < received then
        fail("DECISION_TIME_ORDER", "record",
            "Decision and response deadline cannot precede receipt")
    end

    local response = record.response_recorded_at_unix_s
    if response ~= nil and
        (response < received or response > record.recorded_at_unix_s) then
        fail("RESPONSE_TIME_ORDER", "record.response_recorded_at_unix_s",
            "Response must fall between receipt and record time")
    end

    if record.response_delivery == "confirmed" and response == nil then
        fail("RESPONSE_REQUIRED", "record.response_delivery",
            "Confirmed delivery requires a recorded response")
    end

    local final_review = record.disposition == "nonbinding_recommendation"
        or record.disposition == "declined_with_reasons"
    local publication =
        record.publication_status == "eligible_for_separate_approval"

    if final_review or publication then
        if record.independence ~= "cleared"
            or record.mandate ~= "verified_assertion" then
            fail("REVIEW_ASSERTIONS_REQUIRED", "record",
                "This disposition requires declared independence and mandate")
        end
    end

    if publication and not record.complaint.privacy.allow_public_summary then
        fail("PUBLIC_SUMMARY_PERMISSION_REQUIRED", "record.publication_status",
            "Public-summary eligibility requires recorded permission")
    end
end

local function validate(input)
    plain(input, "record")
    local schema

    if input.record_type == "complaint" then
        schema = COMPLAINT
    elseif input.record_type == "review_decision" then
        schema = DECISION
    else
        fail("UNKNOWN_RECORD_TYPE", "record.record_type",
            "Expected complaint or review_decision")
    end

    local record = shape_copy(input, schema)
    if record.record_type == "complaint" then
        complaint_rules(record)
    else
        decision_rules(record)
    end
    return record
end

function M.validate(input)
    return protect(function() return validate(input) end)
end

function M.inspect(input, now)
    return protect(function()
        valid_time(now, "now")
        local record = validate(input)
        local complaint = record.record_type == "complaint"
            and record or record.complaint
        local latest = record.record_type == "complaint"
            and complaint.received_at_unix_s or record.recorded_at_unix_s

        if now < latest then
            fail("ASSESSMENT_TIME_ORDER", "now",
                "Assessment cannot precede the supplied record")
        end

        local retention = complaint.privacy.retention
        local result = {
            schema_version = VERSION,
            record_type = record.record_type,
            validation = "declared_contract_satisfied",
            retention_review_due = now >= retention.review_due_unix_s,
            deletion_endpoint_reached =
                now >= retention.delete_after_unix_s,
            execution_authority = "none",
            scope =
                "Record consistency only; no evidence authentication, "
                .. "delivery verification, legal finding, or publication."
        }

        if record.record_type == "review_decision" then
            local response = record.response_recorded_at_unix_s
            if response == nil then
                result.response_timing = now >= record.response_due_at_unix_s
                    and "due_without_recorded_response" or "not_yet_due"
            else
                result.response_timing =
                    response <= record.response_due_at_unix_s
                    and "recorded_by_deadline" or "recorded_after_deadline"
            end
            result.publication_status = record.publication_status
        end

        return result
    end)
end

function M.example(record_type)
    local complaint = {
        record_type = "complaint",
        schema_version = VERSION,
        attribution = ATTRIBUTION,
        attribution_scope = ATTRIBUTION_SCOPE,
        environment = "synthetic",
        received_at_unix_s = 100,
        origin = "fictional_test",
        summary = "Synthetic communication update concern",
        requested_outcome = "Review a written correction route",
        communication_mode = "asynchronous_text",
        additional_time_requested = true,
        privacy = {
            purpose = "complaint_review",
            data_class = "synthetic",
            allow_external_contact = false,
            allow_public_summary = false,
            retention = {
                policy_version = "synthetic-policy-1",
                review_due_unix_s = 200,
                delete_after_unix_s = 300
            }
        },
        safeguards = {
            private_inventory_not_required = true,
            non_retaliation_required = true,
            direct_participation_preserved = true
        }
    }

    if record_type == "complaint" then return complaint end
    if record_type == "review_decision" then
        return {
            record_type = "review_decision",
            schema_version = VERSION,
            complaint = complaint,
            recorded_at_unix_s = 120,
            response_due_at_unix_s = 150,
            response_delivery = "not_attempted",
            disposition = "pending",
            reasons = "Independent review pending",
            reviewer_role = "Intake coordinator",
            independence = "not_assessed",
            mandate = "not_verified",
            publication_status = "not_requested",
            execution_authority = "none"
        }
    end
    return nil, {
        code = "UNKNOWN_RECORD_TYPE",
        path = "record_type",
        message = "Expected complaint or review_decision"
    }
end

function M.self_test()
    assert(M.validate(M.example("complaint")))
    assert(M.validate(M.example("review_decision")))

    local record = M.example("complaint")
    record.neural_recording = {}
    local value, err = M.validate(record)
    assert(value == nil and err.code == "UNKNOWN_FIELD")

    record = M.example("review_decision")
    record.response_delivery = "confirmed"
    value, err = M.validate(record)
    assert(value == nil and err.code == "RESPONSE_REQUIRED")

    record = M.example("review_decision")
    record.disposition = "nonbinding_recommendation"
    value, err = M.validate(record)
    assert(value == nil and err.code == "REVIEW_ASSERTIONS_REQUIRED")

    record = M.example("complaint")
    record.privacy.retention.review_due_unix_s = 99
    value, err = M.validate(record)
    assert(value == nil and err.code == "RETENTION_ORDER")

    record = M.example("review_decision")
    record.response_recorded_at_unix_s = 121
    value, err = M.validate(record)
    assert(value == nil and err.code == "RESPONSE_TIME_ORDER")

    local inspected = assert(M.inspect(M.example("review_decision"), 160))
    assert(inspected.response_timing == "due_without_recorded_response")
    assert(inspected.execution_authority == "none")

    record = M.example("complaint")
    local copy = assert(M.validate(record))
    copy.privacy.allow_public_summary = true
    assert(record.privacy.allow_public_summary == false)

    return true
end

return M
