local M = {}

local dispositions = {
    usable = true,
    unusable = true,
    stopped = true,
    declined = true,
    unknown = true
}

local limitations = {
    camera_or_application_unavailable = true,
    timestamp_integrity = true,
    insufficient_duration = true,
    signal_quality_below_criterion = true,
    processing_error = true,
    cause_unresolved = true
}

local evidence_states = {
    observed = true,
    supported_inference = true,
    unresolved = true
}

local fields = {
    individual_pulse_to_pulse_interval_ms = {
        source = "camera_ppg",
        unit = "ms"
    },
    individual_prv_rmssd_ms = {
        source = "camera_ppg",
        unit = "ms"
    },
    individual_prv_spectral_concentration = {
        source = "camera_ppg",
        unit = "dimensionless"
    },
    individual_prv_rmssd_change_ms = {
        source = "camera_ppg",
        unit = "ms"
    },
    individual_prv_rmssd_slope_ms_per_s = {
        source = "camera_ppg",
        unit = "ms_per_s"
    }
}

local function dense_size(values)
    if type(values) ~= "table" then
        error("Provide a dense observation array", 3)
    end
    local n = 0
    for key in pairs(values) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            error("Invalid observation index", 3)
        end
        n = n + 1
    end
    for i = 1, n do
        if values[i] == nil then
            error("Observation array contains a gap", 3)
        end
    end
    return n
end

local function ratio(numerator, denominator)
    if denominator == 0 then
        return nil
    end
    return numerator / denominator
end

function M.validate_observation(record)
    if type(record) ~= "table" then
        error("Provide an acquisition observation", 2)
    end

    local allowed = {
        disposition = true,
        limitation_class = true,
        evidence_state = true
    }
    for key in pairs(record) do
        if not allowed[key] then
            error("Unexpected acquisition field; private metadata is excluded", 2)
        end
    end
    if not dispositions[record.disposition] then
        error("Unsupported acquisition disposition", 2)
    end

    if record.disposition == "unusable" then
        if not limitations[record.limitation_class]
            or not evidence_states[record.evidence_state] then
            error("Unusable recordings require a limitation and evidence state", 2)
        end
        if record.limitation_class == "cause_unresolved"
            and record.evidence_state ~= "unresolved" then
            error("An unresolved cause must retain unresolved evidence status", 2)
        end
    elseif record.limitation_class ~= nil or record.evidence_state ~= nil then
        error("Other dispositions do not require failure attribution", 2)
    end
    return true
end

function M.aggregate(records)
    local n = dense_size(records)
    local counts = {
        usable = 0,
        unusable = 0,
        stopped = 0,
        declined = 0,
        unknown = 0
    }
    local classes = {}
    for class in pairs(limitations) do
        classes[class] = 0
    end

    for i = 1, n do
        local record = records[i]
        M.validate_observation(record)
        counts[record.disposition] = counts[record.disposition] + 1
        if record.disposition == "unusable" then
            classes[record.limitation_class] =
                classes[record.limitation_class] + 1
        end
    end

    local assessed = counts.usable + counts.unusable
    local attempted = assessed + counts.stopped + counts.unknown
    return {
        status = "internal_aggregate_not_release_approved",
        disposition_counts = counts,
        limitation_counts = classes,
        assessed_acquisitions = assessed,
        attempted_acquisitions = attempted,
        assessed_unusable_fraction = ratio(counts.unusable, assessed),
        usable_attempt_yield = ratio(counts.usable, attempted),
        participant_failure_attributed = false,
        participant_profile_created = false,
        automatic_retry_authorized = false
    }
end

function M.validate_feature(field, source, unit)
    local specification = fields[field]
    if not specification then
        return {
            accepted = false,
            message = "Use a reviewed individual pulse-derived field.",
            interpersonal_claim_authorized = false
        }
    end
    if source ~= specification.source or unit ~= specification.unit then
        return {
            accepted = false,
            message = "Measurement source or unit does not match the registry.",
            interpersonal_claim_authorized = false
        }
    end
    return {
        accepted = true,
        field = field,
        source = specification.source,
        unit = specification.unit,
        scope = "individual_measurement_only",
        feature_validity_established = false,
        recovery_established = false,
        interpersonal_claim_authorized = false
    }
end

return M
