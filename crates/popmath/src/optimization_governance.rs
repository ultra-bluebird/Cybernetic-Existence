use alloc::string::String;
use alloc::vec::Vec;

use crate::bounds::UnitInterval;
use crate::governance::GovernanceAssessment;

#[derive(Debug, Clone, PartialEq)]
pub struct AggregateDistrictOutcome {
    pub district_name: String,
    pub baseline_continuity: UnitInterval,
    pub optimized_continuity: UnitInterval,
    pub planning_weight: UnitInterval,
    pub required_minimum_continuity: UnitInterval,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct OptimizationEquityThresholds {
    pub maximum_continuity_gap: UnitInterval,
    pub maximum_improvement_gap: UnitInterval,
}

#[derive(Debug, Clone, PartialEq)]
pub struct OptimizationGovernanceReview {
    pub assessment: GovernanceAssessment,
    pub continuity_gap: UnitInterval,
    pub improvement_gap: UnitInterval,
    pub review_reasons: Vec<String>,
}

pub fn assess_optimization_equity(
    outcomes: &[AggregateDistrictOutcome],
    thresholds: OptimizationEquityThresholds,
) -> OptimizationGovernanceReview {
    if outcomes.is_empty() {
        return OptimizationGovernanceReview {
            assessment: GovernanceAssessment::ReviewRequired,
            continuity_gap: UnitInterval::new(0.0)
                .expect("zero is a valid unit interval"),
            improvement_gap: UnitInterval::new(0.0)
                .expect("zero is a valid unit interval"),
            review_reasons: vec![String::from(
                "No aggregate district outcomes were supplied for optimization review.",
            )],
        };
    }

    let mut minimum_continuity = 1.0_f64;
    let mut maximum_continuity = 0.0_f64;
    let mut minimum_improvement = f64::INFINITY;
    let mut maximum_improvement = f64::NEG_INFINITY;
    let mut positive_improvement_exists = false;
    let mut review_reasons = Vec::new();

    for outcome in outcomes {
        let continuity = outcome.optimized_continuity.value();
        let improvement =
            outcome.optimized_continuity.value() - outcome.baseline_continuity.value();

        minimum_continuity = minimum_continuity.min(continuity);
        maximum_continuity = maximum_continuity.max(continuity);
        minimum_improvement = minimum_improvement.min(improvement);
        maximum_improvement = maximum_improvement.max(improvement);

        if improvement > 0.0 {
            positive_improvement_exists = true;
        }

        if continuity < outcome.required_minimum_continuity.value() {
            review_reasons.push(alloc::format!(
                "District '{}' remains below its declared minimum continuity ratio.",
                outcome.district_name
            ));
        }
    }

    let continuity_gap = (maximum_continuity - minimum_continuity).clamp(0.0, 1.0);
    let improvement_gap = (maximum_improvement - minimum_improvement).clamp(0.0, 1.0);

    if continuity_gap > thresholds.maximum_continuity_gap.value() {
        review_reasons.push(alloc::format!(
            "The projected continuity gap of {:.6} exceeds the declared maximum of {:.6}.",
            continuity_gap,
            thresholds.maximum_continuity_gap.value()
        ));
    }

    if improvement_gap > thresholds.maximum_improvement_gap.value() {
        review_reasons.push(alloc::format!(
            "The projected continuity-improvement gap of {:.6} exceeds the declared maximum of {:.6}.",
            improvement_gap,
            thresholds.maximum_improvement_gap.value()
        ));
    }

    if positive_improvement_exists {
        for outcome in outcomes {
            let improvement =
                outcome.optimized_continuity.value() - outcome.baseline_continuity.value();

            if outcome.planning_weight.value() > 0.0 && improvement <= 0.0 {
                review_reasons.push(alloc::format!(
                    "District '{}' has a positive planning weight but receives no continuity improvement while another district improves.",
                    outcome.district_name
                ));
            }
        }
    }

    let assessment = if review_reasons.is_empty() {
        GovernanceAssessment::Authorized
    } else {
        GovernanceAssessment::ReviewRequired
    };

    OptimizationGovernanceReview {
        assessment,
        continuity_gap: UnitInterval::new(continuity_gap)
            .expect("continuity gap is clamped to the unit interval"),
        improvement_gap: UnitInterval::new(improvement_gap)
            .expect("improvement gap is clamped to the unit interval"),
        review_reasons,
    }
}
