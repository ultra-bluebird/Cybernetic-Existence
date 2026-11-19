use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use thiserror::Error;

/// NeurorightsProfile: Defines neurorights constraints for a host.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NeurorightsProfile {
    /// Host DID for identity binding.
    pub host_did: String,
    /// Whether mental privacy is enforced (no raw neural data export).
    pub mental_privacy_enforced: bool,
    /// Whether cognitive liberty is enforced (no coercive modulation).
    pub cognitive_liberty_enforced: bool,
    /// Whether psychological continuity is enforced (no identity disruption).
    pub psychological_continuity_enforced: bool,
    /// Maximum allowable pain induction score [0.0, 1.0].
    pub max_pain_score: f32,
    /// Maximum allowable fear induction score [0.0, 1.0].
    pub max_fear_score: f32,
    /// Whether explicit consent is required for neurorights-affecting operations.
    pub consent_required: bool,
}

/// ConsentRecord: Records explicit user consent for neurorights-affecting operations.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConsentRecord {
    /// Unique consent identifier.
    pub consent_id: String,
    /// Host DID providing consent.
    pub host_did: String,
    /// Operation or action being consented to.
    pub operation: String,
    /// Timestamp of consent.
    pub granted_at: DateTime<Utc>,
    /// Optional expiration timestamp.
    pub expires_at: Option<DateTime<Utc>>,
    /// Cryptographic signature of consent (hex-encoded).
    pub signature_hex: String,
    /// Whether consent has been revoked.
    pub revoked: bool,
}

#[derive(Error, Debug)]
pub enum NeurorightsError {
    #[error("mental privacy violation: raw neural data export attempted")]
    MentalPrivacyViolation,
    #[error("cognitive liberty violation: coercive modulation attempted")]
    CognitiveLibertyViolation,
    #[error("psychological continuity violation: identity disruption attempted")]
    PsychologicalContinuityViolation,
    #[error("pain score {0} exceeds maximum {1}")]
    PainScoreExceeded(f32, f32),
    #[error("fear score {0} exceeds maximum {1}")]
    FearScoreExceeded(f32, f32),
    #[error("consent required but not provided for operation: {0}")]
    ConsentRequired(String),
    #[error("consent expired or revoked for operation: {0}")]
    ConsentInvalid(String),
}

/// NeurorightsEnforcer: Enforces neurorights constraints for nanoswarm operations.
pub struct NeurorightsEnforcer {
    profile: NeurorightsProfile,
    active_consents: Vec<ConsentRecord>,
}

impl NeurorightsEnforcer {
    /// Create a new enforcer with the given profile.
    pub fn new(profile: NeurorightsProfile) -> Self {
        Self {
            profile,
            active_consents: Vec::new(),
        }
    }

    /// Check if an operation violates neurorights constraints.
    pub fn validate(
        &self,
        operation: &str,
        pain_score: f32,
        fear_score: f32,
        exports_raw_neural_data: bool,
        is_coercive: bool,
        disrupts_identity: bool,
    ) -> Result<(), NeurorightsError> {
        if exports_raw_neural_data && self.profile.mental_privacy_enforced {
            return Err(NeurorightsError::MentalPrivacyViolation);
        }
        if is_coercive && self.profile.cognitive_liberty_enforced {
            return Err(NeurorightsError::CognitiveLibertyViolation);
        }
        if disrupts_identity && self.profile.psychological_continuity_enforced {
            return Err(NeurorightsError::PsychologicalContinuityViolation);
        }
        if pain_score > self.profile.max_pain_score {
            return Err(NeurorightsError::PainScoreExceeded(
                pain_score,
                self.profile.max_pain_score,
            ));
        }
        if fear_score > self.profile.max_fear_score {
            return Err(NeurorightsError::FearScoreExceeded(
                fear_score,
                self.profile.max_fear_score,
            ));
        }
        if self.profile.consent_required {
            if !self.has_valid_consent(operation) {
                return Err(NeurorightsError::ConsentRequired(operation.to_string()));
            }
        }
        Ok(())
    }

    /// Add a new consent record.
    pub fn add_consent(&mut self, consent: ConsentRecord) {
        self.active_consents.push(consent);
    }

    /// Revoke a consent by ID.
    pub fn revoke_consent(&mut self, consent_id: &str) -> bool {
        if let Some(consent) = self.active_consents.iter_mut().find(|c| c.consent_id == consent_id) {
            consent.revoked = true;
            true
        } else {
            false
        }
    }

    /// Check if a valid consent exists for an operation.
    fn has_valid_consent(&self, operation: &str) -> bool {
        let now = Utc::now();
        self.active_consents.iter().any(|c| {
            c.operation == operation
                && !c.revoked
                && c.expires_at.map_or(true, |exp| exp > now)
        })
    }

    /// Get the neurorights profile.
    pub fn profile(&self) -> &NeurorightsProfile {
        &self.profile
    }
}
