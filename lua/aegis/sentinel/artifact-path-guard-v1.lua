-- SPDX-License-Identifier: MIT OR Apache-2.0
-- Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Aegis artifact naming and migration contract.
-- Lua 5.1-5.4. No I/O, network, logging, or filesystem changes.
--
-- A valid path establishes naming conformity only.
-- It does not establish file existence, correct content, scientific
-- validation, publication status, or authorization to migrate.

local M = {}

local ROOT_EXTENSIONS = {
    lua = { lua = true },
    docs = { md = true },
    schemas = { json = true },
    policies = { md = true, json = true, lua = true },
    tests = { lua = true, json = true }
}

local TIERS = {
    forge = true,
    sentinel = true,
    codex = true,
    lattice = true
}

local FUNCTIONS = {
    kernel = true,
    guard = true,
    spec = true,
    memo = true,
    manifest = true,
    ledger = true,
    test = true
}

local MIGRATIONS = {
    {
        source = "docs/research/necro-fall-corridor-connectivity-california-current.md",
        target = "docs/aegis/codex/california-current-necrofall-connectivity-spec-v2.md"
    },
    {
        source = "docs/research/necro-fall-corridor-cyber-particle-memo.md",
        target = "docs/aegis/codex/necrofall-cyber-particle-memo-v2.md"
    },
    {
        source = "schemas/necro-fall-corridor-publication-manifest.json",
        target = "schemas/aegis/lattice/necrofall-publication-manifest-v2.json"
    },
    {
        source = "lua/psych_risk_workflow_envelope.lua",
        target = "lua/aegis/sentinel/psych-risk-workflow-guard-v1.lua"
    },
    {
        source = "lua/terrestrial_coastal_stress_water_wood.lua",
        target = "lua/aegis/forge/coastal-stress-water-wood-kernel-v1.lua"
    },
    {
        source = "lua/corridor_screening_redteam_contract.lua",
        target = "lua/aegis/sentinel/corridor-redteam-review-guard-v1.lua"
    },
    {
        source = "lua/wood_provenance_firepulse_kelp_attribution.lua",
        target = "lua/aegis/forge/wood-provenance-firepulse-kelp-kernel-v1.lua"
    },
    {
        source = "lua/upwelling_oxygen_terrestrial_carbon_budget.lua",
        target = "lua/aegis/forge/upwelling-oxygen-carbon-budget-kernel-v1.lua"
    }
}

local function valid_subject(value)
    return type(value) == "string"
        and value:match("^[a-z0-9][a-z0-9%-]*$") ~= nil
        and value:sub(-1) ~= "-"
        and value:find("--", 1, true) == nil
end

function M.validate_target(path)
    if type(path) ~= "string" or #path == 0 or #path > 240 then
        return nil, "INVALID_PATH_LENGTH_OR_TYPE"
    end

    local forbidden_namespace = "sky" .. "net"
    if path:lower():find(forbidden_namespace, 1, true) then
        return nil, "FORBIDDEN_NAMESPACE"
    end

    local root, archetype, tier, filename =
        path:match("^([a-z]+)/([a-z]+)/([a-z]+)/([^/]+)$")

    if not root then
        return nil, "EXPECTED_ROOT_ARCHETYPE_TIER_FILENAME"
    end
    if not ROOT_EXTENSIONS[root] then
        return nil, "UNSUPPORTED_ROOT"
    end
    if archetype ~= "aegis" then
        return nil, "ARCHETYPE_MUST_BE_AEGIS"
    end
    if not TIERS[tier] then
        return nil, "UNSUPPORTED_TIER"
    end

    local subject, role, version, extension =
        filename:match(
            "^([a-z0-9%-]+)%-([a-z]+)%-v([1-9][0-9]*)%.([a-z]+)$"
        )

    if not subject or not valid_subject(subject) then
        return nil, "INVALID_SUBJECT_FUNCTION_VERSION_GRAMMAR"
    end
    if not FUNCTIONS[role] then
        return nil, "UNSUPPORTED_FUNCTION"
    end
    if not ROOT_EXTENSIONS[root][extension] then
        return nil, "EXTENSION_DOES_NOT_MATCH_ROOT"
    end

    return {
        root = root,
        archetype = archetype,
        tier = tier,
        subject = subject,
        artifact_function = role,
        version = version,
        extension = extension,
        destination = root .. "/aegis/" .. tier .. "/",
        filename = filename,
        naming_conformity_only = true
    }
end

function M.proposed_migrations()
    local result = {}
    local seen_sources = {}
    local seen_targets = {}

    for i = 1, #MIGRATIONS do
        local item = MIGRATIONS[i]
        local parsed, err = M.validate_target(item.target)
        assert(parsed, err)
        assert(not seen_sources[item.source], "duplicate migration source")
        assert(not seen_targets[item.target], "duplicate migration target")
        assert(item.source ~= item.target, "source and target must differ")

        seen_sources[item.source] = true
        seen_targets[item.target] = true

        result[i] = {
            source = item.source,
            target = item.target,
            destination = parsed.destination,
            source_existence_checked = false,
            target_collision_checked = false,
            references_updated = false,
            copy_authorized = false,
            rename_authorized = false,
            deletion_authorized = false
        }
    end

    return {
        status = "PROPOSED_NAMING_MIGRATION_ONLY",
        entries = result,
        performed_filesystem_actions = false,
        legacy_retention_rule =
            "Retain original paths for an explicitly agreed compatibility cycle",
        reference_rule =
            "Update dependent references and imports before retiring original paths",
        content_rule =
            "Preserve attribution, licensing, scientific status, and approval boundaries"
    }
end

function M.self_test()
    local parsed = assert(M.validate_target(
        "lua/aegis/forge/coastal-stress-water-wood-kernel-v1.lua"
    ))
    assert(parsed.destination == "lua/aegis/forge/")
    assert(parsed.artifact_function == "kernel")
    assert(parsed.version == "1")

    local uppercase = M.validate_target(
        "lua/Aegis/forge/coastal-stress-kernel-v1.lua"
    )
    assert(uppercase == nil)

    local underscore = M.validate_target(
        "lua/aegis/forge/coastal_stress-kernel-v1.lua"
    )
    assert(underscore == nil)

    local traversal = M.validate_target(
        "lua/aegis/../coastal-stress-kernel-v1.lua"
    )
    assert(traversal == nil)

    local mismatch = M.validate_target(
        "lua/aegis/forge/coastal-stress-kernel-v1.json"
    )
    assert(mismatch == nil)

    local repeated_hyphen = M.validate_target(
        "lua/aegis/forge/coastal--stress-kernel-v1.lua"
    )
    assert(repeated_hyphen == nil)

    local plan = M.proposed_migrations()
    assert(#plan.entries == #MIGRATIONS)
    assert(plan.performed_filesystem_actions == false)

    plan.entries[1].target = "modified"
    assert(M.proposed_migrations().entries[1].target ~= "modified")

    return {
        status = "SELF_TEST_COMPLETED",
        filesystem_actions_performed = false
    }
end

return M
