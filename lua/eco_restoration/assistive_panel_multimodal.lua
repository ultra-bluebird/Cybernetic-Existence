-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/eco_restoration/assistive_panel_multimodal.lua
-- Destination: lua/eco_restoration/

local AssistivePanel = {}
AssistivePanel.__index = AssistivePanel

local allowed_modalities = {
    adaptive_switch = true,
    bci = true,
    gesture = true,
    haptic = true,
    keyboard = true,
    speech = true,
    text = true,
}

local intent_map = {
    bci = {
        navigate_back = "navigate_back",
        navigate_next = "navigate_next",
        select = "select",
        stop = "stop",
    },
    gesture = {
        swipe_down = "navigate_next",
        swipe_left = "navigate_back",
        tap = "select",
        stop = "stop",
    },
    speech = {
        help = "request_help",
        back = "navigate_back",
        next = "navigate_next",
        select = "select",
        stop = "stop",
    },
    adaptive_switch = {
        primary = "select",
        secondary = "navigate_next",
        back = "navigate_back",
    },
    keyboard = {
        enter = "select",
        escape = "navigate_back",
        tab = "navigate_next",
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

local function utc_now()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function copy_value(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic panel values are not supported")
    seen[value] = true

    local copied = {}
    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function normalize_modalities(modalities)
    assert(type(modalities) == "table", "modalities must be a table")

    local result = {}
    local count = 0

    for _, modality in ipairs(modalities) do
        modality = required_text(modality, "modality")
        assert(allowed_modalities[modality],
            "unsupported assistive modality: " .. modality)

        if not result[modality] then
            result[modality] = true
            count = count + 1
        end
    end

    assert(count > 0, "at least one input modality is required")
    return result
end

local function truncate_text(text, maximum_length)
    if #text <= maximum_length then
        return text
    end

    local shortened = text:sub(1, maximum_length)
    local boundary = shortened:match("^(.+)[%.%!%?]")
    return (boundary or shortened) .. "…"
end

function AssistivePanel.new(config)
    config = config or {}

    return setmetatable({
        default_cognitive_load_limit = clamp01(
            config.default_cognitive_load_limit or 0.75
        ),
        default_minimum_confidence = clamp01(
            config.default_minimum_confidence or 0.80
        ),
        sessions = {},
        audit_events = {},
        sequence = 0,
    }, AssistivePanel)
end

function AssistivePanel:start_session(session)
    assert(type(session) == "table", "session must be a table")

    local session_id = required_text(session.session_id, "session_id")
    assert(not self.sessions[session_id], "session_id already exists")

    self.sessions[session_id] = {
        session_id = session_id,
        subject_reference = required_text(
            session.subject_reference,
            "subject_reference"
        ),
        supported_modalities = normalize_modalities(session.input_modalities),
        preferred_output = session.preferred_output or "text",
        cognitive_load = clamp01(session.cognitive_load or 0),
        cognitive_load_limit = clamp01(
            session.cognitive_load_limit or self.default_cognitive_load_limit
        ),
        minimum_confidence = clamp01(
            session.minimum_confidence or self.default_minimum_confidence
        ),
        current_panel = session.current_panel or "home",
        selected_index = 1,
        active = true,
        started_at_utc = session.started_at_utc or utc_now(),
    }

    self:_audit("panel_session_started", session_id, {
        current_panel = self.sessions[session_id].current_panel,
    })

    return copy_value(self.sessions[session_id])
end

function AssistivePanel:update_cognitive_load(session_id, cognitive_load)
    session_id = required_text(session_id, "session_id")

    local session = assert(self.sessions[session_id], "session not found")
    assert(session.active, "session is not active")

    session.cognitive_load = clamp01(cognitive_load)

    self:_audit("cognitive_load_updated", session_id, {
        cognitive_load = session.cognitive_load,
        simplification_required = session.cognitive_load
            >= session.cognitive_load_limit,
    })

    return session.cognitive_load
end

function AssistivePanel:interpret_input(session_id, event)
    session_id = required_text(session_id, "session_id")
    assert(type(event) == "table", "event must be a table")

    local session = assert(self.sessions[session_id], "session not found")
    assert(session.active, "session is not active")

    local modality = required_text(event.modality, "event.modality")
    assert(session.supported_modalities[modality],
        "event modality is not enabled for this session")

    local command = required_text(event.command, "event.command")
    local confidence = clamp01(event.confidence or 1.0)
    local mapping = intent_map[modality]
    local intent = mapping and mapping[command] or nil

    if not intent then
        self:_audit("unsupported_panel_input", session_id, {
            modality = modality,
        })

        return {
            accepted = false,
            clarification_required = true,
            reason = "unsupported command for selected modality",
        }
    end

    if confidence < session.minimum_confidence then
        self:_audit("low_confidence_input", session_id, {
            modality = modality,
            confidence = confidence,
        })

        return {
            accepted = false,
            clarification_required = true,
            reason = "input confidence is below the configured threshold",
            suggested_output = session.preferred_output,
        }
    end

    if intent == "navigate_next" then
        session.selected_index = session.selected_index + 1
    elseif intent == "navigate_back" then
        session.selected_index = math.max(1, session.selected_index - 1)
    end

    self:_audit("panel_input_interpreted", session_id, {
        modality = modality,
        intent = intent,
    })

    return {
        accepted = true,
        user_intent = intent,
        normalized_input = {
            type = "panel_action",
            action = intent,
            panel = session.current_panel,
            selected_index = session.selected_index,
            occurred_at_utc = event.occurred_at_utc or utc_now(),
        },
    }
end

function AssistivePanel:render(session_id, panel)
    session_id = required_text(session_id, "session_id")
    assert(type(panel) == "table", "panel must be a table")

    local session = assert(self.sessions[session_id], "session not found")
    assert(session.active, "session is not active")

    local title = required_text(panel.title, "panel.title")
    local items = panel.items or {}
    assert(type(items) == "table", "panel.items must be a table")

    local simplified = session.cognitive_load >= session.cognitive_load_limit
    local maximum_items = simplified and 3 or 8
    local output_items = {}

    for index, item in ipairs(items) do
        if index > maximum_items then
            break
        end

        assert(type(item) == "table", "panel item must be a table")

        local label = required_text(item.label, "panel item label")
        if simplified then
            label = truncate_text(label, 80)
        end

        output_items[#output_items + 1] = {
            index = index,
            label = label,
            action = item.action and required_text(item.action, "panel item action")
                or "select",
            selected = index == session.selected_index,
        }
    end

    session.current_panel = panel.panel_id or session.current_panel
    session.selected_index = math.min(
        math.max(session.selected_index, 1),
        math.max(#output_items, 1)
    )

    local rendered = {
        modality = session.preferred_output,
        title = simplified and truncate_text(title, 100) or title,
        items = output_items,
        simplified = simplified,
        confirmation_required = simplified,
        context_preserved = true,
        panel_id = session.current_panel,
        rendered_at_utc = utc_now(),
        knowledge_factor = panel.evidence_complete == true and 0.85 or 0.60,
        eco_impact_value = clamp01(panel.eco_impact_value or 0.50),
        harm_risk = simplified and 0.12 or 0.06,
    }

    self:_audit("panel_rendered", session_id, {
        panel_id = session.current_panel,
        item_count = #output_items,
        simplified = simplified,
    })

    return rendered
end

function AssistivePanel:close_session(session_id)
    session_id = required_text(session_id, "session_id")

    local session = assert(self.sessions[session_id], "session not found")
    session.active = false

    self:_audit("panel_session_closed", session_id, {
        last_panel = session.current_panel,
    })

    return {
        session_id = session_id,
        closed_at_utc = utc_now(),
        current_panel = session.current_panel,
    }
end

function AssistivePanel:_audit(event_type, session_id, details)
    self.sequence = self.sequence + 1

    self.audit_events[#self.audit_events + 1] = {
        sequence = self.sequence,
        event_type = event_type,
        session_reference = "assistive-panel-" .. session_id,
        details = copy_value(details or {}),
        occurred_at_utc = utc_now(),
        knowledge_factor = 0.80,
        eco_impact_value = 0.50,
        harm_risk = 0.10,
    }
end

function AssistivePanel:audit_since(sequence)
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

return AssistivePanel
