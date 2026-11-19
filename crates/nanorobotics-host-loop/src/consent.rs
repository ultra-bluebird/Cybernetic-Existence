// crates/nanorobotics-host-loop/src/consent.rs

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[non_exhaustive]
pub enum ConsentState {
    Observe,
    Diagnostic,
    ActuateExplicit,
    SupermindOverride,
}

impl ConsentState {
    fn order_index(&self) -> u8 {
        match self {
            ConsentState::Observe => 0,
            ConsentState::Diagnostic => 1,
            ConsentState::ActuateExplicit => 2,
            ConsentState::SupermindOverride => 3,
        }
    }
}

pub fn consent_leq(c1: &ConsentState, c2: &ConsentState) -> bool {
    c1.order_index() <= c2.order_index()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConsentCommitment {
    pub host_did: String,
    pub consent_state: ConsentState,
    pub policy_id: String,
    pub commitment: Vec<u8>,
}

impl ConsentCommitment {
    pub fn same_origin(&self, other: &ConsentCommitment) -> bool {
        self.host_did == other.host_did && self.policy_id == other.policy_id
    }
}

pub fn actuation_allowed(state: &ConsentState) -> bool {
    match state {
        ConsentState::Observe => false,
        ConsentState::Diagnostic => false,
        ConsentState::ActuateExplicit => true,
        ConsentState::SupermindOverride => true,
    }
}

pub fn diagnostic_allowed(state: &ConsentState) -> bool {
    match state {
        ConsentState::Observe => false,
        ConsentState::Diagnostic => true,
        ConsentState::ActuateExplicit => true,
        ConsentState::SupermindOverride => true,
    }
}

pub fn supermind_override_allowed(state: &ConsentState) -> bool {
    matches!(state, ConsentState::SupermindOverride)
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum PrivacyLevel {
    Minimal,
    InternalOnly,
    ActuationScope,
    ExtendedScope,
}

pub fn privacy_level(state: &ConsentState) -> PrivacyLevel {
    match state {
        ConsentState::Observe => PrivacyLevel::Minimal,
        ConsentState::Diagnostic => PrivacyLevel::InternalOnly,
        ConsentState::ActuateExplicit => PrivacyLevel::ActuationScope,
        ConsentState::SupermindOverride => PrivacyLevel::ExtendedScope,
    }
}

pub fn privacy_transition_ok(from: &ConsentState, to: &ConsentState) -> bool {
    let from_level = privacy_level(from) as u8;
    let to_level = privacy_level(to) as u8;

    if consent_leq(to, from) {
        to_level <= from_level
    } else {
        true
    }
}

pub fn can_observe(_consent: &ConsentCommitment) -> bool {
    true
}

pub fn can_diagnostic(consent: &ConsentCommitment) -> bool {
    diagnostic_allowed(&consent.consent_state)
}

pub fn can_actuate(consent: &ConsentCommitment) -> bool {
    actuation_allowed(&consent.consent_state)
}

pub fn can_supermind_override(consent: &ConsentCommitment) -> bool {
    supermind_override_allowed(&consent.consent_state)
}

pub fn consent_transition_ok(from: &ConsentCommitment, to: &ConsentCommitment) -> bool {
    if !from.same_origin(to) {
        return false;
    }

    let from_state = &from.consent_state;
    let to_state = &to.consent_state;

    if !privacy_transition_ok(from_state, to_state) {
        return false;
    }

    true
}

pub fn actuation_authorized(consent: &ConsentCommitment) -> bool {
    can_actuate(consent)
}
