// crates/limbic-taint-core/src/lib.rs
#![forbid(unsafe_code)]

#[derive(Clone, Debug)]
pub struct LimbicInfluenceScore {
    /// Scalar in [0,1] quantifying estimated limbic modulation.
    pub score: f32,
    /// Optional provenance tags (e.g., derived from fear/pain tags, limbic telemetry).
    pub sources: &'static [&'static str],
}

impl LimbicInfluenceScore {
    pub fn none() -> Self {
        Self { score: 0.0, sources: &[] }
    }

    pub fn is_zero(&self) -> bool {
        self.score <= 0.0
    }
}
