use popmath::bounds::{NonNegativeF64, UnitInterval};
use popmath::continuity::{
    assess_continuity, assess_continuity_expression, CapabilityExpression, CapabilityKind,
    CapabilityRequirement, CapabilityWindow, ContinuityStatus, EvidenceStatus,
};
use popmath::time::{TimeWindow, UtcTimestamp};

fn timestamp(seconds_since_epoch: i64) -> UtcTimestamp {
    UtcTimestamp::new(seconds_since_epoch).expect("valid timestamp")
}

fn window(start_seconds: i64, end_seconds: i64) -> TimeWindow {
    TimeWindow::new(timestamp(start_seconds), timestamp(end_seconds)).expect("valid time window")
}

fn unit_interval(value: f64) -> UnitInterval {
    UnitInterval::new(value, "test unit interval").expect("valid unit interval")
}

fn non_negative(value: f64) -> NonNegativeF64 {
    NonNegativeF64::new(value, "test non-negative value").expect("valid non-negative value")
}

fn verified_requirement(kind: CapabilityKind) -> CapabilityRequirement {
    CapabilityRequirement::new(
        kind,
        unit_interval(1.0),
        non_negative(0.0),
        EvidenceStatus::Verified,
    )
}

#[test]
fn flat_requirements_preserve_verified_continuity() {
    let assessment = assess_continuity(
        window(0, 3_600),
        &[verified_requirement(CapabilityKind::ContinuousPower)],
        &[CapabilityWindow::new(
            CapabilityKind::ContinuousPower,
            window(0, 3_600),
            EvidenceStatus::Verified,
            true,
        )],
    )
    .expect("continuity assessment");

    assert_eq!(assessment.overall_status, ContinuityStatus::Met);
    assert_eq!(assessment.availability_ratio.get(), 1.0);
    assert_eq!(assessment.verification_ratio.get(), 1.0);
    assert_eq!(assessment.longest_gap_seconds.get(), 0.0);
}

#[test]
fn overlapping_availability_is_unioned_without_exceeding_one() {
    let assessment = assess_continuity(
        window(0, 3_600),
        &[verified_requirement(CapabilityKind::ChargingAvailability)],
        &[
            CapabilityWindow::new(
                CapabilityKind::ChargingAvailability,
                window(0, 2_400),
                EvidenceStatus::Verified,
                true,
            ),
            CapabilityWindow::new(
                CapabilityKind::ChargingAvailability,
                window(1_200, 3_600),
                EvidenceStatus::Verified,
                true,
            ),
        ],
    )
    .expect("continuity assessment");

    assert_eq!(assessment.overall_status, ContinuityStatus::Met);
    assert_eq!(assessment.availability_ratio.get(), 1.0);
    assert_eq!(assessment.unmet_seconds.get(), 0.0);
    assert_eq!(assessment.longest_gap_seconds.get(), 0.0);
}

#[test]
fn unavailable_middle_segment_is_reported_as_longest_gap() {
    let assessment = assess_continuity(
        window(0, 3_600),
        &[CapabilityRequirement::new(
            CapabilityKind::ContinuousPower,
            unit_interval(0.9),
            non_negative(299.0),
            EvidenceStatus::Verified,
        )],
        &[
            CapabilityWindow::new(
                CapabilityKind::ContinuousPower,
                window(0, 1_500),
                EvidenceStatus::Verified,
                true,
            ),
            CapabilityWindow::new(
                CapabilityKind::ContinuousPower,
                window(1_500, 1_800),
                EvidenceStatus::Verified,
                false,
            ),
            CapabilityWindow::new(
                CapabilityKind::ContinuousPower,
                window(1_800, 3_600),
                EvidenceStatus::Verified,
                true,
            ),
        ],
    )
    .expect("continuity assessment");

    assert_eq!(assessment.overall_status, ContinuityStatus::Unmet);
    assert_eq!(assessment.longest_gap_seconds.get(), 300.0);
    assert_eq!(assessment.unmet_seconds.get(), 300.0);
}

#[test]
fn any_expression_accepts_verified_backup_coverage() {
    let expression = CapabilityExpression::any(
        vec![
            CapabilityExpression::requirement(verified_requirement(
                CapabilityKind::ContinuousPower,
            )),
            CapabilityExpression::requirement(verified_requirement(
                CapabilityKind::LocalBackupPower,
            )),
        ],
    )
    .expect("capability expression");

    let assessment = assess_continuity_expression(
        window(0, 3_600),
        &expression,
        &[
            CapabilityWindow::new(
                CapabilityKind::ContinuousPower,
                window(0, 1_800),
                EvidenceStatus::Verified,
                true,
            ),
            CapabilityWindow::new(
                CapabilityKind::LocalBackupPower,
                window(1_800, 3_600),
                EvidenceStatus::Verified,
                true,
            ),
        ],
    )
    .expect("continuity assessment");

    assert_eq!(assessment.overall_status, ContinuityStatus::Met);
    assert_eq!(assessment.availability_ratio.get(), 1.0);
    assert_eq!(assessment.verification_ratio.get(), 1.0);
}

#[test]
fn all_expression_requires_every_capability() {
    let expression = CapabilityExpression::all(
        vec![
            CapabilityExpression::requirement(verified_requirement(
                CapabilityKind::AccessiblePath,
            )),
            CapabilityExpression::requirement(verified_requirement(
                CapabilityKind::LowLatencyConnectivity,
            )),
        ],
    )
    .expect("capability expression");

    let assessment = assess_continuity_expression(
        window(0, 600),
        &expression,
        &[
            CapabilityWindow::new(
                CapabilityKind::AccessiblePath,
                window(0, 600),
                EvidenceStatus::Verified,
                true,
            ),
            CapabilityWindow::new(
                CapabilityKind::LowLatencyConnectivity,
                window(0, 300),
                EvidenceStatus::Verified,
                true,
            ),
        ],
    )
    .expect("continuity assessment");

    assert_eq!(assessment.overall_status, ContinuityStatus::Unmet);
    assert_eq!(assessment.availability_ratio.get(), 0.5);
    assert_eq!(assessment.longest_gap_seconds.get(), 300.0);
}

#[test]
fn assumed_coverage_is_not_accepted_when_verification_is_required() {
    let assessment = assess_continuity(
        window(0, 600),
        &[verified_requirement(CapabilityKind::LocalBackupPower)],
        &[CapabilityWindow::new(
            CapabilityKind::LocalBackupPower,
            window(0, 600),
            EvidenceStatus::Assumed,
            true,
        )],
    )
    .expect("continuity assessment");

    assert_eq!(
        assessment.overall_status,
        ContinuityStatus::InsufficientEvidence
    );
    assert_eq!(assessment.availability_ratio.get(), 0.0);
    assert_eq!(assessment.verification_ratio.get(), 0.0);
}

#[test]
fn assumed_coverage_is_conditionally_met_when_assumed_evidence_is_allowed() {
    let assessment = assess_continuity(
        window(0, 600),
        &[CapabilityRequirement::new(
            CapabilityKind::OfflineServiceAvailability,
            unit_interval(1.0),
            non_negative(0.0),
            EvidenceStatus::Assumed,
        )],
        &[CapabilityWindow::new(
            CapabilityKind::OfflineServiceAvailability,
            window(0, 600),
            EvidenceStatus::Assumed,
            true,
        )],
    )
    .expect("continuity assessment");

    assert_eq!(
        assessment.overall_status,
        ContinuityStatus::ConditionallyMet
    );
    assert_eq!(assessment.availability_ratio.get(), 1.0);
    assert_eq!(assessment.verification_ratio.get(), 0.0);
}

#[test]
fn nested_expression_preserves_logical_composition() {
    let expression = CapabilityExpression::all(
        vec![
            CapabilityExpression::any(
                vec![
                    CapabilityExpression::requirement(verified_requirement(
                        CapabilityKind::ContinuousPower,
                    )),
                    CapabilityExpression::requirement(verified_requirement(
                        CapabilityKind::LocalBackupPower,
                    )),
                ],
            )
            .expect("power alternative"),
            CapabilityExpression::requirement(verified_requirement(
                CapabilityKind::ElectromagneticInterferenceLow,
            )),
        ],
    )
    .expect("nested expression");

    let assessment = assess_continuity_expression(
        window(0, 1_200),
        &expression,
        &[
            CapabilityWindow::new(
                CapabilityKind::ContinuousPower,
                window(0, 600),
                EvidenceStatus::Verified,
                true,
            ),
            CapabilityWindow::new(
                CapabilityKind::LocalBackupPower,
                window(600, 1_200),
                EvidenceStatus::Verified,
                true,
            ),
            CapabilityWindow::new(
                CapabilityKind::ElectromagneticInterferenceLow,
                window(0, 1_200),
                EvidenceStatus::Verified,
                true,
            ),
        ],
    )
    .expect("continuity assessment");

    assert_eq!(assessment.overall_status, ContinuityStatus::Met);
    assert_eq!(assessment.availability_ratio.get(), 1.0);
}
