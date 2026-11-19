local M = {}

local function finite(x)
    return type(x) == "number"
        and x == x
        and x ~= math.huge
        and x ~= -math.huge
end

local function number(x, name, positive)
    if not finite(x) or x < 0 or (positive and x == 0) then
        error(name .. " must be finite and within its declared range", 3)
    end
end

local function text(x, name)
    if type(x) ~= "string" or not x:match("%S") or #x > 4096 then
        error(name .. " must be non-empty text within the limit", 3)
    end
end

local function sequence(values, name)
    if type(values) ~= "table" then
        error(name .. " must be a dense numeric array", 3)
    end
    local n = 0
    for key in pairs(values) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            error(name .. " contains an invalid array key", 3)
        end
        n = n + 1
    end
    for i = 1, n do
        if values[i] == nil then
            error(name .. " must not contain gaps", 3)
        end
    end
    return n
end

function M.prv_rmssd_ms(intervals)
    local n = sequence(intervals, "Pulse intervals")
    if n < 2 then
        error("At least two valid pulse intervals are required", 2)
    end
    for i = 1, n do
        number(intervals[i], "Pulse interval", true)
    end
    local sum = 0
    for i = 1, n - 1 do
        local difference = intervals[i + 1] - intervals[i]
        sum = sum + difference * difference
    end
    if not finite(sum) then
        error("Interval arithmetic exceeded the numeric range", 2)
    end
    return {
        field = "prv_rmssd_ms",
        value = math.sqrt(sum / (n - 1)),
        physiological_state_inferred = false
    }
end

function M.frame_timing(timestamps_s, nominal_fps)
    local n = sequence(timestamps_s, "Frame timestamps")
    number(nominal_fps, "Nominal frame rate", true)
    if n < 2 then
        error("At least two frame timestamps are required", 2)
    end

    local gaps = {}
    local estimated_missing = 0
    for i = 1, n do
        number(timestamps_s[i], "Frame timestamp", false)
        if i > 1 then
            local gap = timestamps_s[i] - timestamps_s[i - 1]
            if gap <= 0 then
                error("Frame timestamps must be strictly increasing", 2)
            end
            local nominal_periods = gap * nominal_fps
            if not finite(nominal_periods) then
                error("Timestamp arithmetic exceeded the numeric range", 2)
            end
            gaps[#gaps + 1] = gap
            estimated_missing = estimated_missing
                + math.max(0, math.floor(nominal_periods + 0.5) - 1)
        end
    end

    local duration = timestamps_s[n] - timestamps_s[1]
    local largest_gap = 0
    for _, gap in ipairs(gaps) do
        largest_gap = math.max(largest_gap, gap)
    end
    local effective_fps = (n - 1) / duration
    if not finite(effective_fps) then
        error("Effective frame rate exceeded the numeric range", 2)
    end

    return {
        frame_count = n,
        observed_span_seconds = duration,
        effective_fps = effective_fps,
        largest_gap_seconds = largest_gap,
        timestamp_estimated_missing_frames = estimated_missing,
        actual_dropped_frames_established = false,
        acquisition_quality_passed = false
    }
end

function M.rmssd_agreement(prv, ecg, policy)
    local n = sequence(prv, "PRV window values")
    if sequence(ecg, "ECG window values") ~= n or n < 2 then
        error("Provide at least two matched RMSSD windows", 2)
    end
    if type(policy) ~= "table" then
        error("Provide a prespecified agreement policy", 2)
    end
    text(policy.scope, "Applied scope")
    number(policy.max_abs_bias_ms, "Bias limit", false)
    number(policy.max_abs_loa_ms, "Agreement limit", false)
    number(policy.minimum_pairs, "Minimum pair count", true)
    if policy.minimum_pairs % 1 ~= 0 or policy.minimum_pairs < 2 then
        error("Minimum pair count must be an integer of at least two", 2)
    end

    local differences = {}
    local sum, absolute_sum = 0, 0
    for i = 1, n do
        number(prv[i], "PRV RMSSD", false)
        number(ecg[i], "ECG RMSSD", false)
        differences[i] = prv[i] - ecg[i]
        sum = sum + differences[i]
        absolute_sum = absolute_sum + math.abs(differences[i])
    end
    local bias = sum / n
    local squared = 0
    for i = 1, n do
        squared = squared + (differences[i] - bias) ^ 2
    end
    local sd = math.sqrt(squared / (n - 1))
    local lower, upper = bias - 1.96 * sd, bias + 1.96 * sd
    if not finite(bias) or not finite(lower) or not finite(upper)
        or not finite(absolute_sum) then
        error("Agreement arithmetic exceeded the numeric range", 2)
    end

    local screen_passed = n >= policy.minimum_pairs
        and math.abs(bias) <= policy.max_abs_bias_ms
        and math.max(math.abs(lower), math.abs(upper))
            <= policy.max_abs_loa_ms

    return {
        status = "descriptive_point_estimate_screen",
        scope = policy.scope,
        matched_windows = n,
        bias_ms = bias,
        mae_ms = absolute_sum / n,
        lower_loa_ms = lower,
        upper_loa_ms = upper,
        prespecified_screen_passed = screen_passed,
        independent_replication_established = false,
        formal_equivalence_established = false,
        output_field = "prv_rmssd_ms"
    }
end

return M
