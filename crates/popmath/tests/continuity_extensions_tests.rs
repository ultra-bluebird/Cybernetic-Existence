use popmath::bounds::{NonNegativeF64, UnitInterval};
use popmath::continuity::{
    assess_continuity_expression, CapabilityExpression, CapabilityKind, CapabilityRequirement,
    CapabilityWindow, ContinuityStatus, EvidenceStatus,
};
use popmath::emi::{
    as_capability_window, ElectricFieldStrengthVoltsPerMeter, EmiMeasurement,
    EmiSensitivityThreshold,
};
use popmath::energy::{
    calculate_critical_load_continuity, CriticalLoadContinuityInput,
    TriangularOutageDistribution,
};
use popmath::social::{calculate_social_acceptance, SocialAcceptanceInput};
use popmath::time::{TimeWindow, UtcTimestamp};

fn timestamp(seconds: i64) -> UtcTimestamp {
    UtcTimestamp::new(seconds).expect("timestamp")
}

fn window(start: i64, end: i64) -> TimeWindow {
    TimeWindow::new(timestamp(start), timestamp(end)).expect("window")
}

fn requirement(kind: CapabilityKind) -> CapabilityRequirement {
    CapabilityRequirement::new(
        kind,
        UnitInterval::new(1.0).expect("availability"),
        NonNegativeF64::new(0.0).expect("gap"),
        EvidenceStatus::Verified,
    )
}

#[test]
fn alternative_power_sources_satisfy_any_expression() {
    let expression = CapabilityExpression::any(vec![
        CapabilityExpression::requirement(requirement(CapabilityKind::ContinuousPower)),
        CapabilityExpression::requirement(requirement(CapabilityKind::LocalBackupPower)),
    ])
    .expect("non-empty expression");

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
    .expect("assessment");

    assert_eq!(assessment.overall_status, ContinuityStatus::Met);
    assert_eq!(assessment.availability_ratio.value(), 1.0);
    assert_eq!(assessment.longest_gap_seconds.value(), 0.0);
}

#[test]
fn overlapping_windows_are_unioned_without_double_counting() {
    let expression = CapabilityExpression::requirement(
        requirement(CapabilityKind::ChargingAvailability),
    );

    let assessment = assess_continuity_expression(
        window(0, 3_600),
        &expression,
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
    .expect("assessment");

    assert_eq!(assessment.availability_ratio.value(), 1.0);
    assert_eq!(assessment.unmet_seconds.value(), 0.0);
    assert_eq!(assessment.longest_gap_seconds.value(), 0.0);
}

#[test]
fn unverified_backup_does_not_satisfy_verified_requirement() {
    let expression = CapabilityExpression::any(vec![
        CapabilityExpression::requirement(requirement(CapabilityKind::ContinuousPower)),
        CapabilityExpression::requirement(requirement(CapabilityKind::LocalBackupPower)),
    ])
    .expect("expression");

    let assessment = assess_continuity_expression(
        window(0, 600),
        &expression,
        &[CapabilityWindow::new(
            CapabilityKind::LocalBackupPower,
            window(0, 600),
            EvidenceStatus::Assumed,
            true,
        )],
    )
    .expect("assessment");

    assert_eq!(assessment.overall_status, ContinuityStatus::Unmet);
    assert_eq!(assessment.availability_ratio.value(), 0.0);
}

#[test]
fn triangular_outage_probability_matches_support_duration() {
    let outage = TriangularOutageDistribution::new(
        NonNegativeF64::new(600.0).expect("minimum"),
        NonNegativeF64::new(1_800.0).expect("mode"),
        NonNegativeF64::new(3_600.0).expect("maximum"),
    )
    .expect("distribution");

    let result = calculate_critical_load_continuity(
        CriticalLoadContinuityInput {
            stored_energy_kwh: NonNegativeF64::new(2.0).expect("energy"),
            discharge_efficiency: UnitInterval::new(0.9).expect("efficiency"),
            critical_load_kw: NonNegativeF64::new(1.0).expect("load"),
            outage_distribution: outage,
        },
        window(0, 3_600),
        EvidenceStatus::Verified,
    )
    .expect("critical-load continuity");

    assert_eq!(result.support_duration_seconds.value(), 6_480.0);
    assert_eq!(result.probability_supported_for_expected_outage.value(), 1.0);
    assert_eq!(result.worst_case_unmet_seconds.value(), 0.0);
}

#[test]
fn emi_measurement_maps_to_low_interference_capability() {
    let measurement = EmiMeasurement {
        corridor_window: window(0, 300),
        electric_field_strength: ElectricFieldStrengthVoltsPerMeter::new(
            NonNegativeF64::new(3.0).expect("field strength"),
        ),
        confidence: UnitInterval::new(0.95).expect("confidence"),
        evidence: EvidenceStatus::Verified,
    };

    let threshold = EmiSensitivityThreshold {
        maximum_field_strength: ElectricFieldStrengthVoltsPerMeter::new(
            NonNegativeF64::new(5.0).expect("threshold"),
        ),
        required_confidence: UnitInterval::new(0.9).expect("required confidence"),
    };

    let capability = as_capability_window(measurement, threshold);

    assert_eq!(
        capability.kind,
        CapabilityKind::ElectromagneticInterferenceLow
    );
    assert!(capability.available);
}

#[test]
fn social_acceptance_requires_non_compensable_foundations() {
    let result = calculate_social_acceptance(SocialAcceptanceInput {
        inclusive_policy_coverage: UnitInterval::new(0.9).expect("policy"),
        inclusive_infrastructure_coverage: UnitInterval::new(0.9).expect("infrastructure"),
        voluntary_participation_coverage: UnitInterval::new(0.8).expect("participation"),
        accessible_remedy_coverage: UnitInterval::new(0.9).expect("remedy"),
        policy_weight: UnitInterval::new(0.25).expect("weight"),
        infrastructure_weight: UnitInterval::new(0.35).expect("weight"),
        participation_weight: UnitInterval::new(0.15).expect("weight"),
        remedy_weight: UnitInterval::new(0.25).expect("weight"),
        minimum_policy_coverage: UnitInterval::new(0.8).expect("minimum"),
        minimum_infrastructure_coverage: UnitInterval::new(0.8).expect("minimum"),
        minimum_remedy_coverage: UnitInterval::new(0.8).expect("minimum"),
    })
    .expect("social acceptance");

    assert!(result.floor_conditions_met);
    assert!(result.social_acceptance_factor.value() > 0.0);
}

#[test]
fn social_acceptance_does_not_compensate_for_missing_remedy_path() {
    let result = calculate_social_acceptance(SocialAcceptanceInput {
        inclusive_policy_coverage: UnitInterval::new(1.0).expect("policy"),
        inclusive_infrastructure_coverage: UnitInterval::new(1.0).expect("infrastructure"),
        voluntary_participation_coverage: UnitInterval::new(1.0).expect("participation"),
        accessible_remedy_coverage: UnitInterval::new(0.2).expect("remedy"),
        policy_weight: UnitInterval::new(0.25).expect("weight"),
        infrastructure_weight: UnitInterval::new(0.35).expect("weight"),
        participation_weight: UnitInterval::new(0.15).expect("weight"),
        remedy_weight: UnitInterval::new(0.25).expect("weight"),
        minimum_policy_coverage: UnitInterval::new(0.8).expect("minimum"),
        minimum_infrastructure_coverage: UnitInterval::new(0.8).expect("minimum"),
        minimum_remedy_coverage: UnitInterval::new(0.8).expect("minimum"),
    })
    .expect("social acceptance");

    assert!(!result.floor_conditions_met);
    assert_eq!(result.social_acceptance_factor.value(), 0.0);
}
