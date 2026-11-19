#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AnomalyDecision {
    Allow,
    RejectFrame,
    RejectAndTerminate,
    Abstain,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ProtocolViolations {
    pub schema_violation: f64,
    pub size_violation: f64,
    pub replay_violation: f64,
    pub version_violation: f64,
    pub canonical_violation: f64,
    pub duplicate_key_violation: f64,
    pub unknown_field_violation: f64,
    pub lease_violation: f64,
    pub capability_violation: f64,
    pub rate_violation: f64,
    pub authentication_failed: bool,
}

impl ProtocolViolations {
    pub fn normalized(self) -> Self {
        Self {
            schema_violation: clamp01(self.schema_violation),
            size_violation: clamp01(self.size_violation),
            replay_violation: clamp01(self.replay_violation),
            version_violation: clamp01(self.version_violation),
            canonical_violation: clamp01(self.canonical_violation),
            duplicate_key_violation: clamp01(self.duplicate_key_violation),
            unknown_field_violation: clamp01(self.unknown_field_violation),
            lease_violation: clamp01(self.lease_violation),
            capability_violation: clamp01(self.capability_violation),
            rate_violation: clamp01(self.rate_violation),
            authentication_failed: self.authentication_failed,
        }
    }

    pub fn has_hard_fault(self) -> bool {
        self.authentication_failed
            || self.replay_violation > 0.0
            || self.lease_violation > 0.0
            || self.capability_violation > 0.0
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct AnomalyWeights {
    pub schema: f64,
    pub size: f64,
    pub replay: f64,
    pub version: f64,
    pub canonical: f64,
    pub duplicate_key: f64,
    pub unknown_field: f64,
    pub lease: f64,
    pub capability: f64,
    pub rate: f64,
}

impl AnomalyWeights {
    pub fn validate(self) -> bool {
        let values = [
            self.schema,
            self.size,
            self.replay,
            self.version,
            self.canonical,
            self.duplicate_key,
            self.unknown_field,
            self.lease,
            self.capability,
            self.rate,
        ];

        values.iter().all(|weight| *weight >= 0.0)
            && (values.iter().sum::<f64>() - 1.0).abs() <= 1e-9
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct AnomalyPolicy {
    pub weights: AnomalyWeights,
    pub reject_threshold: f64,
    pub abstain_threshold: f64,
}

impl AnomalyPolicy {
    pub fn validate(self) -> bool {
        self.weights.validate()
            && (0.0..=1.0).contains(&self.abstain_threshold)
            && (0.0..=1.0).contains(&self.reject_threshold)
            && self.abstain_threshold <= self.reject_threshold
    }

    pub fn score(
        self,
        violations: ProtocolViolations,
    ) -> Option<f64> {
        if !self.validate() {
            return None;
        }

        let violations = violations.normalized();

        Some(
            self.weights.schema * violations.schema_violation
                + self.weights.size * violations.size_violation
                + self.weights.replay * violations.replay_violation
                + self.weights.version * violations.version_violation
                + self.weights.canonical * violations.canonical_violation
                + self.weights.duplicate_key * violations.duplicate_key_violation
                + self.weights.unknown_field * violations.unknown_field_violation
                + self.weights.lease * violations.lease_violation
                + self.weights.capability * violations.capability_violation
                + self.weights.rate * violations.rate_violation,
        )
    }

    pub fn decide(
        self,
        violations: ProtocolViolations,
    ) -> AnomalyDecision {
        if violations.has_hard_fault() {
            return AnomalyDecision::RejectAndTerminate;
        }

        let Some(score) = self.score(violations) else {
            return AnomalyDecision::Abstain;
        };

        if score >= self.reject_threshold {
            AnomalyDecision::RejectFrame
        } else if score >= self.abstain_threshold {
            AnomalyDecision::Abstain
        } else {
            AnomalyDecision::Allow
        }
    }
}

fn clamp01(value: f64) -> f64 {
    value.clamp(0.0, 1.0)
}
