use crate::bounds::{FiniteF64, NonNegativeF64};
use crate::error::{PopmathError, PopmathResult};

/// Domain of an optimization decision variable.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum VariableDomain {
    /// A binary decision.
    Binary,
    /// An integer decision.
    Integer,
    /// A real-valued decision.
    Continuous,
}

/// Direction of an optimization objective.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ObjectiveDirection {
    /// Minimize an objective.
    Minimize,
    /// Maximize an objective.
    Maximize,
}

/// Relation used by an optimization constraint.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ConstraintRelation {
    /// Left side must be less than or equal to right side.
    LessThanOrEqual,
    /// Left side must equal right side.
    Equal,
    /// Left side must be greater than or equal to right side.
    GreaterThanOrEqual,
}

/// Priority of an optimization constraint.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ConstraintPriority {
    /// Constraint may not be relaxed by a solver adapter.
    Hard,
    /// Constraint deviation must be recorded and explained.
    Soft,
}

/// Status returned by an optimization adapter.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SolverStatus {
    /// An optimum was established for the stated model and tolerance.
    Optimal,
    /// A feasible solution was found but optimality was not established.
    Feasible,
    /// Constraints are infeasible.
    Infeasible,
    /// Objective is unbounded.
    Unbounded,
    /// Configured solver time limit was reached.
    TimeLimitReached,
    /// Solver encountered numerical difficulty.
    NumericalFailure,
    /// No solver was selected or run.
    NotRun,
}

/// Status of uniqueness and alternative analysis.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AlternativeAnalysisStatus {
    /// Unique optimum is supported under the declared tolerance.
    ProvenUnique,
    /// Near-optimal alternatives were evaluated.
    MultipleNearOptima,
    /// Multiple exact optima were found.
    MultipleExactOptima,
    /// Alternative analysis is required but has not yet been completed.
    RequiredNotCompleted,
    /// Alternative analysis is not applicable to a closed-form calculation.
    NotApplicable,
    /// The solver did not provide enough information.
    UnknownDueToSolverLimit,
}

/// One declared decision variable.
#[derive(Clone, Debug, PartialEq)]
pub struct DecisionVariable {
    /// Human-readable variable name.
    pub name: String,
    /// Variable domain.
    pub domain: VariableDomain,
    /// Lower bound.
    pub lower_bound: FiniteF64,
    /// Optional upper bound.
    pub upper_bound: Option<FiniteF64>,
}

impl DecisionVariable {
    /// Validates a decision variable.
    pub fn validate(&self) -> PopmathResult<()> {
        if self.name.trim().is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "optimization_variable_name",
            });
        }

        if let Some(upper_bound) = self.upper_bound {
            if upper_bound.get() < self.lower_bound.get() {
                return Err(PopmathError::InvalidInterval {
                    field: "optimization_variable_bounds",
                });
            }
        }

        if self.domain == VariableDomain::Binary
            && (self.lower_bound.get() != 0.0
                || self.upper_bound.map(FiniteF64::get) != Some(1.0))
        {
            return Err(PopmathError::InvalidScenario {
                field: "binary_variable_bounds",
            });
        }

        Ok(())
    }
}

/// One coefficient in a linear expression.
#[derive(Clone, Debug, PartialEq)]
pub struct LinearTerm {
    /// Name of the associated decision variable.
    pub variable_name: String,
    /// Term coefficient.
    pub coefficient: FiniteF64,
}

/// A linear objective or constraint expression.
#[derive(Clone, Debug, PartialEq)]
pub struct LinearExpression {
    /// Terms in the expression.
    pub terms: Vec<LinearTerm>,
    /// Constant offset.
    pub constant: FiniteF64,
}

impl LinearExpression {
    /// Evaluates the expression for named variable assignments.
    pub fn evaluate(&self, assignments: &[VariableAssignment]) -> PopmathResult<f64> {
        let mut value = self.constant.get();

        for term in &self.terms {
            let assignment = assignments
                .iter()
                .find(|assignment| assignment.variable_name == term.variable_name)
                .ok_or(PopmathError::InvalidScenario {
                    field: "missing_variable_assignment",
                })?;

            value += term.coefficient.get() * assignment.value.get();
        }

        if !value.is_finite() {
            return Err(PopmathError::NumericalInstability {
                component: "linear_expression",
            });
        }

        Ok(value)
    }
}

/// One declared objective.
#[derive(Clone, Debug, PartialEq)]
pub struct ObjectiveFunction {
    /// Human-readable objective name.
    pub name: String,
    /// Objective direction.
    pub direction: ObjectiveDirection,
    /// Linear expression being optimized.
    pub expression: LinearExpression,
}

/// One linear optimization constraint.
#[derive(Clone, Debug, PartialEq)]
pub struct OptimizationConstraint {
    /// Human-readable constraint name.
    pub name: String,
    /// Left-side expression.
    pub expression: LinearExpression,
    /// Required relation.
    pub relation: ConstraintRelation,
    /// Right-side scalar value.
    pub right_hand_side: FiniteF64,
    /// Hard or soft constraint priority.
    pub priority: ConstraintPriority,
}

/// Solver-neutral optimization problem declaration.
#[derive(Clone, Debug, PartialEq)]
pub struct OptimizationProblem {
    /// Variables in the problem.
    pub variables: Vec<DecisionVariable>,
    /// Objective functions.
    pub objectives: Vec<ObjectiveFunction>,
    /// Constraints.
    pub constraints: Vec<OptimizationConstraint>,
}

impl OptimizationProblem {
    /// Validates a solver-neutral optimization problem.
    pub fn validate(&self) -> PopmathResult<()> {
        if self.variables.is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "optimization_variables",
            });
        }
        if self.objectives.is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "optimization_objectives",
            });
        }

        for variable in &self.variables {
            variable.validate()?;
        }

        for objective in &self.objectives {
            if objective.name.trim().is_empty() {
                return Err(PopmathError::InvalidScenario {
                    field: "optimization_objective_name",
                });
            }
        }

        for constraint in &self.constraints {
            if constraint.name.trim().is_empty() {
                return Err(PopmathError::InvalidScenario {
                    field: "optimization_constraint_name",
                });
            }
        }

        Ok(())
    }
}

/// One resolved variable value from a solver or hand-built candidate.
#[derive(Clone, Debug, PartialEq)]
pub struct VariableAssignment {
    /// Variable name.
    pub variable_name: String,
    /// Assigned value.
    pub value: FiniteF64,
}

/// Constraint evaluation result.
#[derive(Clone, Debug, PartialEq)]
pub struct ConstraintEvaluation {
    /// Constraint name.
    pub name: String,
    /// Whether the declared relation is satisfied.
    pub satisfied: bool,
    /// Signed difference between the evaluated left side and right side.
    pub residual: FiniteF64,
    /// Hard or soft priority.
    pub priority: ConstraintPriority,
}

/// Independent validation result for a candidate solution.
#[derive(Clone, Debug, PartialEq)]
pub struct SolutionValidation {
    /// Per-constraint evaluations.
    pub constraints: Vec<ConstraintEvaluation>,
    /// Whether every hard constraint is satisfied.
    pub hard_constraints_satisfied: bool,
}

/// Validates a candidate assignment against declared linear constraints.
pub fn validate_solution(
    problem: &OptimizationProblem,
    assignments: &[VariableAssignment],
    tolerance: NonNegativeF64,
) -> PopmathResult<SolutionValidation> {
    problem.validate()?;

    let mut evaluations = Vec::with_capacity(problem.constraints.len());
    let mut hard_constraints_satisfied = true;

    for constraint in &problem.constraints {
        let left = constraint.expression.evaluate(assignments)?;
        let residual = left - constraint.right_hand_side.get();
        let tolerance_value = tolerance.get();

        let satisfied = match constraint.relation {
            ConstraintRelation::LessThanOrEqual => residual <= tolerance_value,
            ConstraintRelation::Equal => residual.abs() <= tolerance_value,
            ConstraintRelation::GreaterThanOrEqual => residual >= -tolerance_value,
        };

        if constraint.priority == ConstraintPriority::Hard && !satisfied {
            hard_constraints_satisfied = false;
        }

        evaluations.push(ConstraintEvaluation {
            name: constraint.name.clone(),
            satisfied,
            residual: FiniteF64::new(residual, "constraint_residual")?,
            priority: constraint.priority,
        });
    }

    Ok(SolutionValidation {
        constraints: evaluations,
        hard_constraints_satisfied,
    })
}

/// Solver-neutral result container.
#[derive(Clone, Debug, PartialEq)]
pub struct OptimizationResult {
    /// Solver or execution status.
    pub solver_status: SolverStatus,
    /// Candidate assignments.
    pub assignments: Vec<VariableAssignment>,
    /// Objective values in declaration order.
    pub objective_values: Vec<FiniteF64>,
    /// Independent constraint validation.
    pub validation: SolutionValidation,
    /// Alternative and uniqueness analysis state.
    pub alternative_analysis: AlternativeAnalysisStatus,
    /// Explicit optimality gap if provided by a solver.
    pub optimality_gap: Option<NonNegativeF64>,
}

/// Builds a solver-neutral candidate result after independent validation.
pub fn build_candidate_result(
    problem: &OptimizationProblem,
    assignments: Vec<VariableAssignment>,
    solver_status: SolverStatus,
    alternative_analysis: AlternativeAnalysisStatus,
    optimality_gap: Option<NonNegativeF64>,
    tolerance: NonNegativeF64,
) -> PopmathResult<OptimizationResult> {
    let validation = validate_solution(problem, &assignments, tolerance)?;

    if !validation.hard_constraints_satisfied && solver_status != SolverStatus::Infeasible {
        return Err(PopmathError::InfeasibleConstraints {
            reason: "candidate violates one or more hard constraints",
        });
    }

    let mut objective_values = Vec::with_capacity(problem.objectives.len());
    for objective in &problem.objectives {
        objective_values.push(FiniteF64::new(
            objective.expression.evaluate(&assignments)?,
            "objective_value",
        )?);
    }

    Ok(OptimizationResult {
        solver_status,
        assignments,
        objective_values,
        validation,
        alternative_analysis,
        optimality_gap,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hard_constraints_are_independently_checked() {
        let binary = DecisionVariable {
            name: "assign_job".to_owned(),
            domain: VariableDomain::Binary,
            lower_bound: FiniteF64::new(0.0, "lower_bound").expect("valid"),
            upper_bound: Some(FiniteF64::new(1.0, "upper_bound").expect("valid")),
        };

        let problem = OptimizationProblem {
            variables: vec![binary],
            objectives: vec![ObjectiveFunction {
                name: "maximize_benefit".to_owned(),
                direction: ObjectiveDirection::Maximize,
                expression: LinearExpression {
                    terms: vec![LinearTerm {
                        variable_name: "assign_job".to_owned(),
                        coefficient: FiniteF64::new(10.0, "coefficient").expect("valid"),
                    }],
                    constant: FiniteF64::new(0.0, "constant").expect("valid"),
                },
            }],
            constraints: vec![OptimizationConstraint {
                name: "capacity".to_owned(),
                expression: LinearExpression {
                    terms: vec![LinearTerm {
                        variable_name: "assign_job".to_owned(),
                        coefficient: FiniteF64::new(1.0, "coefficient").expect("valid"),
                    }],
                    constant: FiniteF64::new(0.0, "constant").expect("valid"),
                },
                relation: ConstraintRelation::LessThanOrEqual,
                right_hand_side: FiniteF64::new(1.0, "right_hand_side").expect("valid"),
                priority: ConstraintPriority::Hard,
            }],
        };

        let result = build_candidate_result(
            &problem,
            vec![VariableAssignment {
                variable_name: "assign_job".to_owned(),
                value: FiniteF64::new(1.0, "assignment").expect("valid"),
            }],
            SolverStatus::Optimal,
            AlternativeAnalysisStatus::ProvenUnique,
            Some(NonNegativeF64::new(0.0, "optimality_gap").expect("valid")),
            NonNegativeF64::new(0.0, "tolerance").expect("valid"),
        )
        .expect("candidate is feasible");

        assert!(result.validation.hard_constraints_satisfied);
        assert_eq!(result.objective_values[0].get(), 10.0);
    }
}
