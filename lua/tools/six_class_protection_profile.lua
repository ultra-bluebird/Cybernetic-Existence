-- Repository: mk-bluebird/Prometheus-Praxis
-- Filename: lua/tools/six_class_protection_profile.lua
-- Destination: lua/tools/

local ProtectionProfile = {}

local PRIORITY_ORDER = {
    "P1",
    "P3",
    "P4",
    "P5",
    "P6",
    "P2",
}

local PROTECTION_CLASSES = {
    P1 = {
        name = "Personhood and expression",
        actions = {
            "Maintain a dated self-authored expression statement.",
            "Document communication accommodations.",
            "Use plain-language and one-question-at-a-time interaction preferences.",
        },
    },
    P2 = {
        name = "Identity and access",
        actions = {
            "Maintain an account and recovery-method inventory.",
            "Store recovery instructions in a protected location.",
            "Record recovery tests on a recurring schedule.",
        },
    },
    P3 = {
        name = "Privacy and confidentiality",
        actions = {
            "Maintain a personal data map.",
            "Maintain a disclosure register.",
            "Record storage, access holders, retention, and sharing rules.",
        },
    },
    P4 = {
        name = "Continuity and records",
        actions = {
            "Create versioned exports of critical records.",
            "Maintain restoration-test evidence.",
            "Use multiple user-controlled archive locations where appropriate.",
        },
    },
    P5 = {
        name = "Reputation and attribution",
        actions = {
            "Maintain dated authorship and provenance records.",
            "Record correction events additively rather than deleting history.",
            "Preserve source location, licensing, and declared signature metadata.",
        },
    },
    P6 = {
        name = "Safety and consent",
        actions = {
            "Default workflows to read-only.",
            "Require explicit approval before external publishing or transmission.",
            "Record consent scope, validity period, and revocability.",
        },
    },
}

local FAIRNESS_CRITERIA = {
    "self_asserted_identity_inclusion",
    "no_third_party_certification_gate",
    "privacy_and_continuity_protection",
    "meaningful_social_impact",
    "equal_treatment_for_augmented_citizens",
}

local function require_table(value, name)
    assert(type(value) == "table", name .. " must be a table")
end

local function require_string(value, name)
    assert(type(value) == "string" and value ~= "", name .. " must be a non-empty string")
end

local function require_boolean(value, name)
    assert(type(value) == "boolean", name .. " must be a boolean")
end

local function copy_array(source)
    local result = {}

    for index, value in ipairs(source) do
        result[index] = value
    end

    return result
end

local function copy_class(class)
    return {
        name = class.name,
        actions = copy_array(class.actions),
    }
end

local function normalized_class_set(class_ids)
    require_table(class_ids, "class_ids")

    local included = {}

    for index, class_id in ipairs(class_ids) do
        require_string(class_id, "class_ids[" .. index .. "]")
        assert(PROTECTION_CLASSES[class_id] ~= nil, "unsupported protection class: " .. class_id)
        included[class_id] = true
    end

    return included
end

--- Produces a prioritized, local implementation plan for the requested
--- protection classes. The plan is documentation only and does not access,
--- modify, publish, transmit, or recover any external account or record.
---@param included_class_ids table|nil
---@return table
function ProtectionProfile.build_plan(included_class_ids)
    local included = normalized_class_set(included_class_ids or PRIORITY_ORDER)
    local plan = {}

    for priority, class_id in ipairs(PRIORITY_ORDER) do
        if included[class_id] then
            local class = PROTECTION_CLASSES[class_id]

            table.insert(plan, {
                priority = priority,
                protection_class = class_id,
                name = class.name,
                actions = copy_array(class.actions),
            })
        end
    end

    return {
        profile_type = "self-asserted-six-class-protection-profile",
        plan = plan,
        priority_order = copy_array(PRIORITY_ORDER),
        defaults = {
            communication = "plain-language, good-faith interpretation, one clear question at a time",
            external_action = "explicit approval required",
            data_handling = "read-only by default",
        },
        authority_effect = "none",
        interpretation =
            "Local planning artifact only. It documents personal protection priorities without "
            .. "claiming external certification, access rights, legal status, medical status, "
            .. "or authority over any external service.",
    }
end

--- Evaluates documented policy criteria as an audit record. It intentionally
--- does not determine legal compliance, identity validity, entitlement, access,
--- authorization, or external service behavior.
---@param answers table
---@return table
function ProtectionProfile.fairness_audit(answers)
    require_table(answers, "fairness_answers")

    local satisfied_count = 0
    local results = {}
    local gaps = {}

    for _, criterion in ipairs(FAIRNESS_CRITERIA) do
        local answer = answers[criterion]
        require_boolean(answer, "fairness_answers." .. criterion)

        results[criterion] = answer

        if answer then
            satisfied_count = satisfied_count + 1
        else
            table.insert(gaps, criterion)
        end
    end

    local score = satisfied_count / #FAIRNESS_CRITERIA

    return {
        audit_type = "fairness-audit-layer",
        score = score,
        results = results,
        gaps = gaps,
        criteria = copy_array(FAIRNESS_CRITERIA),
        review_recommended = #gaps > 0,
        authority_effect = "none",
        interpretation =
            "Audit-layer result only. It documents observable policy concerns for review and "
            .. "does not gate respectful communication, self-authored identity expression, or "
            .. "access-control decisions governed by a separate applicable policy.",
    }
end

--- Produces a structured concern record from user-supplied observable facts.
--- This function is local-only and does not send, publish, or file a complaint.
---@param concern table
---@return table
function ProtectionProfile.concern_record(concern)
    require_table(concern, "concern")

    local fields = {
        "concern_id",
        "occurred_at",
        "system_or_organization",
        "what_occurred",
        "exact_wording_or_action",
        "effect_on_person",
        "available_evidence",
        "requested_correction",
        "communication_accommodation",
    }

    local record = {}

    for _, field in ipairs(fields) do
        local value = concern[field]
        require_string(value, "concern." .. field)
        record[field] = value
    end

    return {
        record_type = "observable-process-concern",
        concern = record,
        status = "draft-for-review",
        authority_effect = "none",
        interpretation =
            "Draft documentation only. Review it for accuracy and explicitly approve any "
            .. "external transmission, publication, submission, or escalation.",
    }
end

return ProtectionProfile
