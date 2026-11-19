#![forbid(unsafe_code)]

/// Low-dimensional principal component shape model for an organ.
#[derive(Clone, Debug, PartialEq)]
pub struct OrganShapeModel {
    /// Number of PCA modes represented.
    pub modes: u8,
    /// Eigenvalues per mode (variance explained).
    pub eigenvalues: Vec<f32>,
    /// Cumulative variance explained in [0,1].
    pub cumulative_variance: f32,
}

/// Host-specific projection of an organ shape into PCA space.
#[derive(Clone, Debug, PartialEq)]
pub struct OrganShapeInstance {
    pub organ_id: super::OrganId,
    /// Coefficients along PCA modes; length <= OrganShapeModel::modes.
    pub coefficients: Vec<f32>,
}

impl OrganShapeInstance {
    /// Conservative check: no NaNs, finite coefficients.
    pub fn validate(&self, model: &OrganShapeModel) -> bool {
        if self.coefficients.len() > model.modes as usize {
            return false;
        }
        self.coefficients.iter().all(|c| c.is_finite())
    }
}

/// Topological summary for an organ (TDA-inspired but simplified).
#[derive(Clone, Debug, PartialEq)]
pub struct OrganTopologySummary {
    /// Connected component count at conservative scale (0D feature).
    pub components_0d: u16,
    /// Count of 1D loops/tunnels detected (1D feature).
    pub loops_1d: u16,
    /// Count of 2D voids/cavities (2D feature).
    pub cavities_2d: u16,
}

impl OrganTopologySummary {
    /// Simple clogging proxy: higher when there are fewer components and more cavities.
    pub fn clogging_score(&self) -> f32 {
        let c0 = if self.components_0d == 0 {
            1.0_f32
        } else {
            self.components_0d as f32
        };
        (self.cavities_2d as f32 + self.loops_1d as f32 + 1.0_f32) / c0
    }
}
