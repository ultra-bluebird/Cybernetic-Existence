local FareValidationFairnessAuditor = {}
FareValidationFairnessAuditor.__index = FareValidationFairnessAuditor

local REQUIRED_MEDIA = {
    anonymous_nfc_token = true,
    disposable_paper_token = true,
    accessible_assistance_panel = true,
    offline_stored_value_media = true,
}

local function assert_table(value, name)
    if type(value) ~= "table" then
        error(name .. " must be a table", 3)
    end
end

local function assert_non_negative_integer(value, name)
    if type(value) ~= "number" or value < 0 or value % 1 ~= 0 then
        error(name .. " must be a non-negative integer", 3)
    end
end

local function assert_fraction(value, name)
    if type(value) ~= "number" or value < 0 or value > 1 then
        error(name .. " must be a fraction from 0 through 1", 3)
    end
end

local function copy_array(values)
    local result = {}
    for index, value in ipairs(values) do
        result[index] = value
    end
    return result
end

function FareValidationFairnessAuditor.new(policy)
    assert_table(policy, "policy")

    if policy.schema ~= "javasphere.transit-fare-validation-policy/v1" then
        error("policy schema is not supported", 2)
    end

    if policy.universal_validation_required ~= true then
        error("universal validation must be enabled", 2)
    end

    if policy.device_free_alternative_required ~= true then
        error("device-free validation support is required", 2)
    end

    if policy.offline_payment_required ~= true then
        error("offline payment support is required", 2)
    end

    if policy.first_non_validation_requires_courtesy ~= true then
        error("first non-validation courtesy handling is required", 2)
    end

    if policy.human_selection_for_inspection_allowed ~= false then
        error("discretionary human selection is prohibited", 2)
    end

    if policy.identity_attributes_stored ~= false or
        policy.route_history_stored ~= false or
        policy.persistent_device_identifier_stored ~= false then
        error("identity, route history, and persistent device data must not be stored", 2)
    end

    if policy.aggregate_reporting_only ~= true then
        error("only aggregate reporting is permitted", 2)
    end

    assert_table(policy.minimum_supported_media, "policy.minimum_supported_media")

    local media_seen = {}
    for _, medium in ipairs(policy.minimum_supported_media) do
        media_seen[medium] = true
    end

    for medium, _ in pairs(REQUIRED_MEDIA) do
        if media_seen[medium] ~= true then
            error("missing required fare medium: " .. medium, 2)
        end
    end

    return setmetatable({
        policy = policy,
    }, FareValidationFairnessAuditor)
end

function FareValidationFairnessAuditor:evaluate_aggregate(report)
    assert_table(report, "report")
    assert_table(report.media, "report.media")

    local findings = {}
    local total_attempts = 0
    local total_successes = 0
    local total_courtesy = 0

    for medium, _ in pairs(REQUIRED_MEDIA) do
        local metrics = report.media[medium]

        if metrics == nil then
            table.insert(findings, {
                code = "missing-required-medium-observation",
                severity = "review",
                medium = medium,
                message = "No aggregate reliability observation is available for a required fare medium.",
            })
        else
            assert_table(metrics, "report.media." .. medium)
            assert_non_negative_integer(metrics.attempts, "attempts")
            assert_non_negative_integer(metrics.successes, "successes")
            assert_non_negative_integer(metrics.courtesy_events, "courtesy_events")

            if metrics.successes > metrics.attempts then
                error("successes cannot exceed attempts", 2)
            end

            if metrics.courtesy_events > metrics.attempts then
                error("courtesy_events cannot exceed attempts", 2)
            end

            total_attempts = total_attempts + metrics.attempts
            total_successes = total_successes + metrics.successes
            total_courtesy = total_courtesy + metrics.courtesy_events
        end
    end

    if total_attempts == 0 then
        table.insert(findings, {
            code = "insufficient-aggregate-evidence",
            severity = "review",
            message = "No aggregate validation attempts are available for fairness evaluation.",
        })
    end

    local overall_success_rate = 0
    if total_attempts > 0 then
        overall_success_rate = total_successes / total_attempts
    end

    local reliability_gap_limit = report.maximum_allowed_success_rate_gap
    assert_fraction(reliability_gap_limit, "report.maximum_allowed_success_rate_gap")

    for medium, _ in pairs(REQUIRED_MEDIA) do
        local metrics = report.media[medium]

        if metrics ~= nil and metrics.attempts > 0 then
            local success_rate = metrics.successes / metrics.attempts
            local gap = math.abs(success_rate - overall_success_rate)

            if gap > reliability_gap_limit then
                table.insert(findings, {
                    code = "validation-reliability-gap",
                    severity = "review",
                    medium = medium,
                    success_rate = success_rate,
                    overall_success_rate = overall_success_rate,
                    gap = gap,
                    message = "A required fare medium has an aggregate validation success rate outside the declared parity bound.",
                })
            end
        end
    end

    if report.human_selected_inspections ~= 0 then
        table.insert(findings, {
            code = "discretionary-inspection-observed",
            severity = "blocking",
            message = "Human-selected fare inspection is prohibited by the universal validation policy.",
        })
    end

    if report.identity_collection_events ~= 0 or
        report.route_history_collection_events ~= 0 or
        report.persistent_device_collection_events ~= 0 then
        table.insert(findings, {
            code = "prohibited-data-collection-observed",
            severity = "blocking",
            message = "Aggregate evidence indicates prohibited identity, route-history, or persistent-device collection.",
        })
    end

    local accepted = true
    for _, finding in ipairs(findings) do
        if finding.severity == "blocking" then
            accepted = false
            break
        end
    end

    return {
        schema = "javasphere.transit-fare-validation-fairness-evaluation/v1",
        accepted_for_human_review = accepted,
        automated_enforcement_authorized = false,
        overall_success_rate = overall_success_rate,
        total_attempts = total_attempts,
        total_courtesy_events = total_courtesy,
        findings = copy_array(findings),
        required_next_step = accepted and
            "Review aggregate modality reliability and accessibility outcomes before changing validator configuration." or
            "Suspend the affected enforcement configuration, preserve accessible fare access, and conduct human review.",
    }
end

return FareValidationFairnessAuditor
