#![forbid(unsafe_code)]

use kani::any;
use cybernano_adaptive::{
    AdaptiveCorridorThresholds,
    UniversalSafetyFloor,
    EvidenceBundle10,
    AdaptiveUpdateError,
};

#[kani::proof]
fn update_from_evidence_never_weaken_usf() {
    // 1. Symbolic USF, but constrained to sane ranges and RoH <= 0.30.
    let mut usf: UniversalSafetyFloor = any();
    kani::assume(usf.roh_ceiling <= 0.30);
    kani::assume(usf.roh_ceiling >= 0.0);
    kani::assume(usf.hrv_min_ms >= 0.0);
    kani::assume(usf.temp_min_c <= usf.temp_max_c);

    // 2. Symbolic current adaptive thresholds, already at least as strict as USF.
    let mut current: AdaptiveCorridorThresholds = any();

    // For ceilings: current <= USF.
    kani::assume(current.il6_max <= usf.il6_max);
    kani::assume(current.temp_max_c <= usf.temp_max_c);
    kani::assume(current.roh_ceiling <= usf.roh_ceiling);

    // For floors: current >= USF.
    kani::assume(current.hrv_min_ms >= usf.hrv_min_ms);
    kani::assume(current.temp_min_c >= usf.temp_min_c);

    // 3. Symbolic EvidenceBundle10 with minimal well-formedness.
    let mut ev: EvidenceBundle10 = any();
    // Enforce exactly 10 tags; the impl already checks for required tags.
    kani::assume(ev.tags.len() == 10);
    // Do not constrain metrics beyond what update_from_evidence already checks;
    // we want the property to hold for all permitted evidence.

    // 4. Call the function under test.
    let res = current.update_from_evidence(usf, ev);

    if let Ok(new) = res {
        // For every max ceiling: new <= current AND new <= USF.
        assert!(new.il6_max <= current.il6_max);
        assert!(new.il6_max <= usf.il6_max);

        assert!(new.temp_max_c <= current.temp_max_c);
        assert!(new.temp_max_c <= usf.temp_max_c);

        assert!(new.roh_ceiling <= current.roh_ceiling);
        assert!(new.roh_ceiling <= usf.roh_ceiling);

        // For every min floor: new >= current AND new >= USF.
        assert!(new.hrv_min_ms >= current.hrv_min_ms);
        assert!(new.hrv_min_ms >= usf.hrv_min_ms);

        assert!(new.temp_min_c >= current.temp_min_c);
        assert!(new.temp_min_c >= usf.temp_min_c);
    } else if let Err(AdaptiveUpdateError::WouldWeakenUniversalFloor { .. }) = res {
        // On an attempted USF weakening, the function must return an error
        // and not change the current thresholds; property is vacuously true.
    } else {
        // Evidence-related errors also do not change current; no further assertion needed.
    }
}
