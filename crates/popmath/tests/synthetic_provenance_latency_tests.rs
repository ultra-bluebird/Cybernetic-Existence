use popmath::bounds::{NonNegativeF64, Probability, UnitInterval};
use popmath::continuity::EvidenceStatus;
use popmath::latency::{
    assess_latency_window, latency_measurement_to_capability_window,
    LatencyMeasurementWindow, LatencyMilliseconds, LatencyRequirement,
};
use popmath::simulation::RandomSeed;
use popmath::synthetic_demand::{
    generate_synthetic_cohort_demand, AggregateZone, DemandTimeBin,
    SyntheticCohortDemandInput, SyntheticDeviceProfile, SyntheticDeviceType,
};
use popmath::time::{TimeWindow, UtcTimestamp};

fn timestamp(seconds: i64) -> UtcTimestamp {
    UtcTimestamp::new(seconds).expect("timestamp")
}

fn window(start: i64, end: i64) -> TimeWindow {
    TimeWindow::new(timestamp(start), timestamp(end)).expect("window")
}

fn synthetic_input(seed: u64) -> SyntheticCohortDemandInput {
    SyntheticCohortDemandInput {
        seed: RandomSeed::new(seed),
        synthetic_population: popmath::units::PopulationCount::new(100)
            .expect("population"),
        zones: vec![
            AggregateZone { zone_index: 1 },
            AggregateZone { zone_index: 2 },
        ],
        time_bins: vec![
            DemandTimeBin {
                bin_index: 0,
                duration_minutes: 60,
                is_peak_period: false,
            },
            DemandTimeBin {
                bin_index: 1,
                duration_minutes: 60,
                is_peak_period: true,
            },
        ],
        device_profiles: vec![
            SyntheticDeviceProfile {
                device_type: SyntheticDeviceType::PoweredMobilitySupport,
                selection_probability: Probability::new(0.6).expect("probability"),
                operating_power_kw: NonNegativeF64::new(0.15).expect("power"),
                recharge_energy_kwh_per_day: NonNegativeF64::new(0.5)
                    .expect("energy"),
                travel_participation_probability: Probability::new(0.8)
                    .expect("probability"),
                peak_utilization: UnitInterval::new(0.8).expect("utilization"),
                off_peak_utilization: UnitInterval::new(0.4).expect("utilization"),
            },
            SyntheticDeviceProfile {
                device_type: SyntheticDeviceType::AssistiveCommunicationInterface,
                selection_probability: Probability::new(0.4).expect("probability"),
                operating_power_kw: NonNegativeF64::new(0.03).expect("power"),
                recharge_energy_kwh_per_day: NonNegativeF64::new(0.1)
                    .expect("energy"),
                travel_participation_probability: Probability::new(0.7)
                    .expect("probability"),
                peak_utilization: UnitInterval::new(0.7).expect("utilization"),
                off_peak_utilization: UnitInterval::new(0.5).expect("utilization"),
            },
        ],
    }
}

#[test]
fn synthetic_demand_generation_is_reproducible_for_same_seed() {
    let first = generate_synthetic_cohort_demand(&synthetic_input(42))
        .expect("first result");

    let second = generate_synthetic_cohort_demand(&synthetic_input(42))
        .expect("second result");

    assert_eq!(first, second);
}

#[test]
fn synthetic_demand_generation_changes_with_a_different_seed() {
    let first = generate_synthetic_cohort_demand(&synthetic_input(42))
        .expect("first result");

    let second = generate_synthetic_cohort_demand(&synthetic_input(43))
        .expect("second result");

    assert_ne!(first.rows, second.rows);
}

#[test]
fn latency_window_meets_a_verified_95th_percentile_requirement() {
    let measurement = LatencyMeasurementWindow {
        window: window(0, 300),
        samples_milliseconds: vec![
            LatencyMilliseconds::new(NonNegativeF64::new(20.0).expect("latency")),
            LatencyMilliseconds::new(NonNegativeF64::new(25.0).expect("latency")),
            LatencyMilliseconds::new(NonNegativeF64::new(30.0).expect("latency")),
            LatencyMilliseconds::new(NonNegativeF64::new(35.0).expect("latency")),
            LatencyMilliseconds::new(NonNegativeF64::new(40.0).expect("latency")),
        ],
        evidence: EvidenceStatus::Verified,
    };

    let requirement = LatencyRequirement {
        maximum_latency: LatencyMilliseconds::new(
            NonNegativeF64::new(40.0).expect("maximum latency"),
        ),
        percentile: UnitInterval::new(0.95).expect("percentile"),
        minimum_sample_count: 5,
        required_evidence: EvidenceStatus::Verified,
    };

    let assessment = assess_latency_window(&measurement, requirement)
        .expect("latency assessment");

    assert!(assessment.available);
    assert_eq!(assessment.sample_count, 5);

    let capability = latency_measurement_to_capability_window(
        &measurement,
        requirement,
    )
    .expect("capability window");

    assert!(capability.available);
}

#[test]
fn latency_window_rejects_insufficient_evidence() {
    let measurement = LatencyMeasurementWindow {
        window: window(0, 300),
        samples_milliseconds: vec![
            LatencyMilliseconds::new(NonNegativeF64::new(10.0).expect("latency")),
            LatencyMilliseconds::new(NonNegativeF64::new(15.0).expect("latency")),
        ],
        evidence: EvidenceStatus::Assumed,
    };

    let requirement = LatencyRequirement {
        maximum_latency: LatencyMilliseconds::new(
            NonNegativeF64::new(50.0).expect("maximum latency"),
        ),
        percentile: UnitInterval::new(0.95).expect("percentile"),
        minimum_sample_count: 2,
        required_evidence: EvidenceStatus::Verified,
    };

    let assessment = assess_latency_window(&measurement, requirement)
        .expect("latency assessment");

    assert!(!assessment.available);
}
