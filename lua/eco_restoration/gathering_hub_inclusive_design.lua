-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/eco_restoration/gathering_hub_inclusive_design.lua
-- Destination: lua/eco_restoration/

local GatheringHubInclusiveDesign = {}
GatheringHubInclusiveDesign.__index = GatheringHubInclusiveDesign

local required_zones = {
    "accessible_entry",
    "quiet_room",
    "low_emi_area",
    "rest_area",
    "accessible_sanitation",
    "accessible_egress",
}

local default_weights = {
    accessible_entry = 0.18,
    quiet_room = 0.18,
    low_emi_area = 0.18,
    rest_area = 0.12,
    accessible_sanitation = 0.17,
    accessible_egress = 0.17,
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
    assert(not seen[value], "cyclic gathering-space records are not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function normalized_weights(weights)
    assert(type(weights) == "table", "weights must be a table")

    local total = 0
    local normalized = {}

    for _, zone in ipairs(required_zones) do
        local weight = finite_number(weights[zone] or 0, "weight for " .. zone)

        assert(weight >= 0, "weights must be non-negative")
        normalized[zone] = weight
        total = total + weight
    end

    assert(total > 0, "at least one zone weight must be positive")

    for zone, weight in pairs(normalized) do
        normalized[zone] = weight / total
    end

    return normalized
end

local function zone_assessment(zone_name, zone)
    assert(type(zone) == "table", "zone data must be a table")

    local available = zone.available == true
    local physical_access = clamp01(zone.physical_access or 0)
    local sensory_access = clamp01(zone.sensory_access or 0)
    local assistive_compatibility = clamp01(
        zone.assistive_compatibility or 0
    )
    local maintenance_reliability = clamp01(
        zone.maintenance_reliability or 0
    )

    local score = available and clamp01(
        physical_access * 0.35
            + sensory_access * 0.30
            + assistive_compatibility * 0.25
            + maintenance_reliability * 0.10
    ) or 0

    local findings = {}

    if not available then
        findings[#findings + 1] = "required zone is unavailable"
    end

    if physical_access < 0.75 then
        findings[#findings + 1] = "physical accessibility is below threshold"
    end

    if sensory_access < 0.75 then
        findings[#findings + 1] = "sensory accessibility is below threshold"
    end

    if assistive_compatibility < 0.75 then
        findings[#findings + 1] =
            "assistive-technology compatibility is below threshold"
    end

    if maintenance_reliability < 0.70 then
        findings[#findings + 1] =
            "maintenance reliability is below threshold"
    end

    return {
        zone = zone_name,
        available = available,
        score = score,
        physical_access = physical_access,
        sensory_access = sensory_access,
        assistive_compatibility = assistive_compatibility,
        maintenance_reliability = maintenance_reliability,
        findings = findings,
    }
end

function GatheringHubInclusiveDesign.new(config)
    config = config or {}

    return setmetatable({
        weights = normalized_weights(config.weights or default_weights),
        minimum_design_score = clamp01(config.minimum_design_score or 0.80),
        minimum_critical_zone_score = clamp01(
            config.minimum_critical_zone_score or 0.75
        ),
        assessments = {},
        sequence = 0,
    }, GatheringHubInclusiveDesign)
end

function GatheringHubInclusiveDesign:evaluate(design)
    assert(type(design) == "table", "design must be a table")

    local hub_id = required_text(design.hub_id, "hub_id")
    local zones = design.zones or {}

    assert(type(zones) == "table", "design.zones must be a table")

    local zone_results = {}
    local findings = {}
    local weighted_score = 0
    local critical_failure = false
    local evidence_count = 0

    for _, zone_name in ipairs(required_zones) do
        local result = zone_assessment(zone_name, zones[zone_name] or {})
        zone_results[zone_name] = result
        weighted_score = weighted_score + result.score * self.weights[zone_name]

        if design.evidence and design.evidence[zone_name] == true then
            evidence_count = evidence_count + 1
        else
            findings[#findings + 1] = {
                zone = zone_name,
                detail = "design evidence is incomplete",
            }
        end

        if result.score < self.minimum_critical_zone_score then
            critical_failure = true
            findings[#findings + 1] = {
                zone = zone_name,
                detail = "critical zone does not meet the minimum score",
            }
        end

        for _, detail in ipairs(result.findings) do
            findings[#findings + 1] = {
                zone = zone_name,
                detail = detail,
            }
        end
    end

    local design_score = clamp01(weighted_score)
    local evidence_complete = evidence_count == #required_zones
    local compliant = design_score >= self.minimum_design_score
        and not critical_failure
        and evidence_complete

    local energy_awareness = clamp01(design.energy_awareness or 0.50)
    local material_safety = clamp01(design.material_safety or 0.50)

    local eco_impact_value = clamp01(
        energy_awareness * 0.45 + material_safety * 0.55
    )

    local harm_risk = clamp01(
        (1 - design_score) * 0.50
            + (critical_failure and 0.30 or 0)
            + (not evidence_complete and 0.15 or 0)
            + ((1 - material_safety) * 0.05)
    )

    local result = {
        hub_id = hub_id,
        advisory_only = true,
        compliant = compliant,
        inclusive_design_score = design_score,
        zone_results = zone_results,
        evidence_complete = evidence_complete,
        findings = findings,
        knowledge_factor = clamp01(
            (evidence_count / #required_zones) * 0.80
                + (design.evidence_complete == true and 0.20 or 0)
        ),
        eco_impact_value = eco_impact_value,
        harm_risk = harm_risk,
        assessed_at_utc = design.assessed_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.assessments[#self.assessments + 1] = copy_value(result)

    return result
end

function GatheringHubInclusiveDesign:recommend(design)
    local assessment = self:evaluate(design)
    local recommendations = {}

    for zone_name, zone in pairs(assessment.zone_results) do
        if not zone.available then
            recommendations[#recommendations + 1] =
                "Provide the required " .. zone_name .. " zone."
        end

        if zone.physical_access < 0.75 then
            recommendations[#recommendations + 1] =
                "Improve obstacle-free access, transfer space, and navigable circulation in "
                    .. zone_name .. "."
        end

        if zone.sensory_access < 0.75 then
            recommendations[#recommendations + 1] =
                "Reduce sensory load through controllable lighting, sound management, and clear wayfinding in "
                    .. zone_name .. "."
        end

        if zone.assistive_compatibility < 0.75 then
            recommendations[#recommendations + 1] =
                "Validate compatibility with declared assistive modalities in "
                    .. zone_name .. "."
        end

        if zone.maintenance_reliability < 0.70 then
            recommendations[#recommendations + 1] =
                "Establish a documented maintenance and availability check for "
                    .. zone_name .. "."
        end
    end

    if #recommendations == 0 then
        recommendations[#recommendations + 1] =
            "Maintain documented accessibility checks and community feedback review."
    end

    return {
        assessment = assessment,
        recommendations = recommendations,
        generated_at_utc = utc_now(),
    }
end

function GatheringHubInclusiveDesign:report_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")

    assert(
        sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer"
    )

    local results = {}
    local highest_harm_risk = 0
    local compliant_count = 0

    for _, result in ipairs(self.assessments) do
        if result.sequence > sequence then
            results[#results + 1] = copy_value(result)
            highest_harm_risk = math.max(
                highest_harm_risk,
                result.harm_risk
            )

            if result.compliant then
                compliant_count = compliant_count + 1
            end
        end
    end

    local count = #results

    return {
        from_sequence = sequence,
        assessment_count = count,
        compliant_count = compliant_count,
        noncompliant_count = count - compliant_count,
        results = results,
        knowledge_factor = count == 0 and 0
            or compliant_count / count,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return GatheringHubInclusiveDesign
