// crates/reality_os_core/src/neurorights_validator.rs
#![forbid(unsafe_code)]
#![deny(warnings)]

use crate::snapshot::RealityOsSnapshot;
use crate::neurorights::{NeurorightsShard, Neuroright};

pub fn neurorights_ok(snapshot: &RealityOsSnapshot, shard: &NeurorightsShard) -> bool {
    if shard.validate().is_err() {
        return false;
    }

    // 1. Mental privacy: no raw EEG/BCI export if active.
    if shard.is_active(Neuroright::MentalPrivacy) {
        if snapshot.telemetry.contains_raw_eeg_export()
            || snapshot.telemetry.contains_unencrypted_bci_traces()
        {
            return false;
        }
    }

    // 2. Cognitive liberty: no forced XR/policy override if active.
    if shard.is_active(Neuroright::CognitiveLiberty) {
        if snapshot.xr_mode.is_punitive()
            || snapshot.policy_flags.contains_forced_cap_changes()
        {
            return false;
        }
    }

    // 3. Mental integrity: psychrisk & RoH within integrity corridors.
    if shard.is_active(Neuroright::MentalIntegrity) {
        if snapshot.roh_scalar > snapshot.roh_integrity_ceiling
            || snapshot.psych_caps.identity_disruption_index()
                > snapshot.psych_caps.identity_disruption_max()
        {
            return false;
        }
    }

    // 4. Non-punitive XR: XR verdicts not marked punitive.
    if shard.is_active(Neuroright::NonPunitiveXR) {
        if snapshot.xr_mode.is_punitive() {
            return false;
        }
    }

    // 5. Soul non-addressability: no soul addresses or cloning tags.
    if shard.is_active(Neuroright::SoulNonAddressability) {
        if snapshot.telemetry.contains_soul_address()
            || snapshot.telemetry.contains_consciousness_clone_tag()
        {
            return false;
        }
    }

    // 6. Non-commercial neural data: no saleable export tags.
    if shard.is_active(Neuroright::NonCommercialNeuralData) {
        if snapshot.telemetry.has_commercial_neural_export()
            || snapshot.organichain_meta.neural_data_for_sale()
        {
            return false;
        }
    }

    // 7. Fair benefit: value routing must pay host share.
    if shard.is_active(Neuroright::FairBenefit) {
        if !snapshot.organichain_meta.host_benefit_binding_ok()
            || snapshot.organichain_meta.value_routing_missing_host_share()
        {
            return false;
        }
    }

    true
}
