local M = {}

M.PROHIBITED_KEY_TOKENS = {
    "person",
    "individual",
    "household",
    "identity",
    "name",
    "email",
    "phone",
    "address",
    "device",
    "macaddress",
    "bluetooth",
    "wifi",
    "trajectory",
    "locationhistory",
    "image",
    "audio",
    "face",
    "gait",
    "health",
    "medical",
    "neural",
    "biometric",
    "disability",
}

local function is_text(value)
    return type(value) == "string"
end

function M.normalize_key(value)
    if not is_text(value) then
        return nil
    end

    return value:lower():gsub("[^a-z0-9]", "")
end

function M.prohibited_key(key)
    local normalized_key = M.normalize_key(key)

    if normalized_key == nil or normalized_key == "" then
        return true, "non_string_or_empty_key"
    end

    for _, token in ipairs(M.PROHIBITED_KEY_TOKENS) do
        local normalized_token = M.normalize_key(token)

        if normalized_token ~= nil
            and normalized_token ~= ""
            and normalized_key:find(normalized_token, 1, true) ~= nil
        then
            return true, token
        end
    end

    return false, nil
end

function M.validate(value, path)
    path = path or "$"

    if type(value) ~= "table" then
        return true, nil
    end

    for key, nested_value in pairs(value) do
        if type(key) ~= "string" then
            return false, {
                code = "prohibited_key",
                path = path,
                reason = "non_string_key",
                token = "non_string_key",
            }
        end

        local rejected, token = M.prohibited_key(key)

        if rejected then
            return false, {
                code = "prohibited_key",
                path = path .. "." .. key,
                reason = "prohibited_key",
                token = token,
            }
        end

        local nested_ok, nested_error = M.validate(
            nested_value,
            path .. "." .. key
        )

        if not nested_ok then
            return false, nested_error
        end
    end

    return true, nil
end

return M
