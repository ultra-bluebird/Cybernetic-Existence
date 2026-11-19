local M = {}

local thresholds = {
    ISO14851 = 60.0,
    ISO14855 = 60.0,
    OECD301 = 60.0,
    OECD201 = 50.0,
    OECD202 = 50.0
}

local function finite(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function in_range(value, low, high)
    return finite(value) and value >= low and value <= high
end

local function clamp(value, low, high)
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

function M.assess(sample)
    if type(sample) ~= "table" then
        return { accepted = false, reason = "invalid_sample", readiness = 0.0 }
    end

    local threshold = thresholds[sample.method]
    if threshold == nil then
        return { accepted = false, reason = "unsupported_method", readiness = 0.0 }
    end

    local fields = {
        { sample.blank_mg_l, 0.0, 100000.0 },
        { sample.inoculum_mg_l, 0.0, 100000.0 },
        { sample.reference_mg_l, 0.0, 100000.0 },
        { sample.test_mg_l, 0.0, 100000.0 },
        { sample.reference_pass_day, 0.0, 60.0 },
        { sample.test_pass_day, 0.0, 60.0 },
        { sample.temperature_c, 0.0, 45.0 },
        { sample.ph, 4.0, 10.0 }
    }

    for _, field in ipairs(fields) do
        if not in_range(field[1], field[2], field[3]) then
            return { accepted = false, reason = "invalid_measurement_range", readiness = 0.0 }
        end
    end

    local denominator = math.max(sample.reference_mg_l - sample.blank_mg_l, 0.001)
    local corrected_reference = clamp(
        100.0 * (sample.reference_mg_l - sample.blank_mg_l) / denominator, 0.0, 100.0)
    local corrected_test = clamp(
        100.0 * (sample.test_mg_l - sample.blank_mg_l) / denominator, 0.0, 100.0)

    local readiness = clamp(
        0.50 * clamp(corrected_test / threshold, 0.0, 1.0) +
        0.20 * (corrected_reference >= 95.0 and 1.0 or corrected_reference / 95.0) +
        0.15 * clamp(1.0 - math.abs(sample.temperature_c - 20.0) / 20.0, 0.0, 1.0) +
        0.10 * clamp(1.0 - math.abs(sample.ph - 7.0) / 3.0, 0.0, 1.0) +
        0.05 * clamp(1.0 - sample.test_pass_day / 60.0, 0.0, 1.0),
        0.0,
        1.0)

    local accepted =
        corrected_test >= threshold and
        corrected_reference >= 95.0 and
        sample.test_pass_day <= 28.0

    return {
        accepted = accepted,
        reason = accepted and "advisory_candidate" or "insufficient_evidence",
        corrected_test_pct = corrected_test,
        corrected_reference_pct = corrected_reference,
        readiness = readiness,
        mode = "advisory_only"
    }
end

return M
