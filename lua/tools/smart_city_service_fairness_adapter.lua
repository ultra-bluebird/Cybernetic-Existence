local FairnessAdapter = {}
FairnessAdapter.__index = FairnessAdapter

local sensitive_fields = {
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

local required_numeric_features = {
    "accessibility_success_rate",
    "identity_neutral_decision_rate",
    "assistive_accommodation_rate",
    "continuity_preservation_rate",
    "privacy_preserving_flow_rate",
    "decision_explanation_rate",
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
    value = finite_number(value, "feature value")

    if value < 0 then
        return 0
    end

    if value > 1 then
        return 1
    end

    return value
end

local function copy_value(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic telemetry values are not supported")
    seen[value] = true

    local copied = {}
    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function stable_reference(namespace, text)
    local state = 2166136261
    local source = namespace .. "|" .. text

    for index = 1, #source do
        state = (state * 16777619 + source:byte(index)) % 4294967296
    end

    return string.format("audit:%08x", state)
end

local function redact_fields(value, path, redactions, visited)
    if type(value) ~= "table" then
        return copy_value(value)
    end

    visited = visited or {}
    assert(not visited[value], "cyclic telemetry values are not supported")
    visited[value] = true

    local result = {}

    for key, item in pairs(value) do
        local key_text = tostring(key)
        local normalized = key_text:lower()
        local item_path = path == "" and key_text or path .. "." .. key_text

        if sensitive_fields[normalized] then
            redactions[#redactions + 1] = {
                path = item_path,
                category = normalized,
            }
        else
            result[key_text] = redact_fields(item, item_path, redactions, visited)
        end
    end

    visited[value] = nil
    return result
end

function FairnessAdapter.new(config)
    config = config or {}

    return setmetatable({
        namespace = required_text(
            config.namespace or "smart-city-fairness-adapter",
            "namespace"
        ),
        service_defaults = copy_value(config.service_defaults or {}),
        sequence = 0,
        audit_events = {},
    }, FairnessAdapter)
end

function FairnessAdapter:adapt(telemetry)
    assert(type(telemetry) == "table", "telemetry must be a table")

    local service_id = required_text(telemetry.service_id, "service_id")
    local snapshot_id = required_text(telemetry.snapshot_id, "snapshot_id")
    local metrics = telemetry.metrics or {}

    assert(type(metrics) == "table", "telemetry.metrics must be a table")

    local redactions = {}
    local safe_metrics = redact_fields(metrics, "metrics", redactions)

    local features = {}
    local missing_features = {}

    for _, feature_name in ipairs(required_numeric_features) do
        local raw_value = safe_metrics[feature_name]

        if raw_value == nil then
            raw_value = self.service_defaults[service_id]
                and self.service_defaults[service_id][feature_name]
        end

        if raw_value == nil then
            missing_features[#missing_features + 1] = feature_name
            features[feature_name] = 0
        else
            features[feature_name] = clamp01(raw_value)
        end
    end

    local audit_reference = stable_reference(
        self.namespace,
        service_id .. "|" .. snapshot_id
    )

    local evidence_complete = #missing_features == 0
    local feature_sum = 0

    for _, feature_name in ipairs(required_numeric_features) do
        feature_sum = feature_sum + features[feature_name]
    end

    local average_feature_score = feature_sum / #required_numeric_features
    local harm_risk = clamp01(
        (1 - average_feature_score) * 0.70
        + (#missing_features > 0 and 0.20 or 0)
    )

    local result = {
        service_id = service_id,
        snapshot_reference = audit_reference,
        observed_at_utc = telemetry.observed_at_utc
            or os.date("!%Y-%m-%dT%H:%M:%SZ"),
        features = features,
        evidence_complete = evidence_complete,
        missing_features = missing_features,
        redactions = redactions,
        raw_identifier_disclosed = false,
        knowledge_factor = evidence_complete and 0.85 or 0.55,
        eco_impact_value = clamp01(telemetry.eco_impact_value or 0.50),
        harm_risk = harm_risk,
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence

    self.audit_events[#self.audit_events + 1] = {
        sequence = result.sequence,
        service_id = result.service_id,
        snapshot_reference = result.snapshot_reference,
        observed_at_utc = result.observed_at_utc,
        evidence_complete = result.evidence_complete,
        missing_feature_count = #result.missing_features,
        redaction_count = #result.redactions,
        raw_identifier_disclosed = false,
        knowledge_factor = result.knowledge_factor,
        eco_impact_value = result.eco_impact_value,
        harm_risk = result.harm_risk,
    }

    return result
end

function FairnessAdapter:report_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")
    assert(sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer")

    local events = {}
    local highest_harm_risk = 0
    local complete = 0

    for _, event in ipairs(self.audit_events) do
        if event.sequence > sequence then
            events[#events + 1] = copy_value(event)
            highest_harm_risk = math.max(highest_harm_risk, event.harm_risk)

            if event.evidence_complete then
                complete = complete + 1
            end
        end
    end

    local total = #events

    return {
        from_sequence = sequence,
        total = total,
        evidence_complete_count = complete,
        evidence_incomplete_count = total - complete,
        events = events,
        knowledge_factor = total == 0 and 0 or complete / total,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
end

return FairnessAdapter
