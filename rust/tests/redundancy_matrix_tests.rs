use augmented_hub::safety::redundancy_matrix::{
    assess, ChannelHealth, ManualOverrideState, RedundancyObservation, RedundancyPolicy,
    SafetyEvidenceState,
};

fn baseline_observation() -> RedundancyObservation {
    RedundancyObservation {
        sequence: 1,
        primary_sensor: ChannelHealth::Healthy,
        secondary_sensor: ChannelHealth::Healthy,
        watchdog_timer: ChannelHealth::Healthy,
        optical_obstacle_detected: false,
        ultrasonic_obstacle_detected: false,
        disagreement_milliunits: 0,
        disagreement_threshold_milliunits: 100,
        manual_override: ManualOverrideState::NotRequested,
        measured_recovery_ms: Some(80),
    }
}

#[test]
fn healthy_independent_channels_are_operational_evidence() {
    let assessment = assess(&baseline_observation(), RedundancyPolicy::default());

    assert_eq!(
        assessment.state,
        SafetyEvidenceState::OperationalEvidenceSufficient
    );
    assert!(assessment.safety_pass_evidence);
    assert!(assessment.reasons.is_empty());
}

#[test]
fn dual_sensor_failure_is_insufficient_evidence() {
    let mut observation = baseline_observation();
    observation.primary_sensor = ChannelHealth::Failed;
    observation.secondary_sensor = ChannelHealth::Failed;

    let assessment = assess(&observation, RedundancyPolicy::default());

    assert_eq!(
        assessment.state,
        SafetyEvidenceState::SafetyEvidenceInsufficient
    );
    assert!(assessment.dual_primary_failure);
    assert!(
        assessment
            .reasons
            .contains(&"primary_and_secondary_sensor_failure".to_owned())
    );
}

#[test]
fn threshold_exceedance_is_insufficient_evidence() {
    let mut observation = baseline_observation();
    observation.disagreement_milliunits = 101;

    let assessment = assess(&observation, RedundancyPolicy::default());

    assert_eq!(
        assessment.state,
        SafetyEvidenceState::SafetyEvidenceInsufficient
    );
    assert!(assessment.disagreement_exceeded);
}

#[test]
fn channel_divergence_requires_review_without_actuation() {
    let mut observation = baseline_observation();
    observation.optical_obstacle_detected = true;
    observation.ultrasonic_obstacle_detected = false;

    let assessment = assess(&observation, RedundancyPolicy::default());

    assert_eq!(assessment.state, SafetyEvidenceState::ReviewRequired);
    assert!(assessment.obstacle_channels_diverge);
}

#[test]
fn recovery_at_or_above_bound_requires_review() {
    let mut observation = baseline_observation();
    observation.measured_recovery_ms = Some(200);

    let assessment = assess(&observation, RedundancyPolicy::default());

    assert_eq!(assessment.state, SafetyEvidenceState::ReviewRequired);
    assert!(assessment.recovery_bound_exceeded);
}

#[test]
fn manual_override_is_reviewable_and_never_an_automatic_command() {
    let mut observation = baseline_observation();
    observation.manual_override = ManualOverrideState::Requested;

    let assessment = assess(&observation, RedundancyPolicy::default());

    assert_eq!(
        assessment.state,
        SafetyEvidenceState::ManualOverrideRequiresReview
    );
    assert!(
        assessment
            .reasons
            .contains(&"manual_override_requires_authorized_human_review".to_owned())
    );
}
