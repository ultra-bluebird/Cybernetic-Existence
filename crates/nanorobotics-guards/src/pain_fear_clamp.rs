use serde::{Deserialize, Serialize};

/// NociceptiveIndex: Normalized pain and fear indices [0.0, 1.0].
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct NociceptiveIndex {
    /// Pain index [0.0, 1.0].
    pub pain: f32,
    /// Fear index [0.0, 1.0].
    pub fear: f32,
}

/// ClampFactor: Output of the pain/fear clamp [0.0, 1.0].
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct ClampFactor(pub f32);

impl ClampFactor {
    /// Create a new clamp factor, clamped to [0.0, 1.0].
    pub fn new(value: f32) -> Self {
        Self(value.clamp(0.0, 1.0))
    }

    /// Get the raw clamp factor value.
    pub fn value(&self) -> f32 {
        self.0
    }

    /// Apply the clamp factor to an actuation value.
    pub fn apply(&self, actuation: f32) -> f32 {
        actuation * self.0
    }
}

/// PainFearClamp: Hardware-level monotone clamp for nociceptive indices.
pub struct PainFearClamp {
    /// Pain floor: below this, no clamping occurs.
    pain_floor: f32,
    /// Pain ceiling: at or above this, full clamping (factor = 0).
    pain_ceiling: f32,
    /// Fear floor: below this, no clamping occurs.
    fear_floor: f32,
    /// Fear ceiling: at or above this, full clamping (factor = 0).
    fear_ceiling: f32,
    /// Pain clamp slope: rate of clamping increase between floor and ceiling.
    pain_slope: f32,
    /// Fear clamp slope: rate of clamping increase between floor and ceiling.
    fear_slope: f32,
}

impl PainFearClamp {
    /// Create a new clamp with the given thresholds and slopes.
    pub fn new(
        pain_floor: f32,
        pain_ceiling: f32,
        fear_floor: f32,
        fear_ceiling: f32,
        pain_slope: f32,
        fear_slope: f32,
    ) -> Self {
        Self {
            pain_floor: pain_floor.clamp(0.0, 1.0),
            pain_ceiling: pain_ceiling.clamp(0.0, 1.0),
            fear_floor: fear_floor.clamp(0.0, 1.0),
            fear_ceiling: fear_ceiling.clamp(0.0, 1.0),
            pain_slope: pain_slope.max(0.0),
            fear_slope: fear_slope.max(0.0),
        }
    }

    /// Compute the clamp factor for given nociceptive indices.
    /// Monotone non-increasing: higher pain/fear => lower or equal clamp factor.
    pub fn compute(&self, indices: NociceptiveIndex) -> ClampFactor {
        let pain_factor = self.compute_single_factor(
            indices.pain,
            self.pain_floor,
            self.pain_ceiling,
            self.pain_slope,
        );
        let fear_factor = self.compute_single_factor(
            indices.fear,
            self.fear_floor,
            self.fear_ceiling,
            self.fear_slope,
        );
        // Combined factor: product ensures either high pain or high fear reduces actuation
        ClampFactor::new(pain_factor * fear_factor)
    }

    /// Compute clamp factor for a single index.
    fn compute_single_factor(
        &self,
        value: f32,
        floor: f32,
        ceiling: f32,
        slope: f32,
    ) -> f32 {
        if value <= floor {
            1.0
        } else if value >= ceiling {
            0.0
        } else {
            // Linear interpolation: factor decreases from 1.0 to 0.0
            let normalized = (value - floor) / (ceiling - floor);
            (1.0 - slope * normalized).clamp(0.0, 1.0)
        }
    }

    /// Verify monotonicity: for any increase in pain or fear, clamp factor does not increase.
    #[cfg(test)]
    pub fn verify_monotonicity(&self) -> bool {
        // Sample test points
        let test_values = [0.0, 0.25, 0.5, 0.75, 1.0];
        for &p1 in &test_values {
            for &p2 in &test_values {
                if p2 > p1 {
                    let c1 = self.compute(NociceptiveIndex { pain: p1, fear: 0.0 });
                    let c2 = self.compute(NociceptiveIndex { pain: p2, fear: 0.0 });
                    if c2.value() > c1.value() {
                        return false;
                    }
                }
            }
        }
        for &f1 in &test_values {
            for &f2 in &test_values {
                if f2 > f1 {
                    let c1 = self.compute(NociceptiveIndex { pain: 0.0, fear: f1 });
                    let c2 = self.compute(NociceptiveIndex { pain: 0.0, fear: f2 });
                    if c2.value() > c1.value() {
                        return false;
                    }
                }
            }
        }
        true
    }
}
