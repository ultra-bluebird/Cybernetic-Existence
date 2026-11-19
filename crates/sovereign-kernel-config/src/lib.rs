// crates/sovereign-kernel-config/src/lib.rs
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SovereignKernelConfig {
    pub hostdid: String,
    pub host_bostrom_primary: String,
    pub policy_id: String,
    pub policy_version: String,
    pub roh_ceiling: f32,
    pub rohautoallow_conservative: f32,
    pub rohautoallow_copilot: f32,
    pub conservative_scaling: EvoModeScaling,
    pub copilot_scaling: EvoModeScaling,
    pub host_budget: HostBudgetEnvelope,
    pub thermo_envelope: ThermodynamicEnvelope,
    pub cognitive_envelope: CognitiveLoadEnvelope,
    pub neural_rope_envelope: NeuralRopeEnvelope,
    pub lifeforce_band: (f32, f32),
    pub forbidden_modules: ForbiddenModules,
    pub forbidden_behaviors: Vec<String>
}

impl SovereignKernelConfig {
    pub fn from_evo(consent: &EvoConsent) -> Self {
        SovereignKernelConfig {
            hostdid: consent.hostdid.clone(),
            host_bostrom_primary: consent.hostbostromprimary.clone(),
            policy_id: consent.policyid.clone(),
            policy_version: consent.policyversion.clone(),
            roh_ceiling: consent.conservativegate.rohceiling,
            rohautoallow_conservative: consent.conservativegate.rohautoallowedmax,
            rohautoallow_copilot: consent.copilotgate.rohautoallowedmax,
            conservative_scaling: consent.conservativescaling.clone(),
            copilot_scaling: consent.copilotscaling.clone(),
            host_budget: consent.hostbudget.clone(),
            thermo_envelope: consent.thermoenvelope.clone(),
            cognitive_envelope: consent.cognitiveenvelope.clone(),
            neural_rope_envelope: consent.neuralropeenvelope.clone(),
            lifeforce_band: (consent.lifeforcemin, consent.lifeforcemax),
            forbidden_modules: consent.forbidden.clone(),
            forbidden_behaviors: consent.forbidden.behaviors.clone()
        }
    }
}
