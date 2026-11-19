-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/assistive_technology_failure_fallback.lua
-- Destination: lua/tools/

local AssistiveTechnologyFailureFallback = {}
AssistiveTechnologyFailureFallback.__index = AssistiveTechnologyFailureFallback

local supported_modalities = {
    adaptive_switch = true,
    eye_tracking = true,
    haptic = true,
    keyboard = true,
    screen_reader = true,
    speech = true,
    text = true,
}

local core_functions = {
    "accessibility_preferences",
    "consent_management",
    "identity_claim_access",
    "identity_continuity_context",
    "local_help",
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

local function utc_now()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function copy_value(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic fallback data is not supported")
    seen[value] = true

    local copied = {}
    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function normalize_modalities(modalities, field)
    assert(type(modalities) == "table", field .. " must be a table")

    local normalized = {}
    local count = 0

    for _, modality in ipairs(modalities) do
        modality = required_text(modality, field .. " modality")
        assert(supported_modalities[modality],
            "unsupported assistive modality: " .. modality)

        if not normalized[modality] then
            normalized[modality] = true
            count = count + 1
        end
    end

    assert(count > 0, field .. " must contain at least one modality")
    return normalized
end

local function ordered_available_modalities(modalities, priority)
    local result = {}

    for _, modality in ipairs(priority) do
        if modalities[modality] then
            result[#result + 1] = modality
        end
    end

    for modality in pairs(modalities) do
        local included = false

        for _, existing in ipairs(result) do
            if modality == existing then
                included = true
                break
            end
        end

        if not included then
            result[#result + 1] = modality
        end
    end

    return result
end

function AssistiveTechnologyFailureFallback.new(config)
    config = config or {}

    return setmetatable({
        minimum_reliability = clamp01(config.minimum_reliability or 0.70),
        default_priority = copy_value(config.default_priority or {
            "adaptive_switch",
            "screen_reader",
            "speech",
            "keyboard",
            "text",
        }),
        plans = {},
        audit_events = {},
        sequence = 0,
    }, AssistiveTechnologyFailureFallback)
end

function AssistiveTechnologyFailureFallback:register_plan(plan)
    assert(type(plan) == "table", "plan must be a table")

    local plan_id = required_text(plan.plan_id, "plan_id")
    assert(not self.plans[plan_id], "plan_id already exists")

    local active_modality = required_text(plan.active_modality, "active_modality")
    assert(supported_modalities[active_modality],
        "unsupported active modality")

    local available = normalize_modalities(
        plan.available_modalities,
        "available_modalities"
    )

    available[active_modality] = true

    local registered = {
        plan_id = plan_id,
        subject_reference = required_text(
            plan.subject_reference,
            "subject_reference"
        ),
        active_modality = active_modality,
        available_modalities = available,
        fallback_priority = copy_value(
            plan.fallback_priority or self.default_priority
        ),
        core_function_context = copy_value(plan.core_function_context or {}),
        allow_trusted_helper_alert = plan.allow_trusted_helper_alert == true,
        active = true,
        registered_at_utc = plan.registered_at_utc or utc_now(),
        fallback_history = {},
    }

    self.plans[plan_id] = registered

    self:_audit("fallback_plan_registered", plan_id, {
        active_modality = active_modality,
    })

    return copy_value(registered)
end

function AssistiveTechnologyFailureFallback:update_context(plan_id, context)
    plan_id = required_text(plan_id, "plan_id")
    assert(type(context) == "table", "context must be a table")

    local plan = assert(self.plans[plan_id], "fallback plan not found")
    assert(plan.active, "fallback plan is inactive")

    plan.core_function_context = copy_value(context)

    self:_audit("fallback_context_updated", plan_id, {
        context_available = true,
    })

    return copy_value(plan.core_function_context)
end

function AssistiveTechnologyFailureFallback:report_device_state(plan_id, state)
    plan_id = required_text(plan_id, "plan_id")
    assert(type(state) == "table", "state must be a table")

    local plan = assert(self.plans[plan_id], "fallback plan not found")
    assert(plan.active, "fallback plan is inactive")

    local modality = required_text(state.modality, "state.modality")
    assert(plan.available_modalities[modality],
        "modality is not available in this fallback plan")

    local connected = state.connected ~= false
    local reliability = clamp01(state.reliability or 1.0)
    local reason = state.reason or "reported device degradation"

    if modality == plan.active_modality
        and (not connected or reliability < self.minimum_reliability) then
        return self:activate_fallback(plan_id, {
            failed_modality = modality,
            reason = reason,
            reliability = reliability,
            connected = connected,
        })
    end

    self:_audit("device_state_accepted", plan_id, {
        modality = modality,
        connected = connected,
        reliability = reliability,
    })

    return {
        plan_id = plan_id,
        active_modality = plan.active_modality,
        fallback_activated = false,
        context = copy_value(plan.core_function_context),
        knowledge_factor = 0.80,
        eco_impact_value = 0.50,
        harm_risk = 0.08,
    }
end

function AssistiveTechnologyFailureFallback:activate_fallback(plan_id, failure)
    plan_id = required_text(plan_id, "plan_id")
    assert(type(failure) == "table", "failure must be a table")

    local plan = assert(self.plans[plan_id], "fallback plan not found")
    assert(plan.active, "fallback plan is inactive")

    local failed_modality = required_text(
        failure.failed_modality,
        "failure.failed_modality"
    )
    local reason = required_text(failure.reason, "failure.reason")

    local candidates = ordered_available_modalities(
        plan.available_modalities,
        plan.fallback_priority
    )

    local selected = nil

    for _, candidate in ipairs(candidates) do
        if candidate ~= failed_modality then
            selected = candidate
            break
        end
    end

    local previous = plan.active_modality

    if selected then
        plan.active_modality = selected
        plan.fallback_history[#plan.fallback_history + 1] = {
            from_modality = previous,
            to_modality = selected,
            reason = reason,
            occurred_at_utc = utc_now(),
        }

        self:_audit("fallback_activated", plan_id, {
            from_modality = previous,
            to_modality = selected,
            reason = reason,
        })

        return {
            plan_id = plan_id,
            fallback_activated = true,
            active_modality = selected,
            status_feedback = "A configured assistive fallback is active.",
            core_functions_available = copy_value(core_functions),
            context = copy_value(plan.core_function_context),
            trusted_helper_notification_permitted =
                plan.allow_trusted_helper_alert,
            knowledge_factor = 0.85,
            eco_impact_value = 0.50,
            harm_risk = 0.15,
        }
    end

    plan.active_modality = "text"

    self:_audit("limited_access_mode_activated", plan_id, {
        failed_modality = failed_modality,
        reason = reason,
    })

    return {
        plan_id = plan_id,
        fallback_activated = false,
        active_modality = "text",
        status_feedback = "No configured assistive fallback is available; local text access is active.",
        core_functions_available = copy_value(core_functions),
        context = copy_value(plan.core_function_context),
        trusted_helper_notification_permitted =
            plan.allow_trusted_helper_alert,
        knowledge_factor = 0.70,
        eco_impact_value = 0.50,
        harm_risk = 0.35,
    }
end

function AssistiveTechnologyFailureFallback:restore_modality(plan_id, modality)
    plan_id = required_text(plan_id, "plan_id")
    modality = required_text(modality, "modality")

    local plan = assert(self.plans[plan_id], "fallback plan not found")
    assert(plan.active, "fallback plan is inactive")
    assert(plan.available_modalities[modality],
        "modality is not available in this fallback plan")

    plan.active_modality = modality

    self:_audit("assistive_modality_restored", plan_id, {
        active_modality = modality,
    })

    return {
        plan_id = plan_id,
        active_modality = modality,
        context = copy_value(plan.core_function_context),
        knowledge_factor = 0.85,
        eco_impact_value = 0.50,
        harm_risk = 0.08,
    }
end

function AssistiveTechnologyFailureFallback:close_plan(plan_id)
    plan_id = required_text(plan_id, "plan_id")

    local plan = assert(self.plans[plan_id], "fallback plan not found")
    plan.active = false

    self:_audit("fallback_plan_closed", plan_id, {
        fallback_count = #plan.fallback_history,
    })

    return {
        plan_id = plan_id,
        fallback_count = #plan.fallback_history,
        closed_at_utc = utc_now(),
    }
end

function AssistiveTechnologyFailureFallback:_audit(event_type, plan_id, details)
    self.sequence = self.sequence + 1

    self.audit_events[#self.audit_events + 1] = {
        sequence = self.sequence,
        event_type = event_type,
        plan_reference = "assistive-fallback-" .. plan_id,
        details = copy_value(details or {}),
        occurred_at_utc = utc_now(),
        knowledge_factor = 0.80,
        eco_impact_value = 0.50,
        harm_risk = 0.10,
    }
end

function AssistiveTechnologyFailureFallback:audit_since(sequence)
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

return AssistiveTechnologyFailureFallback
