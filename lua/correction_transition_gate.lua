local allowed_transitions = {
    DRAFT = {
        SUBMIT = "SUBMITTED",
        REQUEST_HUMAN_ASSISTANCE = "HUMAN_ASSISTANCE"
    },
    HUMAN_ASSISTANCE = {
        RESUME_SELF_SERVICE = "DRAFT",
        SUBMIT = "SUBMITTED"
    },
    SUBMITTED = {
        ISSUE_RECEIPT = "ACKNOWLEDGED",
        REQUIRE_HUMAN_REVIEW = "REVIEW_REQUIRED"
    },
    ACKNOWLEDGED = {
        ASSIGN_REVIEW = "UNDER_REVIEW"
    },
    REVIEW_REQUIRED = {
        ASSIGN_REVIEW = "UNDER_REVIEW"
    },
    UNDER_REVIEW = {
        REQUEST_EVIDENCE = "EVIDENCE_REQUESTED",
        ISSUE_DECISION = "DECISION_ISSUED"
    },
    EVIDENCE_REQUESTED = {
        PROVIDE_EVIDENCE = "UNDER_REVIEW"
    },
    DECISION_ISSUED = {
        OPEN_APPEAL = "APPEAL_AVAILABLE"
    },
    APPEAL_AVAILABLE = {
        REQUEST_APPEAL = "UNDER_REVIEW",
        CLOSE_CASE = "CLOSED"
    }
}

local function nonempty_string(value)
    return type(value) == "string" and #value > 0
end

function validate_transition(request)
    if type(request) ~= "table" then
        return {
            decision = "REJECT",
            code = "INVALID_REQUEST",
            explanation = "The correction transition request is not valid."
        }
    end

    if not nonempty_string(request.case_reference)
        or not nonempty_string(request.current_state)
        or not nonempty_string(request.event)
        or not nonempty_string(request.policy_revision)
        or type(request.expected_version) ~= "number"
        or request.expected_version < 0 then
        return {
            decision = "REJECT",
            code = "MISSING_REQUIRED_FIELD",
            explanation = "Required correction transition information is missing."
        }
    end

    local events = allowed_transitions[request.current_state]
    local next_state = events and events[request.event] or nil

    if next_state == nil then
        return {
            decision = "HUMAN_REVIEW_REQUIRED",
            code = "INVALID_STATE_TRANSITION",
            explanation = "This action is not available in the present correction stage. Human assistance is available."
        }
    end

    return {
        decision = "ACCEPT",
        code = "TRANSITION_ALLOWED",
        next_state = next_state,
        receipt_required = request.event == "SUBMIT",
        policy_revision = request.policy_revision
    }
end

return {
    validate_transition = validate_transition
}
