-- Lua 5.4.
-- Requires the previously supplied cybermind/capability_geometry.lua.
-- Import: local review = require("cybermind.geometry_review")
-- Tests: assert(review.self_test())
-- No I/O, hardware access, external actions, or execution authorization.

local base = require("cybermind.capability_geometry")
local M = {}

local VERSION = "1.0.0"
local ATTRIBUTION =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

local ORDER = {
    "input", "candidate", "private_display",
    "approved_expression", "external_action"
}

local MODES = {strict = true, free = true}
local REVERSIBILITY = {
    reversible = true,
    compensable = true,
    irreversible = true,
    unknown = true
}
local CONSEQUENCES = {
    routine = true,
    consequential = true,
    critical = true,
    unknown = true
}

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

local function text(value, path)
    if type(value) ~= "string" or #value > 4096
        or not value:match("%S") or value:find("%z") then
        fail("INVALID_TEXT", path, "Expected bounded nonblank text")
    end
    return value
end

local function enumeration(value, allowed, path)
    if type(value) ~= "string" or not allowed[value] then
        fail("INVALID_ENUM", path, "Unknown vocabulary value")
    end
    return value
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

function M.inspect(layout, options)
    return protect(function()
        if options == nil then options = {} end
        fields(options, {
            mode = true,
            free_layout_reason = true,
            action_profile = true
        }, "options")

        local mode = options.mode
        if mode == nil then mode = "strict" end
        enumeration(mode, MODES, "options.mode")

        if mode == "free" then
            text(options.free_layout_reason, "options.free_layout_reason")
        elseif options.free_layout_reason ~= nil then
            fail("INAPPLICABLE_FIELD", "options.free_layout_reason",
                "A free-layout reason applies only in free mode")
        end

        local checked, err = base.validate(layout)
        if not checked then error(err, 0) end
        local normalized = checked.layout

        local stage_order = {}
        local previous_x
        for position, stage in ipairs(ORDER) do
            local x = normalized.nodes[stage].x
            if mode == "strict" and previous_x ~= nil and x <= previous_x then
                fail("PRESENTATION_ORDER", "nodes." .. stage .. ".x",
                    "Strict mode requires increasing stage x-coordinates")
            end
            previous_x = x
            stage_order[#stage_order + 1] = {
                stage = stage,
                position = position
            }
        end

        local result = {
            schema_version = VERSION,
            attribution = ATTRIBUTION,
            attribution_scope =
                "Credit and workstream metadata only; not identity, consent, "
                .. "authorization, execution evidence, or authority.",
            mode = mode,
            stage_order = stage_order,
            layout = normalized,
            presentation = "conforms_to_selected_layout_mode",
            action_review = "profile_not_supplied",
            action_profile = nil,
            execution_authority = "none"
        }

        if mode == "free" then
            result.free_layout_reason = options.free_layout_reason
        end

        if options.action_profile ~= nil then
            local source = options.action_profile
            fields(source, {
                action_kind = true,
                reversibility = true,
                consequence = true,
                recovery_note = true,
                authority_requirement = true
            }, "action_profile")

            local profile = {
                action_kind = text(
                    source.action_kind, "action_profile.action_kind"
                ),
                reversibility = enumeration(
                    source.reversibility, REVERSIBILITY,
                    "action_profile.reversibility"
                ),
                consequence = enumeration(
                    source.consequence, CONSEQUENCES,
                    "action_profile.consequence"
                ),
                recovery_note = text(
                    source.recovery_note, "action_profile.recovery_note"
                ),
                authority_requirement = text(
                    source.authority_requirement,
                    "action_profile.authority_requirement"
                )
            }
            result.action_profile = profile

            if profile.reversibility == "unknown"
                or profile.consequence == "unknown" then
                result.action_review = "uncertainty_requires_review"
            elseif profile.reversibility == "irreversible"
                or profile.consequence == "critical" then
                result.action_review = "specialized_review_required"
            else
                result.action_review = "separate_authorization_still_required"
            end
        end

        result.scope =
            "Declared topology, presentation, and consequence profile only; "
            .. "not authenticated review, runtime approval, or safety finding."
        return result
    end)
end

function M.self_test()
    local result = assert(M.inspect(base.default_layout()))
    assert(result.mode == "strict")
    assert(result.execution_authority == "none")

    local scrambled = base.default_layout()
    scrambled.nodes.input.x, scrambled.nodes.candidate.x =
        scrambled.nodes.candidate.x, scrambled.nodes.input.x

    local value, err = M.inspect(scrambled)
    assert(value == nil and err.code == "PRESENTATION_ORDER")

    result = assert(M.inspect(scrambled, {
        mode = "free",
        free_layout_reason = "Synthetic alternative presentation fixture"
    }))
    assert(result.mode == "free")

    value, err = M.inspect(scrambled, {mode = "free"})
    assert(value == nil and err.code == "INVALID_TEXT")

    result = assert(M.inspect(base.default_layout(), {
        action_profile = {
            action_kind = "Publication",
            reversibility = "irreversible",
            consequence = "consequential",
            recovery_note = "Removal cannot ensure recall of external copies",
            authority_requirement = "Separate content and recipient approval"
        }
    }))
    assert(result.action_review == "specialized_review_required")

    local original = base.default_layout()
    result = assert(M.inspect(original))
    result.layout.nodes.input.x = 0.1
    assert(original.nodes.input.x == -1)

    return true
end

return M
