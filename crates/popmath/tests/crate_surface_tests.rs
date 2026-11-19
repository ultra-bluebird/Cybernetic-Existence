use popmath::prelude::{
    CapabilityKind, ContinuityStatus, EnergyKwh, PopmathError, PopulationCount, TimeWindow,
    UtcTimestamp, VolumeM3,
};
use popmath::{
    MODEL_SCHEMA_VERSION, POLICY_CONTRACT_VERSION, RESULT_ENVELOPE_VERSION,
};

#[test]
fn public_contract_versions_are_present() {
    assert!(!MODEL_SCHEMA_VERSION.is_empty());
    assert!(!RESULT_ENVELOPE_VERSION.is_empty());
    assert!(!POLICY_CONTRACT_VERSION.is_empty());
}

#[test]
fn prelude_exposes_core_quantity_types() {
    let energy = EnergyKwh::new(12.5).expect("valid non-negative energy");
    let population = PopulationCount::new(250).expect("valid population count");
    let volume = VolumeM3::new(3.0).expect("valid non-negative volume");

    assert_eq!(energy.value(), 12.5);
    assert_eq!(population.value(), 250);
    assert_eq!(volume.value(), 3.0);
}

#[test]
fn prelude_exposes_time_types() {
    let start = UtcTimestamp::new(1_000).expect("valid timestamp");
    let end = UtcTimestamp::new(1_600).expect("valid timestamp");
    let window = TimeWindow::new(start, end).expect("valid half-open interval");

    assert_eq!(window.start(), start);
    assert_eq!(window.end(), end);
}

#[test]
fn prelude_exposes_continuity_types() {
    let kind = CapabilityKind::ContinuousPower;
    let status = ContinuityStatus::Met;

    assert_eq!(kind, CapabilityKind::ContinuousPower);
    assert_eq!(status, ContinuityStatus::Met);
}

#[test]
fn error_type_is_publicly_reachable() {
    let error = PopmathError::NonFiniteValue;

    assert!(matches!(error, PopmathError::NonFiniteValue));
}
