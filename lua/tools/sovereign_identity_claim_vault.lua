local ClaimVault = {}
ClaimVault.__index = ClaimVault

local function finite_number(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function nonempty_text(value, field)
    assert(type(value) == "string" and value:match("%S"),
        (field or "value") .. " must be a non-empty string")
    return value
end

local function copy_value(value, seen)
    local kind = type(value)
    if kind ~= "table" then
        return value
    end

    seen = seen or {}
    assert(not seen[value], "cyclic tables are not valid claim data")
    seen[value] = true

    local copied = {}
    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end
    seen[value] = nil
    return copied
end

local function freeze(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return value
    end
    seen[value] = true

    for _, item in pairs(value) do
        freeze(item, seen)
    end

    return setmetatable(value, {
        __newindex = function()
            error("claim records are immutable", 2)
        end,
        __metatable = "immutable",
    })
end

local function normalize_utc(timestamp)
    if timestamp == nil then
        return os.date("!%Y-%m-%dT%H:%M:%SZ")
    end

    nonempty_text(timestamp, "timestamp_utc")
    assert(timestamp:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"),
        "timestamp_utc must use UTC format YYYY-MM-DDTHH:MM:SSZ")
    return timestamp
end

local function validate_claim_input(claim)
    assert(type(claim) == "table", "claim must be a table")

    return {
        claim_id = nonempty_text(claim.claim_id, "claim_id"),
        subject_id = nonempty_text(claim.subject_id, "subject_id"),
        claim_type = nonempty_text(claim.claim_type, "claim_type"),
        value = copy_value(claim.value),
        asserted_at_utc = normalize_utc(claim.asserted_at_utc),
        expires_at_utc = claim.expires_at_utc and normalize_utc(claim.expires_at_utc) or nil,
        note = claim.note and nonempty_text(claim.note, "note") or nil,
        verifiability = claim.verifiability or "self_asserted",
    }
end

local function score_metrics(record)
    local evidence = 0.35
    if record.note then
        evidence = evidence + 0.10
    end
    if record.expires_at_utc then
        evidence = evidence + 0.05
    end

    local knowledge_factor = math.min(1.0, evidence)
    local eco_impact_value = 0.50
    local harm_risk = record.status == "active" and 0.20 or 0.05

    return knowledge_factor, eco_impact_value, harm_risk
end

function ClaimVault.new()
    return setmetatable({
        records = {},
        latest_version = {},
        events = {},
    }, ClaimVault)
end

function ClaimVault:_append_event(event)
    self.events[#self.events + 1] = freeze(event)
end

function ClaimVault:assert_claim(claim)
    local normalized = validate_claim_input(claim)
    assert(not self.latest_version[normalized.claim_id],
        "claim_id already exists; use amend_claim for a new version")

    local knowledge_factor, eco_impact_value, harm_risk = score_metrics({
        status = "active",
        note = normalized.note,
        expires_at_utc = normalized.expires_at_utc,
    })

    local record = freeze({
        claim_id = normalized.claim_id,
        subject_id = normalized.subject_id,
        claim_type = normalized.claim_type,
        value = normalized.value,
        asserted_at_utc = normalized.asserted_at_utc,
        expires_at_utc = normalized.expires_at_utc,
        note = normalized.note,
        verifiability = normalized.verifiability,
        version = 1,
        status = "active",
        supersedes_version = nil,
        revoked_at_utc = nil,
        revocation_reason = nil,
        knowledge_factor = knowledge_factor,
        eco_impact_value = eco_impact_value,
        harm_risk = harm_risk,
    })

    self.records[normalized.claim_id] = { record }
    self.latest_version[normalized.claim_id] = 1
    self:_append_event({
        event_type = "claim_asserted",
        claim_id = normalized.claim_id,
        version = 1,
        occurred_at_utc = normalized.asserted_at_utc,
    })

    return record
end

function ClaimVault:get_claim(claim_id, version)
    nonempty_text(claim_id, "claim_id")

    local versions = self.records[claim_id]
    if not versions then
        return nil, "claim not found"
    end

    version = version or self.latest_version[claim_id]
    if not finite_number(version) or version % 1 ~= 0 or version < 1 then
        return nil, "version must be a positive integer"
    end

    local record = versions[version]
    if not record then
        return nil, "claim version not found"
    end

    return record
end

function ClaimVault:amend_claim(claim_id, amendment)
    local previous, err = self:get_claim(claim_id)
    assert(previous, err)
    assert(previous.status == "active",
        "only an active claim can be amended")

    assert(type(amendment) == "table", "amendment must be a table")
    local version = previous.version + 1
    local asserted_at_utc = normalize_utc(amendment.asserted_at_utc)

    local updated = freeze({
        claim_id = previous.claim_id,
        subject_id = amendment.subject_id or previous.subject_id,
        claim_type = amendment.claim_type or previous.claim_type,
        value = amendment.value ~= nil and copy_value(amendment.value) or copy_value(previous.value),
        asserted_at_utc = asserted_at_utc,
        expires_at_utc = amendment.expires_at_utc
            and normalize_utc(amendment.expires_at_utc)
            or previous.expires_at_utc,
        note = amendment.note or previous.note,
        verifiability = amendment.verifiability or previous.verifiability,
        version = version,
        status = "active",
        supersedes_version = previous.version,
        revoked_at_utc = nil,
        revocation_reason = nil,
        knowledge_factor = previous.knowledge_factor,
        eco_impact_value = previous.eco_impact_value,
        harm_risk = previous.harm_risk,
    })

    self.records[claim_id][version] = updated
    self.latest_version[claim_id] = version
    self:_append_event({
        event_type = "claim_amended",
        claim_id = claim_id,
        version = version,
        supersedes_version = previous.version,
        occurred_at_utc = asserted_at_utc,
    })

    return updated
end

function ClaimVault:revoke_claim(claim_id, reason, revoked_at_utc)
    local previous, err = self:get_claim(claim_id)
    assert(previous, err)
    assert(previous.status == "active", "claim is not active")

    nonempty_text(reason, "reason")
    revoked_at_utc = normalize_utc(revoked_at_utc)

    local version = previous.version + 1
    local revoked = freeze({
        claim_id = previous.claim_id,
        subject_id = previous.subject_id,
        claim_type = previous.claim_type,
        value = copy_value(previous.value),
        asserted_at_utc = previous.asserted_at_utc,
        expires_at_utc = previous.expires_at_utc,
        note = previous.note,
        verifiability = previous.verifiability,
        version = version,
        status = "revoked",
        supersedes_version = previous.version,
        revoked_at_utc = revoked_at_utc,
        revocation_reason = reason,
        knowledge_factor = previous.knowledge_factor,
        eco_impact_value = previous.eco_impact_value,
        harm_risk = 0.05,
    })

    self.records[claim_id][version] = revoked
    self.latest_version[claim_id] = version
    self:_append_event({
        event_type = "claim_revoked",
        claim_id = claim_id,
        version = version,
        supersedes_version = previous.version,
        occurred_at_utc = revoked_at_utc,
        reason = reason,
    })

    return revoked
end

function ClaimVault:list_claims(subject_id, include_inactive)
    nonempty_text(subject_id, "subject_id")

    local results = {}
    for claim_id, latest_version in pairs(self.latest_version) do
        local record = self.records[claim_id][latest_version]
        if record.subject_id == subject_id
            and (include_inactive or record.status == "active") then
            results[#results + 1] = record
        end
    end

    table.sort(results, function(a, b)
        if a.claim_type == b.claim_type then
            return a.claim_id < b.claim_id
        end
        return a.claim_type < b.claim_type
    end)

    return freeze(results)
end

function ClaimVault:list_events()
    return freeze(copy_value(self.events))
end

return ClaimVault
