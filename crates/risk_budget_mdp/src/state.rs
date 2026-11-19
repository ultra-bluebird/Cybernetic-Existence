use governance_core::{EvidenceState, RiskAxes, SafetyEnvelopeState};

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RealityState {
    pub risk_axes: RiskAxes,
    pub evidence_state: EvidenceState,
    pub envelope_state: SafetyEnvelopeState,
    pub thermal_delta: Option<f64>,
    pub duty_fraction: Option<f64>,
    pub confidence: f64,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum StateError {
    NotFinite,
    InvalidConfidence,
}

impl RealityState {
    pub fn new(
        risk_axes: RiskAxes,
        evidence_state: EvidenceState,
        envelope_state: SafetyEnvelopeState,
        thermal_delta: Option<f64>,
        duty_fraction: Option<f64>,
        confidence: f64,
    ) -> Result<Self, StateError>;

    pub fn has_required_model_inputs(self) -> bool;
}
