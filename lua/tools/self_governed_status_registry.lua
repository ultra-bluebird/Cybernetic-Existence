-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/self_governed_status_registry.lua
-- Destination: lua/tools/

local SelfGovernedStatusRegistry = {}
SelfGovernedStatusRegistry.__index = SelfGovernedStatusRegistry

local allowed_tiers = {
    tier1 = true,
    tier2 = true,
    tier3 = true,
    unspecified = true,
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
    assert(not seen[value], "cyclic registry values are not supported")
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

    return string.format("status:%08x", state)
end

function SelfGovernedStatusRegistry.new(config)
    config = config or {}

    return setmetatable({
        namespace = required_text(
            config.namespace or "self-governed-status-registry",
            "namespace"
        ),
        records = {},
        audit_events = {},
        sequence = 0,
    }, SelfGovernedStatusRegistry)
end

function SelfGovernedStatusRegistry:declare(declaration)
    assert(type(declaration) == "table", "declaration must be a table")

    local subject_reference = required_text(
        declaration.subject_reference,
        "subject_reference"
    )
    local local_nonce = required_text(
        declaration.local_declaration_nonce,
        "local_declaration_nonce"
    )
    local tier = required_text(
        declaration.cyber_rank_tier or "unspecified",
        "cyber_rank_tier"
    )

    assert(allowed_tiers[tier], "unsupported cyber_rank_tier")
    assert(
        declaration.self_asserted == true,
        "registry records must be explicitly self-asserted"
    )

    local registry_reference = stable_reference(
        self.namespace,
        subject_reference .. "|" .. local_nonce
    )

    local record = {
        registry_reference = registry_reference,
        subject_reference = subject_reference,
        cyber_rank_tier = tier,
        self_governed = declaration.self_governed == true,
        self_asserted = true,
        externally_validated = false,
        external_validation_required = false,
        autonomy_preferences = {
            may_override_automatic_adaptation =
                declaration.may_override_automatic_adaptation ~= false,
            may_revoke_optional_data_sharing =
                declaration.may_revoke_optional_data_sharing ~= false,
            requires_explicit_confirmation_for_irreversible_actions =
                declaration.requires_explicit_confirmation_for_irreversible_actions
                ~= false,
        },
        declaration_note = declaration.declaration_note
            and required_text(declaration.declaration_note, "declaration_note")
            or "self-governed status declared by the individual",
        declared_at_utc = declaration.declared_at_utc or utc_now(),
        updated_at_utc = declaration.declared_at_utc or utc_now(),
        knowledge_factor = declaration.evidence_complete == true and 0.70 or 0.50,
        eco_impact_value = clamp01(declaration.eco_impact_value or 0.50),
        harm_risk = 0.08,
    }

    self.records[registry_reference] = record

    self:_append_audit("self_governed_status_declared", {
        registry_reference = registry_reference,
        cyber_rank_tier = tier,
        self_governed = record.self_governed,
        externally_validated = false,
    })

    return copy_value(record)
end

function SelfGovernedStatusRegistry:update(registry_reference, update)
    registry_reference = required_text(
        registry_reference,
        "registry_reference"
    )
    assert(type(update) == "table", "update must be a table")

    local record = assert(
        self.records[registry_reference],
        "status declaration not found"
    )

    assert(
        update.self_asserted == true,
        "updates must be explicitly self-asserted"
    )

    if update.cyber_rank_tier ~= nil then
        local tier = required_text(
            update.cyber_rank_tier,
            "cyber_rank_tier"
        )

        assert(allowed_tiers[tier], "unsupported cyber_rank_tier")
        record.cyber_rank_tier = tier
    end

    if update.self_governed ~= nil then
        assert(type(update.self_governed) == "boolean",
            "self_governed must be boolean")
        record.self_governed = update.self_governed
    end

    if update.may_override_automatic_adaptation ~= nil then
        assert(type(update.may_override_automatic_adaptation) == "boolean",
            "may_override_automatic_adaptation must be boolean")
        record.autonomy_preferences.may_override_automatic_adaptation =
            update.may_override_automatic_adaptation
    end

    if update.may_revoke_optional_data_sharing ~= nil then
        assert(type(update.may_revoke_optional_data_sharing) == "boolean",
            "may_revoke_optional_data_sharing must be boolean")
        record.autonomy_preferences.may_revoke_optional_data_sharing =
            update.may_revoke_optional_data_sharing
    end

    if update.requires_explicit_confirmation_for_irreversible_actions ~= nil then
        assert(
            type(update.requires_explicit_confirmation_for_irreversible_actions)
                == "boolean",
            "requires_explicit_confirmation_for_irreversible_actions must be boolean"
        )

        record.autonomy_preferences
            .requires_explicit_confirmation_for_irreversible_actions =
            update.requires_explicit_confirmation_for_irreversible_actions
    end

    if update.declaration_note ~= nil then
        record.declaration_note = required_text(
            update.declaration_note,
            "declaration_note"
        )
    end

    record.updated_at_utc = update.updated_at_utc or utc_now()

    self:_append_audit("self_governed_status_updated", {
        registry_reference = registry_reference,
        cyber_rank_tier = record.cyber_rank_tier,
        self_governed = record.self_governed,
    })

    return copy_value(record)
end

function SelfGovernedStatusRegistry:resolve(registry_reference)
    registry_reference = required_text(
        registry_reference,
        "registry_reference"
    )

    local record = self.records[registry_reference]

    if not record then
        return nil, "status declaration not found"
    end

    return {
        registry_reference = record.registry_reference,
        cyber_rank_tier = record.cyber_rank_tier,
        self_governed = record.self_governed,
        self_asserted = true,
        externally_validated = false,
        external_validation_required = false,
        autonomy_preferences = copy_value(record.autonomy_preferences),
        updated_at_utc = record.updated_at_utc,
        knowledge_factor = record.knowledge_factor,
        eco_impact_value = record.eco_impact_value,
        harm_risk = record.harm_risk,
    }
end

function SelfGovernedStatusRegistry:withdraw(registry_reference)
    registry_reference = required_text(
        registry_reference,
        "registry_reference"
    )

    local record = assert(
        self.records[registry_reference],
        "status declaration not found"
    )

    self.records[registry_reference] = nil

    self:_append_audit("self_governed_status_withdrawn", {
        registry_reference = registry_reference,
        externally_validated = false,
    })

    return {
        registry_reference = registry_reference,
        withdrawn = true,
        withdrawn_at_utc = utc_now(),
        knowledge_factor = 0.80,
        eco_impact_value = record.eco_impact_value,
        harm_risk = 0.05,
    }
end

function SelfGovernedStatusRegistry:_append_audit(event_type, details)
    self.sequence = self.sequence + 1

    self.audit_events[#self.audit_events + 1] = {
        sequence = self.sequence,
        event_type = event_type,
        details = copy_value(details or {}),
        occurred_at_utc = utc_now(),
        knowledge_factor = 0.80,
        eco_impact_value = 0.50,
        harm_risk = 0.10,
    }
end

function SelfGovernedStatusRegistry:audit_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")

    assert(
        sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer"
    )

    local events = {}
    local highest_harm_risk = 0

    for _, event in ipairs(self.audit_events) do
        if event.sequence > sequence then
            events[#events + 1] = copy_value(event)
            highest_harm_risk = math.max(
                highest_harm_risk,
                event.harm_risk
            )
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

return SelfGovernedStatusRegistry
