-- SPDX-License-Identifier: MIT OR Apache-2.0
-- In-process approval -> execution -> assertion -> summary association.
-- Requires exact_snapshot_gate.lua and run_lifecycle.lua.
--
-- Trusted host only:
--   controller approves, starts, commits outcomes, and confirms stop.
--   harness sink records trusted test predicates.
--
-- Untrusted/report consumer:
--   viewer accepts only a final receipt issued by this chain.
--
-- No cryptography, worker control, source execution, persistence, or I/O.
-- Resource-terminal VM signals must bypass ordinary guest recovery.
-- issuer() must be a reviewed host generator returning 32 correlation bytes.

local gate_module = require("exact_snapshot_gate")
local lifecycle_module = require("run_lifecycle")

local M = { VERSION = "1.0.0" }
local MAX_ASSERTIONS = 128
local MAX_COUNT = 1000000

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function fail(code)
    return nil, { status = "rejected", code = code }
end

local function decimal(value)
    if value == 0 then return "0" end
    local digits, reversed, output = "0123456789", {}, {}
    while value > 0 do
        local digit = value % 10
        reversed[#reversed + 1] = digits:sub(digit + 1, digit + 1)
        value = value // 10
    end
    for index = #reversed, 1, -1 do
        output[#output + 1] = reversed[index]
    end
    return table.concat(output)
end

function M.assertion_status(execution, planned, passed, failed, not_run)
    local states = {
        not_run = true, running = true, completed = true,
        language_error = true, terminated = true,
    }
    if type(execution) ~= "string" or not states[execution] then
        return fail("execution_state")
    end
    for _, value in ipairs({ planned, passed, failed, not_run }) do
        if math.type(value) ~= "integer" or value < 0 or value > MAX_COUNT then
            return fail("assertion_count")
        end
    end
    -- Explicit checks also reject missing arguments hidden by array holes.
    if math.type(planned) ~= "integer" or math.type(passed) ~= "integer"
        or math.type(failed) ~= "integer" or math.type(not_run) ~= "integer" then
        return fail("assertion_count")
    end
    if passed + failed + not_run ~= planned then
        return fail("assertion_partition")
    end
    if execution == "not_run" and (passed ~= 0 or failed ~= 0) then
        return fail("execution_count_conflict")
    end

    if planned == 0 then return "no assertions planned" end
    if failed > 0 and not_run > 0 then
        return "failures recorded; " .. decimal(not_run) .. " assertions not run"
    end
    if failed > 0 then return "failures recorded" end
    if not_run > 0 then
        return decimal(not_run) .. " planned assertions not run"
    end
    return "all planned assertions recorded as passed"
end

function M.prepare(snapshot, plan, issuer)
    if not plain(plan) or type(issuer) ~= "function" then
        return fail("configuration")
    end

    local count, maximum = 0, 0
    for key in next, plan do
        if math.type(key) ~= "integer" or key < 1 or key > MAX_ASSERTIONS then
            return fail("assertion_plan")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum then return fail("assertion_plan") end

    local labels, outcomes = {}, {}
    local plan_parts = { string.pack(">I4", count) }
    for index = 1, count do
        local label = rawget(plan, index)
        if type(label) ~= "string" or #label > 80
            or not label:match("^[a-z][a-z0-9_]*$")
            or outcomes[label] ~= nil then
            return fail("assertion_label")
        end
        labels[index] = label
        outcomes[label] = "not_run"
        plan_parts[#plan_parts + 1] = string.pack(">I4", #label) .. label
    end

    -- First validate/copy the original snapshot using its existing contract.
    local original, err = gate_module.prepare(snapshot)
    if not original then return nil, err end
    local prepared = assert(original.preview())

    -- Exact framed bytes bind the assertion plan beside the bundle.
    local bundle = prepared.bundle_snapshot_bytes
    prepared.bundle_snapshot_bytes = "BP1"
        .. string.pack(">I4", #bundle) .. bundle
        .. table.concat(plan_parts)

    local gate
    gate, err = gate_module.prepare(prepared)
    if not gate then return nil, err end

    local lifecycle = lifecycle_module.new()
    local approval, attempt, harness_receipt, final_receipt
    local correlation, final_record
    local harness_open, producer_fault = false, false
    local frozen_counts
    local controller, viewer = {}, {}

    function controller.preview()
        return gate.preview()
    end

    function controller.approve(reviewed)
        local accepted, diagnostic = gate.approve(reviewed)
        if not accepted then return nil, diagnostic end
        local transition = lifecycle.approve()
        if transition.status ~= "accepted" then return fail("approval_lifecycle") end
        approval = {}
        return approval
    end

    function controller.start(approval_handle, actual_snapshot)
        if approval == nil or not rawequal(approval_handle, approval) then
            return fail("approval_link_mismatch")
        end
        if lifecycle.snapshot().phase ~= "approved" then
            return fail("start_phase")
        end

        local generated, bytes = pcall(issuer)
        if not generated or type(bytes) ~= "string" or #bytes ~= 32 then
            return fail("correlation_generator")
        end

        local consumed, diagnostic = gate.consume(actual_snapshot)
        if not consumed then return nil, diagnostic end

        local handle = lifecycle.begin()
        if not handle then return fail("start_lifecycle") end
        attempt, correlation = handle, bytes
        harness_open = true

        local sink = {}

        function sink.expect(label, condition)
            if not harness_open or producer_fault
                or lifecycle.snapshot().phase ~= "running"
                or type(label) ~= "string"
                or outcomes[label] ~= "not_run"
                or type(condition) ~= "boolean" then
                producer_fault = true
                return fail("producer_protocol")
            end
            outcomes[label] = condition and "pass" or "fail"
            return true
        end

        function sink.seal()
            if not harness_open or producer_fault then
                return fail("producer_protocol")
            end
            harness_open = false
            local counts = { planned = count, passed = 0, failed = 0, not_run = 0 }
            for _, label in ipairs(labels) do
                local state = outcomes[label]
                if state == "pass" then counts.passed = counts.passed + 1
                elseif state == "fail" then counts.failed = counts.failed + 1
                else counts.not_run = counts.not_run + 1 end
            end
            frozen_counts = counts
            harness_receipt = {}
            return harness_receipt
        end

        -- The trusted executor must compile/execute these returned bytes.
        -- Giving the producer sink to guest code defeats this boundary.
        return attempt, sink, consumed
    end

    function controller.finish(handle, outcome)
        if attempt == nil or not rawequal(handle, attempt) then
            return fail("attempt_link_mismatch")
        end
        return lifecycle.finish(handle, outcome)
    end

    function controller.cancel()
        return lifecycle.cancel()
    end

    function controller.confirm_stopped(handle)
        if attempt == nil or not rawequal(handle, attempt) then
            return fail("attempt_link_mismatch")
        end
        return lifecycle.worker_stopped(handle)
    end

    function controller.finalize(approval_handle, attempt_handle, producer_receipt)
        if approval == nil or not rawequal(approval_handle, approval) then
            return fail("approval_link_mismatch")
        end
        if attempt == nil or not rawequal(attempt_handle, attempt) then
            return fail("attempt_link_mismatch")
        end
        if harness_receipt == nil
            or not rawequal(producer_receipt, harness_receipt) then
            return fail("producer_receipt_mismatch")
        end
        if producer_fault then return fail("producer_protocol") end

        local state = lifecycle.snapshot()
        if state.phase ~= "settled" or not state.worker_stop_confirmed then
            return fail("lifecycle_not_settled")
        end
        if final_receipt then return final_receipt end

        local execution = state.outcome == "completed" and "completed"
            or state.outcome == "language_error" and "language_error"
            or "terminated"

        final_record = {
            execution = execution,
            committed_outcome = state.outcome,
            assertion_status = assert(M.assertion_status(
                execution, frozen_counts.planned, frozen_counts.passed,
                frozen_counts.failed, frozen_counts.not_run
            )),
            planned = frozen_counts.planned,
            passed = frozen_counts.passed,
            failed = frozen_counts.failed,
            not_run = frozen_counts.not_run,
            correlation_reference = correlation,
            snapshot_binding = "exact_bytes_in_process",
            producer_binding = "owned_harness_receipt",
            cryptographic_authentication = "not_performed",
            scientific_validation = "not_established",
        }
        final_receipt = {}
        return final_receipt
    end

    function viewer.record(receipt)
        if final_receipt == nil or not rawequal(receipt, final_receipt) then
            return fail("untrusted_evidence_record")
        end
        local copy = {}
        for key, value in pairs(final_record) do copy[key] = value end
        return copy
    end

    function viewer.render(receipt)
        local record, diagnostic = viewer.record(receipt)
        if not record then return nil, diagnostic end

        local lines = {
            "Owned execution evidence | Format: 1",
            "Execution: " .. record.execution,
            "Committed outcome: " .. record.committed_outcome,
            "Assertions: " .. record.assertion_status,
            "Planned: " .. decimal(record.planned),
            "Passed: " .. decimal(record.passed),
            "Failed: " .. decimal(record.failed),
            "Not run: " .. decimal(record.not_run),
            "Snapshot binding: exact bytes in process",
            "Producer binding: owned harness receipt",
            "Cryptographic authentication: not performed",
            "Scientific validation: not established",
        }
        if record.execution ~= "completed" then
            lines[#lines + 1] =
                "Warning: assertion outcomes do not establish successful completion."
        end
        return table.concat(lines, "\n") .. "\n"
    end

    return controller, viewer
end

return M
