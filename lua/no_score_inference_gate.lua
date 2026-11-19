local M = {}

local prohibited_exact = {
    score = true,
    rank = true,
    tier = true,
    eligibility = true,
    credibility = true,
    integrationdepth = true,
    stabilityindex = true,
    identityconfidence = true,
    augmentationstatus = true,
    consentcompliance = true,
    healthstatus = true,
    neuralstatus = true,
    biometricprofile = true
}

local prohibited_fragments = {
    "score",
    "rank",
    "tier",
    "eligib",
    "credib",
    "integration",
    "stability",
    "identityconfidence",
    "augmentation",
    "consentcompliance",
    "health",
    "neural",
    "biometric"
}

local function normalize(value)
    if type(value) ~= "string" then
        return nil
    end

    return value:lower():gsub("[^a-z0-9]", "")
end

local function prohibited_key(key)
    local normalized = normalize(key)

    if not normalized then
        return true, "non_string_key"
    end

    if prohibited_exact[normalized] then
        return true, "prohibited_exact_key"
    end

    for _, fragment in ipairs(prohibited_fragments) do
        if normalized:find(fragment, 1, true) then
            return true, "prohibited_key_fragment"
        end
    end

    return false, nil
end

function M.validate(value, path)
    path = path or "$"

    if type(value) ~= "table" then
        return true
    end

    for key, nested in pairs(value) do
        local invalid, reason = prohibited_key(key)

        if invalid then
            return false, {
                path = path .. "." .. tostring(key),
                reason = reason
            }
        end

        local nested_valid, nested_error = M.validate(
            nested,
            path .. "." .. tostring(key)
        )

        if not nested_valid then
            return false, nested_error
        end
    end

    return true
end

function M.validate_event(event)
    if type(event) ~= "table" then
        return false, {
            path = "$",
            reason = "event_must_be_table"
        }
    end

    return M.validate(event, "$")
end

return M
