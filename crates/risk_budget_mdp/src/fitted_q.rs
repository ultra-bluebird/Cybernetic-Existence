#[derive(Clone, Copy, Debug, PartialEq)]
pub struct FittedQConfig {
    pub max_iterations: usize,
    pub convergence_tolerance: f64,
    pub discount_factor: f64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FittedQIteration {
    pub config: FittedQConfig,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum FittedQError {
    InvalidIterationCount,
    InvalidTolerance,
    InvalidDiscountFactor,
    EmptyDataset,
    IncompleteEvidence,
}

impl FittedQConfig {
    pub fn new(
        max_iterations: usize,
        convergence_tolerance: f64,
        discount_factor: f64,
    ) -> Result<Self, FittedQError>;
}

impl FittedQIteration {
    pub fn new(config: FittedQConfig) -> Self;
}
