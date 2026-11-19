use std::collections::BTreeSet;

#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd)]
pub enum SwarmNodeState {
    Cold,
    ReadOnly,
    Attesting,
    Eligible,
    Quarantined,
    Revoked,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SwarmVote {
    Accept,
    Reject,
    Abstain,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct IntegrityAttestation {
    pub node_id: u64,
    pub simulation_generation: u64,
    pub software_measurement: [u8; 32],
    pub policy_version: String,
    pub issued_at_ms: u64,
    pub expires_at_ms: u64,
    pub nonce: [u8; 32],
    pub signature_valid: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SwarmNode {
    pub node_id: u64,
    pub state: SwarmNodeState,
    pub policy_version: String,
    pub simulation_generation: u64,
    pub accepted_measurements: BTreeSet<[u8; 32]>,
    pub last_vote: Option<SwarmVote>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum SwarmError {
    InvalidTransition,
    InvalidAttestation,
    NotEligible,
    PolicyMismatch,
    Revoked,
}

impl SwarmNode {
    pub fn new(
        node_id: u64,
        policy_version: impl Into<String>,
        simulation_generation: u64,
        accepted_measurements: BTreeSet<[u8; 32]>,
    ) -> Self {
        Self {
            node_id,
            state: SwarmNodeState::Cold,
            policy_version: policy_version.into(),
            simulation_generation,
            accepted_measurements,
            last_vote: None,
        }
    }

    pub fn enter_read_only(
        &mut self,
    ) -> Result<(), SwarmError> {
        match self.state {
            SwarmNodeState::Cold
            | SwarmNodeState::Quarantined => {
                self.state = SwarmNodeState::ReadOnly;
                self.last_vote = None;
                Ok(())
            }
            _ => Err(SwarmError::InvalidTransition),
        }
    }

    pub fn begin_attestation(
        &mut self,
    ) -> Result<(), SwarmError> {
        if self.state != SwarmNodeState::ReadOnly {
            return Err(SwarmError::InvalidTransition);
        }

        self.state = SwarmNodeState::Attesting;
        Ok(())
    }

    pub fn verify_attestation(
        &mut self,
        attestation: &IntegrityAttestation,
        now_ms: u64,
    ) -> Result<(), SwarmError> {
        if self.state != SwarmNodeState::Attesting {
            return Err(SwarmError::InvalidTransition);
        }

        let valid = attestation.node_id == self.node_id
            && attestation.simulation_generation == self.simulation_generation
            && attestation.policy_version == self.policy_version
            && attestation.signature_valid
            && now_ms < attestation.expires_at_ms
            && self
                .accepted_measurements
                .contains(&attestation.software_measurement);

        if valid {
            self.state = SwarmNodeState::Eligible;
            Ok(())
        } else {
            self.state = SwarmNodeState::Quarantined;
            self.last_vote = None;
            Err(SwarmError::InvalidAttestation)
        }
    }

    pub fn vote(
        &mut self,
        vote: SwarmVote,
    ) -> Result<(), SwarmError> {
        if self.state == SwarmNodeState::Revoked {
            return Err(SwarmError::Revoked);
        }

        if self.state != SwarmNodeState::Eligible {
            return Err(SwarmError::NotEligible);
        }

        self.last_vote = Some(vote);
        Ok(())
    }

    pub fn quarantine(
        &mut self,
    ) {
        self.state = SwarmNodeState::Quarantined;
        self.last_vote = None;
    }

    pub fn revoke(
        &mut self,
    ) {
        self.state = SwarmNodeState::Revoked;
        self.last_vote = None;
    }

    pub fn is_read_only(
        &self,
    ) -> bool {
        self.state == SwarmNodeState::ReadOnly
    }

    pub fn may_vote(
        &self,
    ) -> bool {
        self.state == SwarmNodeState::Eligible
    }

    pub fn may_mutate_policy(
        &self,
    ) -> bool {
        false
    }

    pub fn may_issue_capability(
        &self,
    ) -> bool {
        false
    }

    pub fn may_dispatch_action(
        &self,
    ) -> bool {
        false
    }
}
