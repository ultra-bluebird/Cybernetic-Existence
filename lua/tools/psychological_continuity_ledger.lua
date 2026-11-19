local ContinuityLedger = {}
ContinuityLedger.__index = ContinuityLedger

local function clamp01(value)
    assert(type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge,
        "score inputs must be finite numbers")
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function required_text(value, field)
    assert(type(value) == "string" and value:match("%S"),
        (field or "value") .. " must be a non-empty string")
    return value
end

local function utc(value)
    if value == nil then
        return os.date("!%Y-%m-%dT%H:%M:%SZ")
    end

    required_text(value, "timestamp_utc")
    assert(value:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"),
        "timestamp_utc must use UTC format YYYY-MM-DDTHH:MM:SSZ")
    return value
end

local function freeze(table_value)
    return setmetatable(table_value, {
        __newindex = function()
            error("ledger records are immutable", 2)
        end,
        __metatable = "immutable",
    })
end

local function copy_table(value)
    if type(value) ~= "table" then
        return value
    end

    local copied = {}
    for key, item in pairs(value) do
        copied[copy_table(key)] = copy_table(item)
    end
    return copied
end

local function anchor_score(anchor)
    local memory = clamp01(anchor.memory_continuity or 0)
    local learning = clamp01(anchor.learning_pattern_continuity or 0)
    local interface = clamp01(anchor.interface_transition_integrity or 0)
    local consent = clamp01(anchor.self_attestation_confidence or 0)

    return (memory * 0.35)
        + (learning * 0.30)
        + (interface * 0.20)
        + (consent * 0.15)
end

function ContinuityLedger.new(config)
    config = config or {}
    local threshold = clamp01(config.minimum_continuity_score or 0.60)

    return setmetatable({
        minimum_continuity_score = threshold,
        anchors_by_subject = {},
        sequence_by_subject = {},
    }, ContinuityLedger)
end

function ContinuityLedger:record_anchor(anchor)
    assert(type(anchor) == "table", "anchor must be a table")

    local subject_id = required_text(anchor.subject_id, "subject_id")
    local anchor_id = required_text(anchor.anchor_id, "anchor_id")
    local timestamp_utc = utc(anchor.timestamp_utc)

    local score = anchor_score(anchor)
    local sequence = (self.sequence_by_subject[subject_id] or 0) + 1

    local record = freeze({
        subject_id = subject_id,
        anchor_id = anchor_id,
        sequence = sequence,
        timestamp_utc = timestamp_utc,
        interface_id = required_text(anchor.interface_id, "interface_id"),
        interface_change = anchor.interface_change == true,
        memory_continuity = clamp01(anchor.memory_continuity or 0),
        learning_pattern_continuity = clamp01(anchor.learning_pattern_continuity or 0),
        interface_transition_integrity = clamp01(anchor.interface_transition_integrity or 0),
        self_attestation_confidence = clamp01(anchor.self_attestation_confidence or 0),
        evidence_references = copy_table(anchor.evidence_references or {}),
        continuity_score = score,
        continuity_status = score >= self.minimum_continuity_score
            and "supported" or "insufficient_evidence",
        knowledge_factor = clamp01(
            ((anchor.memory_continuity or 0)
                + (anchor.learning_pattern_continuity or 0)
                + (anchor.interface_transition_integrity or 0)
                + (anchor.self_attestation_confidence or 0)) / 4
        ),
        eco_impact_value = 0.50,
        harm_risk = score >= self.minimum_continuity_score and 0.15 or 0.35,
    })

    self.anchors_by_subject[subject_id] = self.anchors_by_subject[subject_id] or {}
    self.anchors_by_subject[subject_id][sequence] = record
    self.sequence_by_subject[subject_id] = sequence

    return record
end

function ContinuityLedger:list_anchors(subject_id)
    required_text(subject_id, "subject_id")

    local anchors = self.anchors_by_subject[subject_id] or {}
    return freeze(copy_table(anchors))
end

function ContinuityLedger:validate_continuity(subject_id)
    required_text(subject_id, "subject_id")

    local anchors = self.anchors_by_subject[subject_id] or {}
    local count = #anchors

    if count == 0 then
        return freeze({
            subject_id = subject_id,
            anchor_count = 0,
            supported = false,
            continuity_score = 0,
            knowledge_factor = 0,
            eco_impact_value = 0.50,
            harm_risk = 0.60,
            reason = "no continuity anchors recorded",
        })
    end

    local weighted_total = 0
    local weight_sum = 0
    local interface_changes = 0

    for index, anchor in ipairs(anchors) do
        local weight = index / count
        weighted_total = weighted_total + anchor.continuity_score * weight
        weight_sum = weight_sum + weight

        if anchor.interface_change then
            interface_changes = interface_changes + 1
        end
    end

    local continuity_score = weighted_total / weight_sum
    local supported = continuity_score >= self.minimum_continuity_score

    return freeze({
        subject_id = subject_id,
        anchor_count = count,
        interface_change_count = interface_changes,
        supported = supported,
        continuity_score = continuity_score,
        knowledge_factor = continuity_score,
        eco_impact_value = 0.50,
        harm_risk = supported and (1 - continuity_score) * 0.40 or 0.40,
        reason = supported
            and "self-attested continuity is supported by recorded anchors"
            or "recorded anchors do not meet the configured evidence threshold",
    })
end

return ContinuityLedger
