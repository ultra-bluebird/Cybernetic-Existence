local M = {}

local function text(value, name)
    if type(value) ~= "string" or not value:match("%S") or #value > 4096 then
        error(name .. " must be non-empty text within the limit", 3)
    end
end

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function nonnegative(value, name)
    if not finite(value) or value < 0 then
        error(name .. " must be finite and non-negative", 3)
    end
end

local function boolean(value, name)
    if type(value) ~= "boolean" then
        error(name .. " must be boolean", 3)
    end
end

local function array_size(values, name)
    if type(values) ~= "table" then
        error(name .. " must be a dense array", 3)
    end
    local n = 0
    for key in pairs(values) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            error(name .. " contains an invalid index", 3)
        end
        n = n + 1
    end
    for i = 1, n do
        if values[i] == nil then
            error(name .. " contains a gap", 3)
        end
    end
    return n
end

function M.validate_protocol(p)
    if type(p) ~= "table" then
        error("Provide a protocol table", 2)
    end
    for _, field in ipairs({
        "revision", "elapsed_anchor", "posture",
        "instruction_text", "artifact_policy"
    }) do
        text(p[field], field)
    end
    if p.measurement_field ~= "prv_rmssd_ms" then
        error("Camera-derived measurements must retain PRV naming", 2)
    end
    if p.pacing_during_observation ~= false then
        error("This protocol requires companion pacing to be stopped", 2)
    end
    nonnegative(p.window_duration_s, "Window duration")
    nonnegative(p.timing_tolerance_s, "Timing tolerance")
    if p.window_duration_s == 0 then
        error("Window duration must be positive", 2)
    end
    local n = array_size(p.window_starts_s, "Window starts")
    if n == 0 then
        error("Declare at least one observation window", 2)
    end
    local previous_end = nil
    for i = 1, n do
        local start = p.window_starts_s[i]
        nonnegative(start, "Window start")
        local finish = start + p.window_duration_s
        if not finite(finish) then
            error("Window end exceeds numeric range", 2)
        end
        if previous_end and start < previous_end then
            error("This baseline requires ordered non-overlapping windows", 2)
        end
        previous_end = finish
    end
    return true
end

function M.check_observation(p, observation)
    M.validate_protocol(p)
    if type(observation) ~= "table" then
        error("Provide an observation declaration", 2)
    end
    boolean(observation.participant_stopped, "Participant stop")
    if observation.participant_stopped then
        return {
            status = "stopped_without_penalty",
            analysis_eligible = false,
            participant_failure = false
        }
    end

    for _, field in ipairs({
        "protocol_revision", "elapsed_anchor", "posture",
        "instruction_text", "artifact_policy"
    }) do
        text(observation[field], field)
    end
    boolean(
        observation.pacing_during_observation,
        "Observed pacing state"
    )
    boolean(observation.signal_quality_passed, "Signal quality status")
    nonnegative(observation.start_s, "Observed start")
    nonnegative(observation.end_s, "Observed end")
    nonnegative(
        observation.elapsed_since_pacing_stopped_s,
        "Elapsed time since pacing stopped"
    )
    if observation.end_s <= observation.start_s then
        error("Observed end must follow observed start", 2)
    end

    local matched_window = false
    for _, start in ipairs(p.window_starts_s) do
        if math.abs(observation.start_s - start) <= p.timing_tolerance_s
            and math.abs(
                observation.end_s - (start + p.window_duration_s)
            ) <= p.timing_tolerance_s then
            matched_window = true
            break
        end
    end

    local reasons = {}
    local comparisons = {
        {"revision", observation.protocol_revision == p.revision},
        {"anchor", observation.elapsed_anchor == p.elapsed_anchor},
        {"posture", observation.posture == p.posture},
        {"instructions", observation.instruction_text == p.instruction_text},
        {"artifact_policy", observation.artifact_policy == p.artifact_policy},
        {"pacing", observation.pacing_during_observation == false},
        {"window_timing", matched_window},
        {"signal_quality", observation.signal_quality_passed}
    }
    for _, comparison in ipairs(comparisons) do
        if not comparison[2] then
            reasons[#reasons + 1] = comparison[1]
        end
    end

    return {
        status = #reasons == 0
            and "matches_declared_protocol"
            or "outside_declared_analysis_conditions",
        analysis_eligible = #reasons == 0,
        review_reasons = reasons,
        measurement_field = "prv_rmssd_ms",
        physiological_recovery_established = false,
        participant_failure = false
    }
end

function M.half_life_boundary(definitions)
    if type(definitions) ~= "table" then
        error("Provide endpoint definition states", 2)
    end
    local missing = {}
    for _, field in ipairs({
        "returning_signal_defined",
        "baseline_defined",
        "time_origin_defined",
        "model_defined",
        "nonreturn_rules_defined",
        "validation_review_complete",
        "interpretation_defined"
    }) do
        boolean(definitions[field], field)
        if not definitions[field] then
            missing[#missing + 1] = field
        end
    end
    return {
        status = #missing == 0
            and "definitions_complete_requires_separate_endpoint_approval"
            or "recovery_half_life_deferred",
        missing_definitions = missing,
        half_life_enabled = false,
        estimate_seconds = nil,
        participant_endpoint_authorized = false
    }
end

return M
