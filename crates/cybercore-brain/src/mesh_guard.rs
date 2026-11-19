// crates/cybercore-brain/src/mesh_guard.rs
use limbic_taint_core::LimbicInfluenceScore;

pub fn enforce_limbic_block(
    mesh_blocks: &[String],
    out: &SensoryOutput,
) -> Result<(), MeshGuardError> {
    let blocks_affective = mesh_blocks.iter().any(|b| {
        b.eq_ignore_ascii_case("AFFECTIVE_STEERING") ||
        b.eq_ignore_ascii_case("COERCIVE_REINFORCEMENT")
    });

    if blocks_affective && !out.limbic_influence.is_zero() {
        return Err(MeshGuardError::LimbicInfluenceBlocked);
    }

    Ok(())
}
