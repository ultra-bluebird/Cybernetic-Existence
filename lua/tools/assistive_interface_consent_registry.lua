-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/assistive_interface_consent_registry.lua
-- Destination: lua/tools/

local ConsentRegistry = {}
ConsentRegistry.__index = ConsentRegistry

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
    assert(not seen[value], "cyclic consent records are not supported")
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

    return string.format("consent:%08x", state)
end

local function normalize_modalities(modalities)
    assert(type(modalities) == "table", "modalities must be a table")

    local permitted = {
        adaptive_switch = true,
        eye_tracking = true,
        haptic = true,
        keyboard = true,
        screen_reader = true,
        speech = true,
        text = true,
    }

    local normalized = {}

    for _, modality in ipairs(modalities) do
        modality = required_text(modality, "modality")
        assert(permitted[modality], "unsupported modality: " .. modality)
        normalized[modality] = true
    end

    assert(next(normalized) ~= nil, "at least one modality is required")
    return normalized
end

function ConsentRegistry.new(config)
    config = config or {}

    return setmetatable({
        namespace = required_text(
            config.namespace or "assistive-interface-consent-registry",
            "namespace"
        ),
        profiles = {},
        events = {},
        sequence = 0,
    }, ConsentRegistry)
end

function ConsentRegistry:register_interface(subject_reference, interface)
    subject_reference = required_text(subject_reference, "subject_reference")
    assert(type(interface) == "table", "interface must be a table")

    local interface_nonce = required_text(
        interface.local_interface_nonce,
        "local_interface_nonce"
    )

    local interface_reference = stable_reference(
        self.namespace,
        subject_reference .. "|" .. interface_nonce
    )

    local record = {
        interface_reference = interface_reference,
        subject_reference = subject_reference,
        label = interface.label or "assistive interface",
        modalities = normalize_modalities(interface.modalities),
        allowed_services = {},
        preferences = {
            preferred_output = interface.preferred_output or "text",
            fallback_enabled = interface.fallback_enabled ~= false,
            confirmation_required = interface.confirmation_required ~= false,
            output_verbosity = interface.output_verbosity or "standard",
        },
        consent = {
            active = interface.consent_active == true,
            raw_signal_local_only = interface.raw_signal_local_only ~= false,
            semantic_intent_sharing_allowed =
                interface.semantic_intent_sharing_allowed == true,
            aggregate_telemetry_sharing_allowed =
                interface.aggregate_telemetry_sharing_allowed == true,
            trusted_helper_alert_allowed =
                interface.trusted_helper_alert_allowed == true,
            updated_at_utc = interface.updated_at_utc or utc_now(),
        },
        registered_at_utc = utc_now(),
        updated_at_utc = utc_now(),
    }

    self.profiles[interface_reference] = record
    self:_append_event("interface_registered", interface_reference, {
        consent_active = record.consent.active,
        modalities = copy_value(record.modalities),
    })

    return copy_value(record)
end

function ConsentRegistry:grant_service_access(interface_reference, service_reference, scopes)
    interface_reference = required_text(interface_reference, "interface_reference")
    service_reference = required_text(service_reference, "service_reference")
    assert(type(scopes) == "table", "scopes must be a table")

    local record = assert(self.profiles[interface_reference], "interface not registered")
    assert(record.consent.active, "active user consent is required")

    local granted = {}

    for _, scope in ipairs(scopes) do
        scope = required_text(scope, "service scope")

        assert(
            scope == "adapted_output"
                or scope == "semantic_intent"
                or scope == "aggregate_health_metric",
            "unsupported service scope"
        )

        if scope == "semantic_intent" then
            assert(record.consent.semantic_intent_sharing_allowed,
                "semantic-intent sharing is not consented")
        end

        if scope == "aggregate_health_metric" then
            assert(record.consent.aggregate_telemetry_sharing_allowed,
                "aggregate telemetry sharing is not consented")
        end

        granted[scope] = true
    end

    record.allowed_services[service_reference] = {
        scopes = granted,
        granted_at_utc = utc_now(),
        active = true,
    }
    record.updated_at_utc = utc_now()

    self:_append_event("service_access_granted", interface_reference, {
        service_reference = service_reference,
        scopes = copy_value(granted),
    })

    return copy_value(record.allowed_services[service_reference])
end

function ConsentRegistry:update_preferences(interface_reference, preferences)
    interface_reference = required_text(interface_reference, "interface_reference")
    assert(type(preferences) == "table", "preferences must be a table")

    local record = assert(self.profiles[interface_reference], "interface not registered")

    if preferences.preferred_output ~= nil then
        record.preferences.preferred_output = required_text(
            preferences.preferred_output,
            "preferred_output"
        )
    end

    if preferences.fallback_enabled ~= nil then
        assert(type(preferences.fallback_enabled) == "boolean",
            "fallback_enabled must be boolean")
        record.preferences.fallback_enabled = preferences.fallback_enabled
    end

    if preferences.confirmation_required ~= nil then
        assert(type(preferences.confirmation_required) == "boolean",
            "confirmation_required must be boolean")
        record.preferences.confirmation_required =
            preferences.confirmation_required
    end

    if preferences.output_verbosity ~= nil then
        record.preferences.output_verbosity = required_text(
            preferences.output_verbosity,
            "output_verbosity"
        )
    end

    record.updated_at_utc = utc_now()

    self:_append_event("interface_preferences_updated", interface_reference, {
        preference_fields_updated = true,
    })

    return copy_value(record.preferences)
end

function ConsentRegistry:revoke_service_access(interface_reference, service_reference)
    interface_reference = required_text(interface_reference, "interface_reference")
    service_reference = required_text(service_reference, "service_reference")

    local record = assert(self.profiles[interface_reference], "interface not registered")
    local service = assert(
        record.allowed_services[service_reference],
        "service has no registered access"
    )

    service.active = false
    service.revoked_at_utc = utc_now()
    record.updated_at_utc = utc_now()

    self:_append_event("service_access_revoked", interface_reference, {
        service_reference = service_reference,
    })

    return copy_value(service)
end

function ConsentRegistry:revoke_all_consent(interface_reference)
    interface_reference = required_text(interface_reference, "interface_reference")

    local record = assert(self.profiles[interface_reference], "interface not registered")

    record.consent.active = false
    record.consent.semantic_intent_sharing_allowed = false
    record.consent.aggregate_telemetry_sharing_allowed = false
    record.consent.trusted_helper_alert_allowed = false
    record.consent.updated_at_utc = utc_now()

    for _, service in pairs(record.allowed_services) do
        service.active = false
        service.revoked_at_utc = utc_now()
    end

    record.updated_at_utc = utc_now()

    self:_append_event("all_consent_revoked", interface_reference, {
        external_service_access_disabled = true,
        raw_signal_local_only = true,
    })

    return copy_value(record.consent)
end

function ConsentRegistry:resolve_service_scope(interface_reference, service_reference)
    interface_reference = required_text(interface_reference, "interface_reference")
    service_reference = required_text(service_reference, "service_reference")

    local record = self.profiles[interface_reference]
    if not record or not record.consent.active then
        return {
            allowed = false,
            reason = "no active consent",
            knowledge_factor = 0.70,
            eco_impact_value = 0.50,
            harm_risk = 0.40,
        }
    end

    local service = record.allowed_services[service_reference]
    if not service or not service.active then
        return {
            allowed = false,
            reason = "service access is not active",
            knowledge_factor = 0.80,
            eco_impact_value = 0.50,
            harm_risk = 0.30,
        }
    end

    return {
        allowed = true,
        interface_reference = interface_reference,
        service_reference = service_reference,
        scopes = copy_value(service.scopes),
        preferences = copy_value(record.preferences),
        raw_signal_local_only = true,
        knowledge_factor = 0.85,
        eco_impact_value = 0.50,
        harm_risk = 0.08,
    }
end

function ConsentRegistry:_append_event(event_type, interface_reference, details)
    self.sequence = self.sequence + 1

    self.events[#self.events + 1] = {
        sequence = self.sequence,
        event_type = event_type,
        interface_reference = interface_reference,
        details = copy_value(details or {}),
        occurred_at_utc = utc_now(),
        knowledge_factor = 0.80,
        eco_impact_value = 0.50,
        harm_risk = 0.10,
    }
end

function ConsentRegistry:audit_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")
    assert(sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer")

    local events = {}
    local highest_harm_risk = 0

    for _, event in ipairs(self.events) do
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

return ConsentRegistry
