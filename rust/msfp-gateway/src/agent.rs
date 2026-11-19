use crate::{GatewaySession, SessionState};
use serde::Serialize;
use std::collections::BTreeSet;

pub const SESSION_STATUS_READ: &str = "session.status.read";
pub const IDENTITY_PROOF_VERIFY: &str = "identity.proof.verify";
pub const TELEMETRY_SUMMARY_READ: &str = "telemetry.summary.read";

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct AgentCapability {
    pub operation: String,
    pub session_generation: u64,
    pub expires_at_ms: u64,
    pub delegable: bool,
}

impl AgentCapability {
    pub fn read_only(
        operation: impl Into<String>,
        session_generation: u64,
        expires_at_ms: u64,
    ) -> Self {
        Self {
            operation: operation.into(),
            session_generation,
            expires_at_ms,
            delegable: false,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum AgentRequest {
    SessionStatusRead,
    IdentityProofVerify {
        proof_digest: [u8; 32],
    },
    TelemetrySummaryRead,
    CommandExecute,
    ActuationControl,
    ConfigurationWrite,
    FirmwareUpdate,
    RawMemoryRead,
}

impl AgentRequest {
    pub fn operation(&self) -> &'static str {
        match self {
            Self::SessionStatusRead => SESSION_STATUS_READ,
            Self::IdentityProofVerify { .. } => IDENTITY_PROOF_VERIFY,
            Self::TelemetrySummaryRead => TELEMETRY_SUMMARY_READ,
            Self::CommandExecute => "command.execute",
            Self::ActuationControl => "actuation.control",
            Self::ConfigurationWrite => "configuration.write",
            Self::FirmwareUpdate => "firmware.update",
            Self::RawMemoryRead => "raw.memory.read",
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct SessionStatusSummary {
    pub state: String,
    pub generation: u64,
    pub external_authority_active: bool,
    pub remaining_session_bytes: u64,
    pub remaining_session_messages: u64,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct IdentityProofSummary {
    pub verification_supported: bool,
    pub proof_digest_received: bool,
    pub identity_data_disclosed: bool,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct TelemetrySummary {
    pub session_active: bool,
    pub remaining_session_bytes: u64,
    pub remaining_session_messages: u64,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub enum AgentResponse {
    SessionStatus(SessionStatusSummary),
    IdentityProof(IdentityProofSummary),
    Telemetry(TelemetrySummary),
    Denied {
        operation: String,
        reason: String,
    },
}

pub struct AgentFacade<'a> {
    session: &'a GatewaySession,
    allowed_operations: BTreeSet<String>,
}

impl<'a> AgentFacade<'a> {
    pub fn new(
        session: &'a GatewaySession,
        capabilities: impl IntoIterator<Item = AgentCapability>,
        now_ms: u64,
    ) -> Self {
        let allowed_operations = capabilities
            .into_iter()
            .filter(|capability| {
                capability.session_generation == session.generation()
                    && capability.expires_at_ms > now_ms
                    && !capability.delegable
                    && agent_operation_allowed(&capability.operation)
            })
            .map(|capability| capability.operation)
            .collect();

        Self {
            session,
            allowed_operations,
        }
    }

    pub fn handle(
        &self,
        request: AgentRequest,
    ) -> AgentResponse {
        let operation = request.operation();

        if !self.allowed_operations.contains(operation) {
            return AgentResponse::Denied {
                operation: operation.to_owned(),
                reason: "operation is not authorized for this agent capability set".to_owned(),
            };
        }

        match request {
            AgentRequest::SessionStatusRead => {
                AgentResponse::SessionStatus(SessionStatusSummary {
                    state: session_state_name(self.session.state()).to_owned(),
                    generation: self.session.generation(),
                    external_authority_active: self.session.has_external_authority(),
                    remaining_session_bytes: self.session.remaining_session_bytes(),
                    remaining_session_messages: self.session.remaining_session_messages(),
                })
            }
            AgentRequest::IdentityProofVerify { proof_digest } => {
                AgentResponse::IdentityProof(IdentityProofSummary {
                    verification_supported: self.session.state() == SessionState::Active,
                    proof_digest_received: proof_digest != [0_u8; 32],
                    identity_data_disclosed: false,
                })
            }
            AgentRequest::TelemetrySummaryRead => {
                AgentResponse::Telemetry(TelemetrySummary {
                    session_active: self.session.is_active(),
                    remaining_session_bytes: self.session.remaining_session_bytes(),
                    remaining_session_messages: self.session.remaining_session_messages(),
                })
            }
            AgentRequest::CommandExecute
            | AgentRequest::ActuationControl
            | AgentRequest::ConfigurationWrite
            | AgentRequest::FirmwareUpdate
            | AgentRequest::RawMemoryRead => AgentResponse::Denied {
                operation: operation.to_owned(),
                reason: "operation is permanently excluded from the agent facade".to_owned(),
            },
        }
    }
}

pub fn agent_operation_allowed(
    operation: &str,
) -> bool {
    matches!(
        operation,
        SESSION_STATUS_READ
            | IDENTITY_PROOF_VERIFY
            | TELEMETRY_SUMMARY_READ
    )
}

fn session_state_name(
    state: SessionState,
) -> &'static str {
    match state {
        SessionState::Cold => "cold",
        SessionState::Active => "active",
        SessionState::Revoked => "revoked",
        SessionState::Expired => "expired",
    }
}
