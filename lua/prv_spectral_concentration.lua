local M = {}
local pi = math.pi

local function finite(x)
    return type(x) == "number" and x == x
        and x ~= math.huge and x ~= -math.huge
end

local function nonnegative(x, name)
    if not finite(x) or x < 0 then
        error(name .. " must be finite and non-negative", 3)
    end
end

local function positive(x, name)
    nonnegative(x, name)
    if x == 0 then
        error(name .. " must be positive", 3)
    end
end

local function dense(values)
    if type(values) ~= "table" then
        error("Series must be a dense numeric array", 3)
    end
    local n = 0
    for k in pairs(values) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
            error("Invalid series index", 3)
        end
        n = n + 1
    end
    for i = 1, n do
        if not finite(values[i]) then
            error("Series contains missing or non-finite values", 3)
        end
    end
    return n
end

function M.duration_advisory(f_min_hz)
    positive(f_min_hz, "Lowest frequency")
    local value = 10 / f_min_hz
    if not finite(value) then
        error("Duration exceeds numeric range", 2)
    end
    return {
        minimum_seconds = value,
        advisory_cycles = 10,
        validity_guaranteed = false
    }
end

function M.guide_cycles_per_minute(frequency_hz)
    positive(frequency_hz, "Guide frequency")
    local rate = frequency_hz * 60
    if not finite(rate) then
        error("Conversion exceeds numeric range", 2)
    end
    return {
        frequency_hz = frequency_hz,
        guide_cycles_per_minute = rate,
        observed_breathing = false
    }
end

local function integrate(f, p, lower, upper)
    local total = 0
    for i = 1, #f - 1 do
        local left = math.max(lower, f[i])
        local right = math.min(upper, f[i + 1])
        if right > left then
            local width = f[i + 1] - f[i]
            local slope = (p[i + 1] - p[i]) / width
            local p_left = p[i] + slope * (left - f[i])
            local p_right = p[i] + slope * (right - f[i])
            total = total + (p_left + p_right) * (right - left) / 2
        end
    end
    return total
end

function M.estimate(series_ms, config)
    local n = dense(series_ms)
    if type(config) ~= "table" then
        error("Provide an explicit estimator configuration", 2)
    end

    local fs = config.sample_rate_hz
    local length = config.segment_samples
    local overlap = config.overlap_samples
    local floor_power = config.total_power_floor_ms2

    positive(fs, "Sampling rate")
    nonnegative(floor_power, "Total power floor")
    if type(length) ~= "number" or length % 1 ~= 0
        or length < 4 or length > 4096 or length % 2 ~= 0 then
        error("Segment length must be an even integer from 4 to 4096", 2)
    end
    if type(overlap) ~= "number" or overlap % 1 ~= 0
        or overlap ~= length / 2 then
        error("This protocol requires exactly 50 percent overlap", 2)
    end
    if n < 2 then
        return {status = "insufficient_samples", concentration = nil}
    end
    if fs / 2 < 0.26 then
        return {status = "analysis_band_exceeds_nyquist", concentration = nil}
    end

    local duration = (n - 1) / fs
    local segment_duration = (length - 1) / fs
    if not finite(duration) or not finite(segment_duration) then
        error("Duration arithmetic exceeds numeric range", 2)
    end
    if duration < 250 or segment_duration < 250 then
        return {
            status = "below_ten_cycle_advisory",
            observed_seconds = duration,
            segment_observed_seconds = segment_duration,
            required_seconds = 250,
            concentration = nil
        }
    end
    if n < length then
        return {status = "segment_does_not_fit", concentration = nil}
    end

    local step = length - overlap
    local segments = math.floor((n - length) / step) + 1
    local bins = length / 2 + 1
    local operations = segments * bins * length
    if not finite(operations) or operations > 10000000 then
        error("Offline DFT budget exceeded; use a reviewed FFT adapter", 2)
    end

    local window, window_energy = {}, 0
    for j = 0, length - 1 do
        local w = 0.5 - 0.5 * math.cos(2 * pi * j / length)
        window[j + 1] = w
        window_energy = window_energy + w * w
    end

    local frequencies, psd = {}, {}
    for k = 0, length / 2 do
        frequencies[k + 1] = k * fs / length
        psd[k + 1] = 0
    end

    for segment = 0, segments - 1 do
        local start = segment * step + 1
        local mean = 0
        for j = 0, length - 1 do
            mean = mean + series_ms[start + j] / length
        end
        for k = 0, length / 2 do
            local re, im = 0, 0
            for j = 0, length - 1 do
                local value = (series_ms[start + j] - mean) * window[j + 1]
                local angle = 2 * pi * k * j / length
                re = re + value * math.cos(angle)
                im = im - value * math.sin(angle)
            end
            local power = (re * re + im * im) / (fs * window_energy)
            if k > 0 and k < length / 2 then
                power = 2 * power
            end
            psd[k + 1] = psd[k + 1] + power / segments
        end
    end

    for _, power in ipairs(psd) do
        if not finite(power) or power < 0 then
            return {status = "invalid_psd_arithmetic", concentration = nil}
        end
    end

    local peak_index = nil
    for i, frequency in ipairs(frequencies) do
        if frequency >= 0.04 and frequency <= 0.26 then
            if not peak_index or psd[i] > psd[peak_index] then
                peak_index = i
            end
        end
    end
    if not peak_index then
        return {status = "no_peak_bin_in_band", concentration = nil}
    end

    local peak = frequencies[peak_index]
    local lower = math.max(0.04, peak - 0.015)
    local upper = math.min(0.26, peak + 0.015)
    local total = integrate(frequencies, psd, 0.04, 0.26)
    local numerator = integrate(frequencies, psd, lower, upper)

    if not finite(total) or not finite(numerator) or total <= floor_power then
        return {status = "invalid_or_insufficient_band_power", concentration = nil}
    end
    local concentration = numerator / total
    if not finite(concentration) or concentration < 0 or concentration > 1 then
        return {status = "invalid_concentration", concentration = nil}
    end

    return {
        status = "exploratory_prv_feature",
        prv_spectral_concentration = concentration,
        peak_frequency_hz = peak,
        numerator_lower_hz = lower,
        numerator_upper_hz = upper,
        numerator_width_hz = upper - lower,
        total_band_power_ms2 = total,
        peak_band_power_ms2 = numerator,
        observed_seconds = duration,
        segment_observed_seconds = segment_duration,
        nominal_bin_spacing_hz = fs / length,
        averaged_segments = segments,
        unused_tail_samples = n - ((segments - 1) * step + length),
        window = "periodic_hann",
        detrending = "per_segment_mean_removal",
        integration = "piecewise_linear_trapezoidal",
        physiological_state_inferred = false,
        measurement_validity_established = false
    }
end

return M
