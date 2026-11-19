use alloc::string::String;
use alloc::vec::Vec;

use crate::bounds::{NonNegativeF64, UnitInterval};
use crate::error::PopmathError;
use crate::optimization::{
    ConstraintPriority, ConstraintRelation, DecisionVariable, LinearExpression,
    OptimizationConstraint, VariableDomain,
};

#[derive(Debug, Clone, PartialEq)]
pub struct DistrictContinuityInput {
    pub district_name: String,
    pub baseline_continuity: UnitInterval,
    pub continuity_gain_per_station: NonNegativeF64,
    pub maximum_station_count: u32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct DistrictEquityConstraintModel {
    pub decision_variables: Vec<DecisionVariable>,
    pub constraints: Vec<OptimizationConstraint>,
    pub explanation: String,
}

pub fn build_district_equity_constraint_model(
    districts: &[DistrictContinuityInput],
    maximum_continuity_gap: UnitInterval,
) -> Result<DistrictEquityConstraintModel, PopmathError> {
    if districts.len() < 2 {
        return Err(PopmathError::InvalidInput(
            "at least two districts are required for an equity-gap constraint",
        ));
    }

    let mut decision_variables = Vec::with_capacity(districts.len() + 2);
    let mut constraints = Vec::with_capacity((districts.len() * 2) + 1);

    let highest_continuity_variable =
        String::from("district_continuity_highest");

    let lowest_continuity_variable =
        String::from("district_continuity_lowest");

    decision_variables.push(DecisionVariable {
        name: highest_continuity_variable.clone(),
        domain: VariableDomain::Continuous {
            lower_bound: 0.0,
            upper_bound: 1.0,
        },
    });

    decision_variables.push(DecisionVariable {
        name: lowest_continuity_variable.clone(),
        domain: VariableDomain::Continuous {
            lower_bound: 0.0,
            upper_bound: 1.0,
        },
    });

    for district in districts {
        if district.district_name.trim().is_empty() {
            return Err(PopmathError::InvalidInput(
                "district name must be non-empty",
            ));
        }

        let station_variable = station_variable_name(&district.district_name);

        decision_variables.push(DecisionVariable {
            name: station_variable.clone(),
            domain: VariableDomain::Integer {
                lower_bound: 0,
                upper_bound: i64::from(district.maximum_station_count),
            },
        });

        let mut highest_expression = LinearExpression::zero();
        highest_expression.add_term(highest_continuity_variable.clone(), 1.0);
        highest_expression.add_term(
            station_variable.clone(),
            -district.continuity_gain_per_station.value(),
        );

        constraints.push(OptimizationConstraint {
            name: alloc::format!(
                "continuity_highest_bound__{}",
                normalize_name(&district.district_name)
            ),
            expression: highest_expression,
            relation: ConstraintRelation::GreaterThanOrEqual,
            right_hand_side: district.baseline_continuity.value(),
            priority: ConstraintPriority::Hard,
            explanation: alloc::format!(
                "The highest continuity auxiliary variable must be at least the projected continuity of district '{}'.",
                district.district_name
            ),
        });

        let mut lowest_expression = LinearExpression::zero();
        lowest_expression.add_term(lowest_continuity_variable.clone(), 1.0);
        lowest_expression.add_term(
            station_variable,
            -district.continuity_gain_per_station.value(),
        );

        constraints.push(OptimizationConstraint {
            name: alloc::format!(
                "continuity_lowest_bound__{}",
                normalize_name(&district.district_name)
            ),
            expression: lowest_expression,
            relation: ConstraintRelation::LessThanOrEqual,
            right_hand_side: district.baseline_continuity.value(),
            priority: ConstraintPriority::Hard,
            explanation: alloc::format!(
                "The lowest continuity auxiliary variable must be no greater than the projected continuity of district '{}'.",
                district.district_name
            ),
        });
    }

    let mut equity_gap_expression = LinearExpression::zero();
    equity_gap_expression.add_term(highest_continuity_variable, 1.0);
    equity_gap_expression.add_term(lowest_continuity_variable, -1.0);

    constraints.push(OptimizationConstraint {
        name: String::from("district_continuity_equity_gap"),
        expression: equity_gap_expression,
        relation: ConstraintRelation::LessThanOrEqual,
        right_hand_side: maximum_continuity_gap.value(),
        priority: ConstraintPriority::Hard,
        explanation: String::from(
            "The gap between the highest and lowest projected district continuity ratios must not exceed the declared maximum.",
        ),
    });

    Ok(DistrictEquityConstraintModel {
        decision_variables,
        constraints,
        explanation: String::from(
            "Solver-neutral district continuity equity constraint with bounded integer station-placement variables.",
        ),
    })
}

fn station_variable_name(district_name: &str) -> String {
    alloc::format!(
        "charging_station_count__{}",
        normalize_name(district_name)
    )
}

fn normalize_name(value: &str) -> String {
    value
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() {
                character.to_ascii_lowercase()
            } else {
                '_'
            }
        })
        .collect()
}
