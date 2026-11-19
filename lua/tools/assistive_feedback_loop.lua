-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/assistive_feedback_loop.lua
-- Destination: lua/tools/

local AssistiveFeedbackLoop = {}
AssistiveFeedbackLoop.__index = AssistiveFeedbackLoop

local function required_text(value, field)
    assert(type(value) == "string" and value:match("%S"),
        (field or "value") .. " must be a non-empty string")
    return value
end

local function finite_number(value, field)
    assert(type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge,
        (field or "value") .. " must be a finite number")
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
    assert(not seen[value], "cyclic feedback values are not supported")
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

    return string.format("feedback:%08x", state)
end

local function normalized_modality(value)
    local modality = required_text(value, "modality"):lower()

    local allowed = {
        adaptive_switch = true,
        eye_tracking = true,
        haptic = true,
        keyboard = true,
        screen_reader = true,
        speech = true,
        text = true,
    }

    assert(allowed[modality], "unsupported assistive modality: " .. modality)
    return modality
end

local function classify_feedback(record)
    if record.success_rate < 0.50 then
        return "critical"
    end

    if record.success_rate < 0.75
        or record.satisfaction < 0.60
        or record.reliability < 0.65 then
        return "improvement_needed"
    end

    return "performing_well"
end

function AssistiveFeedbackLoop.new(config)
    config = config or {}

    return setmetatable({
        namespace = required_text(
            config.namespace or "augmented-hub-assistive-feedback",
            "namespace"
        ),
        minimum_samples_for_suggestion = math.max(
            1,
            math.floor(finite_number(
                config.minimum_samples_for_suggestion or 3,
                "minimum_samples_for_suggestion"
            ))
        ),
        local_feedback = {},
        aggregates = {},
        sequence = 0,
    }, AssistiveFeedbackLoop)
end

function AssistiveFeedbackLoop:record(feedback)
    assert(type(feedback) == "table", "feedback must be a table")
    assert(feedback.consent_to_record == true,
        "explicit local feedback consent is required")

    local feature_id = required_text(feedback.feature_id, "feature_id")
    local modality = normalized_modality(feedback.modality)
    local session_reference = required_text(
        feedback.local_session_reference,
        "local_session_reference"
    )

    local record = {
        reference = stable_reference(
            self.namespace,
            feature_id .. "|" .. modality .. "|" .. session_reference
                .. "|" .. tostring(self.sequence + 1)
        ),
        feature_id = feature_id,
        modality = modality,
        success_rate = clamp01(feedback.success_rate),
        satisfaction = clamp01(feedback.satisfaction),
        reliability = clamp01(feedback.reliability),
        cognitive_load = clamp01(feedback.cognitive_load or 0),
        fallback_used = feedback.fallback_used == true,
        interaction_count = math.max(
            0,
            math.floor(finite_number(
                feedback.interaction_count or 0,
                "interaction_count"
            ))
        ),
        user_note_category = feedback.user_note_category
            and required_text(feedback.user_note_category, "user_note_category")
            or "not_provided",
        recorded_at_utc = feedback.recorded_at_utc or utc_now(),
    }

    self.sequence = self.sequence + 1
    record.sequence = self.sequence
    record.classification = classify_feedback(record)
    record.knowledge_factor = 0.75
    record.eco_impact_value = 0.50
    record.harm_risk = clamp01(
        ((1 - record.success_rate) * 0.35)
        + ((1 - record.reliability) * 0.30)
        + (record.fallback_used and 0.15 or 0)
        + (record.cognitive_load * 0.20)
    )

    self.local_feedback[#self.local_feedback + 1] = record
    self:_update_aggregate(record)

    return copy_value(record)
end

function AssistiveFeedbackLoop:_update_aggregate(record)
    local aggregate_key = record.feature_id .. "|" .. record.modality
    local aggregate = self.aggregates[aggregate_key]

    if not aggregate then
        aggregate = {
            feature_id = record.feature_id,
            modality = record.modality,
            sample_count = 0,
            total_success_rate = 0,
            total_satisfaction = 0,
            total_reliability = 0,
            total_cognitive_load = 0,
            fallback_count = 0,
            total_interaction_count = 0,
            highest_harm_risk = 0,
        }
        self.aggregates[aggregate_key] = aggregate
    end

    aggregate.sample_count = aggregate.sample_count + 1
    aggregate.total_success_rate = aggregate.total_success_rate + record.success_rate
    aggregate.total_satisfaction = aggregate.total_satisfaction + record.satisfaction
    aggregate.total_reliability = aggregate.total_reliability + record.reliability
    aggregate.total_cognitive_load = aggregate.total_cognitive_load + record.cognitive_load
    aggregate.total_interaction_count =
        aggregate.total_interaction_count + record.interaction_count
    aggregate.highest_harm_risk =
        math.max(aggregate.highest_harm_risk, record.harm_risk)

    if record.fallback_used then
        aggregate.fallback_count = aggregate.fallback_count + 1
    end
end

function AssistiveFeedbackLoop:feature_summary(feature_id, modality)
    feature_id = required_text(feature_id, "feature_id")
    modality = normalized_modality(modality)

    local aggregate = self.aggregates[feature_id .. "|" .. modality]
    if not aggregate then
        return nil, "no local feedback recorded for this feature and modality"
    end

    local count = aggregate.sample_count

    return {
        feature_id = aggregate.feature_id,
        modality = aggregate.modality,
        sample_count = count,
        average_success_rate = aggregate.total_success_rate / count,
        average_satisfaction = aggregate.total_satisfaction / count,
        average_reliability = aggregate.total_reliability / count,
        average_cognitive_load = aggregate.total_cognitive_load / count,
        fallback_rate = aggregate.fallback_count / count,
        average_interaction_count = aggregate.total_interaction_count / count,
        highest_harm_risk = aggregate.highest_harm_risk,
        knowledge_factor = math.min(1.0, count / self.minimum_samples_for_suggestion),
        eco_impact_value = 0.50,
        harm_risk = aggregate.highest_harm_risk,
    }
end

function AssistiveFeedbackLoop:suggest_improvements(feature_id, modality)
    local summary, error_message = self:feature_summary(feature_id, modality)

    if not summary then
        return nil, error_message
    end

    if summary.sample_count < self.minimum_samples_for_suggestion then
        return {
            feature_id = summary.feature_id,
            modality = summary.modality,
            ready = false,
            suggestions = {},
            reason = "additional local feedback is required before suggesting changes",
            knowledge_factor = summary.knowledge_factor,
            eco_impact_value = 0.50,
            harm_risk = summary.harm_risk,
        }
    end

    local suggestions = {}

    if summary.average_success_rate < 0.75 then
        suggestions[#suggestions + 1] =
            "Reduce command-set complexity and require confirmation for ambiguous actions."
    end

    if summary.average_reliability < 0.70 then
        suggestions[#suggestions + 1] =
            "Review local signal-quality thresholds and activate a preferred fallback modality earlier."
    end

    if summary.average_satisfaction < 0.70 then
        suggestions[#suggestions + 1] =
            "Offer user-controlled adjustments for output timing, verbosity, and feedback modality."
    end

    if summary.average_cognitive_load >= 0.70 then
        suggestions[#suggestions + 1] =
            "Use shorter output segments, fewer concurrent choices, and explicit progress acknowledgments."
    end

    if summary.fallback_rate >= 0.25 then
        suggestions[#suggestions + 1] =
            "Investigate primary-modality reliability and verify that fallback preserves task context."
    end

    if #suggestions == 0 then
        suggestions[#suggestions + 1] =
            "Maintain current settings while continuing privacy-preserving local monitoring."
    end

    return {
        feature_id = summary.feature_id,
        modality = summary.modality,
        ready = true,
        suggestions = suggestions,
        basis = {
            sample_count = summary.sample_count,
            average_success_rate = summary.average_success_rate,
            average_satisfaction = summary.average_satisfaction,
            average_reliability = summary.average_reliability,
            average_cognitive_load = summary.average_cognitive_load,
            fallback_rate = summary.fallback_rate,
        },
        knowledge_factor = summary.knowledge_factor,
        eco_impact_value = 0.50,
        harm_risk = summary.harm_risk,
        generated_at_utc = utc_now(),
    }
end

function AssistiveFeedbackLoop:report_since(sequence)
    sequence = sequence or 0
    finite_number(sequence, "sequence")
    assert(sequence >= 0 and sequence % 1 == 0,
        "sequence must be a non-negative integer")

    local records = {}
    local highest_harm_risk = 0

    for _, record in ipairs(self.local_feedback) do
        if record.sequence > sequence then
            records[#records + 1] = copy_value(record)
            highest_harm_risk = math.max(highest_harm_risk, record.harm_risk)
        end
    end

    local total = #records
    local learning_coverage = math.min(
        1.0,
        total / self.minimum_samples_for_suggestion
    )

    return {
        from_sequence = sequence,
        record_count = total,
        records = records,
        knowledge_factor = learning_coverage,
        eco_impact_value = 0.50,
        harm_risk = highest_harm_risk,
        generated_at_utc = utc_now(),
    }
end

return AssistiveFeedbackLoop
