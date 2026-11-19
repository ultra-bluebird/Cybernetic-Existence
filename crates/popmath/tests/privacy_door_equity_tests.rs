use popmath::bounds::{NonNegativeF64, PositiveF64, UnitInterval};
use popmath::district_equity::{
    build_district_equity_constraint_model, DistrictContinuityInput,
};
use popmath::privacy_aggregate::{
    aggregate_release_to_service_demand, clip_energy_contribution,
    AggregateDemandInput, EnergyContributionBound, PrivacyBudgetEpsilon,
};
use popmath::simulation::RandomSeed;

#[test]
fn individual_energy_contribution_is_clipped_to_declared_bound() {
    let clipped = clip_energy_contribution(
        NonNegativeF64::new(9.0).expect("contribution"),
        EnergyContributionBound::new(
            NonNegativeF64::new(2.0).expect("bound"),
        ),
    );

    assert_eq!(clipped.value(), 2.0);
}

#[test]
fn aggregate_demand_requires_no_person_level_shape() {
    let input = AggregateDemandInput {
        seed: RandomSeed::new(42),
        epsilon: PrivacyBudgetEpsilon::new(
            PositiveF64::new(1.0).expect("epsilon"),
        ),
        contribution_bound: EnergyContributionBound::new(
            NonNegativeF64::new(2.0).expect("bound"),
        ),
    };

    assert_eq!(input.seed.value(), 42);
    assert_eq!(input.epsilon.value(), 1.0);
    assert_eq!(input.contribution_bound.value(), 2.0);
}

#[test]
fn district_equity_model_contains_station_and_gap_constraints() {
    let model = build_district_equity_constraint_model(
        &[
            DistrictContinuityInput {
                district_name: String::from("District A"),
                baseline_continuity: UnitInterval::new(0.82)
                    .expect("continuity"),
                continuity_gain_per_station: NonNegativeF64::new(0.03)
                    .expect("gain"),
                maximum_station_count: 12,
            },
            DistrictContinuityInput {
                district_name: String::from("District B"),
                baseline_continuity: UnitInterval::new(0.74)
                    .expect("continuity"),
                continuity_gain_per_station: NonNegativeF64::new(0.04)
                    .expect("gain"),
                maximum_station_count: 12,
            },
            DistrictContinuityInput {
                district_name: String::from("District C"),
                baseline_continuity: UnitInterval::new(0.77)
                    .expect("continuity"),
                continuity_gain_per_station: NonNegativeF64::new(0.02)
                    .expect("gain"),
                maximum_station_count: 12,
            },
        ],
        UnitInterval::new(0.08).expect("maximum gap"),
    )
    .expect("equity model");

    assert_eq!(model.decision_variables.len(), 5);
    assert_eq!(model.constraints.len(), 7);

    assert!(
        model
            .constraints
            .iter()
            .any(|constraint| constraint.name == "district_continuity_equity_gap")
    );
}
