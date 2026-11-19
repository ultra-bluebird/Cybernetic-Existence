use augmented_governance_core::{EvoMode, EvoModeScaling, ScalingError};

#[test]
fn valid_scaling_accepts_inclusive_bounds() {
    let scaling = EvoModeScaling::new(0.0, 0.5, 1.0).expect("valid scaling");

    assert_eq!(scaling.factor_for(EvoMode::Conservative), 0.0);
    assert_eq!(scaling.factor_for(EvoMode::Copilot), 0.5);
    assert_eq!(scaling.factor_for(EvoMode::Custom), 1.0);
}

#[test]
fn scaling_rejects_non_finite_factors() {
    let result = EvoModeScaling::new(f32::NAN, 0.5, 1.0);

    assert_eq!(result, Err(ScalingError::NonFiniteScale));
}

#[test]
fn scaling_rejects_out_of_range_factors() {
    let result = EvoModeScaling::new(0.5, 1.1, 0.8);

    assert_eq!(result, Err(ScalingError::ScaleOutsideInclusiveRange));
}
