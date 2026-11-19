#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum FirebreakOutcome {
    Allowed,
    Blocked,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct FirebreakContext {
    pub operation_id: String,
    pub has_biological_data: bool,
    pub has_actuation_data: bool,
    pub operation_type: String,
}

impl FirebreakContext {
    pub fn new(
        operation_id: String,
        has_biological_data: bool,
        has_actuation_data: bool,
        operation_type: String,
    ) -> Self {
        Self {
            operation_id,
            has_biological_data,
            has_actuation_data,
            operation_type,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct FirebreakDecision {
    pub outcome: FirebreakOutcome,
    pub reasons: Vec<String>,
}

pub fn evaluate_firebreak(context: &FirebreakContext) -> FirebreakDecision {
    let mut reasons = Vec::new();

    if context.has_biological_data && context.has_actuation_data {
        reasons.push("Biological data cannot co-exist with actuation data".to_string());
    }

    if context.has_biological_data {
        match context.operation_type.as_str() {
            "authorize" | "actuate" | "execute" | "deploy" => {
                reasons.push("Biological data cannot authorize or actuate operations".to_string());
            }
            "record_receipt" | "log_metric" | "emit_reference" => {
                // Allowed: minimal, non-authorizing operations
            }
            _ => {
                reasons.push("Operation type not approved for biological data context".to_string());
            }
        }
    }

    if context.has_actuation_data && context.operation_type != "record_actuation_event" {
        reasons.push("Actuation must be separately authorized and recorded".to_string());
    }

    if !reasons.is_empty() {
        FirebreakDecision {
            outcome: FirebreakOutcome::Blocked,
            reasons,
        }
    } else {
        FirebreakDecision {
            outcome: FirebreakOutcome::Allowed,
            reasons: vec!["Operation respects firebreak boundaries".to_string()],
        }
    }
}
