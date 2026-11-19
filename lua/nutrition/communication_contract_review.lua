-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Lua 5.4: application communication-contract evidence review.
-- Supplied test outcomes are claims, not independently verified results.
-- No signals, diagnosis, device control, persistence, or external action.
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

local M = {}

local obligations = {
    "communication_route",
    "user_led_pacing",
    "sensory_presentation",
    "session_continuity",
    "human_fallback",
    "food_water_access",
    "decline_without_penalty",
    "edit_cancel_communication"
}

local states = {
    matched = true,
    mismatched = true,
    unknown = true
}

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function shape(value, allowed)
    if not plain(value) then return false end
    local count = 0
    for key in next, value do
        count = count + 1
        if count > 32 or not allowed[key] then return false end
    end
    return true
end

local function reference(value)
    return type(value) == "string" and #value > 0 and #value <= 160
        and value:match("^local:[A-Za-z0-9_-]+$") ~= nil
end

function M.contract()
    local names = {}
    for index, name in ipairs(obligations) do names[index] = name end
    return {
        schema_version = "communication-contract-review-v1",
        obligations = names,
        states = { "matched", "mismatched", "unknown" }
    }
end

function M.evaluate(input)
    local output = {
        schema_version = "communication-contract-review-v1",
        review_status = "unavailable",
        evidence_verification = "not_performed",
        accessibility_certification = "not_performed",
        passive_sensing_authorized = false,
        nutritional_personalization_authorized = false,
        findings = {},
        automated = { matched = 0, mismatched = 0, unknown = 0 },
        user_task = { matched = 0, mismatched = 0, unknown = 0 }
    }

    local invalid = false
    local function add(code, field)
        invalid = true
        output.findings[#output.findings + 1] = {
            code = code, field = field
        }
    end

    if not shape(input, {
        schema_version = true,
        procedure_reference = true,
        adapter_revision = true,
        results = true
    }) then
        add("invalid_review_shape", "input")
        return output
    end

    if rawget(input, "schema_version") ~= "communication-review-input-v1" then
        add("unsupported_schema", "schema_version")
    end

    for _, field in ipairs({ "procedure_reference", "adapter_revision" }) do
        if not reference(rawget(input, field)) then
            add("local_reference_required", field)
        end
    end

    local results = rawget(input, "results")
    local allowed = {}
    for _, name in ipairs(obligations) do allowed[name] = true end

    if not shape(results, allowed) then
        add("invalid_results_shape", "results")
        return output
    end

    for _, name in ipairs(obligations) do
        local item = rawget(results, name)

        if not shape(item, {
            automated = true,
            user_task = true,
            evidence_reference = true
        }) then
            add("invalid_obligation_record", "results." .. name)
        else
            local evidence = rawget(item, "evidence_reference")
            if not reference(evidence) then
                add("evidence_reference_required", "results." .. name)
            end

            for _, axis in ipairs({ "automated", "user_task" }) do
                local state = rawget(item, axis)
                if type(state) ~= "string" or not states[state] then
                    add("invalid_assessment_state",
                        "results." .. name .. "." .. axis)
                else
                    output[axis][state] = output[axis][state] + 1
                end
            end
        end
    end

    if invalid then return output end

    if output.automated.mismatched > 0 or output.user_task.mismatched > 0 then
        output.review_status = "barriers_reported"
    elseif output.automated.unknown > 0 or output.user_task.unknown > 0 then
        output.review_status = "evidence_incomplete"
    else
        output.review_status = "scoped_matches_reported"
    end

    return output
end

return M
