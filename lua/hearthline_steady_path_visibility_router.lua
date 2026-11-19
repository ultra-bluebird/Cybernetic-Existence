local SteadyPathVisibilityRouter = {}

local allowed_interactions = {
    CANDIDATE_PRESENTATION = true,
    EXISTING_CONVERSATION = true,
    DIGEST_NOTIFICATION = true
}

local function contains(values, expected)
    for _, value in ipairs(values) do
        if value == expected then
            return true
        end
    end

    return false
end

function SteadyPathVisibilityRouter.route(state, interaction, window_open)
    if type(state) ~= "table" then
        error("state must be a table")
    end

    if not allowed_interactions[interaction] then
        return {
            allowed = false,
            reason = "UNSUPPORTED_INTERACTION",
            external_action_authorized = false
        }
    end

    if state.state == "PAUSED" then
        return {
            allowed = false,
            reason = "PAUSED_BY_USER",
            external_action_authorized = false
        }
    end

    if not window_open then
        return {
            allowed = false,
            reason = "OUTSIDE_USER_SELECTED_WINDOW",
            external_action_authorized = false
        }
    end

    if type(state.allowed_interactions) ~= "table"
        or not contains(state.allowed_interactions, interaction) then
        return {
            allowed = false,
            reason = "INTERACTION_NOT_ENABLED",
            external_action_authorized = false
        }
    end

    return {
        allowed = true,
        reason = "USER_SELECTED_PACING_ALLOWS_INTERACTION",
        external_action_authorized = false
    }
end

return SteadyPathVisibilityRouter
