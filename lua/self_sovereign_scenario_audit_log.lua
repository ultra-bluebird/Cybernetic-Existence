local AuditLog = {}

local function assert_nonempty_string(value, field_name)
    if type(value) ~= "string" or value == "" then
        error(field_name .. " must be a non-empty string", 3)
    end
end

local function assert_boolean(value, field_name)
    if type(value) ~= "boolean" then
        error(field_name .. " must be boolean", 3)
    end
end

local function assert_integer(value, field_name)
    if type(value) ~= "number"
        or value ~= math.floor(value)
        or value < 0 then
        error(field_name .. " must be a non-negative integer", 3)
    end
end

local function assert_sha256_hex(value, field_name)
    assert_nonempty_string(value, field_name)

    if #value ~= 64 or value:match("^[a-f0-9]+$") == nil then
        error(field_name .. " must be a lowercase SHA-256 hexadecimal digest", 3)
    end
end

local function canonical_escape(value)
    return value
        :gsub("\\", "\\\\")
        :gsub("\"", "\\\"")
        :gsub("\b", "\\b")
        :gsub("\f", "\\f")
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
end

local function canonical_scalar(value)
    local value_type = type(value)

    if value_type == "string" then
        return "\"" .. canonical_escape(value) .. "\""
    end

    if value_type == "boolean" then
        return value and "true" or "false"
    end

    if value_type == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            error("canonical serialization rejects non-finite numbers", 3)
        end

        return string.format("%.17g", value)
    end

    if value == nil then
        return "null"
    end

    error("unsupported scalar type: " .. value_type, 3)
end

local function is_array(value)
    if type(value) ~= "table" then
        return false
    end

    local count = 0

    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
            return false
        end

        count = count + 1
    end

    for index = 1, count do
        if value[index] == nil then
            return false
        end
    end

    return true
end

local function canonical_json(value)
    local value_type = type(value)

    if value_type ~= "table" then
        return canonical_scalar(value)
    end

    if is_array(value) then
        local parts = {}

        for index = 1, #value do
            parts[index] = canonical_json(value[index])
        end

        return "[" .. table.concat(parts, ",") .. "]"
    end

    local keys = {}

    for key, _ in pairs(value) do
        if type(key) ~= "string" then
            error("object keys must be strings", 3)
        end

        keys[#keys + 1] = key
    end

    table.sort(keys)

    local parts = {}

    for _, key in ipairs(keys) do
        parts[#parts + 1] = canonical_scalar(key) .. ":" .. canonical_json(value[key])
    end

    return "{" .. table.concat(parts, ",") .. "}"
end

local function read_all(path)
    local handle, open_error = io.open(path, "rb")

    if handle == nil then
        return nil, open_error
    end

    local content = handle:read("*a")
    handle:close()

    return content, nil
end

local function write_all(path, content)
    local handle, open_error = io.open(path, "wb")

    if handle == nil then
        return nil, open_error
    end

    local written, write_error = handle:write(content)

    if written == nil then
        handle:close()
        return nil, write_error
    end

    handle:flush()
    handle:close()

    return true, nil
end

local function sha256_hex(bytes)
    assert_nonempty_string(bytes, "bytes")

    local command = "sha256sum"
    local temporary_path = os.tmpname()
    local ok, write_error = write_all(temporary_path, bytes)

    if not ok then
        error("unable to write temporary hashing input: " .. tostring(write_error), 3)
    end

    local process = io.popen(command .. " " .. string.format("%q", temporary_path), "r")

    if process == nil then
        os.remove(temporary_path)
        error("sha256sum command is unavailable", 3)
    end

    local output = process:read("*a")
    local success = process:close()
    os.remove(temporary_path)

    if success ~= true then
        error("sha256sum command failed", 3)
    end

    local digest = output:match("^([a-f0-9]+)")

    if digest == nil or #digest ~= 64 then
        error("sha256sum output was invalid", 3)
    end

    return digest
end

local function entry_payload(entry)
    return {
        audit_version = entry.audit_version,
        sequence = entry.sequence,
        recorded_at_utc = entry.recorded_at_utc,
        scenario_digest = entry.scenario_digest,
        parent_scenario_digest = entry.parent_scenario_digest,
        safety_assessment_digest = entry.safety_assessment_digest,
        workflow_result_digest = entry.workflow_result_digest,
        reviewer_pseudonym = entry.reviewer_pseudonym,
        reviewer_role = entry.reviewer_role,
        review_outcome = entry.review_outcome,
        review_scope = entry.review_scope,
        decision_state = entry.decision_state,
        reason_codes = entry.reason_codes,
        policy_digest = entry.policy_digest,
        previous_entry_digest = entry.previous_entry_digest,
        reviewer_attestation_digest = entry.reviewer_attestation_digest
    }
end

local function compute_entry_digest(entry)
    return sha256_hex(canonical_json(entry_payload(entry)))
end

local function validate_entry(entry)
    if type(entry) ~= "table" then
        return false, "entry must be a table"
    end

    assert_nonempty_string(entry.audit_version, "audit_version")
    assert_integer(entry.sequence, "sequence")
    assert_nonempty_string(entry.recorded_at_utc, "recorded_at_utc")
    assert_sha256_hex(entry.scenario_digest, "scenario_digest")
    assert_sha256_hex(entry.safety_assessment_digest, "safety_assessment_digest")
    assert_sha256_hex(entry.workflow_result_digest, "workflow_result_digest")
    assert_nonempty_string(entry.reviewer_pseudonym, "reviewer_pseudonym")
    assert_nonempty_string(entry.reviewer_role, "reviewer_role")
    assert_nonempty_string(entry.review_outcome, "review_outcome")
    assert_nonempty_string(entry.review_scope, "review_scope")
    assert_nonempty_string(entry.decision_state, "decision_state")
    assert_sha256_hex(entry.policy_digest, "policy_digest")
    assert_sha256_hex(entry.previous_entry_digest, "previous_entry_digest")
    assert_sha256_hex(entry.reviewer_attestation_digest, "reviewer_attestation_digest")
    assert_sha256_hex(entry.entry_digest, "entry_digest")

    if entry.parent_scenario_digest ~= nil then
        assert_sha256_hex(entry.parent_scenario_digest, "parent_scenario_digest")
    end

    if type(entry.reason_codes) ~= "table" or not is_array(entry.reason_codes) then
        error("reason_codes must be an array", 3)
    end

    for _, reason_code in ipairs(entry.reason_codes) do
        assert_nonempty_string(reason_code, "reason_code")
    end

    if entry.decision_state ~= "simulate"
        and entry.decision_state ~= "derate"
        and entry.decision_state ~= "hold"
        and entry.decision_state ~= "reject" then
        return false, "decision_state is invalid"
    end

    return true, nil
end

function AuditLog.create_genesis_digest(audit_name, audit_scope)
    assert_nonempty_string(audit_name, "audit_name")
    assert_nonempty_string(audit_scope, "audit_scope")

    return sha256_hex(canonical_json({
        audit_name = audit_name,
        audit_scope = audit_scope,
        format = "cyboquatic-self-sovereign-audit-log",
        version = "1.0.0"
    }))
end

function AuditLog.append_entry(
    log_path,
    prior_entry_digest,
    entry
)
    assert_nonempty_string(log_path, "log_path")
    assert_sha256_hex(prior_entry_digest, "prior_entry_digest")

    if type(entry) ~= "table" then
        error("entry must be a table", 2)
    end

    entry.previous_entry_digest = prior_entry_digest
    entry.entry_digest = compute_entry_digest(entry)

    local valid, validation_error = validate_entry(entry)

    if not valid then
        error(validation_error, 2)
    end

    local existing, read_error = read_all(log_path)

    if existing == nil and read_error ~= nil then
        existing = ""
    end

    local line = canonical_json(entry) .. "\n"
    local ok, write_error = write_all(log_path .. ".pending", (existing or "") .. line)

    if not ok then
        error("unable to write pending log: " .. tostring(write_error), 2)
    end

    local renamed, rename_error = os.rename(log_path .. ".pending", log_path)

    if not renamed then
        os.remove(log_path .. ".pending")
        error("unable to atomically replace log: " .. tostring(rename_error), 2)
    end

    return entry.entry_digest
end

function AuditLog.verify_entries(entries, genesis_digest)
    assert_sha256_hex(genesis_digest, "genesis_digest")

    if type(entries) ~= "table" or not is_array(entries) then
        return {
            valid = false,
            error = "entries must be an array"
        }
    end

    local prior_digest = genesis_digest
    local expected_sequence = 0

    for index, entry in ipairs(entries) do
        local valid, validation_error = validate_entry(entry)

        if not valid then
            return {
                valid = false,
                entry_index = index,
                error = validation_error
            }
        end

        if entry.sequence ~= expected_sequence then
            return {
                valid = false,
                entry_index = index,
                error = "sequence is not contiguous"
            }
        end

        if entry.previous_entry_digest ~= prior_digest then
            return {
                valid = false,
                entry_index = index,
                error = "previous entry digest does not match"
            }
        end

        local computed_digest = compute_entry_digest(entry)

        if computed_digest ~= entry.entry_digest then
            return {
                valid = false,
                entry_index = index,
                error = "entry digest mismatch"
            }
        end

        prior_digest = entry.entry_digest
        expected_sequence = expected_sequence + 1
    end

    return {
        valid = true,
        final_entry_digest = prior_digest,
        verified_entry_count = #entries
    }
end

function AuditLog.load_entries(log_path, json_decode)
    assert_nonempty_string(log_path, "log_path")

    if type(json_decode) ~= "function" then
        error("json_decode must be a function", 2)
    end

    local content, read_error = read_all(log_path)

    if content == nil then
        return nil, read_error
    end

    local entries = {}

    for line in content:gmatch("[^\r\n]+") do
        local entry = json_decode(line)

        if type(entry) ~= "table" then
            return nil, "invalid JSON line in audit log"
        end

        entries[#entries + 1] = entry
    end

    return entries, nil
end

return AuditLog
