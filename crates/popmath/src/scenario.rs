use crate::error::{PopmathError, PopmathResult};
use crate::governance::{DataUsePolicy, Purpose};
use crate::provenance::ProvenanceRecord;
use crate::time::TimeWindow;

/// A structured input assumption.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Assumption {
    name: String,
    basis: String,
}

impl Assumption {
    /// Creates a named assumption with a documented basis.
    pub fn new(name: impl Into<String>, basis: impl Into<String>) -> PopmathResult<Self> {
        let name = name.into();
        let basis = basis.into();

        if name.trim().is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "assumption_name",
            });
        }
        if basis.trim().is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "assumption_basis",
            });
        }

        Ok(Self { name, basis })
    }

    /// Returns the assumption name.
    #[must_use]
    pub fn name(&self) -> &str {
        &self.name
    }

    /// Returns the assumption basis.
    #[must_use]
    pub fn basis(&self) -> &str {
        &self.basis
    }
}

/// Whether a constraint is a required condition or a disclosed tradeoff.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ConstraintKind {
    /// The condition must be met.
    Hard,
    /// The condition may be deviated from only with a disclosed result.
    Soft,
}

/// A named scenario condition.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Constraint {
    name: String,
    kind: ConstraintKind,
    explanation: String,
}

impl Constraint {
    /// Creates a named constraint.
    pub fn new(
        name: impl Into<String>,
        kind: ConstraintKind,
        explanation: impl Into<String>,
    ) -> PopmathResult<Self> {
        let name = name.into();
        let explanation = explanation.into();

        if name.trim().is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "constraint_name",
            });
        }
        if explanation.trim().is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "constraint_explanation",
            });
        }

        Ok(Self {
            name,
            kind,
            explanation,
        })
    }

    /// Returns the constraint name.
    #[must_use]
    pub fn name(&self) -> &str {
        &self.name
    }

    /// Returns the constraint kind.
    #[must_use]
    pub const fn kind(&self) -> ConstraintKind {
        self.kind
    }
}

/// Immutable scenario definition used by a calculation.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Scenario {
    name: String,
    description: String,
    purpose: Purpose,
    time_window: TimeWindow,
    provenance: ProvenanceRecord,
    policy: DataUsePolicy,
    assumptions: Vec<Assumption>,
    constraints: Vec<Constraint>,
}

impl Scenario {
    /// Creates an immutable scenario after validating source and policy status.
    pub fn new(
        name: impl Into<String>,
        description: impl Into<String>,
        purpose: Purpose,
        time_window: TimeWindow,
        provenance: ProvenanceRecord,
        policy: DataUsePolicy,
        assumptions: Vec<Assumption>,
        constraints: Vec<Constraint>,
    ) -> PopmathResult<Self> {
        let name = name.into();
        let description = description.into();

        if name.trim().is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "scenario_name",
            });
        }
        if description.trim().is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "scenario_description",
            });
        }

        provenance.authorize_calculation()?;
        policy.authorize()?;

        Ok(Self {
            name,
            description,
            purpose,
            time_window,
            provenance,
            policy,
            assumptions,
            constraints,
        })
    }

    /// Returns the scenario name.
    #[must_use]
    pub fn name(&self) -> &str {
        &self.name
    }

    /// Returns the scenario purpose.
    #[must_use]
    pub fn purpose(&self) -> &Purpose {
        &self.purpose
    }

    /// Returns the scenario time window.
    #[must_use]
    pub const fn time_window(&self) -> TimeWindow {
        self.time_window
    }

    /// Returns source provenance.
    #[must_use]
    pub fn provenance(&self) -> &ProvenanceRecord {
        &self.provenance
    }

    /// Returns policy metadata.
    #[must_use]
    pub fn policy(&self) -> &DataUsePolicy {
        &self.policy
    }

    /// Returns documented assumptions.
    #[must_use]
    pub fn assumptions(&self) -> &[Assumption] {
        &self.assumptions
    }

    /// Returns declared constraints.
    #[must_use]
    pub fn constraints(&self) -> &[Constraint] {
        &self.constraints
    }
}
