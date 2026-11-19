use popmath::bounds::{NonNegativeF64, UnitInterval};
use popmath::kiosk_reserve::{
    calculate_public_charging_kiosk_reserve, KioskReserveSizingInput,
};
use popmath::social_feedback::{
    simulate_social_acceptance_feedback, SocialFeedbackInput,
};

#[test]
fn social_feedback_remains_bounded_and_deterministic() {
    let input = SocialFeedbackInput {
        initial_acceptance: UnitInterval::new(0.40).expect("initial"),
        target_acceptance: UnitInterval::new(0.85).expect("target"),
        kiosk_reference_count: NonNegativeF64::new(100.0).expect("reference"),
        initial_kiosk_count: NonNegativeF64::new(20.0).expect("kiosks"),
        adaptation_gain: UnitInterval::new(0.25).expect("gain"),
        infrastructure_weight: UnitInterval::new(0.45).expect("weight"),
        mitigation_weight: UnitInterval::new(0.25).expect("weight"),
        investment_pacing: UnitInterval::new(0.20).expect("pacing"),
        mitigation_factor: UnitInterval::new(0.90).expect("mitigation"),
        periods: 12,
    };

    let first = simulate_social_acceptance_feedback(input).expect("result");
    let second = simulate_social_acceptance_feedback(input).expect("result");

    assert_eq!(first, second);
    assert_eq!(first.periods.len(), 12);

    for period in first.periods {
        assert!((0.0..=1.0).contains(&period.acceptance_factor.value()));
        assert!((0.0..=1.0).contains(&period.infrastructure_factor.value()));
        assert!((0.0..=1.0).contains(&period.target_factor.value()));
    }
}

#[test]
fn kiosk_reserve_size_matches_synthetic_example() {
    let result = calculate_public_charging_kiosk_reserve(
        KioskReserveSizingInput {
            critical_load_kw: NonNegativeF64::new(2.0).expect("load"),
            mean_outage_hours: NonNegativeF64::new(1.0).expect("mean"),
            outage_variance_hours_squared: NonNegativeF64::new(0.25)
                .expect("variance"),
            confidence_level: UnitInterval::new(0.90).expect("confidence"),
            continuity_ratio: UnitInterval::new(0.999).expect("continuity"),
            service_window_hours: NonNegativeF64::new(8.0)
                .expect("service window"),
            discharge_efficiency: UnitInterval::new(0.92)
                .expect("efficiency"),
            usable_depth_of_discharge: UnitInterval::new(0.80)
                .expect("depth of discharge"),
            reserve_margin: UnitInterval::new(0.20).expect("margin"),
        },
    )
    .expect("reserve sizing");

    assert!((result.conservative_outage_hours.value() - 2.5).abs() < 1e-9);
    assert!((result.required_support_hours.value() - 2.5).abs() < 1e-9);
    assert!(
        (result.maximum_allowed_gap_hours.value() - 0.008).abs() < 1e-9
    );
    assert!(
        (result.minimum_nominal_capacity_kwh.value().value() - 8.152_173_913)
            .abs()
            < 1e-6
    );
}
