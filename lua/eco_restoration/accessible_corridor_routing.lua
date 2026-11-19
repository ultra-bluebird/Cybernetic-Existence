local AccessibleCorridorRouting = {}
AccessibleCorridorRouting.__index = AccessibleCorridorRouting

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
    assert(not seen[value], "cyclic corridor data is not supported")
    seen[value] = true

    local copied = {}

    for key, item in pairs(value) do
        copied[copy_value(key, seen)] = copy_value(item, seen)
    end

    seen[value] = nil
    return copied
end

local function normalize_requirements(requirements)
    assert(type(requirements) == "table", "requirements must be a table")

    return {
        minimum_width_m = math.max(
            0,
            finite_number(
                requirements.minimum_width_m or 1.20,
                "minimum_width_m"
            )
        ),
        minimum_surface_quality = clamp01(
            requirements.minimum_surface_quality or 0.70
        ),
        minimum_lighting_quality = clamp01(
            requirements.minimum_lighting_quality or 0.60
        ),
        maximum_slope_ratio = math.max(
            0,
            finite_number(
                requirements.maximum_slope_ratio or 0.08,
                "maximum_slope_ratio"
            )
        ),
        maximum_condition_risk = clamp01(
            requirements.maximum_condition_risk or 0.30
        ),
        require_curb_ramps = requirements.require_curb_ramps ~= false,
        require_tactile_guidance = requirements.require_tactile_guidance == true,
        require_low_stimulation = requirements.require_low_stimulation == true,
    }
end

local function evaluate_segment(segment, requirements)
    assert(type(segment) == "table", "corridor segment must be a table")

    local width_m = math.max(
        0,
        finite_number(segment.width_m, "segment.width_m")
    )
    local surface_quality = clamp01(segment.surface_quality)
    local lighting_quality = clamp01(segment.lighting_quality)
    local slope_ratio = math.max(
        0,
        finite_number(segment.slope_ratio, "segment.slope_ratio")
    )
    local condition_risk = clamp01(segment.condition_risk or 0)
    local curb_ramp_available = segment.curb_ramp_available == true
    local tactile_guidance_available = segment.tactile_guidance_available == true
    local stimulation_level = clamp01(segment.stimulation_level or 0.50)

    local failures = {}

    if width_m < requirements.minimum_width_m then
        failures[#failures + 1] = "insufficient accessible width"
    end

    if surface_quality < requirements.minimum_surface_quality then
        failures[#failures + 1] = "surface quality below requirement"
    end

    if lighting_quality < requirements.minimum_lighting_quality then
        failures[#failures + 1] = "lighting quality below requirement"
    end

    if slope_ratio > requirements.maximum_slope_ratio then
        failures[#failures + 1] = "slope exceeds requirement"
    end

    if condition_risk > requirements.maximum_condition_risk then
        failures[#failures + 1] = "real-time condition risk exceeds requirement"
    end

    if requirements.require_curb_ramps and not curb_ramp_available then
        failures[#failures + 1] = "required curb ramp unavailable"
    end

    if requirements.require_tactile_guidance and not tactile_guidance_available then
        failures[#failures + 1] = "required tactile guidance unavailable"
    end

    if requirements.require_low_stimulation and stimulation_level > 0.50 then
        failures[#failures + 1] = "stimulation level exceeds declared preference"
    end

    local accessibility_score = (
        clamp01(width_m / math.max(requirements.minimum_width_m, 0.01))
            * 0.20
        + surface_quality * 0.20
        + lighting_quality * 0.15
        + (1 - clamp01(
            slope_ratio / math.max(requirements.maximum_slope_ratio, 0.01)
        )) * 0.15
        + (1 - condition_risk) * 0.20
        + (curb_ramp_available and 0.05 or 0)
        + (tactile_guidance_available and 0.05 or 0)
    )

    return {
        segment_id = required_text(segment.segment_id, "segment.segment_id"),
        accessible = #failures == 0,
        failures = failures,
        accessibility_score = clamp01(accessibility_score),
        condition_risk = condition_risk,
        length_m = math.max(
            0,
            finite_number(segment.length_m or 0, "segment.length_m")
        ),
        updated_at_utc = segment.updated_at_utc or utc_now(),
    }
end

function AccessibleCorridorRouting.new(config)
    config = config or {}

    return setmetatable({
        minimum_route_score = clamp01(config.minimum_route_score or 0.75),
        route_history = {},
        sequence = 0,
    }, AccessibleCorridorRouting)
end

function AccessibleCorridorRouting:evaluate_route(route, requirements)
    assert(type(route) == "table", "route must be a table")

    local route_id = required_text(route.route_id, "route_id")
    local segments = route.segments or {}

    assert(type(segments) == "table" and #segments > 0,
        "route.segments must contain at least one segment")

    requirements = normalize_requirements(requirements or {})

    local segment_results = {}
    local total_length_m = 0
    local weighted_score = 0
    local highest_condition_risk = 0
    local route_failures = {}

    for _, segment in ipairs(segments) do
        local result = evaluate_segment(segment, requirements)

        segment_results[#segment_results + 1] = result
        total_length_m = total_length_m + result.length_m
        weighted_score = weighted_score
            + (result.accessibility_score * math.max(result.length_m, 1))
        highest_condition_risk = math.max(
            highest_condition_risk,
            result.condition_risk
        )

        if not result.accessible then
            route_failures[#route_failures + 1] = {
                segment_id = result.segment_id,
                failures = result.failures,
            }
        end
    end

    local route_score = weighted_score / math.max(total_length_m, #segments)
    local accessible = #route_failures == 0
        and route_score >= self.minimum_route_score

    local result = {
        route_id = route_id,
        advisory_only = true,
        accessible = accessible,
        route_score = clamp01(route_score),
        total_length_m = total_length_m,
        segment_results = segment_results,
        route_failures = route_failures,
        highest_condition_risk = highest_condition_risk,
        requirements = copy_value(requirements),
        knowledge_factor = route.evidence_complete == true and 0.85 or 0.60,
        eco_impact_value = clamp01(route.eco_impact_value or 0.50),
        harm_risk = clamp01(
            (1 - route_score) * 0.55
                + highest_condition_risk * 0.30
                + (#route_failures > 0 and 0.15 or 0)
        ),
        assessed_at_utc = route.assessed_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    result.sequence = self.sequence
    self.route_history[#self.route_history + 1] = copy_value(result)

    return result
end

function AccessibleCorridorRouting:choose_best_route(routes, requirements)
    assert(type(routes) == "table" and #routes > 0,
        "routes must contain at least one candidate route")

    local candidates = {}

    for _, route in ipairs(routes) do
        candidates[#candidates + 1] = self:evaluate_route(route, requirements)
    end

    table.sort(candidates, function(left, right)
        if left.accessible ~= right.accessible then
            return left.accessible
        end

        if left.route_score == right.route_score then
            return left.total_length_m < right.total_length_m
        end

        return left.route_score > right.route_score
    end)

    return {
        selected_route = candidates[1],
        evaluated_routes = candidates,
        advisory_only = true,
        knowledge_factor = candidates[1].knowledge_factor,
        eco_impact_value = candidates[1].eco_impact_value,
        harm_risk = candidates[1].harm_risk,
        selected_at_utc = utc_now(),
    }
end

function AccessibleCorridorRouting:report_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")
    assert(
        sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer"
    )

    local entries = {}
    local highest_harm_risk = 0

    for _, entry in ipairs(self.route_history) do
        if entry.sequence > sequence then
            entries[#entries + 1] = copy_value(entry)
            highest_harm_risk = math.max(
                highest_harm_risk,
                entry.harm_risk
            )
        end
    end

    return {
        from_sequence = sequence,
        entry_count = #entries,
        entries = entries,
        knowledge_factor = #entries == 0 and 0 or 0.75,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return AccessibleCorridorRouting
