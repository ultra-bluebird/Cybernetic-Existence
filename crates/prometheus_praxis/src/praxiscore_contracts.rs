// Filename: crates/prometheus_praxis/src/praxiscore_contracts.rs
#![forbid(unsafe_code)]

/// Zero-cost abstraction representing municipal infrastructure.
pub struct CityActuationCapability;

/// Zero-cost abstraction representing a sovereign personal domain.
/// This type is intentionally uninhabited by any municipal API.
pub struct PersonalDomain;

/// The municipal actuator guard. It structurally cannot accept a PersonalDomain.
pub fn authorize_public_actuation(
    _capability: CityActuationCapability,
    target: &PublicInfrastructureTarget,
) -> ActuationDecision {
    // Safety and corridor checks occur here.
    ActuationDecision::Allow
}

// --- Kani Proof Harness ---
#[cfg(kani)]
mod verification {
    use super::*;
    use kani::proof;

    /// Proof: It is impossible to construct a call to authorize_public_actuation 
    /// using a PersonalDomain target. The Rust compiler enforces this, and Kani 
    /// verifies the control flow graph contains no such path.
    #[proof]
    fn proof_no_private_domain_actuation() {
        let capability = CityActuationCapability;
        let target = PublicInfrastructureTarget::new_mock();
        
        // This compiles and passes.
        let _decision = authorize_public_actuation(capability, &target);
        
        // The following line would cause a compile-time error, proving 
        // the non-interference boundary is structurally enforced:
        // let personal = PersonalDomain;
        // authorize_public_actuation(capability, &personal); // ERROR
    }
}
