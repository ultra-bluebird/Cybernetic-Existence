// crates/neuroxr-pipeline/src/types.rs
use limbic_taint_core::LimbicInfluenceScore;

#[derive(Clone, Debug)]
pub struct SensoryOutput {
    pub payload: SensoryPayload,
    pub limbic_influence: LimbicInfluenceScore,
}
