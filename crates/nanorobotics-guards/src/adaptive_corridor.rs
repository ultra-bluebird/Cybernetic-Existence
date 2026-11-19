// Path: crates/nanorobotics-guards/src/adaptive_corridor.rs

/// Adaptive thresholds over multiple biomarkers, all monotone-tightening.
#[derive(Clone, Debug)]
pub struct AdaptiveCorridorThresholds {
    pub hrv_sdnn_min: f32,
    pub hrv_sdnn_max: f32,
    pub il6_max: f32,
    pub core_temp_delta_max: f32,
    pub nanoswarm_duty_max: f32,
    // ... other axes
}

impl AdaptiveCorridorThresholds {
    /// Check that `self` is no looser than `baseline` (componentwise tightening).
    pub fn noworsethan(&self, baseline: &Self) -> bool {
        self.hrv_sdnn_min >= baseline.hrv_sdnn_min &&
        self.hrv_sdnn_max <= baseline.hrv_sdnn_max &&
        self.il6_max      <= baseline.il6_max &&
        self.core_temp_delta_max <= baseline.core_temp_delta_max &&
        self.nanoswarm_duty_max  <= baseline.nanoswarm_duty_max
        // ... extend for all axes
    }

    /// Merge multiple tightening proposals with a monotone-safe AND rule.
    pub fn merge_tightening(
        baseline: &Self,
        proposals: &[Self],
    ) -> Option<Self> {
        let mut merged = baseline.clone();

        for p in proposals {
            // Reject any non-tightening proposal.
            if !p.noworsethan(baseline) {
                return None;
            }

            merged.hrv_sdnn_min = merged.hrv_sdnn_min.max(p.hrv_sdnn_min);
            merged.hrv_sdnn_max = merged.hrv_sdnn_max.min(p.hrv_sdnn_max);
            merged.il6_max      = merged.il6_max.min(p.il6_max);
            merged.core_temp_delta_max =
                merged.core_temp_delta_max.min(p.core_temp_delta_max);
            merged.nanoswarm_duty_max =
                merged.nanoswarm_duty_max.min(p.nanoswarm_duty_max);
            // ... same pattern for all axes
        }

        Some(merged)
    }
}
