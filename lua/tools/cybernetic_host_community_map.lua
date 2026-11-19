-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/cybernetic_host_community_map.lua
-- Destination: lua/tools/

local CommunityMap = {}
CommunityMap.__index = CommunityMap

local allowed_place_kinds = {
    business = true,
    community_space = true,
    public_service = true,
    support_service = true,
}

local supported_access_features = {
    accessible_entry = true,
    assistive_device_support = true,
    cognitive_load_support = true,
    low_stimulation_area = true,
    private_rest_area = true,
    sensory_accessibility = true,
    text_based_support = true,
}

local allowed_public_statuses = {
    published = true,
    review_required = true,
    withdrawn = true,
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
    assert(not seen[value], "cyclic community-map values are not supported")
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

    return string.format("place:%08x", state)
end

local function normalize_features(features)
    assert(type(features) == "table", "access_features must be a table")

    local normalized = {}
    local count = 0

    for _, feature in ipairs(features) do
        feature = required_text(feature, "access feature")
        assert(
            supported_access_features[feature],
            "unsupported access feature: " .. feature
        )

        if not normalized[feature] then
            normalized[feature] = true
            count = count + 1
        end
    end

    assert(count > 0, "at least one access feature is required")
    return normalized
end

local function feature_list(features)
    local result = {}

    for feature in pairs(features) do
        result[#result + 1] = feature
    end

    table.sort(result)
    return result
end

function CommunityMap.new(config)
    config = config or {}

    return setmetatable({
        namespace = required_text(
            config.namespace or "cybernetic-host-community-map",
            "namespace"
        ),
        minimum_public_confidence = clamp01(
            config.minimum_public_confidence or 0.70
        ),
        places = {},
        audit_events = {},
        sequence = 0,
    }, CommunityMap)
end

function CommunityMap:contribute(entry)
    assert(type(entry) == "table", "entry must be a table")
    assert(
        entry.community_consent == true,
        "explicit community contribution consent is required"
    )

    local place_kind = required_text(entry.place_kind, "place_kind")
    assert(allowed_place_kinds[place_kind], "unsupported place_kind")

    local source_nonce = required_text(
        entry.local_contribution_nonce,
        "local_contribution_nonce"
    )
    local place_reference = stable_reference(self.namespace, source_nonce)
    local confidence = clamp01(entry.accessibility_confidence or 0)

    local status = confidence >= self.minimum_public_confidence
        and "published"
        or "review_required"

    local normalized = {
        place_reference = place_reference,
        place_kind = place_kind,
        public_label = required_text(entry.public_label, "public_label"),
        area_reference = required_text(entry.area_reference, "area_reference"),
        access_features = normalize_features(entry.access_features),
        accessibility_confidence = confidence,
        status = status,
        community_evidence_count = math.max(
            0,
            math.floor(finite_number(
                entry.community_evidence_count or 0,
                "community_evidence_count"
            ))
        ),
        last_confirmed_utc = entry.last_confirmed_utc or utc_now(),
        contributor_reference_retained = false,
        raw_assistive_data_retained = false,
        precise_personal_location_retained = false,
        knowledge_factor = clamp01(
            (entry.evidence_complete == true and 0.60 or 0.30)
                + math.min(0.40, (entry.community_evidence_count or 0) / 25)
        ),
        eco_impact_value = clamp01(entry.eco_impact_value or 0.50),
        harm_risk = clamp01(
            (1 - confidence) * 0.35
                + (status == "review_required" and 0.20 or 0.05)
        ),
        created_at_utc = utc_now(),
        updated_at_utc = utc_now(),
    }

    self.places[place_reference] = normalized
    self:_append_audit("community_place_contributed", {
        place_reference = place_reference,
        status = status,
        place_kind = place_kind,
        feature_count = #feature_list(normalized.access_features),
    })

    return copy_value(normalized)
end

function CommunityMap:update_status(place_reference, status, review)
    place_reference = required_text(place_reference, "place_reference")
    status = required_text(status, "status")
    assert(allowed_public_statuses[status], "unsupported public status")
    assert(type(review) == "table", "review must be a table")

    local place = assert(self.places[place_reference], "place not found")

    if status == "published" then
        assert(
            clamp01(review.accessibility_confidence or 0)
                >= self.minimum_public_confidence,
            "published entries require sufficient accessibility confidence"
        )
        assert(review.evidence_complete == true,
            "published entries require complete review evidence")
    end

    place.status = status
    place.accessibility_confidence = clamp01(
        review.accessibility_confidence
            or place.accessibility_confidence
    )
    place.community_evidence_count = math.max(
        place.community_evidence_count,
        math.floor(finite_number(
            review.community_evidence_count
                or place.community_evidence_count,
            "community_evidence_count"
        ))
    )
    place.last_confirmed_utc = review.last_confirmed_utc or utc_now()
    place.updated_at_utc = utc_now()
    place.knowledge_factor = clamp01(
        (review.evidence_complete == true and 0.60 or 0.30)
            + math.min(0.40, place.community_evidence_count / 25)
    )
    place.harm_risk = clamp01(
        (1 - place.accessibility_confidence) * 0.35
            + (status == "review_required" and 0.20 or 0.05)
    )

    self:_append_audit("community_place_status_updated", {
        place_reference = place_reference,
        status = status,
    })

    return copy_value(place)
end

function CommunityMap:withdraw(place_reference)
    place_reference = required_text(place_reference, "place_reference")

    local place = assert(self.places[place_reference], "place not found")
    place.status = "withdrawn"
    place.updated_at_utc = utc_now()
    place.harm_risk = 0.10

    self:_append_audit("community_place_withdrawn", {
        place_reference = place_reference,
    })

    return copy_value(place)
end

function CommunityMap:list_public(area_reference)
    if area_reference ~= nil then
        required_text(area_reference, "area_reference")
    end

    local results = {}

    for _, place in pairs(self.places) do
        if place.status == "published"
            and (area_reference == nil or place.area_reference == area_reference) then
            results[#results + 1] = {
                place_reference = place.place_reference,
                place_kind = place.place_kind,
                public_label = place.public_label,
                area_reference = place.area_reference,
                access_features = feature_list(place.access_features),
                accessibility_confidence = place.accessibility_confidence,
                community_evidence_count = place.community_evidence_count,
                last_confirmed_utc = place.last_confirmed_utc,
                contributor_reference_retained = false,
                raw_assistive_data_retained = false,
            }
        end
    end

    table.sort(results, function(left, right)
        if left.accessibility_confidence == right.accessibility_confidence then
            return left.public_label < right.public_label
        end

        return left.accessibility_confidence > right.accessibility_confidence
    end)

    return {
        advisory_only = true,
        area_reference = area_reference or "all_public_areas",
        place_count = #results,
        places = results,
        knowledge_factor = #results == 0 and 0 or 0.80,
        eco_impact_value = 0.50,
        harm_risk = 0.05,
        generated_at_utc = utc_now(),
    }
end

function CommunityMap:_append_audit(event_type, details)
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

function CommunityMap:audit_since(sequence)
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

return CommunityMap
