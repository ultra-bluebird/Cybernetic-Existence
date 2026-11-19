pub struct MissionTickResult {
    pub allowed: bool,
    pub violation: Option<GuardViolation>,
    pub tsafe: TsafeVec,
    pub governance: GovernanceVector,
}

pub fn guard_twin_step(
    prev_twin: &TwinState,
    next_twin: &TwinState,
    tsafe_poly: &TsafePolytope,
    prev_lyap: f32,
    next_lyap: f32,
) -> MissionTickResult {
    let tsafe = project_twin_to_tsafe(next_twin);
    let governance = project_tsafe_to_governance(&tsafe);

    match UnifiedTwinGuard::evaluate_step(&tsafe, &governance, tsafe_poly, prev_lyap, next_lyap) {
        Ok(()) => MissionTickResult {
            allowed: true,
            violation: None,
            tsafe,
            governance,
        },
        Err(err) => MissionTickResult {
            allowed: false,
            violation: Some(err),
            tsafe,
            governance,
        },
    }
}
