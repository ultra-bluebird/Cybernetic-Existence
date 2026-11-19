use core::fmt;

/// Standard result type returned by `popmath`.
pub type PopmathResult<T> = Result<T, PopmathError>;

/// Structured error categories for invalid data, math, policy, and scenarios.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum PopmathError {
    /// A value was not finite.
    NonFiniteValue {
        /// Field that failed validation.
        field: &'static str,
    },
    /// A value was below its permitted lower bound.
    NegativeValue {
        /// Field that failed validation.
        field: &'static str,
    },
    /// A value must be greater than zero.
    ZeroNotAllowed {
        /// Field that failed validation.
        field: &'static str,
    },
    /// A value was outside a bounded domain.
    OutOfRange {
        /// Field that failed validation.
        field: &'static str,
        /// Minimum permitted value.
        minimum: &'static str,
        /// Maximum permitted value.
        maximum: &'static str,
    },
    /// An interval has an invalid ordering.
    InvalidInterval {
        /// Field that failed validation.
        field: &'static str,
    },
    /// A time range is invalid.
    InvalidTimeWindow,
    /// An input lacks necessary source information.
    MissingProvenance {
        /// Required provenance component.
        field: &'static str,
    },
    /// The input has insufficient aggregation documentation.
    InsufficientAggregation,
    /// The input is quarantined and cannot run the requested model.
    QuarantinedAggregation,
    /// The input is not permitted for the declared purpose.
    DataUseNotAuthorizedForDeclaredPurpose,
    /// The requested use is prohibited by the scenario policy.
    ProhibitedUse,
    /// The scenario does not satisfy a required governance condition.
    GovernanceReviewRequired,
    /// A scenario is malformed.
    InvalidScenario {
        /// Field that failed validation.
        field: &'static str,
    },
    /// A calculation requires a matching currency.
    CurrencyMismatch,
    /// A model constraint set cannot be satisfied.
    InfeasibleConstraints {
        /// Plain-language explanation.
        reason: &'static str,
    },
    /// A calculation would divide by zero.
    DivisionByZero {
        /// Field that caused the invalid operation.
        field: &'static str,
    },
    /// A result cannot be represented safely.
    NumericalInstability {
        /// Calculation component with unstable output.
        component: &'static str,
    },
}

impl fmt::Display for PopmathError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::NonFiniteValue { field } => {
                write!(formatter, "{field} must be a finite number")
            }
            Self::NegativeValue { field } => {
                write!(formatter, "{field} must be non-negative")
            }
            Self::ZeroNotAllowed { field } => {
                write!(formatter, "{field} must be greater than zero")
            }
            Self::OutOfRange {
                field,
                minimum,
                maximum,
            } => {
                write!(formatter, "{field} must be between {minimum} and {maximum}")
            }
            Self::InvalidInterval { field } => {
                write!(formatter, "{field} has an invalid interval ordering")
            }
            Self::InvalidTimeWindow => {
                write!(formatter, "time window start must not occur after its end")
            }
            Self::MissingProvenance { field } => {
                write!(formatter, "required provenance field is missing: {field}")
            }
            Self::InsufficientAggregation => {
                write!(formatter, "input aggregation documentation is insufficient")
            }
            Self::QuarantinedAggregation => {
                write!(
                    formatter,
                    "input aggregation is unknown and is quarantined from scenario execution"
                )
            }
            Self::DataUseNotAuthorizedForDeclaredPurpose => {
                write!(
                    formatter,
                    "input data use is not authorized for the declared scenario purpose"
                )
            }
            Self::ProhibitedUse => {
                write!(formatter, "the declared scenario use is prohibited")
            }
            Self::GovernanceReviewRequired => {
                write!(formatter, "governance review is required before this calculation")
            }
            Self::InvalidScenario { field } => {
                write!(formatter, "scenario field is invalid: {field}")
            }
            Self::CurrencyMismatch => {
                write!(formatter, "currency values must use the same currency code")
            }
            Self::InfeasibleConstraints { reason } => {
                write!(formatter, "model constraints are infeasible: {reason}")
            }
            Self::DivisionByZero { field } => {
                write!(formatter, "{field} must not be zero")
            }
            Self::NumericalInstability { component } => {
                write!(formatter, "numerical instability in calculation component: {component}")
            }
        }
    }
}

#[cfg(feature = "std")]
impl std::error::Error for PopmathError {}
