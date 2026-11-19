use alloc::string::String;
use alloc::vec::Vec;

use crate::bounds::{NonNegativeF64, UnitInterval};
use crate::continuity::ContinuityAssessment;
use crate::error::PopmathError;
use crate::optimization::{
    ConstraintPriority, ConstraintRelation, DecisionVariable, LinearExpression,
    ObjectiveDirection, ObjectiveFunction, OptimizationConstraint, VariableDomain,
};

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct AreaSquareMeters {
    value: NonNegativeF64,
}

impl AreaSquareMeters {
    pub fn new(value: NonNegativeF64) -> Self {
        Self { value }
    }

    pub fn value(self) -> f64 {
        self.value.value()
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CurrencyPerSquareMeter {
    value: NonNegativeF64,
}

impl CurrencyPerSquareMeter {
    pub fn new(value: NonNegativeF64) -> Self {
        Self { value }
    }

    pub fn value(self) -> f64 {
        self.value.value()
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CubicMetersPerSquareMeter {
    value: NonNegativeF64,
}

impl CubicMetersPerSquareMeter {
    pub fn new(value: NonNegativeF64) -> Self {
        Self { value }
    }

    pub fn value(self) -> f64 {
        self.value.value()
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct HeatIslandReductionPerSquareMeter {
    value: NonNegativeF64,
}

impl HeatIslandReductionPerSquareMeter {
    pub fn new(value: NonNegativeF64) -> Self {
        Self { value }
    }

    pub fn value(self) -> f64 {
        self.value.value()
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct HeatIslandOptimizationInput {
    pub eligible_albedo_area: AreaSquareMeters,
    pub plantable_canopy_area: AreaSquareMeters,
    pub minimum_canopy_area: AreaSquareMeters,
    pub albedo_cost_per_square_meter: CurrencyPerSquareMeter,
    pub canopy_cost_per_square_meter: CurrencyPerSquareMeter,
    pub canopy_irrigation_m3_per_square_meter: CubicMetersPerSquareMeter,
    pub budget_limit: NonNegativeF64,
    pub seasonal_water_limit_m3: NonNegativeF64,
    pub albedo_heat_reduction_per_square_meter: HeatIslandReductionPerSquareMeter,
    pub canopy_heat_reduction_per_square_meter: HeatIslandReductionPerSquareMeter,
    pub irrigation_continuity: ContinuityAssessment,
    pub minimum_irrigation_continuity: UnitInterval,
    pub maximum_irrigation_gap_seconds: NonNegativeF64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct HeatIslandOptimizationModel {
    pub feasible: bool,
    pub decision_variables: Vec<DecisionVariable>,
    pub objective: ObjectiveFunction,
    pub constraints: Vec<OptimizationConstraint>,
    pub explanation: String,
}

pub fn build_heat_island_optimization_model(
    input: HeatIslandOptimizationInput,
) -> Result<HeatIslandOptimizationModel, PopmathError> {
    if input.minimum_canopy_area.value() > input.plantable_canopy_area.value() {
        return Err(PopmathError::InvalidInput(
            "minimum canopy area cannot exceed plantable canopy area",
        ));
    }

    let irrigation_available = input
        .irrigation_continuity
        .availability_ratio
        .value()
        >= input.minimum_irrigation_continuity.value()
        && input
            .irrigation_continuity
            .longest_gap_seconds
            .value()
            <= input.maximum_irrigation_gap_seconds.value();

    if !irrigation_available && input.minimum_canopy_area.value() > 0.0 {
        return Ok(HeatIslandOptimizationModel {
            feasible: false,
            decision_variables: Vec::new(),
            objective: ObjectiveFunction {
                direction: ObjectiveDirection::Maximize,
                expression: LinearExpression::zero(),
                explanation: String::from(
                    "Modeled heat-island reduction is not optimized because declared irrigation continuity is not satisfied.",
                ),
            },
            constraints: Vec::new(),
            explanation: String::from(
                "The requested canopy floor requires irrigation continuity that is not available in the declared scenario window.",
            ),
        });
    }

    let albedo_variable = String::from("high_albedo_area_square_meters");
    let canopy_variable = String::from("tree_canopy_area_square_meters");

    let decision_variables = vec![
        DecisionVariable {
            name: albedo_variable.clone(),
            domain: VariableDomain::Continuous {
                lower_bound: 0.0,
                upper_bound: input.eligible_albedo_area.value(),
            },
        },
        DecisionVariable {
            name: canopy_variable.clone(),
            domain: VariableDomain::Continuous {
                lower_bound: input.minimum_canopy_area.value(),
                upper_bound: input.plantable_canopy_area.value(),
            },
        },
    ];

    let mut objective_expression = LinearExpression::zero();
    objective_expression.add_term(
        albedo_variable.clone(),
        input.albedo_heat_reduction_per_square_meter.value(),
    );
    objective_expression.add_term(
        canopy_variable.clone(),
        input.canopy_heat_reduction_per_square_meter.value(),
    );

    let objective = ObjectiveFunction {
        direction: ObjectiveDirection::Maximize,
        expression: objective_expression,
        explanation: String::from(
            "Maximize modeled urban heat-island reduction through high-albedo surface area and tree canopy coverage.",
        ),
    };

    let mut budget_expression = LinearExpression::zero();
    budget_expression.add_term(
        albedo_variable.clone(),
        input.albedo_cost_per_square_meter.value(),
    );
    budget_expression.add_term(
        canopy_variable.clone(),
        input.canopy_cost_per_square_meter.value(),
    );

    let mut water_expression = LinearExpression::zero();
    water_expression.add_term(
        canopy_variable.clone(),
        input.canopy_irrigation_m3_per_square_meter.value(),
    );

    let constraints = vec![
        OptimizationConstraint {
            name: String::from("capital_budget"),
            expression: budget_expression,
            relation: ConstraintRelation::LessThanOrEqual,
            right_hand_side: input.budget_limit.value(),
            priority: ConstraintPriority::Hard,
            explanation: String::from(
                "Total high-albedo and canopy investment must remain within the declared capital budget.",
            ),
        },
        OptimizationConstraint {
            name: String::from("seasonal_irrigation_water"),
            expression: water_expression,
            relation: ConstraintRelation::LessThanOrEqual,
            right_hand_side: input.seasonal_water_limit_m3.value(),
            priority: ConstraintPriority::Hard,
            explanation: String::from(
                "Seasonal irrigation demand for new canopy must remain within declared water availability.",
            ),
        },
    ];

    Ok(HeatIslandOptimizationModel {
        feasible: true,
        decision_variables,
        objective,
        constraints,
        explanation: String::from(
            "Solver-neutral heat-island intervention model with budget, water, canopy-floor, and irrigation-continuity constraints.",
        ),
    })
}
