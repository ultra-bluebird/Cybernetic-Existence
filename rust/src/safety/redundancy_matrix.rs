use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ChannelHealth {
    Healthy,
    Degraded,
    Failed,
    Unknown,
}

impl ChannelHealth {
    pub const fn is_healthy(self) -> bool {
        matches!(self, Self::Healthy)
    }

    pub const fn is_failed(self) -> bool {
        matches!(self, Self::Failed)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ManualOverrideState {
    NotRequested,
    Requested,
    Active,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SafetyEvidenceState {
    OperationalEvidenceSufficient,
    ReviewRequired,
    SafetyEvidenceInsufficient,
    ManualOverrideRequiresReview,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RedundancyObservation {
    pub sequence: u64,
    pub primary_sensor: ChannelHealth,
    pub secondary_sensor: ChannelHealth,
    pub watchdog_timer: ChannelHealth,
    pub optical_obstacle_detected: bool,
    pub ultrasonic_obstacle_detected: bool,
    pub disagreement_milliunits: u32,
    pub disagreement_threshold_milliunits: u32,
    pub manual_override: ManualOverrideState,
    pub measured_recovery_ms: Option<u32>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RedundancyAssessment {
    pub sequence: u64,
    pub primary_and_secondary_healthy: bool,
    pub primary_and_watchdog_healthy: bool,
    pub safety_pass_evidence: bool,
    pub dual_primary_failure: bool,
    pub disagreement_exceeded: bool,
    pub recovery_bound_exceeded: bool,
    pub obstacle_channels_diverge: bool,
    pub state: SafetyEvidenceState,
    pub reasons: Vec<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RedundancyPolicy {
    pub maximum_recovery_ms: u32,
}

impl Default for RedundancyPolicy {
    fn default() -> Self {
        Self {
            maximum_recovery_ms: 200,
        }
    }
}

pub fn assess(
    observation: &RedundancyObservation,
    policy: RedundancyPolicy,
) -> RedundancyAssessment {
    let primary_and_secondary_healthy =
        observation.primary_sensor.is_healthy() && observation.secondary_sensor.is_healthy();

    let primary_and_watchdog_healthy =
        observation.primary_sensor.is_healthy() && observation.watchdog_timer.is_healthy();

    let safety_pass_evidence =
        primary_and_secondary_healthy || primary_and_watchdog_healthy;

    let dual_primary_failure =
        observation.primary_sensor.is_failed() && observation.secondary_sensor.is_failed();

    let disagreement_exceeded =
        observation.disagreement_milliunits > observation.disagreement_threshold_milliunits;

    let recovery_bound_exceeded = observation
        .measured_recovery_ms
        .is_some_and(|elapsed| elapsed >= policy.maximum_recovery_ms);

    let obstacle_channels_diverge =
        observation.optical_obstacle_detected != observation.ultrasonic_obstacle_detected;

    let mut reasons = Vec::new();

    if dual_primary_failure {
        reasons.push("primary_and_secondary_sensor_failure".to_owned());
    }

    if disagreement_exceeded {
        reasons.push("measurement_disagreement_exceeds_threshold".to_owned());
    }

    if obstacle_channels_diverge {
        reasons.push("optical_and_ultrasonic_observation_diverge".to_owned());
    }

    if recovery_bound_exceeded {
        reasons.push("recovery_time_exceeds_configured_bound".to_owned());
    }

    if !safety_pass_evidence {
        reasons.push("redundancy_health_evidence_is_insufficient".to_owned());
    }

    let state = if matches!(
        observation.manual_override,
        ManualOverrideState::Requested | ManualOverrideState::Active
    ) {
        reasons.push("manual_override_requires_authorized_human_review".to_owned());
        SafetyEvidenceState::ManualOverrideRequiresReview
    } else if dual_primary_failure || disagreement_exceeded || !safety_pass_evidence {
        SafetyEvidenceState::SafetyEvidenceInsufficient
    } else if obstacle_channels_diverge || recovery_bound_exceeded {
        SafetyEvidenceState::ReviewRequired
    } else {
        SafetyEvidenceState::OperationalEvidenceSufficient
    };

    RedundancyAssessment {
        sequence: observation.sequence,
        primary_and_secondary_healthy,
        primary_and_watchdog_healthy,
        safety_pass_evidence,
        dual_primary_failure,
        disagreement_exceeded,
        recovery_bound_exceeded,
        obstacle_channels_diverge,
        state,
        reasons,
    }
}
