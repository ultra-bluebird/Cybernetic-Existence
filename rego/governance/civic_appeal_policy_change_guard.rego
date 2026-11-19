package augmented_hub.governance.civic_appeal_policy_change_guard

default allow_policy_change := false
default require_community_outreach := false
default require_escalation := false

valid_unit_interval(value) {
    is_number(value)
    value >= 0
    value <= 1
}

civic_submission_accessible(submission) {
    submission.accessible_channel_used == true
}

civic_submission_accessible(submission) {
    submission.voice_channel_used == true
}

civic_submission_accessible(submission) {
    submission.offline_channel_used == true
}

civic_access_rate := count([
    submission |
    submission := input.civic.submissions[_]
    civic_submission_accessible(submission)
]) / max([count(input.civic.submissions), 1])

require_community_outreach {
    civic_access_rate < 0.85
}

appeal_state_valid {
    input.appeal.state in {
        "submitted",
        "acknowledged",
        "under_review",
        "corrected",
        "rejected_with_reason",
        "escalated"
    }
}

appeal_escalation_available {
    count(input.appeal.non_digital_escalation_channels) > 0
}

require_escalation {
    input.appeal.is_overdue == true
}

require_escalation {
    input.appeal.state == "rejected_with_reason"
}

review_count_sufficient {
    input.policy_change.review_count >= 5
}

affected_groups_sufficient {
    input.policy_change.affected_group_count >= input.policy.minimum_affected_group_count
}

sai_non_regression {
    input.policy_change.new_sai >= input.policy_change.old_sai - 0.02
}

non_compensatory_change_gate {
    input.policy_change.reduces_essential_access == false
    input.policy_change.requires_optional_telemetry == false
    input.policy_change.requires_continuous_connectivity == false
    input.policy_change.requires_new_identity_certification == false
    input.policy_change.reduces_accessibility == false
    input.policy_change.reduces_privacy == false
    input.policy_change.human_review_preserved == true
    input.policy_change.appeal_path_preserved == true
}

allow_policy_change {
    input.policy_change.advisory_only == true
    review_count_sufficient
    affected_groups_sufficient
    sai_non_regression
    non_compensatory_change_gate
}

deny_reason["civic participation below the target requires outreach and access improvements, not participant penalties"] {
    civic_access_rate < 0.85
}

deny_reason["appeal cases require a valid workflow state"] {
    not appeal_state_valid
}

deny_reason["every appeal state requires at least one non-digital escalation path"] {
    not appeal_escalation_available
}

deny_reason["overdue or rejected cases require escalation support"] {
    require_escalation
}

deny_reason["policy changes require at least five valid independent review contributions"] {
    not review_count_sufficient
}

deny_reason["policy changes require representation from affected groups"] {
    not affected_groups_sufficient
}

deny_reason["policy changes cannot materially regress the aggregate social-acceptance indicator"] {
    not sai_non_regression
}

deny_reason["policy changes cannot reduce essential access, accessibility, privacy, human review, or appeal rights"] {
    not non_compensatory_change_gate
}

deny_reason["policy changes remain advisory-only until their safeguards are verified"] {
    input.policy_change.advisory_only != true
}
