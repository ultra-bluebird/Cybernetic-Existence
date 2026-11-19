local M = {}

local valid_kinds = {
    assertion = true,
    holder_correction = true,
    external_analysis = true,
    holder_acceptance = true,
    holder_rejection = true,
    consent_revocation = true,
    proof_revocation = true,
    dispute = true
}

local valid_statuses = {
    active = true,
    superseded = true,
    disputed = true,
    unreviewed = true,
    holder_accepted = true,
    holder_rejected = true,
    revoked = true
}

local function copy_array(values)
    local result = {}

    for index, value in ipairs(values) do
        result[index] = value
    end

    return result
end

local function copy_map(values)
    local result = {}

    for key, value in pairs(values) do
        result[key] = value
    end

    return result
end

local function append(history, event)
    local result = copy_array(history)
    result[#result + 1] = event
    return result
end

local function valid_event(event)
    return type(event) == "table"
        and type(event.id) == "string"
        and event.id ~= ""
        and valid_kinds[event.kind] == true
        and type(event.claim_key) == "string"
        and event.claim_key ~= ""
        and type(event.sequence) == "number"
        and event.sequence > 0
        and type(event.holder_authorized) == "boolean"
end

local function status_for_external_analysis(event)
    if event.signature_valid ~= true then
        return "unreviewed"
    end

    return "disputed"
end

function M.new_state()
    return {
        history = {},
        interpretation = {},
        proof_status = {},
        baseline_rights = {
            equal_access = true,
            human_fallback = true,
            non_discrimination = true,
            accessible_communication = true
        },
        last_sequence = 0
    }
end

function M.reconcile(state, event)
    if type(state) ~= "table" or not valid_event(event) then
        return nil, "invalid_state_or_event"
    end

    if event.sequence <= state.last_sequence then
        return nil, "non_forward_sequence"
    end

    local next_state = {
        history = append(state.history, event),
        interpretation = copy_map(state.interpretation),
        proof_status = copy_map(state.proof_status),
        baseline_rights = copy_map(state.baseline_rights),
        last_sequence = event.sequence
    }

    local key = event.claim_key

    if event.kind == "assertion" then
        if event.holder_authorized then
            next_state.interpretation[key] = "active"
        else
            next_state.interpretation[key] = "unreviewed"
        end
    elseif event.kind == "holder_correction" then
        if event.holder_authorized then
            next_state.interpretation[key] = "superseded"
            next_state.proof_status[key] = "fresh_consent_required"
        else
            next_state.interpretation[key] = "unreviewed"
        end
    elseif event.kind == "external_analysis" then
        next_state.interpretation[key] = status_for_external_analysis(event)
        next_state.proof_status[key] = "suspended_pending_holder_review"
    elseif event.kind == "holder_acceptance" then
        if event.holder_authorized then
            next_state.interpretation[key] = "holder_accepted"
            next_state.proof_status[key] = "fresh_consent_required"
        end
    elseif event.kind == "holder_rejection" then
        if event.holder_authorized then
            next_state.interpretation[key] = "holder_rejected"
            next_state.proof_status[key] = "no_external_proof_from_analysis"
        end
    elseif event.kind == "consent_revocation" then
        if event.holder_authorized then
            next_state.proof_status[key] = "revoked"
        end
    elseif event.kind == "proof_revocation" then
        next_state.proof_status[key] = "revoked"
    elseif event.kind == "dispute" then
        next_state.interpretation[key] = "disputed"
        next_state.proof_status[key] = "suspended_pending_holder_review"
    end

    for right, available in pairs(state.baseline_rights) do
        if available ~= true then
            return nil, "baseline_rights_invalid"
        end
        next_state.baseline_rights[right] = true
    end

    return next_state
end

function M.is_forward_only(previous, next_state)
    if type(previous) ~= "table" or type(next_state) ~= "table" then
        return false
    end

    if #next_state.history < #previous.history then
        return false
    end

    for index, event in ipairs(previous.history) do
        if next_state.history[index] ~= event then
            return false
        end
    end

    return next_state.last_sequence > previous.last_sequence
end

function M.baseline_rights_preserved(state)
    if type(state) ~= "table" then
        return false
    end

    for _, key in ipairs({
        "equal_access",
        "human_fallback",
        "non_discrimination",
        "accessible_communication"
    }) do
        if state.baseline_rights[key] ~= true then
            return false
        end
    end

    return true
end

return M
