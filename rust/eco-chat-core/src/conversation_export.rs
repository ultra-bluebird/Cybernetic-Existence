#![forbid(unsafe_code)]

use crate::conversation::{
    ApprovalState, ContentExportMode, EcoChatConversation, KfkEvaluationStatus, ToolCallStatus,
};

pub fn validate_for_ersi_export(
    conversation: &EcoChatConversation,
) -> Result<(), Vec<String>> {
    let mut errors = Vec::new();

    if conversation.schema_version != "1.0" {
        errors.push("unsupported conversation schema version".to_owned());
    }

    if conversation.session_id.trim().is_empty() {
        errors.push("session_id must not be empty".to_owned());
    }

    if conversation.final_kfk_evaluation.kfk_version != conversation.provenance.kfk_version {
        errors.push("KFK evaluation version must match provenance KFK version".to_owned());
    }

    if matches!(
        conversation.final_kfk_evaluation.status,
        KfkEvaluationStatus::Revoked | KfkEvaluationStatus::Unknown
    ) && conversation.final_kfk_evaluation.final_multiplier.0 != 0.0
    {
        errors.push(
            "revoked or unknown KFK versions must have final_multiplier equal to zero".to_owned(),
        );
    }

    for message in &conversation.messages {
        if message.message_id.trim().is_empty() {
            errors.push("message_id must not be empty".to_owned());
        }

        if matches!(
            message.content.export_mode,
            ContentExportMode::FullTextWithConsent
        ) && (!conversation.provenance.consent_scope.export_to_ersi
            || !conversation.provenance.consent_scope.allow_message_content_export)
        {
            errors.push(
                "full message text export requires explicit ERSI and message-content consent"
                    .to_owned(),
            );
        }
    }

    for call in &conversation.applied_tool_calls {
        if call.tool_id.trim().is_empty() {
            errors.push("tool_id must not be empty".to_owned());
        }

        if matches!(call.status, ToolCallStatus::Applied) && call.output_digest_sha256.is_none() {
            errors.push(format!(
                "applied tool call {} must include an output digest",
                call.call_id
            ));
        }

        if call.requires_human_approval
            && matches!(call.status, ToolCallStatus::Applied)
            && call.approval_state != ApprovalState::Approved
        {
            errors.push(format!(
                "tool call {} was applied without approved human authorization",
                call.call_id
            ));
        }

        for artifact in &call.evidence_artifacts {
            if artifact.repo_relative_path.starts_with('/')
                || artifact.repo_relative_path.split('/').any(|part| part == "..")
            {
                errors.push(format!(
                    "tool call {} includes a non-repository-relative artifact path",
                    call.call_id
                ));
            }

            if !artifact.verified {
                errors.push(format!(
                    "tool call {} includes an unverified evidence artifact",
                    call.call_id
                ));
            }
        }
    }

    if errors.is_empty() {
        Ok(())
    } else {
        Err(errors)
    }
}
