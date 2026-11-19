-- Lua 5.4.
-- Requires cybermind/bci_geometry_monitor.lua from the preceding artifact.
-- No notifications, hardware access, modality changes, or external actions.
-- Import: local observer = require("cybermind.bci_geometry_observer")
-- Tests: assert(observer.self_test())
--
-- All time values are injected monotonic milliseconds in one clock domain.
-- The host must authenticate preference updates where appropriate.

local base = require("cybermind.bci_geometry_monitor")
local M = {}

local VERSION = "1.0.0"
local MAX_TIME = 9000000000000
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

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

local function integer(value, path, minimum, maximum)
    if type(value) ~= "number" or math.type(value) ~= "integer"
        or value < minimum or value > maximum then
        fail("INVALID_INTEGER", path, "Integer outside permitted range")
    end
    return value
end

local function preferences(value)
    fields(value, {
        recovery_notices_enabled = true,
        declined_until_ms = true,
        minimum_notice_interval_ms = true
    }, "preferences")

    if type(value.recovery_notices_enabled) ~= "boolean" then
        fail("INVALID_BOOLEAN", "preferences.recovery_notices_enabled",
            "Expected boolean")
    end

    return {
        recovery_notices_enabled = value.recovery_notices_enabled,
        declined_until_ms = integer(
            value.declined_until_ms, "preferences.declined_until_ms",
            0, MAX_TIME
        ),
        minimum_notice_interval_ms = integer(
            value.minimum_notice_interval_ms,
            "preferences.minimum_notice_interval_ms", 0, 86400000
        )
    }
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

function M.new(config, initial_preferences)
    return protect(function()
        local policy = preferences(initial_preferences or {
            recovery_notices_enabled = false,
            declined_until_ms = 0,
            minimum_notice_interval_ms = 0
        })

        local monitor, err = base.new(config)
        if not monitor then error(err, 0) end

        local episode = "quiet"
        local last_time
        local last_notice_eligible
        local closed = false
        local api = {}

        local function check_time(now)
            integer(now, "now", 0, MAX_TIME)
            if last_time ~= nil and now < last_time then
                fail("CLOCK_REVERSED", "now",
                    "Injected monotonic time moved backward")
            end
        end

        local function require_open()
            if closed then
                fail("CLOSED_OBSERVER", "observer", "Create a new observer")
            end
        end

        local function notice_disposition(now)
            if not policy.recovery_notices_enabled then
                return "suppressed_by_preference"
            end
            if now < policy.declined_until_ms then
                return "suppressed_by_decline_interval"
            end
            if last_notice_eligible ~= nil
                and now - last_notice_eligible
                    < policy.minimum_notice_interval_ms then
                return "suppressed_by_minimum_interval"
            end
            last_notice_eligible = now
            return "eligible_for_separate_notification_workflow"
        end

        local function adapt(raw, from_sample)
            local events = {}
            local notice = "not_requested"

            if from_sample and raw.status == "concern" then
                if episode ~= "concern_open" then
                    episode = "concern_open"
                    events[#events + 1] = {
                        kind = "latency_concern_onset_observed",
                        observed_ms = raw.last_observed_ms,
                        evaluated_ms = raw.evaluated_ms
                    }
                end
            elseif from_sample and raw.status == "recovery_candidate" then
                if episode == "concern_open" then
                    episode = "requalified"
                    notice = notice_disposition(raw.evaluated_ms)
                    events[#events + 1] = {
                        kind = "latency_requalification_observed",
                        observed_ms = raw.last_observed_ms,
                        evaluated_ms = raw.evaluated_ms
                    }
                end
            end

            local observation = raw.status
            if observation == "recovery_candidate" then
                observation = "sustained_requalification_recorded"
            elseif not from_sample and observation == "monitoring" then
                observation = "freshness_checked_without_new_sample"
            end

            return {
                schema_version = VERSION,
                attribution = ATTRIBUTION,
                attribution_scope =
                    "Credit and workstream metadata only; not identity, "
                    .. "consent, authorization, execution evidence, or authority.",
                observation = observation,
                episode_state = episode,
                events = events,
                recovery_notice = notice,
                measurement = {
                    sample_count = raw.sample_count,
                    window_span_ms = raw.window_span_ms,
                    ewma_latency_ms = raw.ewma_latency_ms,
                    latency_quantile = raw.latency_quantile,
                    quantile_level = raw.quantile_level,
                    last_observed_ms = raw.last_observed_ms,
                    evaluated_ms = raw.evaluated_ms,
                    qualifying_observations = raw.qualifying_observations,
                    qualifying_since_ms = raw.qualifying_since_ms
                },
                reasons = raw.reasons,
                scope =
                    "Latency observations and bounded event semantics only; "
                    .. "no notification, causal classification, consent finding, "
                    .. "capability guarantee, or execution authority."
            }
        end

        function api.observe(sample)
            return protect(function()
                require_open()
                if type(sample) ~= "table" or getmetatable(sample) ~= nil then
                    fail("INVALID_TABLE", "sample", "Expected a plain table")
                end
                check_time(sample.received_ms)
                local raw, failure = monitor.observe(sample)
                if not raw then error(failure, 0) end
                last_time = sample.received_ms
                return adapt(raw, true)
            end)
        end

        function api.tick(now)
            return protect(function()
                require_open()
                check_time(now)
                local raw, failure = monitor.tick(now)
                if not raw then error(failure, 0) end
                last_time = now
                return adapt(raw, false)
            end)
        end

        function api.set_preferences(value, now)
            return protect(function()
                require_open()
                check_time(now)
                local replacement = preferences(value)
                policy = replacement
                last_time = now
                return {
                    status = "preferences_updated",
                    historical_events_replayed = false,
                    recovery_episode_rearmed = false
                }
            end)
        end

        function api.close()
            monitor.close()
            closed = true
            return {
                status = "closed",
                retained_samples = 0,
                notifications_sent = 0
            }
        end

        return api
    end)
end

local function fixture()
    return {
        capability = "Written communication",
        latency_definition = "Synthetic input-to-private-candidate latency",
        threshold_basis = "Synthetic fixture; not validated thresholds",
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
    local function sample(observer, time, latency)
        return assert(observer.observe({
            latency_ms = latency,
            observed_ms = time,
            received_ms = time
        }))
    end

    local observer = assert(M.new(fixture()))
    local first = sample(observer, 0, 250)
    assert(#first.events == 1)
    assert(first.episode_state == "concern_open")

    local count = 0
    for time = 10, 200, 10 do
        local result = sample(observer, time, 10)
        for _, event in ipairs(result.events) do
            if event.kind == "latency_requalification_observed" then
                count = count + 1
                assert(result.recovery_notice == "suppressed_by_preference")
            end
        end
    end
    assert(count == 1)

    local gap = assert(observer.tick(400))
    assert(#gap.events == 0)
    assert(gap.episode_state == "requalified")

    for time = 410, 500, 10 do
        assert(#sample(observer, time, 10).events == 0)
    end

    assert(observer.set_preferences({
        recovery_notices_enabled = true,
        declined_until_ms = 1000,
        minimum_notice_interval_ms = 100
    }, 500))
    assert(#sample(observer, 510, 10).events == 0)

    local concern = sample(observer, 520, 250)
    assert(#concern.events == 1)

    local declined_event = false
    for time = 530, 720, 10 do
        local result = sample(observer, time, 10)
        if #result.events > 0 then
            assert(result.events[1].kind ==
                "latency_requalification_observed")
            assert(result.recovery_notice ==
                "suppressed_by_decline_interval")
            declined_event = true
        end
    end
    assert(declined_event)

    local value, err = observer.tick(719)
    assert(value == nil and err.code == "CLOCK_REVERSED")
    assert(observer.close().retained_samples == 0)

    return true
end

return M
