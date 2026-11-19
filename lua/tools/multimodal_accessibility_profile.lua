-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/multimodal_accessibility_profile.lua
-- Destination: lua/tools/

local AccessibilityProfile = {}
AccessibilityProfile.__index = AccessibilityProfile

local supported_modalities = {
    adaptive_switch = true,
    eye_tracking = true,
    haptic = true,
    keyboard = true,
    screen_reader = true,
    speech = true,
    text = true,
}

local supported_verbosity = {
    concise = true,
    standard = true,
    detailed = true,
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
    assert(not seen[value], "cyclic accessibility profiles are not supported")
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

    return string.format("access:%08x", state)
end

local function normalize_modalities(values, field)
    assert(type(values) == "table", field .. " must be a table")

    local normalized = {}
    local count = 0

    for _, value in ipairs(values) do
        local modality = required_text(value, field .. " modality")
        assert(supported_modalities[modality],
            "unsupported modality: " .. modality)

        if not normalized[modality] then
            normalized[modality] = true
            count = count + 1
        end
    end

    assert(count > 0, field .. " must include at least one modality")
    return normalized
end

local function ordered_modalities(modalities, preferences)
    local result = {}

    for modality in pairs(modalities) do
        result[#result + 1] = modality
    end

    table.sort(result, function(left, right)
        local left_priority = preferences[left] or math.huge
        local right_priority = preferences[right] or math.huge

        if left_priority == right_priority then
            return left < right
        end

        return left_priority < right_priority
    end)

    return result
end

function AccessibilityProfile.new(config)
    config = config or {}

    return setmetatable({
        namespace = required_text(
            config.namespace or "multimodal-accessibility-profile",
            "namespace"
        ),
        profiles = {},
        sequence = 0,
        audit_events = {},
    }, AccessibilityProfile)
end

function AccessibilityProfile:create(subject_reference, profile)
    subject_reference = required_text(subject_reference, "subject_reference")
    assert(type(profile) == "table", "profile must be a table")

    local local_profile_nonce = required_text(
        profile.local_profile_nonce,
        "local_profile_nonce"
    )

    local profile_reference = stable_reference(
        self.namespace,
        subject_reference .. "|" .. local_profile_nonce
    )

    local input_modalities = normalize_modalities(
        profile.input_modalities,
        "input_modalities"
    )

    local output_modalities = normalize_modalities(
        profile.output_modalities,
        "output_modalities"
    )

    local verbosity = profile.output_verbosity or "standard"
    assert(supported_verbosity[verbosity],
        "output_verbosity must be concise, standard, or detailed")

    local preferences = profile.modality_priority or {}
    assert(type(preferences) == "table", "modality_priority must be a table")

    local record = {
        profile_reference = profile_reference,
        subject_reference = subject_reference,
        input_modalities = input_modalities,
        output_modalities = output_modalities,
        modality_priority = copy_value(preferences),
        latency_requirement_ms = math.max(
            0,
            math.floor(finite_number(
                profile.latency_requirement_ms or 500,
                "latency_requirement_ms"
            ))
        ),
        cognitive_load_limit = clamp01(profile.cognitive_load_limit or 0.75),
        output_verbosity = verbosity,
        confirmation_required = profile.confirmation_required ~= false,
        fallback_enabled = profile.fallback_enabled ~= false,
        consent = {
            active = profile.consent_active == true,
            share_with_services = profile.share_with_services == true,
            allowed_profile_fields = {},
            updated_at_utc = profile.updated_at_utc or utc_now(),
        },
        created_at_utc = utc_now(),
        updated_at_utc = utc_now(),
    }

    for _, field in ipairs(profile.allowed_profile_fields or {}) do
        field = required_text(field, "allowed profile field")

        assert(
            field == "input_modalities"
                or field == "output_modalities"
                or field == "latency_requirement_ms"
                or field == "cognitive_load_limit"
                or field == "output_verbosity"
                or field == "confirmation_required"
                or field == "fallback_enabled",
            "unsupported shareable accessibility field"
        )

        record.consent.allowed_profile_fields[field] = true
    end

    self.profiles[profile_reference] = record

    self:_append_event("profile_created", profile_reference, {
        consent_active = record.consent.active,
        service_sharing_enabled = record.consent.share_with_services,
    })

    return copy_value(record)
end

function AccessibilityProfile:update(profile_reference, update)
    profile_reference = required_text(profile_reference, "profile_reference")
    assert(type(update) == "table", "update must be a table")

    local profile = assert(self.profiles[profile_reference], "profile not found")

    if update.input_modalities ~= nil then
        profile.input_modalities = normalize_modalities(
            update.input_modalities,
            "input_modalities"
        )
    end

    if update.output_modalities ~= nil then
        profile.output_modalities = normalize_modalities(
            update.output_modalities,
            "output_modalities"
        )
    end

    if update.modality_priority ~= nil then
        assert(type(update.modality_priority) == "table",
            "modality_priority must be a table")
        profile.modality_priority = copy_value(update.modality_priority)
    end

    if update.latency_requirement_ms ~= nil then
        profile.latency_requirement_ms = math.max(
            0,
            math.floor(finite_number(
                update.latency_requirement_ms,
                "latency_requirement_ms"
            ))
        )
    end

    if update.cognitive_load_limit ~= nil then
        profile.cognitive_load_limit = clamp01(update.cognitive_load_limit)
    end

    if update.output_verbosity ~= nil then
        assert(supported_verbosity[update.output_verbosity],
            "unsupported output_verbosity")
        profile.output_verbosity = update.output_verbosity
    end

    if update.confirmation_required ~= nil then
        assert(type(update.confirmation_required) == "boolean",
            "confirmation_required must be boolean")
        profile.confirmation_required = update.confirmation_required
    end

    if update.fallback_enabled ~= nil then
        assert(type(update.fallback_enabled) == "boolean",
            "fallback_enabled must be boolean")
        profile.fallback_enabled = update.fallback_enabled
    end

    profile.updated_at_utc = update.updated_at_utc or utc_now()

    self:_append_event("profile_updated", profile_reference, {
        profile_fields_updated = true,
    })

    return copy_value(profile)
end

function AccessibilityProfile:grant_service_sharing(profile_reference, fields)
    profile_reference = required_text(profile_reference, "profile_reference")
    assert(type(fields) == "table", "fields must be a table")

    local profile = assert(self.profiles[profile_reference], "profile not found")
    assert(profile.consent.active, "active consent is required")

    local allowed = {
        input_modalities = true,
        output_modalities = true,
        latency_requirement_ms = true,
        cognitive_load_limit = true,
        output_verbosity = true,
        confirmation_required = true,
        fallback_enabled = true,
    }

    profile.consent.share_with_services = true
    profile.consent.allowed_profile_fields = {}

    for _, field in ipairs(fields) do
        field = required_text(field, "shareable field")
        assert(allowed[field], "unsupported shareable field")
        profile.consent.allowed_profile_fields[field] = true
    end

    profile.consent.updated_at_utc = utc_now()
    profile.updated_at_utc = utc_now()

    self:_append_event("service_sharing_granted", profile_reference, {
        field_count = #fields,
    })

    return copy_value(profile.consent)
end

function AccessibilityProfile:revoke_service_sharing(profile_reference)
    profile_reference = required_text(profile_reference, "profile_reference")

    local profile = assert(self.profiles[profile_reference], "profile not found")

    profile.consent.share_with_services = false
    profile.consent.allowed_profile_fields = {}
    profile.consent.updated_at_utc = utc_now()
    profile.updated_at_utc = utc_now()

    self:_append_event("service_sharing_revoked", profile_reference, {
        external_profile_disclosure_disabled = true,
    })

    return copy_value(profile.consent)
end

function AccessibilityProfile:service_view(profile_reference, service_reference)
    profile_reference = required_text(profile_reference, "profile_reference")
    service_reference = required_text(service_reference, "service_reference")

    local profile = self.profiles[profile_reference]
    if not profile then
        return nil, "profile not found"
    end

    if not profile.consent.active or not profile.consent.share_with_services then
        return {
            allowed = false,
            reason = "service sharing is not actively consented",
            knowledge_factor = 0.75,
            eco_impact_value = 0.50,
            harm_risk = 0.35,
        }
    end

    local view = {
        allowed = true,
        profile_reference = profile.profile_reference,
        service_reference = service_reference,
        raw_identifier_disclosed = false,
        knowledge_factor = 0.85,
        eco_impact_value = 0.50,
        harm_risk = 0.08,
    }

    for field in pairs(profile.consent.allowed_profile_fields) do
        if field == "input_modalities" then
            view.input_modalities = ordered_modalities(
                profile.input_modalities,
                profile.modality_priority
            )
        elseif field == "output_modalities" then
            view.output_modalities = ordered_modalities(
                profile.output_modalities,
                profile.modality_priority
            )
        else
            view[field] = copy_value(profile[field])
        end
    end

    self:_append_event("service_view_created", profile_reference, {
        service_reference = stable_reference(self.namespace, service_reference),
        raw_identifier_disclosed = false,
    })

    return view
end

function AccessibilityProfile:_append_event(event_type, profile_reference, details)
    self.sequence = self.sequence + 1

    self.audit_events[#self.audit_events + 1] = {
        sequence = self.sequence,
        event_type = event_type,
        profile_reference = profile_reference,
        details = copy_value(details or {}),
        occurred_at_utc = utc_now(),
        knowledge_factor = 0.80,
        eco_impact_value = 0.50,
        harm_risk = 0.10,
    }
end

function AccessibilityProfile:audit_since(sequence)
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

return AccessibilityProfile
