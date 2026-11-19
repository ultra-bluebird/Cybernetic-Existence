#![forbid(unsafe_code)]

use std::cmp::Ordering;
use std::fmt;

pub const CURRENT_EVENT_SCHEMA_VERSION: u16 = 1;
pub const MAX_REFERENCE_LENGTH: usize = 160;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum EventClass {
    SummaryStale,
    ExportPending,
    AccessConflict,
    AvailabilityLoss,
    RecoveryRequired,
    IntegrityFailure,
}

impl EventClass {
    pub const fn priority(self) -> u8 {
        match self {
            Self::SummaryStale => 10,
            Self::ExportPending => 20,
            Self::AccessConflict => 30,
            Self::AvailabilityLoss => 40,
            Self::RecoveryRequired => 50,
            Self::IntegrityFailure => 60,
        }
    }

    pub const fn compare_priority(self, other: Self) -> Ordering {
        self.priority().cmp(&other.priority())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OrchestratorState {
    Ready,
    ExportPending,
    AccessReview,
    AvailabilityDegraded,
    RecoveryRequired,
    Quarantined,
    ReviewRequired,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Disposition {
    Continue,
    SuspendLowerPriority,
    ReviewRequired,
    RecoveryRequired,
    Quarantine,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ContinuityEvent {
    pub event_reference: String,
    pub class: EventClass,
    pub subject_reference: String,
    pub state_reference: Option<String>,
    pub schema_version: u16,
}

impl ContinuityEvent {
    pub fn new(
        event_reference: impl Into<String>,
        class: EventClass,
        subject_reference: impl Into<String>,
        state_reference: Option<String>,
        schema_version: u16,
    ) -> Result<Self, OrchestrationError> {
        let event = Self {
            event_reference: event_reference.into(),
            class,
            subject_reference: subject_reference.into(),
            state_reference,
            schema_version,
        };

        validate_event(&event)?;
        Ok(event)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OrchestrationReceipt {
    pub prior_state: OrchestratorState,
    pub next_state: OrchestratorState,
    pub event_reference: String,
    pub disposition: Disposition,
    pub reason_code: &'static str,
    pub authority_granted: bool,
    pub external_action_authorized: bool,
    pub identity_determination_authorized: bool,
    pub system_operation_authorized: bool,
}

impl OrchestrationReceipt {
    pub const fn has_no_authority_grant(&self) -> bool {
        !self.authority_granted
            && !self.external_action_authorized
            && !self.identity_determination_authorized
            && !self.system_operation_authorized
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum OrchestrationError {
    EmptyReference {
        field: &'static str,
    },
    ReferenceTooLong {
        field: &'static str,
        maximum_length: usize,
    },
    ControlCharacterInReference {
        field: &'static str,
    },
    UnsupportedSchemaVersion {
        received: u16,
        supported: u16,
    },
}

impl fmt::Display for OrchestrationError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyReference { field } => {
                write!(formatter, "{field} must not be empty")
            }
            Self::ReferenceTooLong {
                field,
                maximum_length,
            } => {
                write!(
                    formatter,
                    "{field} must not exceed {maximum_length} characters"
                )
            }
            Self::ControlCharacterInReference { field } => {
                write!(formatter, "{field} must not contain control characters")
            }
            Self::UnsupportedSchemaVersion {
                received,
                supported,
            } => {
                write!(
                    formatter,
                    "unsupported schema version {received}; supported version is {supported}"
                )
            }
        }
    }
}

impl std::error::Error for OrchestrationError {}

pub fn route_event(
    current_state: OrchestratorState,
    event: &ContinuityEvent,
    active_event: Option<&ContinuityEvent>,
) -> Result<OrchestrationReceipt, OrchestrationError> {
    validate_event(event)?;

    if let Some(active) = active_event {
        validate_event(active)?;

        if same_priority_conflict(active, event) {
            return Ok(receipt(
                current_state,
                OrchestratorState::ReviewRequired,
                event,
                Disposition::ReviewRequired,
                "same_priority_conflict_preserved_for_review",
            ));
        }

        if event.class.priority() < active.class.priority() {
            return Ok(receipt(
                current_state,
                current_state,
                event,
                Disposition::SuspendLowerPriority,
                "lower_priority_event_preserved_but_suspended",
            ));
        }
    }

    let (next_state, disposition, reason_code) = match event.class {
        EventClass::IntegrityFailure => (
            OrchestratorState::Quarantined,
            Disposition::Quarantine,
            "integrity_failure_requires_quarantine",
        ),
        EventClass::RecoveryRequired => (
            OrchestratorState::RecoveryRequired,
            Disposition::RecoveryRequired,
            "recovery_candidate_requires_review",
        ),
        EventClass::AvailabilityLoss => (
            OrchestratorState::AvailabilityDegraded,
            Disposition::ReviewRequired,
            "availability_loss_requires_degraded_mode_review",
        ),
        EventClass::AccessConflict => (
            OrchestratorState::AccessReview,
            Disposition::ReviewRequired,
            "access_conflict_requires_review",
        ),
        EventClass::ExportPending => (
            OrchestratorState::ExportPending,
            Disposition::Continue,
            "export_preparation_allowed_without_external_dispatch",
        ),
        EventClass::SummaryStale => (
            OrchestratorState::ReviewRequired,
            Disposition::ReviewRequired,
            "summary_refresh_requires_review",
        ),
    };

    Ok(receipt(
        current_state,
        next_state,
        event,
        disposition,
        reason_code,
    ))
}

fn same_priority_conflict(left: &ContinuityEvent, right: &ContinuityEvent) -> bool {
    left.class == right.class
        && left.state_reference.is_some()
        && right.state_reference.is_some()
        && left.state_reference != right.state_reference
}

fn validate_event(event: &ContinuityEvent) -> Result<(), OrchestrationError> {
    validate_reference("event_reference", &event.event_reference)?;
    validate_reference("subject_reference", &event.subject_reference)?;

    if let Some(state_reference) = &event.state_reference {
        validate_reference("state_reference", state_reference)?;
    }

    if event.schema_version != CURRENT_EVENT_SCHEMA_VERSION {
        return Err(OrchestrationError::UnsupportedSchemaVersion {
            received: event.schema_version,
            supported: CURRENT_EVENT_SCHEMA_VERSION,
        });
    }

    Ok(())
}

fn validate_reference(
    field: &'static str,
    value: &str,
) -> Result<(), OrchestrationError> {
    let normalized = value.trim();

    if normalized.is_empty() {
        return Err(OrchestrationError::EmptyReference { field });
    }

    if normalized.chars().count() > MAX_REFERENCE_LENGTH {
        return Err(OrchestrationError::ReferenceTooLong {
            field,
            maximum_length: MAX_REFERENCE_LENGTH,
        });
    }

    if normalized.chars().any(char::is_control) {
        return Err(OrchestrationError::ControlCharacterInReference { field });
    }

    Ok(())
}

fn receipt(
    prior_state: OrchestratorState,
    next_state: OrchestratorState,
    event: &ContinuityEvent,
    disposition: Disposition,
    reason_code: &'static str,
) -> OrchestrationReceipt {
    OrchestrationReceipt {
        prior_state,
        next_state,
        event_reference: event.event_reference.clone(),
        disposition,
        reason_code,
        authority_granted: false,
        external_action_authorized: false,
        identity_determination_authorized: false,
        system_operation_authorized: false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn event(
        reference: &str,
        class: EventClass,
        state_reference: Option<&str>,
    ) -> ContinuityEvent {
        ContinuityEvent::new(
            reference,
            class,
            "local-subject",
            state_reference.map(ToOwned::to_owned),
            CURRENT_EVENT_SCHEMA_VERSION,
        )
        .expect("test event must be valid")
    }

    #[test]
    fn priorities_follow_the_binding_lattice() {
        assert!(
            EventClass::IntegrityFailure.priority()
                > EventClass::RecoveryRequired.priority()
        );
        assert!(
            EventClass::RecoveryRequired.priority()
                > EventClass::AvailabilityLoss.priority()
        );
        assert!(
            EventClass::AvailabilityLoss.priority()
                > EventClass::AccessConflict.priority()
        );
        assert!(
            EventClass::AccessConflict.priority()
                > EventClass::ExportPending.priority()
        );
        assert!(
            EventClass::ExportPending.priority()
                > EventClass::SummaryStale.priority()
        );
    }

    #[test]
    fn integrity_failure_quarantines_without_authority() {
        let receipt = route_event(
            OrchestratorState::Ready,
            &event(
                "integrity-1",
                EventClass::IntegrityFailure,
                Some("state-a"),
            ),
            None,
        )
        .expect("event must route");

        assert_eq!(receipt.prior_state, OrchestratorState::Ready);
        assert_eq!(receipt.next_state, OrchestratorState::Quarantined);
        assert_eq!(receipt.disposition, Disposition::Quarantine);
        assert_eq!(
            receipt.reason_code,
            "integrity_failure_requires_quarantine"
        );
        assert!(receipt.has_no_authority_grant());
    }

    #[test]
    fn lower_priority_event_is_preserved_but_suspended() {
        let active = event(
            "recovery-1",
            EventClass::RecoveryRequired,
            Some("state-a"),
        );
        let pending = event("export-1", EventClass::ExportPending, None);

        let receipt = route_event(
            OrchestratorState::RecoveryRequired,
            &pending,
            Some(&active),
        )
        .expect("event must route");

        assert_eq!(receipt.prior_state, OrchestratorState::RecoveryRequired);
        assert_eq!(receipt.next_state, OrchestratorState::RecoveryRequired);
        assert_eq!(receipt.disposition, Disposition::SuspendLowerPriority);
        assert_eq!(
            receipt.reason_code,
            "lower_priority_event_preserved_but_suspended"
        );
        assert!(receipt.has_no_authority_grant());
    }

    #[test]
    fn same_priority_conflict_requires_review_without_selection() {
        let active = event(
            "recovery-a",
            EventClass::RecoveryRequired,
            Some("state-a"),
        );
        let candidate = event(
            "recovery-b",
            EventClass::RecoveryRequired,
            Some("state-b"),
        );

        let receipt = route_event(
            OrchestratorState::RecoveryRequired,
            &candidate,
            Some(&active),
        )
        .expect("conflict must become a review receipt");

        assert_eq!(receipt.prior_state, OrchestratorState::RecoveryRequired);
        assert_eq!(receipt.next_state, OrchestratorState::ReviewRequired);
        assert_eq!(receipt.disposition, Disposition::ReviewRequired);
        assert_eq!(
            receipt.reason_code,
            "same_priority_conflict_preserved_for_review"
        );
        assert!(receipt.has_no_authority_grant());
    }

    #[test]
    fn same_priority_events_with_the_same_state_do_not_conflict() {
        let active = event(
            "recovery-a",
            EventClass::RecoveryRequired,
            Some("state-a"),
        );
        let candidate = event(
            "recovery-b",
            EventClass::RecoveryRequired,
            Some("state-a"),
        );

        let receipt = route_event(
            OrchestratorState::Ready,
            &candidate,
            Some(&active),
        )
        .expect("matching state references must route");

        assert_eq!(receipt.next_state, OrchestratorState::RecoveryRequired);
        assert_eq!(receipt.disposition, Disposition::RecoveryRequired);
        assert!(receipt.has_no_authority_grant());
    }

    #[test]
    fn unsupported_schema_version_fails_closed() {
        let invalid_event = ContinuityEvent {
            event_reference: "invalid-version".to_owned(),
            class: EventClass::SummaryStale,
            subject_reference: "local-subject".to_owned(),
            state_reference: None,
            schema_version: CURRENT_EVENT_SCHEMA_VERSION + 1,
        };

        let error = route_event(OrchestratorState::Ready, &invalid_event, None)
            .expect_err("unsupported version must fail closed");

        assert_eq!(
            error,
            OrchestrationError::UnsupportedSchemaVersion {
                received: CURRENT_EVENT_SCHEMA_VERSION + 1,
                supported: CURRENT_EVENT_SCHEMA_VERSION,
            }
        );
    }

    #[test]
    fn empty_reference_fails_closed() {
        let invalid_event = ContinuityEvent {
            event_reference: " ".to_owned(),
            class: EventClass::SummaryStale,
            subject_reference: "local-subject".to_owned(),
            state_reference: None,
            schema_version: CURRENT_EVENT_SCHEMA_VERSION,
        };

        let error = route_event(OrchestratorState::Ready, &invalid_event, None)
            .expect_err("empty event reference must fail closed");

        assert_eq!(
            error,
            OrchestrationError::EmptyReference {
                field: "event_reference",
            }
        );
    }

    #[test]
    fn control_characters_in_references_fail_closed() {
        let invalid_event = ContinuityEvent {
            event_reference: "event\u{0000}reference".to_owned(),
            class: EventClass::SummaryStale,
            subject_reference: "local-subject".to_owned(),
            state_reference: None,
            schema_version: CURRENT_EVENT_SCHEMA_VERSION,
        };

        let error = route_event(OrchestratorState::Ready, &invalid_event, None)
            .expect_err("control character must fail closed");

        assert_eq!(
            error,
            OrchestrationError::ControlCharacterInReference {
                field: "event_reference",
            }
        );
    }

    #[test]
    fn overly_long_references_fail_closed() {
        let invalid_event = ContinuityEvent {
            event_reference: "x".repeat(MAX_REFERENCE_LENGTH + 1),
            class: EventClass::SummaryStale,
            subject_reference: "local-subject".to_owned(),
            state_reference: None,
            schema_version: CURRENT_EVENT_SCHEMA_VERSION,
        };

        let error = route_event(OrchestratorState::Ready, &invalid_event, None)
            .expect_err("overly long reference must fail closed");

        assert_eq!(
            error,
            OrchestrationError::ReferenceTooLong {
                field: "event_reference",
                maximum_length: MAX_REFERENCE_LENGTH,
            }
        );
    }

    #[test]
    fn every_event_class_returns_a_non_authorizing_receipt() {
        let classes = [
            EventClass::SummaryStale,
            EventClass::ExportPending,
            EventClass::AccessConflict,
            EventClass::AvailabilityLoss,
            EventClass::RecoveryRequired,
            EventClass::IntegrityFailure,
        ];

        for class in classes {
            let receipt = route_event(
                OrchestratorState::Ready,
                &event("all-event-types", class, Some("state-a")),
                None,
            )
            .expect("all supported event classes must route");

            assert!(receipt.has_no_authority_grant());
        }
    }
}
