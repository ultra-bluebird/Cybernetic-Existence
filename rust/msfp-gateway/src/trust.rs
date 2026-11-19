#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AuthorizationState {
    Active,
    Revoked,
    Expired,
    IntegrityFailed,
    ConsentWithdrawn,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct TrustDecayPolicy {
    pub initial_confidence: f64,
    pub decay_rate_per_ms: f64,
    pub continue_threshold: f64,
}

impl TrustDecayPolicy {
    pub fn validate(self) -> bool {
        (0.0..=1.0).contains(&self.initial_confidence)
            && self.decay_rate_per_ms >= 0.0
            && (0.0..=1.0).contains(&self.continue_threshold)
    }

    pub fn confidence_at(
        self,
        elapsed_ms: u64,
        lease_expires_at_ms: u64,
        now_ms: u64,
        state: AuthorizationState,
    ) -> f64 {
        if !self.validate()
            || now_ms >= lease_expires_at_ms
            || state != AuthorizationState::Active
        {
            return 0.0;
        }

        let elapsed = elapsed_ms as f64;
        let value = self.initial_confidence
            * (-self.decay_rate_per_ms * elapsed).exp();

        value.clamp(0.0, 1.0)
    }

    pub fn session_may_continue(
        self,
        elapsed_ms: u64,
        lease_expires_at_ms: u64,
        now_ms: u64,
        state: AuthorizationState,
    ) -> bool {
        self.confidence_at(
            elapsed_ms,
            lease_expires_at_ms,
            now_ms,
            state,
        ) >= self.continue_threshold
    }

    pub fn half_life_ms(
        self,
    ) -> Option<f64> {
        if self.decay_rate_per_ms <= 0.0 {
            return None;
        }

        Some(std::f64::consts::LN_2 / self.decay_rate_per_ms)
    }
}
