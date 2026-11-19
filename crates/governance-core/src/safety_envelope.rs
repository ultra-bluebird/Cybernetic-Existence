#[derive(Clone, Copy, Debug, PartialEq)]
pub struct SafetyEnvelope {
    pub roh_ceiling: RiskValue,
    pub thermal_delta_limit: f64,
    pub duty_fraction_limit: f64,
    pub pain_index_limit: f64,
    pub fear_index_minimum: f64,
    pub fear_index_maximum: f64,
    pub psych_continuity_minimum: f64,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SafetyEnvelopeState {
    WithinEnvelope,
    OutsideEnvelope,
    UnknownInput,
    ReviewRequired,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SafetyEnvelopeError {
    NotFinite,
    InvalidRange,
    RoHAboveGlobalCeiling,
    NonMonotoneTightening,
}

impl SafetyEnvelope {
    pub fn new(
        roh_ceiling: RiskValue,
        thermal_delta_limit: f64,
        duty_fraction_limit: f64,
        pain_index_limit: f64,
        fear_index_minimum: f64,
        fear_index_maximum: f64,
        psych_continuity_minimum: f64,
    ) -> Result<Self, SafetyEnvelopeError>;

    pub fn is_at_least_as_protective_as(
        self,
        previous: Self,
    ) -> Result<bool, SafetyEnvelopeError>;

    pub fn evaluate(
        self,
        observed: EnvelopeObservation,
    ) -> SafetyEnvelopeState;
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct EnvelopeObservation {
    pub roh: Option<RiskValue>,
    pub thermal_delta: Option<f64>,
    pub duty_fraction: Option<f64>,
    pub pain_index: Option<f64>,
    pub fear_index: Option<f64>,
    pub psych_continuity: Option<f64>,
}
