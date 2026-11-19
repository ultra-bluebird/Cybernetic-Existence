-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/public_perception_sentiment_analyzer.lua
-- Destination: lua/tools/

local PublicPerceptionSentimentAnalyzer = {}
PublicPerceptionSentimentAnalyzer.__index = PublicPerceptionSentimentAnalyzer

local positive_terms = {
    "accessible",
    "accommodation",
    "belonging",
    "community",
    "dignity",
    "equal access",
    "fair",
    "inclusive",
    "inclusion",
    "respect",
    "rights",
    "support",
    "welcome",
}

local negative_terms = {
    "ban",
    "dangerous",
    "deny",
    "exclude",
    "hostile",
    "inferior",
    "remove access",
    "segregate",
    "target",
    "threat",
    "unwelcome",
}

local high_risk_terms = {
    "ban augmented",
    "deny service",
    "exclude augmented",
    "remove access",
    "segregate augmented",
    "target augmented",
}

local sensitive_fields = {
    address = true,
    biometric = true,
    device_id = true,
    email = true,
    full_name = true,
    government_id = true,
    ip_address = true,
    location = true,
    medical_record = true,
    phone = true,
    raw_identifier = true,
    social_security = true,
    voiceprint = true,
}

local allowed_sources = {
    community_forum = true,
    news_summary = true,
    public_comment = true,
    public_policy_record = true,
    public_social_post = true,
}

local function required_text(value, field)
    assert(type(value) == "string" and value:match("%S"),
        (field or "value") .. " must be a non-empty string")
    return value
end

local function finite_number(value, field)
    assert(
        type(value) == "number"
            and value == value
            and value ~= math.huge
            and value ~= -math.huge,
        (field or "value") .. " must be a finite number"
    )
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

local function utc_now()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function copy_value(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic discourse records are not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function stable_reference(namespace, value)
    local state = 2166136261
    local material = namespace .. "|" .. value

    for index = 1, #material do
        state = (state * 16777619 + material:byte(index)) % 4294967296
    end

    return string.format("discourse:%08x", state)
end

local function redact_text(text)
    local redaction_count = 0

    local function replace(pattern, replacement)
        text = text:gsub(pattern, function()
            redaction_count = redaction_count + 1
            return replacement
        end)
    end

    replace(
        "[%w%._%+%-]+@[%w%-]+%.[%w%.%-]+",
        "[REDACTED:EMAIL]"
    )

    replace(
        "%f[%d]%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?%f[%D]",
        "[REDACTED:IP_ADDRESS]"
    )

    replace(
        "%f[%d]%d%d%d?%-%d%d%-%d%d%d%d%f[%D]",
        "[REDACTED:IDENTIFIER]"
    )

    replace(
        "%f[%d]%d%d?%d?[%s%-%)]%d%d%d[%s%-]%d%d%d%d%f[%D]",
        "[REDACTED:PHONE]"
    )

    return text, redaction_count
end

local function redact_fields(value, redactions, path, seen)
    if type(value) ~= "table" then
        if type(value) == "string" then
            local sanitized, count = redact_text(value)

            if count > 0 then
                redactions[#redactions + 1] = {
                    path = path,
                    category = "sensitive_text",
                    count = count,
                }
            end

            return sanitized
        end

        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic discourse data is not supported")
    seen[value] = true

    local sanitized = {}

    for key, item in pairs(value) do
        local key_text = tostring(key)
        local normalized = key_text:lower()
        local item_path = path == "" and key_text or path .. "." .. key_text

        if sensitive_fields[normalized] then
            sanitized[key_text] = "[REDACTED:" .. normalized:upper() .. "]"
            redactions[#redactions + 1] = {
                path = item_path,
                category = normalized,
                count = 1,
            }
        else
            sanitized[key_text] = redact_fields(
                item,
                redactions,
                item_path,
                seen
            )
        end
    end

    seen[value] = nil
    return sanitized
end

local function count_terms(text, terms)
    local normalized = text:lower()
    local matches = {}

    for _, term in ipairs(terms) do
        local start_at = 1
        local count = 0

        while true do
            local found_at = normalized:find(term, start_at, true)

            if not found_at then
                break
            end

            count = count + 1
            start_at = found_at + #term
        end

        if count > 0 then
            matches[term] = count
        end
    end

    return matches
end

local function total_matches(matches)
    local total = 0

    for _, count in pairs(matches) do
        total = total + count
    end

    return total
end

local function risk_level(hostility_score, high_risk_count)
    if high_risk_count > 0 or hostility_score >= 0.75 then
        return "high"
    end

    if hostility_score >= 0.45 then
        return "elevated"
    end

    if hostility_score >= 0.20 then
        return "watch"
    end

    return "low"
end

function PublicPerceptionSentimentAnalyzer.new(config)
    config = config or {}

    return setmetatable({
        namespace = required_text(
            config.namespace or "public-perception-sentiment",
            "namespace"
        ),
        findings = {},
        sequence = 0,
    }, PublicPerceptionSentimentAnalyzer)
end

function PublicPerceptionSentimentAnalyzer:analyze(record)
    assert(type(record) == "table", "record must be a table")

    local source_kind = required_text(record.source_kind, "source_kind")
    assert(allowed_sources[source_kind], "unsupported public discourse source")

    local public_text = required_text(record.text, "record.text")
    local redactions = {}
    local sanitized_context = redact_fields(
        record.context or {},
        redactions,
        "context"
    )
    local sanitized_text, text_redaction_count = redact_text(public_text)

    if text_redaction_count > 0 then
        redactions[#redactions + 1] = {
            path = "text",
            category = "sensitive_text",
            count = text_redaction_count,
        }
    end

    local positive_matches = count_terms(sanitized_text, positive_terms)
    local negative_matches = count_terms(sanitized_text, negative_terms)
    local high_risk_matches = count_terms(sanitized_text, high_risk_terms)

    local positive_count = total_matches(positive_matches)
    local negative_count = total_matches(negative_matches)
    local high_risk_count = total_matches(high_risk_matches)
    local total_sentiment_terms = positive_count + negative_count

    local support_score = total_sentiment_terms == 0
        and 0.50
        or positive_count / total_sentiment_terms

    local hostility_score = clamp01(
        (total_sentiment_terms == 0 and 0.10 or negative_count / total_sentiment_terms)
            + math.min(0.45, high_risk_count * 0.20)
    )

    local discourse_reference = stable_reference(
        self.namespace,
        required_text(record.local_record_nonce, "local_record_nonce")
    )

    local result = {
        discourse_reference = discourse_reference,
        source_kind = source_kind,
        public_text_retained = false,
        raw_author_identifier_retained = false,
        sanitized_context = sanitized_context,
        positive_matches = positive_matches,
        negative_matches = negative_matches,
        high_risk_matches = high_risk_matches,
        support_score = support_score,
        hostility_score = hostility_score,
        alert_level = risk_level(hostility_score, high_risk_count),
        early_warning = hostility_score >= 0.45 or high_risk_count > 0,
        redactions = redactions,
        knowledge_factor = record.evidence_complete == true and 0.80 or 0.55,
        eco_impact_value = clamp01(record.eco_impact_value or 0.50),
        harm_risk = clamp01(
            hostility_score * 0.75
                + (record.evidence_complete ~= true and 0.15 or 0)
        ),
        analyzed_at_utc = record.analyzed_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.findings[#self.findings + 1] = copy_value(result)

    return result
end

function PublicPerceptionSentimentAnalyzer:analyze_batch(records)
    assert(type(records) == "table", "records must be a table")

    local results = {}
    local alert_counts = {
        low = 0,
        watch = 0,
        elevated = 0,
        high = 0,
    }
    local highest_hostility_score = 0
    local highest_harm_risk = 0

    for _, record in ipairs(records) do
        local result = self:analyze(record)

        results[#results + 1] = result
        alert_counts[result.alert_level] =
            alert_counts[result.alert_level] + 1
        highest_hostility_score = math.max(
            highest_hostility_score,
            result.hostility_score
        )
        highest_harm_risk = math.max(
            highest_harm_risk,
            result.harm_risk
        )
    end

    local count = #results
    local total_support = 0
    local total_knowledge = 0

    for _, result in ipairs(results) do
        total_support = total_support + result.support_score
        total_knowledge = total_knowledge + result.knowledge_factor
    end

    return {
        record_count = count,
        results = results,
        alert_counts = alert_counts,
        average_support_score = count == 0 and 0 or total_support / count,
        highest_hostility_score = highest_hostility_score,
        early_warning_required = alert_counts.elevated > 0
            or alert_counts.high > 0,
        knowledge_factor = count == 0 and 0 or total_knowledge / count,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        analyzed_at_utc = utc_now(),
    }
end

function PublicPerceptionSentimentAnalyzer:report_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")

    assert(
        sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer"
    )

    local results = {}
    local highest_harm_risk = 0
    local highest_hostility_score = 0

    for _, result in ipairs(self.findings) do
        if result.sequence > sequence then
            results[#results + 1] = copy_value(result)
            highest_harm_risk = math.max(
                highest_harm_risk,
                result.harm_risk
            )
            highest_hostility_score = math.max(
                highest_hostility_score,
                result.hostility_score
            )
        end
    end

    return {
        from_sequence = sequence,
        result_count = #results,
        results = results,
        highest_hostility_score = highest_hostility_score,
        early_warning_required = highest_hostility_score >= 0.45,
        knowledge_factor = #results == 0 and 0 or (function()
            local total = 0

            for _, result in ipairs(results) do
                total = total + result.knowledge_factor
            end

            return total / #results
        end)(),
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return PublicPerceptionSentimentAnalyzer
