#[derive(Clone, Copy, Debug, PartialEq)]
pub enum CflError {
    NonFiniteInput,
    NonPositiveSpacing,
    NonPositiveTimeStep,
    NegativeDepth,
    NonPositiveGravity,
    InvalidCflLimit,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct CellState {
    pub depth_m: f64,
    pub discharge_m3_s: f64,
    pub area_m2: f64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct CflInputs {
    pub delta_x_m: f64,
    pub delta_t_s: f64,
    pub gravity_m_s2: f64,
    pub cfl_limit: f64,
}

pub fn characteristic_speed(
    state: CellState,
    gravity_m_s2: f64,
) -> Result<f64, CflError> {
    if !state.depth_m.is_finite()
        || !state.discharge_m3_s.is_finite()
        || !state.area_m2.is_finite()
        || !gravity_m_s2.is_finite()
    {
        return Err(CflError::NonFiniteInput);
    }

    if state.depth_m < 0.0 {
        return Err(CflError::NegativeDepth);
    }

    if state.area_m2 <= 0.0 || gravity_m_s2 <= 0.0 {
        return Err(CflError::NonPositiveGravity);
    }

    let velocity_m_s = state.discharge_m3_s / state.area_m2;
    let celerity_m_s = (gravity_m_s2 * state.depth_m).sqrt();
    let speed_m_s = velocity_m_s.abs() + celerity_m_s;

    if !speed_m_s.is_finite() {
        return Err(CflError::NonFiniteInput);
    }

    Ok(speed_m_s)
}

pub fn cfl_is_satisfied(
    states: &[CellState],
    inputs: CflInputs,
) -> Result<bool, CflError> {
    if !inputs.delta_x_m.is_finite()
        || !inputs.delta_t_s.is_finite()
        || !inputs.gravity_m_s2.is_finite()
        || !inputs.cfl_limit.is_finite()
    {
        return Err(CflError::NonFiniteInput);
    }

    if inputs.delta_x_m <= 0.0 {
        return Err(CflError::NonPositiveSpacing);
    }

    if inputs.delta_t_s <= 0.0 {
        return Err(CflError::NonPositiveTimeStep);
    }

    if inputs.gravity_m_s2 <= 0.0 {
        return Err(CflError::NonPositiveGravity);
    }

    if !(0.0 < inputs.cfl_limit && inputs.cfl_limit <= 1.0) {
        return Err(CflError::InvalidCflLimit);
    }

    let mut max_speed_m_s = 0.0_f64;

    for state in states {
        max_speed_m_s = max_speed_m_s.max(characteristic_speed(
            *state,
            inputs.gravity_m_s2,
        )?);
    }

    if max_speed_m_s == 0.0 {
        return Ok(true);
    }

    let courant =
        max_speed_m_s * inputs.delta_t_s / inputs.delta_x_m;

    Ok(courant <= inputs.cfl_limit)
}

#[cfg(kani)]
mod proofs {
    use super::*;

    fn bounded_nonnegative() -> f64 {
        let value: f64 = kani::any();
        kani::assume(value.is_finite());
        kani::assume(value >= 0.0);
        kani::assume(value <= 1_000_000.0);
        value
    }

    fn bounded_positive() -> f64 {
        let value: f64 = kani::any();
        kani::assume(value.is_finite());
        kani::assume(value > 0.0);
        kani::assume(value <= 1_000_000.0);
        value
    }

    #[kani::proof]
    fn characteristic_speed_is_finite_for_bounded_valid_inputs() {
        let state = CellState {
            depth_m: bounded_nonnegative(),
            discharge_m3_s: bounded_nonnegative(),
            area_m2: bounded_positive(),
        };

        let gravity = bounded_positive();

        let speed = characteristic_speed(state, gravity).unwrap();

        assert!(speed.is_finite());
        assert!(!speed.is_nan());
        assert!(speed >= 0.0);
    }

    #[kani::proof]
    fn accepted_cfl_step_respects_declared_limit() {
        let states = [
            CellState {
                depth_m: bounded_nonnegative(),
                discharge_m3_s: bounded_nonnegative(),
                area_m2: bounded_positive(),
            },
            CellState {
                depth_m: bounded_nonnegative(),
                discharge_m3_s: bounded_nonnegative(),
                area_m2: bounded_positive(),
            },
        ];

        let inputs = CflInputs {
            delta_x_m: bounded_positive(),
            delta_t_s: bounded_positive(),
            gravity_m_s2: bounded_positive(),
            cfl_limit: 0.9,
        };

        let accepted = cfl_is_satisfied(&states, inputs).unwrap();

        if accepted {
            let mut max_speed = 0.0_f64;
            for state in states {
                max_speed = max_speed.max(
                    characteristic_speed(state, inputs.gravity_m_s2).unwrap(),
                );
            }

            if max_speed > 0.0 {
                let courant =
                    max_speed * inputs.delta_t_s / inputs.delta_x_m;

                assert!(courant <= inputs.cfl_limit);
            }
        }
    }
}
