#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeMap;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct EcoChatConversation {
    pub schema_version: String,
    pub session_id: String,
    pub started_at_utc: String,
    pub completed_at_utc: Option<String>,
    pub retention_class: RetentionClass,
    pub provenance: ConversationProvenance,
    pub messages: Vec<EcoChatMessage>,
    pub applied_tool_calls: Vec<AppliedToolCall>,
    pub ker_metrics: KerMetrics,
    pub final_kfk_evaluation: KfkEvaluation,
    #[serde(default, skip_serializing_if = "BTreeMap::is_empty")]
    pub extra: BTreeMap<String, Value>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RetentionClass {
    Ephemeral,
    AuditLimited,
    PolicyDefined,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct ConversationProvenance {
    pub kfk_version: String,
    pub config_digest_sha256: String,
    pub tool_registry_digest_sha256: String,
    pub conversation_digest_sha256: Option<String>,
    pub subject_did_anchor: Option<String>,
    pub consent_scope: ConsentScope,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct ConsentScope {
    pub export_to_ersi: bool,
    pub allow_tool_provenance: bool,
    pub allow_message_content_export: bool,
    pub purpose: String,
    pub retention_days: Option<u32>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct EcoChatMessage {
    pub message_id: String,
    pub sequence: u32,
    pub role: MessageRole,
    pub created_at_utc: String,
    pub content: MessageContent,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub citations: Vec<CitationRecord>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MessageRole {
    System,
    User,
    Assistant,
    Tool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct MessageContent {
    pub export_mode: ContentExportMode,
    pub text: Option<String>,
    pub sha256: String,
    pub byte_len: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ContentExportMode {
    Omitted,
    DigestOnly,
    RedactedText,
    FullTextWithConsent,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct CitationRecord {
    pub source_id: String,
    pub source_type: CitationSourceType,
    pub artifact_sha256: Option<String>,
    pub retrieved_at_utc: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CitationSourceType {
    Aln,
    Database,
    LocalArtifact,
    Web,
    Other,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct AppliedToolCall {
    pub call_id: String,
    pub sequence: u32,
    pub tool_id: String,
    pub tool_version: String,
    pub language: ToolLanguage,
    pub invocation_mode: ToolInvocationMode,
    pub planes: Vec<GovernancePlane>,
    pub requested_at_utc: String,
    pub completed_at_utc: Option<String>,
    pub status: ToolCallStatus,
    pub requires_human_approval: bool,
    pub approval_state: ApprovalState,
    pub input_digest_sha256: String,
    pub output_digest_sha256: Option<String>,
    pub output_summary: Option<String>,
    pub error_code: Option<String>,
    pub evidence_artifacts: Vec<ArtifactReference>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ToolLanguage {
    Cpp,
    Java,
    Javascript,
    Kotlin,
    Lua,
    Python,
    Rego,
    Rust,
    Shell,
    Sql,
    Typescript,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ToolInvocationMode {
    InProcess,
    Subprocess,
    HttpLocal,
    HttpApprovedRemote,
    SqlReadOnly,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ToolCallStatus {
    Applied,
    Rejected,
    Unavailable,
    TimedOut,
    FailedValidation,
    FailedExecution,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ApprovalState {
    NotRequired,
    Pending,
    Approved,
    Denied,
    Expired,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GovernancePlane {
    Accessibility,
    Audit,
    Eco,
    Governance,
    Integrity,
    Privacy,
    Research,
    Safety,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct ArtifactReference {
    pub repo_relative_path: String,
    pub sha256: String,
    pub verified: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct KerMetrics {
    pub knowledge_factor: BoundedUnitInterval,
    pub eco_impact_value: BoundedUnitInterval,
    pub harm_risk: BoundedUnitInterval,
    pub accessibility_impact: BoundedUnitInterval,
    pub rights_alignment: BoundedUnitInterval,
    pub research_efficiency_score: Option<BoundedUnitInterval>,
    pub tokens_used: u64,
    pub compute_joules: Option<f64>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct BoundedUnitInterval(pub f64);

impl BoundedUnitInterval {
    pub fn new(value: f64) -> Result<Self, &'static str> {
        if !value.is_finite() {
            return Err("value must be finite");
        }

        if !(0.0..=1.0).contains(&value) {
            return Err("value must be in the inclusive range [0, 1]");
        }

        Ok(Self(value))
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct KfkEvaluation {
    pub kfk_version: String,
    pub status: KfkEvaluationStatus,
    pub validated_trust: BoundedUnitInterval,
    pub version_multiplier: BoundedUnitInterval,
    pub evidence_freshness: BoundedUnitInterval,
    pub final_multiplier: BoundedUnitInterval,
    pub evaluated_at_utc: String,
    pub manifest_sha256: String,
    pub reasons: Vec<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum KfkEvaluationStatus {
    Current,
    Supported,
    Deprecated,
    Superseded,
    Revoked,
    Unknown,
}
