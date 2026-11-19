-- Repository: mk-bluebird/Augmented-Hub
-- Filename: lua/tools/bci_latency_guard.lua
-- Destination: lua/tools/

local BciLatencyGuard = {}
BciLatencyGuard.__index = BciLatencyGuard

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

local function utc_now()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function copy_value(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic samples are not supported")
    seen[value] = true

    local copied = {}
    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function mean(values)
    if #values == 0 then
        return 0
    end

    local total = 0
    for _, value in ipairs(values) do
        total = total + value
    end

    return total / #values
end

local function bounded_append(values, value, capacity)
    values[#values + 1] = value

    while #values > capacity do
        table.remove(values, 1)
    end
end

function BciLatencyGuard.new(config)
    config = config or {}

    return setmetatable({
        maximum_latency_ms = math.max(
            1,
            finite_number(config.maximum_latency_ms or 350, "maximum_latency_ms")
        ),
        minimum_reliability = clamp01(config.minimum_reliability or 0.80),
        minimum_confidence = clamp01(config.minimum_confidence or 0.85),
        sample_window = math.max(
            1,
            math.floor(finite_number(config.sample_window or 10, "sample_window"))
        ),
        default_fallbacks = copy_value(config.default_fallbacks or {
            "adaptive_switch",
            "screen_reader",
            "speech",
            "keyboard",
            "text",
        }),
        sessions = {},
        audit_events = {},
        sequence = 0,
    }, BciLatencyGuard)
end

function BciLatencyGuard:start_session(session)
    assert(type(session) == "table", "session must be a table")

    local session_id = required_text(session.session_id, "session_id")
    assert(not self.sessions[session_id], "session_id already exists")

    local fallbacks = session.fallback_modalities or self.default_fallbacks
    assert(type(fallbacks) == "table", "fallback_modalities must be a table")

    self.sessions[session_id] = {
        session_id = session_id,
        subject_reference = required_text(
            session.subject_reference,
            "subject_reference"
        ),
        active_modality = "bci",
        fallback_modalities = copy_value(fallbacks),
        current_context = copy_value(session.current_context or {}),
        latency_samples_ms = {},
        reliability_samples = {},
        confidence_samples = {},
        fallback_history = {},
        active = true,
        started_at_utc = session.started_at_utc or utc_now(),
    }

    self:_audit("bci_session_started", session_id, {
        active_modality = "bci",
    })

    return copy_value(self.sessions[session_id])
end

function BciLatencyGuard:update_context(session_id, context)
    session_id = required_text(session_id, "session_id")
    assert(type(context) == "table", "context must be a table")

    local session = assert(self.sessions[session_id], "session not found")
    assert(session.active, "session is not active")

    session.current_context = copy_value(context)

    self:_audit("context_updated", session_id, {
        context_available = true,
    })

    return copy_value(session.current_context)
end

function BciLatencyGuard:observe(session_id, sample)
    session_id = required_text(session_id, "session_id")
    assert(type(sample) == "table", "sample must be a table")

    local session = assert(self.sessions[session_id], "session not found")
    assert(session.active, "session is not active")

    local latency_ms = math.max(
        0,
        finite_number(sample.latency_ms, "sample.latency_ms")
    )
    local reliability = clamp01(sample.reliability)
    local confidence = clamp01(sample.confidence)

    bounded_append(
        session.latency_samples_ms,
        latency_ms,
        self.sample_window
    )
    bounded_append(
        session.reliability_samples,
        reliability,
        self.sample_window
    )
    bounded_append(
        session.confidence_samples,
        confidence,
        self.sample_window
    )

    local average_latency_ms = mean(session.latency_samples_ms)
    local average_reliability = mean(session.reliability_samples)
    local average_confidence = mean(session.confidence_samples)

    local latency_ok = average_latency_ms <= self.maximum_latency_ms
    local reliability_ok = average_reliability >= self.minimum_reliability
    local confidence_ok = average_confidence >= self.minimum_confidence
    local accepted = latency_ok and reliability_ok and confidence_ok

    local result = {
        session_id = session_id,
        active_modality = session.active_modality,
        accepted = accepted,
        latest_latency_ms = latency_ms,
        latest_reliability = reliability,
        latest_confidence = confidence,
        average_latency_ms = average_latency_ms,
        average_reliability = average_reliability,
        average_confidence = average_confidence,
        thresholds = {
            maximum_latency_ms = self.maximum_latency_ms,
            minimum_reliability = self.minimum_reliability,
            minimum_confidence = self.minimum_confidence,
        },
        assessed_at_utc = sample.assessed_at_utc or utc_now(),
        knowledge_factor = #session.latency_samples_ms / self.sample_window,
        eco_impact_value = 0.50,
        harm_risk = clamp01(
            ((average_latency_ms > self.maximum_latency_ms) and 0.35 or 0)
            + ((average_reliability < self.minimum_reliability) and 0.35 or 0)
            + ((average_confidence < self.minimum_confidence) and 0.30 or 0)
        ),
    }

    if not accepted and session.active_modality == "bci" then
        result.fallback = self:activate_fallback(
            session_id,
            "bci_latency_or_reliability_threshold_not_met"
        )
        result.active_modality = session.active_modality
    end

    self:_audit("bci_sample_observed", session_id, {
        accepted = result.accepted,
        average_latency_ms = average_latency_ms,
        average_reliability = average_reliability,
        average_confidence = average_confidence,
        fallback_activated = result.fallback ~= nil,
    })

    return result
end

function BciLatencyGuard:activate_fallback(session_id, reason)
    session_id = required_text(session_id, "session_id")
    reason = required_text(reason, "reason")

    local session = assert(self.sessions[session_id], "session not found")
    assert(session.active, "session is not active")

    if session.active_modality ~= "bci" then
        return {
            activated = false,
            reason = "a fallback modality is already active",
            active_modality = session.active_modality,
            context = copy_value(session.current_context),
        }
    end

    local fallback_modality = session.fallback_modalities[1]

    if type(fallback_modality) ~= "string" or not fallback_modality:match("%S") then
        self:_audit("limited_assistive_mode_required", session_id, {
            reason = reason,
        })

        return {
            activated = false,
            reason = "no fallback modality is configured",
            active_modality = "text",
            context = copy_value(session.current_context),
        }
    end

    session.active_modality = fallback_modality
    session.fallback_history[#session.fallback_history + 1] = {
        from_modality = "bci",
        to_modality = fallback_modality,
        reason = reason,
        occurred_at_utc = utc_now(),
    }

    self:_audit("fallback_activated", session_id, {
        from_modality = "bci",
        to_modality = fallback_modality,
        reason = reason,
    })

    return {
        activated = true,
        active_modality = fallback_modality,
        reason = reason,
        context = copy_value(session.current_context),
        status_feedback = "BCI quality is below the local threshold; fallback is active.",
    }
end

function BciLatencyGuard:restore_bci(session_id)
    session_id = required_text(session_id, "session_id")

    local session = assert(self.sessions[session_id], "session not found")
    assert(session.active, "session is not active")

    local average_latency_ms = mean(session.latency_samples_ms)
    local average_reliability = mean(session.reliability_samples)
    local average_confidence = mean(session.confidence_samples)

    local suitable = average_latency_ms <= self.maximum_latency_ms
        and average_reliability >= self.minimum_reliability
        and average_confidence >= self.minimum_confidence

    if suitable then
        session.active_modality = "bci"
    end

    self:_audit("bci_restore_assessed", session_id, {
        restored = suitable,
        average_latency_ms = average_latency_ms,
        average_reliability = average_reliability,
        average_confidence = average_confidence,
    })

    return {
        restored = suitable,
        active_modality = session.active_modality,
        average_latency_ms = average_latency_ms,
        average_reliability = average_reliability,
        average_confidence = average_confidence,
        context = copy_value(session.current_context),
        knowledge_factor = #session.latency_samples_ms / self.sample_window,
        eco_impact_value = 0.50,
        harm_risk = suitable and 0.08 or 0.30,
    }
end

function BciLatencyGuard:end_session(session_id)
    session_id = required_text(session_id, "session_id")

    local session = assert(self.sessions[session_id], "session not found")
    session.active = false

    self:_audit("bci_session_ended", session_id, {
        final_modality = session.active_modality,
        fallback_count = #session.fallback_history,
    })

    return {
        session_id = session_id,
        final_modality = session.active_modality,
        fallback_count = #session.fallback_history,
        ended_at_utc = utc_now(),
    }
end

function BciLatencyGuard:_audit(event_type, session_id, details)
    self.sequence = self.sequence + 1

    self.audit_events[#self.audit_events + 1] = {
        sequence = self.sequence,
        event_type = event_type,
        session_reference = "bci-session-" .. session_id,
        details = copy_value(details or {}),
        occurred_at_utc = utc_now(),
        knowledge_factor = 0.80,
        eco_impact_value = 0.50,
        harm_risk = 0.10,
    }
end

function BciLatencyGuard:audit_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")
    assert(sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer")

    local events = {}
    local highest_harm_risk = 0

    for _, event in ipairs(self.audit_events) do
        if event.sequence > sequence then
            events[#events + 1] = copy_value(event)
            highest_harm_risk = math.max(highest_harm_risk, event.harm_risk)
        end
    end

    return {
        from_sequence = sequence,
        event_count = #events,
        events = events,
        knowledge_factor = #events == 0 and 0 or 0.80,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return BciLatencyGuard
