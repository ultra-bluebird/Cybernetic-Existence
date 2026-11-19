#![forbid(unsafe_code)]
#![deny(clippy::all)]
#![deny(clippy::pedantic)]

pub mod lipschitz;
pub mod hrv_leak_guard;
pub mod roh_free_energy;

pub use lipschitz::{
    BciDecoderConfig,
    DecoderLipschitzEnvelope,
    MotorIntentBox,
    BciDecoderLipschitzGuardVerdict,
    estimate_lipschitz_constant,
    check_lipschitz_bound,
};
pub use hrv_leak_guard::{
    HrvLeakageEnvelope,
    SwarmStateSummary,
    HrvLeakGuardVerdict,
    hrv_mutual_information_bound,
    evaluate_hrv_leakage,
};
pub use roh_free_energy::{
    RohFreeEnergyMappingConfig,
    FreeEnergyOverrideDecision,
    FreeEnergyOverrideVerdict,
    compute_roh_free_energy_scalar,
    generate_override_from_free_energy,
}
