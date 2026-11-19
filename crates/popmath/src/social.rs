use crate::bounds::UnitInterval;
use crate::error::PopmathError;

const WEIGHT_SUM_TOLERANCE: f64 = 1.0e-12;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct SocialAcceptanceInput {
    pub inclusive_policy_coverage: UnitInterval,
    pub inclusive_infrastructure_coverage: UnitInterval,
    pub voluntary_participation_coverage: UnitInterval,
    pub accessible_remedy_coverage: UnitInterval,
    pub policy_weight: UnitInterval,
    pub infrastructure_weight: UnitInterval,
    pub participation_weight: UnitInterval,
    pub remedy_weight: UnitInterval,
    pub minimum_policy_coverage: UnitInterval,
    pub minimum_infrastructure_coverage: UnitInterval,
    pub minimum_remedy_coverage: UnitInterval,
}

impl SocialAcceptanceInput {
    pub fn weight_sum(self) -> f64 {
        self.policy_weight.value()
            + self.infrastructure_weight.value()
            + self.participation_weight.value()
            + self.remedy_weight.value()
    }

    pub fn weights_sum_to_one(self) -> bool {
        (self.weight_sum() - 1.0).abs() <= WEIGHT_SUM_TOLERANCE
    }

    pub fn floor_conditions_met(self) -> bool {
        self.inclusive_policy_coverage.value() >= self.minimum_policy_coverage.value()
            && self.inclusive_infrastructure_coverage.value()
                >= self.minimum_infrastructure_coverage.value()
            && self.accessible_remedy_coverage.value()
                >= self.minimum_remedy_coverage.value()
    }

    pub fn weighted_score(self) -> f64 {
        self.inclusive_policy_coverage.value() * self.policy_weight.value()
            + self.inclusive_infrastructure_coverage.value()
                * self.infrastructure_weight.value()
            + self.voluntary_participation_coverage.value()
                * self.participation_weight.value()
            + self.accessible_remedy_coverage.value() * self.remedy_weight.value()
    }

    pub fn validate(self) -> Result<(), PopmathError> {
        if !self.weights_sum_to_one() {
            return Err(PopmathError::InvalidInput(
                "social acceptance weights must sum to one within tolerance",
            ));
        }

        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct SocialAcceptanceComponents {
    pub policy_component: UnitInterval,
    pub infrastructure_component: UnitInterval,
    pub participation_component: UnitInterval,
    pub remedy_component: UnitInterval,
    pub weighted_score: UnitInterval,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct SocialAcceptanceResult {
    pub social_acceptance_factor: UnitInterval,
    pub floor_conditions_met: bool,
    pub components: SocialAcceptanceComponents,
}

pub fn calculate_social_acceptance(
    input: SocialAcceptanceInput,
) -> Result<SocialAcceptanceResult, PopmathError> {
    input.validate()?;

    let policy_component =
        UnitInterval::new(input.inclusive_policy_coverage.value() * input.policy_weight.value())?;

    let infrastructure_component = UnitInterval::new(
        input.inclusive_infrastructure_coverage.value() * input.infrastructure_weight.value(),
    )?;

    let participation_component = UnitInterval::new(
        input.voluntary_participation_coverage.value() * input.participation_weight.value(),
    )?;

    let remedy_component =
        UnitInterval::new(input.accessible_remedy_coverage.value() * input.remedy_weight.value())?;

    let weighted_score = UnitInterval::new(input.weighted_score())?;
    let floor_conditions_met = input.floor_conditions_met();

    let social_acceptance_factor = if floor_conditions_met {
        weighted_score
    } else {
        UnitInterval::new(0.0)?
    };

    Ok(SocialAcceptanceResult {
        social_acceptance_factor,
        floor_conditions_met,
        components: SocialAcceptanceComponents {
            policy_component,
            infrastructure_component,
            participation_component,
            remedy_component,
            weighted_score,
        },
    })
}
