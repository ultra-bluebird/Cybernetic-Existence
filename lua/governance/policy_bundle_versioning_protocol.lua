local PolicyBundle = {}

local protected_rule_names = {
    privacy = true,
    consent = true,
    accessibility = true,
    rights_alignment = true,
    human_review = true,
    appeal = true,
    non_digital_escalation = true,
    service_continuity = true,
    non_discrimination = true,
    data_retention = true,
    data_release = true,
    identity_self_assertion = true
}

local function result(bundle_state, output_state, reason_codes, values)
    return {
        bundle_state = bundle_state,
        output_state = output_state,
        reason_codes = reason_codes or {},
        values = values or {},
        local_first = true,
        automated_actuation_authorized = false,
        automated_service_denial_permitted = false,
        biometric_identification_permitted = false,
        cybernetic_status_penalty_permitted = false,
        individual_profiling_permitted = false,
        accessible_explanation_available = true,
        appeal_path_available = true,
        non_digital_escalation_available = true
    }
end

local function parse_semantic_version(version)
    if type(version) ~= "string" then
        return nil
    end

    local major, minor, patch = version:match("^v?(%d+)%.(%d+)%.(%d+)")
    if major == nil then
        return nil
    end

    return {
        major = tonumber(major),
        minor = tonumber(minor),
        patch = tonumber(patch)
    }
end

local function is_protected_configuration_valid(bundle)
    return bundle.local_first == true
        and bundle.automated_actuation_permitted == false
        and bundle.automated_service_denial_permitted == false
        and bundle.biometric_identification_permitted == false
        and bundle.cybernetic_status_penalty_permitted == false
        and bundle.individual_profiling_permitted == false
        and bundle.accessible_explanation_available == true
        and bundle.appeal_path_available == true
        and bundle.non_digital_escalation_available == true
end

local function contains_protected_rule_change(bundle)
    if type(bundle.changed_protected_rules) ~= "table" then
        return false
    end

    for _, rule in ipairs(bundle.changed_protected_rules) do
        if protected_rule_names[rule] then
            return true
        end
    end

    return false
end

local function has_required_migration_documents(bundle)
    return bundle.migration_required == true
        and type(bundle.migration_artifact_reference) == "string"
        and bundle.migration_artifact_reference ~= ""
        and type(bundle.accessibility_impact_statement) == "string"
        and bundle.accessibility_impact_statement ~= ""
        and type(bundle.privacy_impact_statement) == "string"
        and bundle.privacy_impact_statement ~= ""
        and type(bundle.anti_regression_statement) == "string"
        and bundle.anti_regression_statement ~= ""
end

local function date_is_valid(value)
    return type(value) == "string"
        and value:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d")
        ~= nil
end

function PolicyBundle.evaluate(bundle, now_utc)
    if type(bundle) ~= "table" then
        return result(
            "blocked_by_policy",
            "blocked_by_policy",
            { "policy_bundle_missing" }
        )
    end

    if parse_semantic_version(bundle.policy_version) == nil then
        return result(
            "blocked_by_policy",
            "blocked_by_policy",
            { "policy_version_invalid" }
        )
    end

    if type(bundle.registry_version) ~= "string"
        or bundle.registry_version == ""
        or not date_is_valid(bundle.effective_date)
        or not date_is_valid(bundle.expiration_date)
        or type(bundle.policy_content_digest) ~= "string"
        or #bundle.policy_content_digest < 64 then
        return result(
            "blocked_by_policy",
            "blocked_by_policy",
            { "policy_bundle_metadata_incomplete" }
        )
    end

    if not is_protected_configuration_valid(bundle) then
        return result(
            "blocked_by_policy",
            "blocked_by_policy",
            { "policy_bundle_violates_protected_configuration" }
        )
    end

    if bundle.compatibility_declaration == "incompatible"
        and not has_required_migration_documents(bundle) then
        return result(
            "migration_pending",
            "needs_review",
            { "incompatible_policy_requires_migration_documents" }
        )
    end

    if contains_protected_rule_change(bundle)
        and bundle.community_review_status ~= "complete" then
        return result(
            "migration_pending",
            "needs_review",
            { "protected_rule_change_requires_community_review" }
        )
    end

    if bundle.review_status ~= "approved" then
        return result(
            "migration_pending",
            "needs_review",
            { "policy_bundle_review_not_approved" }
        )
    end

    if type(now_utc) ~= "string" or not date_is_valid(now_utc) then
        return result(
            "needs_review",
            "needs_review",
            { "local_time_reference_invalid" }
        )
    end

    if now_utc < bundle.effective_date then
        return result(
            "migration_pending",
            "needs_review",
            { "policy_bundle_not_effective_yet" }
        )
    end

    if now_utc >= bundle.expiration_date then
        return result(
            "expired",
            "needs_review",
            {
                "policy_bundle_expired",
                "protected_actions_fail_closed",
                "explanation_and_appeal_information_remain_available"
            }
        )
    end

    if bundle.compatibility_declaration == "incompatible"
        and bundle.migration_state ~= "complete" then
        return result(
            "migration_pending",
            "needs_review",
            {
                "dual_interpretation_or_migration_completion_required"
            }
        )
    end

    return result(
        "active_local",
        "advisory_only",
        {
            "policy_bundle_active_for_local_advisory_evaluation",
            "protected_actions_remain_non_compensatory",
            "no_automated_actuation_or_service_denial_authorized"
        },
        {
            policy_version = bundle.policy_version,
            registry_version = bundle.registry_version,
            compatibility_declaration = bundle.compatibility_declaration
        }
    )
end

function PolicyBundle.evaluate_transition(previous_bundle, next_bundle)
    if type(previous_bundle) ~= "table" or type(next_bundle) ~= "table" then
        return result(
            "migration_pending",
            "needs_review",
            { "policy_transition_requires_previous_and_next_bundle" }
        )
    end

    if next_bundle.compatibility_declaration == "incompatible" then
        return result(
            "migration_pending",
            "needs_review",
            {
                "incompatible_metric_or_threshold_change_requires_dual_interpretation",
                "apply_stricter_old_and_new_protected_gates_until_migration_complete"
            }
        )
    end

    if contains_protected_rule_change(next_bundle) then
        return result(
            "migration_pending",
            "needs_review",
            {
                "protected_rule_change_requires_accessibility_privacy_and_anti_regression_review"
            }
        )
    end

    return result(
        "active_local",
        "advisory_only",
        { "policy_transition_declared_backward_compatible" }
    )
end

function PolicyBundle.render_accessible_explanation(assessment)
    local bundle_state = assessment.bundle_state or "needs_review"
    local output_state = assessment.output_state or "needs_review"
    local reasons = table.concat(assessment.reason_codes or {}, ", ")

    return "Policy bundle state: " .. bundle_state .. ". "
        .. "Conformance result: " .. output_state .. ". "
        .. "This local policy assessment does not authorize automated action, "
        .. "service denial, identity resolution, biometric identification, "
        .. "or cybernetic-status assessment. "
        .. "If a policy is expired or incompatible, protected actions remain "
        .. "blocked or require review while explanation, appeal, correction, "
        .. "and non-digital escalation information remain available. "
        .. "Reason codes: " .. reasons .. "."
end

return PolicyBundle
