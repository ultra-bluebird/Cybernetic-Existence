local FogCorrectionPathGate = {}

local forbidden_patterns = {
    "[Cc][Uu][Rr][Ll]",
    "[Ww][Gg][Ee][Tt]",
    "[Cc][Uu][Rr][Ll]",
    "[Pp][Oo][Ww][Ee][Rr][Ss][Hh][Ee][Ll][Ll]",
    "[Bb][Aa][Ss][Hh]",
    "[Cc][Mm][Dd]",
    "[Ee][Xx][Ee][Cc]",
    "[Ss][Hh][Ee][Ll][Ll]",
    "[Rr][Uu][Nn]%s+",
    "[Ee][Xx][Ee][Cc][Uu][Tt][Ee]%s+",
    "[Dd][Ee][Ll][Ee][Tt][Ee]%s+",
    "[Uu][Pp][Dd][Aa][Tt][Ee]%s+",
    "[Cc][Oo][Nn][Tt][Rr][Oo][Ll]%s+",
    "[Aa][Cc][Tt][Uu][Aa][Tt][Ee]%s+",
    "https?://",
    "`",
    "%$%(",
    "<script"
}

local function contains_forbidden_content(value)
    for _, pattern in ipairs(forbidden_patterns) do
        if string.find(value, pattern) ~= nil then
            return true, pattern
        end
    end

    return false, nil
end

function FogCorrectionPathGate.validate(path)
    assert(type(path) == "table", "path must be a table")
    assert(path.advisory_only == true, "path must be advisory_only")
    assert(path.exposes_system_internals == false,
        "path must not expose system internals")

    local required_fields = {
        "evidenceCategory",
        "suggestedAction",
        "humanContactScope",
        "plainLanguageMessage"
    }

    for _, field in ipairs(required_fields) do
        assert(type(path[field]) == "string" and #path[field] > 0,
            field .. " must be a non-empty string")

        local found, pattern = contains_forbidden_content(path[field])
        assert(not found,
            field .. " contains disallowed actionable content: " .. pattern)
    end

    assert(#path.plainLanguageMessage <= 1400,
        "plainLanguageMessage exceeds bounded length")

    return {
        valid = true,
        advisory_only = true,
        automation_command_emitted = false
    }
end

return FogCorrectionPathGate
