local Registry = {}
Registry.__index = Registry

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
    value = finite_number(value, "metric")

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
    assert(not seen[value], "registry records cannot contain cyclic tables")
    seen[value] = true

    local result = {}
    for key, item in pairs(value) do
        result[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return result
end

local function immutable_copy(value)
    local copied = copy_value(value)

    local function freeze(item, seen)
        if type(item) ~= "table" then
            return item
        end

        seen = seen or {}
        if seen[item] then
            return item
        end

        seen[item] = true

        for _, nested in pairs(item) do
            freeze(nested, seen)
        end

        return setmetatable(item, {
            __newindex = function()
                error("registry records are immutable", 2)
            end,
            __metatable = "immutable",
        })
    end

    return freeze(copied)
end

local function validate_service_record(record)
    assert(type(record) == "table", "service record must be a table")

    local fairness_score = clamp01(record.fairness_score)
    local accessibility = clamp01(record.accessibility)
    local identity_neutrality = clamp01(record.identity_neutrality)
    local assistive_accommodation = clamp01(record.assistive_accommodation)

    return {
        service_id = required_text(record.service_id, "service_id"),
        service_name = required_text(record.service_name, "service_name"),
        region = record.region or "Phoenix-AZ",
        policy_version = required_text(record.policy_version, "policy_version"),
        assessed_at_utc = record.assessed_at_utc or utc_now(),
        fairness_score = fairness_score,
        accessibility = accessibility,
        identity_neutrality = identity_neutrality,
        assistive_accommodation = assistive_accommodation,
        policy_outcome = required_text(record.policy_outcome, "policy_outcome"),
        public_summary = required_text(record.public_summary, "public_summary"),
        evidence_reference = required_text(record.evidence_reference, "evidence_reference"),
        reviewed_by = required_text(record.reviewed_by, "reviewed_by"),
        knowledge_factor = clamp01(record.knowledge_factor or 0.60),
        eco_impact_value = clamp01(record.eco_impact_value or 0.50),
        harm_risk = clamp01(record.harm_risk or (1 - fairness_score)),
    }
end

function Registry.new(config)
    config = config or {}

    return setmetatable({
        city = config.city or "Phoenix",
        public_registry_version = config.public_registry_version or "1.0",
        service_versions = {},
        events = {},
    }, Registry)
end

function Registry:record_assessment(record)
    local normalized = validate_service_record(record)
    self.service_versions[normalized.service_id] =
        self.service_versions[normalized.service_id] or {}

    local versions = self.service_versions[normalized.service_id]
    local version_number = #versions + 1

    local immutable_record = immutable_copy({
        registry_version = self.public_registry_version,
        entry_version = version_number,
        city = self.city,
        service_id = normalized.service_id,
        service_name = normalized.service_name,
        region = normalized.region,
        policy_version = normalized.policy_version,
        assessed_at_utc = normalized.assessed_at_utc,
        fairness_score = normalized.fairness_score,
        accessibility = normalized.accessibility,
        identity_neutrality = normalized.identity_neutrality,
        assistive_accommodation = normalized.assistive_accommodation,
        policy_outcome = normalized.policy_outcome,
        public_summary = normalized.public_summary,
        evidence_reference = normalized.evidence_reference,
        reviewed_by = normalized.reviewed_by,
        knowledge_factor = normalized.knowledge_factor,
        eco_impact_value = normalized.eco_impact_value,
        harm_risk = normalized.harm_risk,
    })

    versions[version_number] = immutable_record
    self.events[#self.events + 1] = immutable_copy({
        event_type = "assessment_recorded",
        service_id = normalized.service_id,
        entry_version = version_number,
        occurred_at_utc = normalized.assessed_at_utc,
    })

    return immutable_record
end

function Registry:get_latest(service_id)
    required_text(service_id, "service_id")

    local versions = self.service_versions[service_id]
    if not versions or #versions == 0 then
        return nil, "service assessment not found"
    end

    return versions[#versions]
end

function Registry:get_history(service_id)
    required_text(service_id, "service_id")

    local versions = self.service_versions[service_id]
    if not versions then
        return {}
    end

    return immutable_copy(versions)
end

function Registry:list_public_entries()
    local entries = {}

    for _, versions in pairs(self.service_versions) do
        entries[#entries + 1] = versions[#versions]
    end

    table.sort(entries, function(left, right)
        if left.service_name == right.service_name then
            return left.service_id < right.service_id
        end

        return left.service_name < right.service_name
    end)

    return immutable_copy(entries)
end

function Registry:public_dashboard()
    local entries = self:list_public_entries()
    local total_fairness = 0
    local total_accessibility = 0
    local total_identity_neutrality = 0
    local total_assistive_accommodation = 0
    local highest_harm_risk = 0

    for _, entry in ipairs(entries) do
        total_fairness = total_fairness + entry.fairness_score
        total_accessibility = total_accessibility + entry.accessibility
        total_identity_neutrality = total_identity_neutrality + entry.identity_neutrality
        total_assistive_accommodation = total_assistive_accommodation
            + entry.assistive_accommodation
        highest_harm_risk = math.max(highest_harm_risk, entry.harm_risk)
    end

    local count = #entries

    return immutable_copy({
        city = self.city,
        registry_version = self.public_registry_version,
        service_count = count,
        average_fairness_score = count == 0 and 0 or total_fairness / count,
        average_accessibility = count == 0 and 0 or total_accessibility / count,
        average_identity_neutrality = count == 0 and 0
            or total_identity_neutrality / count,
        average_assistive_accommodation = count == 0 and 0
            or total_assistive_accommodation / count,
        highest_harm_risk = highest_harm_risk,
        knowledge_factor = count == 0 and 0
            or (function()
                local total = 0
                for _, entry in ipairs(entries) do
                    total = total + entry.knowledge_factor
                end
                return total / count
            end)(),
        eco_impact_value = count == 0 and 0
            or (function()
                local total = 0
                for _, entry in ipairs(entries) do
                    total = total + entry.eco_impact_value
                end
                return total / count
            end)(),
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
        entries = entries,
    })
end

return Registry
