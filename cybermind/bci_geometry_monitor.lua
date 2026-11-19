-- Lua 5.4.
-- Advisory latency monitor for a declared capability-mediation boundary.
-- No hardware control, neural processing, modality switching, or audit store.
-- Import: local monitor = require("cybermind.bci_geometry_monitor")
-- Tests: assert(monitor.self_test())
--
-- Timestamps are injected integer milliseconds from one monotonic domain.
-- Returned tables are independent snapshots.
-- The bounded ring stores latency and timestamps only.

local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
local MAX_TIME = 9000000000000

local function fail(code, path, message)
    error({code = code, path = path, message = message}, 0)
end

local function fields(value, allowed, path)
    if type(value) ~= "table" or getmetatable(value) ~= nil then
        fail("INVALID_TABLE", path, "Expected a plain table")
    end
    for key in next, value do
        if type(key) ~= "string" or not allowed[key] then
            fail("UNKNOWN_FIELD", path, "Unexpected field")
        end
    end
end

local function number(value, path, minimum, maximum, whole)
    if type(value) ~= "number" or value ~= value
        or value == math.huge or value == -math.huge
        or value < minimum or value > maximum
        or (whole and value % 1 ~= 0) then
        fail("INVALID_NUMBER", path, "Number violates declared bounds")
    end
    return value
end

local function text(value, path)
    if type(value) ~= "string" or #value > 4096
        or not value:match("%S") or value:find("%c") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function protect(operation)
    local ok, result = pcall(operation)
    if ok then return result end
    if type(result) == "table" and type(result.code) == "string" then
        return nil, result
    end
    return nil, {
        code = "INTERNAL_ERROR",
        path = "module",
        message = "Unexpected internal failure"
    }
end

local CONFIG_FIELDS = {
    capability = true,
    latency_definition = true,
    threshold_basis = true,
    window_capacity = true,
    minimum_samples = true,
    minimum_span_ms = true,
    quantile = true,
    half_life_ms = true,
    trigger_latency_ms = true,
    recovery_latency_ms = true,
    hard_latency_ms = true,
    maximum_latency_ms = true,
    maximum_gap_ms = true,
    maximum_delivery_age_ms = true,
    recovery_observations = true,
    recovery_dwell_ms = true
}

local function configuration(source)
    fields(source, CONFIG_FIELDS, "config")
    local c = {
        capability = text(source.capability, "config.capability"),
        latency_definition = text(
            source.latency_definition, "config.latency_definition"
        ),
        threshold_basis = text(source.threshold_basis, "config.threshold_basis")
    }

    c.window_capacity = number(source.window_capacity,
        "config.window_capacity", 2, 4096, true)
    c.minimum_samples = number(source.minimum_samples,
        "config.minimum_samples", 2, c.window_capacity, true)
    c.minimum_span_ms = number(source.minimum_span_ms,
        "config.minimum_span_ms", 1, 86400000, true)
    c.quantile = number(source.quantile, "config.quantile", 0.5, 1, false)
    c.half_life_ms = number(source.half_life_ms,
        "config.half_life_ms", 1, 86400000, true)
    c.maximum_latency_ms = number(source.maximum_latency_ms,
        "config.maximum_latency_ms", 1, 86400000, false)
    c.recovery_latency_ms = number(source.recovery_latency_ms,
        "config.recovery_latency_ms", 0, c.maximum_latency_ms, false)
    c.trigger_latency_ms = number(source.trigger_latency_ms,
        "config.trigger_latency_ms", 0, c.maximum_latency_ms, false)
    c.hard_latency_ms = number(source.hard_latency_ms,
        "config.hard_latency_ms", 0, c.maximum_latency_ms, false)

    if not (c.recovery_latency_ms < c.trigger_latency_ms
        and c.trigger_latency_ms < c.hard_latency_ms) then
        fail("INVALID_HYSTERESIS", "config",
            "Require recovery < trigger < hard latency thresholds")
    end

    c.maximum_gap_ms = number(source.maximum_gap_ms,
        "config.maximum_gap_ms", 1, 86400000, true)
    c.maximum_delivery_age_ms = number(source.maximum_delivery_age_ms,
        "config.maximum_delivery_age_ms", 0, 86400000, true)
    c.recovery_observations = number(source.recovery_observations,
        "config.recovery_observations", 2, 1000000, true)
    c.recovery_dwell_ms = number(source.recovery_dwell_ms,
        "config.recovery_dwell_ms", 1, 86400000, true)

    return c
end

function M.new(source)
    return protect(function()
        local c = configuration(source)
        local ring = {}
        local head, size = 1, 0
        local ewma
        local last_observed, last_received
        local good_since, good_count = nil, 0
        local concern_seen = false
        local closed = false
        local api = {}

        local function reset_evidence()
            ring = {}
            head, size = 1, 0
            ewma = nil
            last_observed = nil
            good_since, good_count = nil, 0
        end

        local function reset_recovery()
            good_since, good_count = nil, 0
        end

        local function append(latency, observed)
            local index
            if size < c.window_capacity then
                index = ((head + size - 1) % c.window_capacity) + 1
                size = size + 1
            else
                index = head
                head = (head % c.window_capacity) + 1
            end
            ring[index] = {latency = latency, observed = observed}
        end

        local function summarize()
            if size == 0 then return nil, 0 end
            local values = {}
            local oldest = ring[head].observed
            local newest = oldest

            for offset = 0, size - 1 do
                local index = ((head + offset - 1) % c.window_capacity) + 1
                local sample = ring[index]
                values[#values + 1] = sample.latency
                newest = sample.observed
            end

            table.sort(values)
            return values[math.ceil(c.quantile * size)], newest - oldest
        end

        local function result(status, reasons, now)
            local tail, span = summarize()
            return {
                schema_version = VERSION,
                attribution = ATTRIBUTION,
                attribution_scope =
                    "Credit and workstream metadata only; not identity, "
                    .. "consent, authorization, execution evidence, or authority.",
                status = status,
                reasons = reasons,
                capability = c.capability,
                sample_count = size,
                window_span_ms = span,
                ewma_latency_ms = ewma,
                latency_quantile = tail,
                quantile_level = c.quantile,
                last_observed_ms = last_observed,
                evaluated_ms = now,
                qualifying_observations = good_count,
                qualifying_since_ms = good_since,
                concern_previously_observed = concern_seen,
                instruction =
                    "Advisory only: preserve existing essential access; "
                    .. "do not switch, disable, or restore a modality.",
                scope =
                    "Recorded latency indicators only; no confidence, "
                    .. "reliability, clinical-safety, or capability guarantee."
            }
        end

        local function require_open()
            if closed then
                fail("CLOSED_MONITOR", "monitor", "Create a new monitor")
            end
        end

        local function validate_received(now)
            number(now, "received_ms", 0, MAX_TIME, true)
            if last_received ~= nil and now < last_received then
                fail("CLOCK_REVERSED", "received_ms",
                    "Injected monotonic time moved backward")
            end
        end

        function api.observe(sample)
            return protect(function()
                require_open()
                fields(sample, {
                    latency_ms = true,
                    observed_ms = true,
                    received_ms = true
                }, "sample")

                local latency = number(sample.latency_ms,
                    "sample.latency_ms", 0, c.maximum_latency_ms, false)
                local observed = number(sample.observed_ms,
                    "sample.observed_ms", 0, MAX_TIME, true)
                local received = sample.received_ms
                validate_received(received)

                if observed > received then
                    fail("FUTURE_OBSERVATION", "sample.observed_ms",
                        "Observation cannot follow receipt in the same clock domain")
                end
                if last_observed ~= nil and observed <= last_observed then
                    fail("NONINCREASING_OBSERVATION", "sample.observed_ms",
                        "Observations must be strictly time ordered")
                end

                local stale = received - observed > c.maximum_delivery_age_ms
                    or received - observed > c.maximum_gap_ms

                if stale then
                    last_received = received
                    reset_recovery()
                    return result("insufficient_fresh_evidence",
                        {"sample_delivery_stale"}, received)
                end

                local gap = last_observed ~= nil
                    and observed - last_observed > c.maximum_gap_ms

                if gap then reset_evidence() end

                if ewma == nil then
                    ewma = latency
                else
                    local elapsed = observed - last_observed
                    local alpha = 1 - math.exp(
                        -math.log(2) * elapsed / c.half_life_ms
                    )
                    ewma = alpha * latency + (1 - alpha) * ewma
                end

                append(latency, observed)
                last_observed, last_received = observed, received

                local tail, span = summarize()
                local sufficient = size >= c.minimum_samples
                    and span >= c.minimum_span_ms
                local reasons = {}

                if gap then reasons[#reasons + 1] = "evidence_reset_after_gap" end

                if latency >= c.hard_latency_ms then
                    concern_seen = true
                    reset_recovery()
                    reasons[#reasons + 1] = "current_sample_hard_limit"
                    return result("concern", reasons, received)
                end

                if not sufficient then
                    reset_recovery()
                    reasons[#reasons + 1] = "minimum_evidence_not_met"
                    return result("warming", reasons, received)
                end

                if ewma > c.trigger_latency_ms
                    or tail > c.trigger_latency_ms then
                    concern_seen = true
                    reset_recovery()
                    if ewma > c.trigger_latency_ms then
                        reasons[#reasons + 1] = "ewma_trigger"
                    end
                    if tail > c.trigger_latency_ms then
                        reasons[#reasons + 1] = "quantile_trigger"
                    end
                    return result("concern", reasons, received)
                end

                local qualifying = ewma <= c.recovery_latency_ms
                    and tail <= c.recovery_latency_ms

                if qualifying then
                    if good_since == nil then good_since = observed end
                    good_count = math.min(
                        good_count + 1, c.recovery_observations
                    )
                else
                    reset_recovery()
                end

                if concern_seen and qualifying
                    and good_count >= c.recovery_observations
                    and observed - good_since >= c.recovery_dwell_ms then
                    return result("recovery_candidate",
                        {"participant_controlled_transition_review_only"}, received)
                end

                return result("monitoring",
                    qualifying and {"recorded_indicators_below_recovery_limits"}
                        or {"hysteresis_band"}, received)
            end)
        end

        function api.tick(now)
            return protect(function()
                require_open()
                validate_received(now)
                last_received = now

                if last_observed == nil
                    or now - last_observed > c.maximum_gap_ms then
                    reset_recovery()
                    return result("insufficient_fresh_evidence",
                        {"no_current_observation"}, now)
                end
                return result("monitoring",
                    {"tick_is_not_new_recovery_evidence"}, now)
            end)
        end

        function api.close()
            reset_evidence()
            last_received = nil
            closed = true
            return {status = "closed", retained_samples = 0}
        end

        return api
    end)
end

local function fixture()
    return {
        capability = "Written communication",
        latency_definition = "Synthetic event-to-private-candidate latency",
        threshold_basis = "Test fixture only; not clinical thresholds",
        window_capacity = 4,
        minimum_samples = 2,
        minimum_span_ms = 10,
        quantile = 0.95,
        half_life_ms = 10,
        trigger_latency_ms = 100,
        recovery_latency_ms = 50,
        hard_latency_ms = 200,
        maximum_latency_ms = 10000,
        maximum_gap_ms = 100,
        maximum_delivery_age_ms = 20,
        recovery_observations = 2,
        recovery_dwell_ms = 10
    }
end

function M.self_test()
    local monitor = assert(M.new(fixture()))
    local empty = assert(monitor.tick(0))
    assert(empty.status == "insufficient_fresh_evidence")
    assert(empty.ewma_latency_ms == nil)

    local hard = assert(monitor.observe({
        latency_ms = 250, observed_ms = 1, received_ms = 1
    }))
    assert(hard.status == "concern")
    assert(hard.reasons[1] == "current_sample_hard_limit")

    local recovered
    for time = 11, 101, 10 do
        recovered = assert(monitor.observe({
            latency_ms = 10, observed_ms = time, received_ms = time
        }))
    end
    assert(recovered.status == "recovery_candidate")
    assert(recovered.sample_count == 4)

    local stale = assert(monitor.tick(202))
    assert(stale.status == "insufficient_fresh_evidence")
    assert(stale.qualifying_observations == 0)

    local gap = assert(monitor.observe({
        latency_ms = 10, observed_ms = 203, received_ms = 203
    }))
    assert(gap.status == "warming")
    assert(gap.sample_count == 1)

    local value, err = monitor.observe({
        latency_ms = 10, observed_ms = 204, received_ms = 202
    })
    assert(value == nil and err.code == "CLOCK_REVERSED")

    local closed = monitor.close()
    assert(closed.retained_samples == 0)
    value, err = monitor.tick(205)
    assert(value == nil and err.code == "CLOSED_MONITOR")

    local independent = assert(M.new(fixture()))
    local first = assert(independent.observe({
        latency_ms = 20, observed_ms = 0, received_ms = 0
    }))
    first.reasons[1] = "Caller edit"
    assert(assert(independent.tick(1)).reasons[1] ==
        "tick_is_not_new_recovery_evidence")

    local config = fixture()
    config.window_capacity = 1000000000
    value, err = M.new(config)
    assert(value == nil and err.code == "INVALID_NUMBER")

    return true
end

return M
