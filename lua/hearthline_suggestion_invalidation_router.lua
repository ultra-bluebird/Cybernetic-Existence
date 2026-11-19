local SuggestionInvalidationRouter = {}

local valid_event_types = {
    CONSENT_SCOPE_REVOKED = true,
    CONSENT_SCOPE_EXPIRED = true,
    CONSENT_SCOPE_SUPERSEDED = true
}

function SuggestionInvalidationRouter.route(event)
    if type(event) ~= "table" then
        error("event must be a table")
    end

    if not valid_event_types[event.event_type] then
        return {
            accepted = false,
            reason = "UNSUPPORTED_EVENT_TYPE",
            external_action_authorized = false
        }
    end

    if type(event.subject_ref) ~= "string" or event.subject_ref == "" then
        error("subject_ref must be a non-empty string")
    end

    if type(event.recipient_ref) ~= "string" or event.recipient_ref == "" then
        error("recipient_ref must be a non-empty string")
    end

    if type(event.policy_revision) ~= "number" or event.policy_revision < 0 then
        error("policy_revision must be a non-negative number")
    end

    return {
        accepted = true,
        route = "HEARTHCHAT_INVALIDATE_BY_RECIPIENT_SCOPE",
        subject_ref = event.subject_ref,
        recipient_ref = event.recipient_ref,
        policy_revision = event.policy_revision,
        external_action_authorized = false
    }
end

return SuggestionInvalidationRouter
