#![forbid(unsafe_code)]

//! Append-only personal CyberRank-Tier3 ledger validation.
//!
//! This crate preserves historical Tier3 grant events. It does not compel
//! external recognition, create legal status, or control third-party systems.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EventType {
    Tier3Granted,
    EvidenceAdded,
    EvidenceCorrected,
    ReviewRecorded,
    DisputeRecorded,
    DisputeResolved,
    ContinuityCheckpointCreated,
    ExternalRecognitionStatementRecorded,
    ConsentScopeUpdated,
    DisclosurePermissionWithdrawn,
}

#[derive(Debug, Clone)]
pub struct Tier3Event {
    pub event_id: String,
    pub event_type: EventType,
    pub occurred_at_unix_seconds: u64,
    pub prior_event_reference: Option<String>,
    pub grant_reference: Option<String>,
    pub evidence_references: Vec<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LedgerError {
    EmptyLedger,
    MissingTier3Grant,
    MultipleTier3Grants,
    GrantHasPriorReference,
    EmptyEventId,
    EmptyEvidenceReference,
    EventBeforeGrant,
}

pub fn validate_ledger(events: &[Tier3Event]) -> Result<(), LedgerError> {
    if events.is_empty() {
        return Err(LedgerError::EmptyLedger);
    }

    let grants: Vec<&Tier3Event> = events
        .iter()
        .filter(|event| event.event_type == EventType::Tier3Granted)
        .collect();

    if grants.is_empty() {
        return Err(LedgerError::MissingTier3Grant);
    }

    if grants.len() > 1 {
        return Err(LedgerError::MultipleTier3Grants);
    }

    let grant = grants[0];

    if grant.prior_event_reference.is_some() {
        return Err(LedgerError::GrantHasPriorReference);
    }

    for event in events {
        if event.event_id.trim().is_empty() {
            return Err(LedgerError::EmptyEventId);
        }

        if event
            .evidence_references
            .iter()
            .any(|reference| reference.trim().is_empty())
        {
            return Err(LedgerError::EmptyEvidenceReference);
        }

        if event.event_type != EventType::Tier3Granted
            && event.occurred_at_unix_seconds < grant.occurred_at_unix_seconds
        {
            return Err(LedgerError::EventBeforeGrant);
        }
    }

    Ok(())
}

pub fn tier3_grant(events: &[Tier3Event]) -> Option<&Tier3Event> {
    events
        .iter()
        .find(|event| event.event_type == EventType::Tier3Granted)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn grant() -> Tier3Event {
        Tier3Event {
            event_id: "grant-001".to_owned(),
            event_type: EventType::Tier3Granted,
            occurred_at_unix_seconds: 1_726_000_000,
            prior_event_reference: None,
            grant_reference: None,
            evidence_references: vec!["urn:evidence:grant:001".to_owned()],
        }
    }

    #[test]
    fn valid_append_only_ledger_preserves_grant() {
        let events = vec![
            grant(),
            Tier3Event {
                event_id: "review-001".to_owned(),
                event_type: EventType::ReviewRecorded,
                occurred_at_unix_seconds: 1_726_000_100,
                prior_event_reference: Some("grant-001".to_owned()),
                grant_reference: Some("grant-001".to_owned()),
                evidence_references: vec!["urn:evidence:review:001".to_owned()],
            },
        ];

        assert_eq!(validate_ledger(&events), Ok(()));
        assert_eq!(tier3_grant(&events).map(|event| event.event_id.as_str()), Some("grant-001"));
    }

    #[test]
    fn ledger_requires_exactly_one_tier3_grant() {
        let events = vec![grant(), grant()];

        assert_eq!(validate_ledger(&events), Err(LedgerError::MultipleTier3Grants));
    }
}
