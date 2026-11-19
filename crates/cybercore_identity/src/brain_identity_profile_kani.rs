use kani::any;

#[cfg_attr(kani, kani::proof)]
fn kani_psych_caps_new_rejects_invalid() {
    let roh_max: f32 = any();
    let pain_max: f32 = any();
    let fear_max: f32 = any();
    let cognitive_load_max: f32 = any();
    let identity_disruption_max: f32 = any();

    if let Some(caps) =
        PsychCaps::new(roh_max, pain_max, fear_max, cognitive_load_max, identity_disruption_max)
    {
        assert!(caps.roh_max >= 0.0 && caps.roh_max <= 0.3);
        assert!(caps.pain_max >= 0.0 && caps.pain_max <= 1.0);
        assert!(caps.fear_max >= 0.0 && caps.fear_max <= 1.0);
        assert!(caps.cognitive_load_max >= 0.0 && caps.cognitive_load_max <= 1.0);
        assert!(caps.identity_disruption_max >= 0.0 && caps.identity_disruption_max <= 1.0);
    }
}

#[cfg_attr(kani, kani::proof)]
fn kani_brain_identity_profile_new_respects_invariants() {
    let host_did: String = any();
    let bostrom_addr: String = any();
    let roh_max: f32 = any();
    let pain_max: f32 = any();
    let fear_max: f32 = any();
    let cognitive_load_max: f32 = any();
    let identity_disruption_max: f32 = any();
    let hardware_claim: Vec<u8> = any();
    let created_at_ms: i64 = any();
    let psych_caps_schema: String = any();
    let attestation_sig: Vec<u8> = any();

    if let Some(psych_caps) = PsychCaps::new(
        roh_max,
        pain_max,
        fear_max,
        cognitive_load_max,
        identity_disruption_max,
    ) {
        if let Some(profile) = BrainIdentityProfile::new(
            host_did,
            bostrom_addr,
            psych_caps,
            hardware_claim,
            created_at_ms,
            psych_caps_schema,
            attestation_sig,
        ) {
            assert!(validate_did(&profile.host_did));
            assert!(validate_bostrom_addr(&profile.bostrom_addr));
            assert!(verify_attestation_signature(
                &profile.attestation_sig,
                &profile.host_did,
                &profile.bostrom_addr,
                &profile.psych_caps,
                &profile.hardware_claim,
                profile.created_at_ms,
                &profile.psych_caps_schema
            ));
        }
    }
}
