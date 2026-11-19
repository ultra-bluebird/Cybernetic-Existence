/// IMMUTABLE POLICY - Modification requires full binary recompilation
pub const HOST_BOSTROM_ADDR: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
pub const POLICY_VERSION: &str = "IMMUTABLE_V1_2026_05_28";

/// ONLY permitted safety recovery causes - enum is NOT #[non_exhaustive]
/// Adding variants is compile error
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PermittedSafetyRecoveryCause {
    BioIncompatibilityCrisis,    // CRP >10 mg/L >48h + metabolic crisis
    LifeCriticalIntervention,     // Immediate vital-sign emergency
    ErrorCorrection,              // ALN shard corruption only
    HostAuthorizedDiagnostic,     // Your signature + 72h expiry
}

impl PermittedSafetyRecoveryCause {
    pub const fn min_evidence_strength(&self) -> u8 {
        match self {
            Self::BioIncompatibilityCrisis => 10,
            Self::LifeCriticalIntervention => 8,
            Self::ErrorCorrection => 6,
            Self::HostAuthorizedDiagnostic => 10,
        }
    }
    
    pub const fn max_capability_regression(&self) -> f64 {
        match self {
            Self::BioIncompatibilityCrisis => 0.20,  // Max 20% loss
            Self::LifeCriticalIntervention => 0.15,  // Max 15% loss
            Self::ErrorCorrection => 0.05,           // Max 5% loss
            Self::HostAuthorizedDiagnostic => 0.30,  // Max 30% for diagnostics
        }
    }
}

/// Decision struct with PRIVATE fields - no external mutation possible
#[derive(Debug)]
pub struct ImmutableSafetyRecoveryDecision {
    permitted: bool,
    cause: Option<PermittedSafetyRecoveryCause>,
    evidence_hash: [u8; 32],
    capability_floor_enforced: f64,
}

impl ImmutableSafetyRecoveryDecision {
    /// ONLY constructor - enforces all invariants
    pub fn evaluate(
        cause: PermittedSafetyRecoveryCause,
        evidence: &EvidenceBundle10,
        biomarkers: &BiomarkerSnapshot,
        current_caps: &PsychCaps,
        host_sig: Option<&HostSignature>,
    ) -> Option<Self> {
        // Evidence strength check
        if evidence.validated_tag_count() < cause.min_evidence_strength() {
            return None;
        }
        
        // Host signature required for diagnostics
        if cause.requires_host_signature() {
            match host_sig {
                Some(sig) => if !sig.verify_host_address(HOST_BOSTROM_ADDR) {
                    return None;
                },
                None => return None,
            }
        }
        
        // Bio-incompatibility: verify SUSTAINED crisis (>=48 hours)
        if cause == PermittedSafetyRecoveryCause::BioIncompatibilityCrisis {
            let sustained = biomarkers.crp_mg_per_l > 10.0 
                && biomarkers.duration_hours >= 48.0;
            let metabolic = biomarkers.lactate_mmol_per_l > 4.0 
                || biomarkers.atp_depletion_percent > 30.0;
            
            if !(sustained && metabolic) {
                return None;
            }
        }
        
        // Capability floor: NEVER drop below 70% of current
        let min_capability = current_caps.capability_norm() 
            * (1.0 - cause.max_capability_regression());
        
        Some(Self {
            permitted: true,
            cause: Some(cause),
            evidence_hash: evidence.compute_hash(),
            capability_floor_enforced: min_capability.max(0.70 * current_caps.capability_norm()),
        })
    }
    
    // Read-only accessors
    pub fn is_permitted(&self) -> bool { self.permitted }
    pub fn capability_floor(&self) -> f64 { self.capability_floor_enforced }
}
