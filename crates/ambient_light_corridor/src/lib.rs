#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct CorridorWeights {
    pub light: f64,
    pub uv: f64,
    pub heat: f64,
    pub accessibility: f64,
    pub distance: f64,
    pub uncertainty: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct SegmentInput {
    pub segment_id: u64,
    pub duration_minutes: f64,
    pub distance_meters: f64,
    pub normalized_light: f64,
    pub normalized_uv: f64,
    pub shade_coverage: f64,
    pub protection_score: f64,
    pub heat_load: f64,
    pub accessibility_penalty: f64,
    pub data_quality: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CorridorClass {
    PreferredShade,
    Acceptable,
    ElevatedExposure,
    AvoidWhenFeasible,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct SegmentAssessment {
    pub segment_id: u64,
    pub cost: f64,
    pub exposure_component: f64,
    pub accessibility_component: f64,
    pub uncertainty_component: f64,
    pub class: CorridorClass,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CorridorError {
    NonFiniteInput,
    NegativeDuration,
    NegativeDistance,
    OutOfRangeUnitInterval,
    NegativeWeight,
    ZeroTotalWeight,
}

fn is_unit_interval(value: f64) -> bool {
    value.is_finite() && (0.0..=1.0).contains(&value)
}

fn is_non_negative_finite(value: f64) -> bool {
    value.is_finite() && value >= 0.0
}

impl CorridorWeights {
    pub fn validate(self) -> Result<(), CorridorError> {
        let values = [
            self.light,
            self.uv,
            self.heat,
            self.accessibility,
            self.distance,
            self.uncertainty,
        ];

        if values.iter().any(|value| !value.is_finite()) {
            return Err(CorridorError::NonFiniteInput);
        }

        if values.iter().any(|value| *value < 0.0) {
            return Err(CorridorError::NegativeWeight);
        }

        if values.iter().all(|value| *value == 0.0) {
            return Err(CorridorError::ZeroTotalWeight);
        }

        Ok(())
    }
}

impl SegmentInput {
    pub fn validate(self) -> Result<(), CorridorError> {
        if !is_non_negative_finite(self.duration_minutes) {
            return Err(CorridorError::NegativeDuration);
        }

        if !is_non_negative_finite(self.distance_meters) {
            return Err(CorridorError::NegativeDistance);
        }

        let normalized_values = [
            self.normalized_light,
            self.normalized_uv,
            self.shade_coverage,
            self.protection_score,
            self.heat_load,
            self.accessibility_penalty,
            self.data_quality,
        ];

        if normalized_values
            .iter()
            .any(|value| !value.is_finite())
        {
            return Err(CorridorError::NonFiniteInput);
        }

        if normalized_values
            .iter()
            .any(|value| !is_unit_interval(*value))
        {
            return Err(CorridorError::OutOfRangeUnitInterval);
        }

        Ok(())
    }
}

pub fn assess_segment(
    weights: CorridorWeights,
    segment: SegmentInput,
) -> Result<SegmentAssessment, CorridorError> {
    weights.validate()?;
    segment.validate()?;

    let direct_light = segment.normalized_light * (1.0 - segment.shade_coverage);
    let unprotected_uv = segment.normalized_uv * (1.0 - segment.protection_score);

    let exposure_component = segment.duration_minutes
        * ((weights.light * direct_light)
            + (weights.uv * unprotected_uv)
            + (weights.heat * segment.heat_load));

    let accessibility_component =
        weights.accessibility * segment.accessibility_penalty;

    let distance_component = weights.distance * segment.distance_meters;

    let uncertainty_component =
        weights.uncertainty * (1.0 - segment.data_quality);

    let cost = exposure_component
        + accessibility_component
        + distance_component
        + uncertainty_component;

    let class = if segment.accessibility_penalty >= 0.75
        || segment.data_quality <= 0.15
        || (direct_light >= 0.85 && segment.heat_load >= 0.80)
    {
        CorridorClass::AvoidWhenFeasible
    } else if direct_light >= 0.60
        || segment.normalized_uv >= 0.70
        || segment.heat_load >= 0.70
    {
        CorridorClass::ElevatedExposure
    } else if segment.shade_coverage >= 0.65
        && segment.heat_load <= 0.40
        && segment.accessibility_penalty <= 0.25
        && segment.data_quality >= 0.70
    {
        CorridorClass::PreferredShade
    } else {
        CorridorClass::Acceptable
    };

    Ok(SegmentAssessment {
        segment_id: segment.segment_id,
        cost,
        exposure_component,
        accessibility_component,
        uncertainty_component,
        class,
    })
}

pub fn assess_path(
    weights: CorridorWeights,
    segments: &[SegmentInput],
) -> Result<f64, CorridorError> {
    let mut total = 0.0;

    for segment in segments {
        total += assess_segment(weights, *segment)?.cost;
    }

    Ok(total)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shaded_accessible_segment_costs_less_than_exposed_segment() {
        let weights = CorridorWeights {
            light: 4.0,
            uv: 3.0,
            heat: 2.0,
            accessibility: 10.0,
            distance: 0.001,
            uncertainty: 2.0,
        };

        let shaded = SegmentInput {
            segment_id: 1,
            duration_minutes: 5.0,
            distance_meters: 300.0,
            normalized_light: 0.8,
            normalized_uv: 0.7,
            shade_coverage: 0.8,
            protection_score: 0.5,
            heat_load: 0.3,
            accessibility_penalty: 0.0,
            data_quality: 0.9,
        };

        let exposed = SegmentInput {
            segment_id: 2,
            shade_coverage: 0.0,
            heat_load: 0.8,
            ..shaded
        };

        let shaded_assessment = assess_segment(weights, shaded).unwrap();
        let exposed_assessment = assess_segment(weights, exposed).unwrap();

        assert!(shaded_assessment.cost < exposed_assessment.cost);
        assert_eq!(shaded_assessment.class, CorridorClass::PreferredShade);
        assert_eq!(
            exposed_assessment.class,
            CorridorClass::ElevatedExposure
        );
    }

    #[test]
    fn invalid_normalized_values_are_rejected() {
        let weights = CorridorWeights {
            light: 1.0,
            uv: 1.0,
            heat: 1.0,
            accessibility: 1.0,
            distance: 1.0,
            uncertainty: 1.0,
        };

        let segment = SegmentInput {
            segment_id: 1,
            duration_minutes: 1.0,
            distance_meters: 10.0,
            normalized_light: 1.2,
            normalized_uv: 0.5,
            shade_coverage: 0.5,
            protection_score: 0.5,
            heat_load: 0.5,
            accessibility_penalty: 0.5,
            data_quality: 0.5,
        };

        assert_eq!(
            assess_segment(weights, segment),
            Err(CorridorError::OutOfRangeUnitInterval)
        );
    }
}
