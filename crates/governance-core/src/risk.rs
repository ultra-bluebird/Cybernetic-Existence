pub const GLOBAL_ROH_CEILING: f64 = 0.30;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RiskPlane {
    Biophysical,
    Cybernetic,
    Cognitive,
    Social,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RiskValue(f64);

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RiskAxes {
    pub biophysical: RiskValue,
    pub cybernetic: RiskValue,
    pub cognitive: RiskValue,
    pub social: RiskValue,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RiskBudget {
    pub biophysical_ceiling: RiskValue,
    pub cybernetic_ceiling: RiskValue,
    pub cognitive_ceiling: RiskValue,
    pub social_ceiling: RiskValue,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RiskError {
    NotFinite,
    Negative,
    AboveUnitInterval,
    AboveGlobalCeiling,
    AggregateAboveGlobalCeiling,
}
