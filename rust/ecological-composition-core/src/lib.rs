#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum AssuranceState {
    Exploratory,
    Preliminary,
    Calibrated,
    ValidatedAdvisory,
    CorridorGated,
    Qualified,
    Suspended,
    Expired,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CompositionDecision {
    ExploratoryOnly,
    AdvisoryOnly,
    CorridorGated,
    Indeterminate,
    Rejected,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum CompositionError {
    NonFiniteInput,
    InvalidDimension,
    InvalidDissipation,
    InvalidGain,
    InvalidMargin,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CompositionInputs<'a> {
    pub residuals: &'a [f64],
    pub dissipation: &'a [f64],
    pub gains: &'a [f64],
    pub model_states: &'a [AssuranceState],
    pub schemas_compatible: bool,
    pub purposes_compatible: bool,
    pub privacy_compatible: bool,
    pub all_inputs_in_domain: bool,
    pub hard_planes_compliant: bool,
    pub required_small_gain_margin: f64,
}

pub fn normalized_gain_row_sum_upper_bound(
    gains: &[f64],
    dissipation: &[f64],
    model_count: usize,
) -> Result<f64, CompositionError> {
    if model_count == 0
        || dissipation.len() != model_count
        || gains.len() != model_count * model_count
    {
        return Err(CompositionError::InvalidDimension);
    }

    let mut maximum_row_sum = 0.0_f64;

    for row in 0..model_count {
        let damping = dissipation[row];

        if !damping.is_finite() || damping <= 0.0 {
            return Err(CompositionError::InvalidDissipation);
        }

        let mut row_sum = 0.0_f64;

        for column in 0..model_count {
            let gain = gains[row * model_count + column];

            if !gain.is_finite() || gain < 0.0 {
                return Err(CompositionError::InvalidGain);
            }

            row_sum += gain / damping;
        }

        maximum_row_sum = maximum_row_sum.max(row_sum);
    }

    Ok(maximum_row_sum)
}

pub fn compose(
    input: CompositionInputs<'_>,
) -> Result<CompositionDecision, CompositionError> {
    let model_count = input.residuals.len();

    if model_count == 0
        || input.dissipation.len() != model_count
        || input.model_states.len() != model_count
    {
        return Err(CompositionError::InvalidDimension);
    }

    if !input.required_small_gain_margin.is_finite()
        || input.required_small_gain_margin <= 0.0
        || input.required_small_gain_margin >= 1.0
    {
        return Err(CompositionError::InvalidMargin);
    }

    if input.residuals.iter().any(|value| !value.is_finite() || *value < 0.0) {
        return Err(CompositionError::NonFiniteInput);
    }

    if !input.schemas_compatible
        || !input.purposes_compatible
        || !input.privacy_compatible
        || !input.all_inputs_in_domain
        || !input.hard_planes_compliant
    {
        return Ok(CompositionDecision::Rejected);
    }

    let gain_bound = normalized_gain_row_sum_upper_bound(
        input.gains,
        input.dissipation,
        model_count,
    )?;

    if gain_bound > 1.0 - input.required_small_gain_margin {
        return Ok(CompositionDecision::Indeterminate);
    }

    let weakest = input
        .model_states
        .iter()
        .copied()
        .min()
        .ok_or(CompositionError::InvalidDimension)?;

    let decision = match weakest {
        AssuranceState::CorridorGated => CompositionDecision::CorridorGated,
        AssuranceState::ValidatedAdvisory => CompositionDecision::AdvisoryOnly,
        AssuranceState::Exploratory
        | AssuranceState::Preliminary
        | AssuranceState::Calibrated => CompositionDecision::ExploratoryOnly,
        AssuranceState::Qualified
        | AssuranceState::Suspended
        | AssuranceState::Expired => CompositionDecision::Rejected,
    };

    Ok(decision)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unstable_gain_bound_is_indeterminate() {
        let result = compose(CompositionInputs {
            residuals: &[0.1, 0.1],
            dissipation: &[1.0, 1.0],
            gains: &[0.8, 0.3, 0.3, 0.8],
            model_states: &[
                AssuranceState::CorridorGated,
                AssuranceState::CorridorGated,
            ],
            schemas_compatible: true,
            purposes_compatible: true,
            privacy_compatible: true,
            all_inputs_in_domain: true,
            hard_planes_compliant: true,
            required_small_gain_margin: 0.1,
        })
        .expect("valid composition input");

        assert_eq!(result, CompositionDecision::Indeterminate);
    }

    #[test]
    fn preliminary_component_prevents_corridor_gated_composition() {
        let result = compose(CompositionInputs {
            residuals: &[0.1, 0.1],
            dissipation: &[1.0, 1.0],
            gains: &[0.1, 0.0, 0.0, 0.1],
            model_states: &[
                AssuranceState::CorridorGated,
                AssuranceState::Preliminary,
            ],
            schemas_compatible: true,
            purposes_compatible: true,
            privacy_compatible: true,
            all_inputs_in_domain: true,
            hard_planes_compliant: true,
            required_small_gain_margin: 0.1,
        })
        .expect("valid composition input");

        assert_eq!(result, CompositionDecision::ExploratoryOnly);
    }
}
