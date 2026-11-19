local RedactionPipeline = {}
RedactionPipeline.__index = RedactionPipeline

local default_sensitive_fields = {
    "address",
    "biometric",
    "birthdate",
    "date_of_birth",
    "device_id",
    "email",
    "face_embedding",
    "fingerprint",
    "full_name",
    "government_id",
    "hardware_serial",
    "ip_address",
    "iris",
    "location",
    "mac_address",
    "medical_record",
    "phone",
    "raw_identifier",
    "retina",
    "social_security",
    "voiceprint",
}

local default_text_rules = {
    {
        name = "email",
        pattern = "[%w%._%+%-]+@[%w%-]+%.[%w%.%-]+",
        replacement = "[REDACTED:EMAIL]",
    },
    {
        name = "ipv4",
        pattern = "%f[%d]%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?%f[%D]",
        replacement = "[REDACTED:IP_ADDRESS]",
    },
    {
        name = "mac_address",
        pattern = "%f[%x][%x][%x]:[%x][%x]:[%x][%x]:[%x][%x]:[%x][%x]:[%x][%x]%f[^%x]",
        replacement = "[REDACTED:MAC_ADDRESS]",
    },
    {
        name = "government_identifier_like",
        pattern = "%f[%d]%d%d%d?%-%d%d%-%d%d%d%d%f[%D]",
        replacement = "[REDACTED:GOVERNMENT_IDENTIFIER]",
    },
    {
        name = "phone_like",
        pattern = "%f[%d]%d%d?%d?[%s%-%)]%d%d%d[%s%-]%d%d%d%d%f[%D]",
        replacement = "[REDACTED:PHONE]",
    },
}

local function required_text(value, field)
    assert(type(value) == "string" and value:match("%S"),
        (field or "value") .. " must be a non-empty string")
    return value
end

local function finite_number(value, field)
    assert(type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge,
        (field or "value") .. " must be a finite number")
    return value
end

local function clamp01(value)
    value = finite_number(value, "score")

    if value < 0 then
        return 0
    end

    if value > 1 then
        return 1
    end

    return value
end

local function copy_value(value, seen)
    local kind = type(value)

    if kind ~= "table" then
        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic tables are not valid pipeline inputs")
    seen[value] = true

    local copied = {}
    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function redact_text(text, rules)
    local result = text
    local matches = {}

    for _, rule in ipairs(rules) do
        local redaction_count = 0

        result = result:gsub(rule.pattern, function()
            redaction_count = redaction_count + 1
            return rule.replacement
        end)

        if redaction_count > 0 then
            matches[#matches + 1] = {
                category = rule.name,
                count = redaction_count,
            }
        end
    end

    return result, matches
end

local function merge_matches(target, source)
    for _, match in ipairs(source) do
        target[#target + 1] = match
    end
end

local function append_path(path, key)
    if path == "" then
        return tostring(key)
    end

    return path .. "." .. tostring(key)
end

function RedactionPipeline.new(config)
    config = config or {}

    local sensitive_fields = {}
    for field in pairs(default_sensitive_fields) do
        sensitive_fields[field] = true
    end

    for _, field in ipairs(config.additional_sensitive_fields or {}) do
        sensitive_fields[required_text(field, "additional sensitive field"):lower()] = true
    end

    local rules = copy_value(default_text_rules)
    for _, rule in ipairs(config.additional_text_rules or {}) do
        assert(type(rule) == "table", "additional text rule must be a table")
        rules[#rules + 1] = {
            name = required_text(rule.name, "text rule name"),
            pattern = required_text(rule.pattern, "text rule pattern"),
            replacement = required_text(rule.replacement, "text rule replacement"),
        }
    end

    return setmetatable({
        sensitive_fields = sensitive_fields,
        text_rules = rules,
        audit_log = {},
        sequence = 0,
        maximum_harm_risk = clamp01(config.maximum_harm_risk or 0.20),
    }, RedactionPipeline)
end

function RedactionPipeline:_redact_value(value, path, report, visited)
    local kind = type(value)

    if kind == "string" then
        local redacted, matches = redact_text(value, self.text_rules)
        merge_matches(report.text_redactions, matches)

        if #matches > 0 then
            report.changed_paths[#report.changed_paths + 1] = path
        end

        return redacted
    end

    if kind ~= "table" then
        return value
    end

    visited = visited or {}
    assert(not visited[value], "cyclic tables are not valid pipeline inputs")
    visited[value] = true

    local redacted = {}

    for key, item in pairs(value) do
        local key_text = tostring(key)
        local normalized_key = key_text:lower()
        local item_path = append_path(path, key_text)

        if self.sensitive_fields[normalized_key] then
            redacted[key_text] = "[REDACTED:" .. normalized_key:upper() .. "]"
            report.field_redactions[#report.field_redactions + 1] = {
                path = item_path,
                category = normalized_key,
            }
            report.changed_paths[#report.changed_paths + 1] = item_path
        else
            redacted[key_text] = self:_redact_value(item, item_path, report, visited)
        end
    end

    visited[value] = nil
    return redacted
end

function RedactionPipeline:redact(payload, context)
    context = context or {}
    assert(type(context) == "table", "context must be a table")

    local report = {
        source_kind = context.source_kind or "unspecified",
        destination_kind = context.destination_kind or "local",
        field_redactions = {},
        text_redactions = {},
        changed_paths = {},
    }

    local redacted_payload = self:_redact_value(payload, "payload", report)

    local text_redaction_count = 0
    for _, item in ipairs(report.text_redactions) do
        text_redaction_count = text_redaction_count + item.count
    end

    local redaction_count = #report.field_redactions + text_redaction_count
    local harm_risk = redaction_count == 0 and 0.05 or 0.12

    report.redaction_count = redaction_count
    report.accepted = harm_risk <= self.maximum_harm_risk
    report.knowledge_factor = context.schema_validated == true and 0.85 or 0.60
    report.eco_impact_value = 0.50
    report.harm_risk = harm_risk
    report.processed_at_utc = context.processed_at_utc or os.date("!%Y-%m-%dT%H:%M:%SZ")

    self.sequence = self.sequence + 1
    report.sequence = self.sequence
    self.audit_log[#self.audit_log + 1] = {
        sequence = report.sequence,
        source_kind = report.source_kind,
        destination_kind = report.destination_kind,
        redaction_count = report.redaction_count,
        accepted = report.accepted,
        knowledge_factor = report.knowledge_factor,
        eco_impact_value = report.eco_impact_value,
        harm_risk = report.harm_risk,
        processed_at_utc = report.processed_at_utc,
    }

    return {
        payload = redacted_payload,
        report = report,
    }
end

function RedactionPipeline:process_outbound(payload, destination_kind, context)
    context = context or {}
    assert(type(context) == "table", "context must be a table")

    context.destination_kind = required_text(destination_kind, "destination_kind")
    context.source_kind = context.source_kind or "local"

    local result = self:redact(payload, context)

    assert(result.report.accepted,
        "outbound payload did not meet the configured harm-risk threshold")

    return result
end

function RedactionPipeline:audit_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")
    assert(sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer")

    local events = {}
    local accepted = 0
    local rejected = 0
    local highest_harm_risk = 0

    for _, event in ipairs(self.audit_log) do
        if event.sequence > sequence then
            events[#events + 1] = copy_value(event)
            highest_harm_risk = math.max(highest_harm_risk, event.harm_risk)

            if event.accepted then
                accepted = accepted + 1
            else
                rejected = rejected + 1
            end
        end
    end

    local total = accepted + rejected

    return {
        from_sequence = sequence,
        total = total,
        accepted = accepted,
        rejected = rejected,
        highest_harm_risk = highest_harm_risk,
        events = events,
        knowledge_factor = total == 0 and 0 or accepted / total,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
end

return RedactionPipeline
