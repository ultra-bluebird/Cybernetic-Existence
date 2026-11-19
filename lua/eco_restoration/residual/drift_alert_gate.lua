local M = {}

local allowed_classifications = {
    informational = true,
    human_review_pending = true,
    recalibration_candidate = true,
    data_expansion_required = true,
    withheld = true
}

local function finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

function M.route(alert)
    if type(alert) ~= "table" then
        return {
            status = "withheld",
            queue = "human_review_queue",
            reason = "residual alert must be a table"
        }
    end

    if not allowed_classifications[alert.classification] then
        return {
            status = "withheld",
            queue = "human_review_queue",
            reason = "residual alert classification is invalid"
        }
    end

    if not finite_number(alert.z_score) then
        return {
            status = "withheld",
            queue = "human_review_queue",
            reason = "residual alert z-score must be finite"
        }
    end

    if alert.classification == "recalibration_candidate" then
        return {
            status = "human_review_pending",
            queue = "human_review_queue",
            reason = "persistent residual drift requires human acknowledgment before recalibration"
        }
    end

    if alert.classification == "data_expansion_required" then
        return {
            status = "human_review_pending",
            queue = "evidence_gap_review_queue",
            reason = "additional in-scope evidence is required before recalibration"
        }
    end

    if alert.classification == "withheld" then
        return {
            status = "withheld",
            queue = "human_review_queue",
            reason = "residual result is withheld pending governance or scope resolution"
        }
    end

    return {
        status = "informational",
        queue = "local_monitoring_queue",
        reason = "residual remains within the configured monitoring bounds"
    }
end

return M
