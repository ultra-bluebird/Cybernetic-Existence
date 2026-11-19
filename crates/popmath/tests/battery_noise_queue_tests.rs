use popmath::battery_degradation::{
    calculate_battery_degradation, BatteryDegradationInput,
};
use popmath::bounds::{NonNegativeF64, PositiveF64, UnitInterval};
use popmath::continuity::EvidenceStatus;
use popmath::noise::{
    interpolate_corridor_noise, noise_measurement_to_capability_window,
    AWeightedDecibels, CorridorNoisePoint, CorridorPositionMeters,
    NoiseMeasurementWindow, NoiseRequirement,
};
use popmath::queues::{
    calculate_two_class_queue_service_level,
    TwoClassQueueServiceLevelInput,
};
use popmath::time::{TimeWindow, UtcTimestamp};
use popmath::units::EnergyKwh;

fn timestamp(seconds: i64) -> UtcTimestamp {
    UtcTimestamp::new(seconds).expect("timestamp")
}

fn window(start: i64, end: i64) -> TimeWindow {
    TimeWindow::new(timestamp(start), timestamp(end)).expect("window")
}

#[test]
fn five_year_battery_curve_declines_monotonically() {
    let mut previous_capacity = f64::INFINITY;

    for year in 0..=5 {
        let result = calculate_battery_degradation(
            BatteryDegradationInput {
                nominal_capacity_kwh: EnergyKwh::new(
                    NonNegativeF64::new(10.0).expect("capacity"),
                ),
                cycle_count: NonNegativeF64::new(f64::from(year) * 300.0)
                    .expect("cycles"),
                depth_of_discharge: UnitInterval::new(0.80)
                    .expect("depth"),
                reference_depth_of_discharge: UnitInterval::new(0.80)
                    .expect("reference depth"),
                cycle_fade_per_reference_cycle: UnitInterval::new(0.00005)
                    .expect("cycle fade"),
                depth_of_discharge_exponent: NonNegativeF64::new(1.3)
                    .expect("exponent"),
                calendar_years: NonNegativeF64::new(f64::from(year))
                    .expect("years"),
                calendar_fade_per_year: UnitInterval::new(0.01)
                    .expect("calendar fade"),
                capacity_floor: UnitInterval::new(0.60)
                    .expect("capacity floor"),
            },
        )
        .expect("battery degradation result");

        let capacity = result.available_capacity_kwh.value().value();

        assert!(capacity <= previous_capacity);
        assert!(capacity >= 6.0);

        previous_capacity = capacity;
    }
}

#[test]
fn hourly_noise_measurement_maps_to_low_noise_capability() {
    let requirement = NoiseRequirement {
        maximum_laeq_one_hour: AWeightedDecibels::new(
            NonNegativeF64::new(45.0).expect("threshold"),
        ),
        minimum_confidence: UnitInterval::new(0.90).expect("confidence"),
        required_evidence: EvidenceStatus::Verified,
    };

    let measurement = NoiseMeasurementWindow {
        window: window(0, 3600),
        laeq_one_hour: AWeightedDecibels::new(
            NonNegativeF64::new(44.0).expect("noise"),
        ),
        confidence: UnitInterval::new(0.95).expect("confidence"),
        evidence: EvidenceStatus::Verified,
    };

    let capability = noise_measurement_to_capability_window(
        measurement,
        requirement,
    );

    assert!(capability.available);
}

#[test]
fn corridor_noise_interpolation_uses_energy_domain() {
    let interpolated = interpolate_corridor_noise(
        CorridorNoisePoint {
            position: CorridorPositionMeters::new(
                NonNegativeF64::new(0.0).expect("position"),
            ),
            laeq_one_hour: AWeightedDecibels::new(
                NonNegativeF64::new(40.0).expect("noise"),
            ),
        },
        CorridorNoisePoint {
            position: CorridorPositionMeters::new(
                NonNegativeF64::new(100.0).expect("position"),
            ),
            laeq_one_hour: AWeightedDecibels::new(
                NonNegativeF64::new(50.0).expect("noise"),
            ),
        },
        CorridorPositionMeters::new(
            NonNegativeF64::new(50.0).expect("position"),
        ),
    )
    .expect("interpolation");

    assert!(interpolated.value() > 47.0);
    assert!(interpolated.value() < 48.0);
}

#[test]
fn two_class_queue_reports_service_continuity_for_extended_class() {
    let result = calculate_two_class_queue_service_level(
        TwoClassQueueServiceLevelInput {
            standard_arrival_rate_per_hour: NonNegativeF64::new(8.0)
                .expect("arrival"),
            extended_arrival_rate_per_hour: NonNegativeF64::new(2.0)
                .expect("arrival"),
            standard_service_rate_per_hour: PositiveF64::new(12.0)
                .expect("service"),
            extended_service_rate_per_hour: PositiveF64::new(4.0)
                .expect("service"),
            channel_count: 2,
            maximum_extended_total_time_hours: NonNegativeF64::new(0.50)
                .expect("time threshold"),
        },
    )
    .expect("queue result");

    assert!(result.stable);
    assert!(result.utilization.value() < 1.0);
    assert!(result.expected_extended_total_time_hours.value() > 0.0);
}
