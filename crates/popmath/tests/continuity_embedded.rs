use popmath::continuity_embedded::{
    assess_continuity,
    CapabilityWindow,
    EvidenceStatus,
    MAX_CAPABILITY_WINDOWS,
    UnitInterval,
};

#[test]
fn assesses_continuity_with_a_fixed_capacity_of_sixteen_windows() {
    let mut windows = [CapabilityWindow {
        starts_at_milliseconds: 0,
        ends_at_milliseconds_exclusive: 0,
        evidence_status: EvidenceStatus::Unavailable,
        satisfied: false,
    }; MAX_CAPABILITY_WINDOWS];

    windows[0] = CapabilityWindow {
        starts_at_milliseconds: 0,
        ends_at_milliseconds_exclusive: 2_000,
        evidence_status: EvidenceStatus::Verified,
        satisfied: true,
    };

    windows[1] = CapabilityWindow {
        starts_at_milliseconds: 2_000,
        ends_at_milliseconds_exclusive: 5_000,
        evidence_status: EvidenceStatus::Verified,
        satisfied: true,
    };

    windows[2] = CapabilityWindow {
        starts_at_milliseconds: 5_000,
        ends_at_milliseconds_exclusive: 10_000,
        evidence_status: EvidenceStatus::Verified,
        satisfied: true,
    };

    let assessment = assess_continuity(
        0,
        10_000,
        &windows,
        3,
    )
    .unwrap();

    assert_eq!(assessment.continuity_ratio, UnitInterval::ONE);
    assert!(assessment.uninterrupted);
    assert_eq!(assessment.verified_window_count, 3);
}

#[test]
fn excludes_unverified_windows_from_embedded_continuity_coverage() {
    let mut windows = [CapabilityWindow {
        starts_at_milliseconds: 0,
        ends_at_milliseconds_exclusive: 0,
        evidence_status: EvidenceStatus::Unavailable,
        satisfied: false,
    }; MAX_CAPABILITY_WINDOWS];

    windows[0] = CapabilityWindow {
        starts_at_milliseconds: 0,
        ends_at_milliseconds_exclusive: 4_000,
        evidence_status: EvidenceStatus::Verified,
        satisfied: true,
    };

    windows[1] = CapabilityWindow {
        starts_at_milliseconds: 4_000,
        ends_at_milliseconds_exclusive: 10_000,
        evidence_status: EvidenceStatus::PendingReview,
        satisfied: true,
    };

    let assessment = assess_continuity(
        0,
        10_000,
        &windows,
        2,
    )
    .unwrap();

    assert_eq!(
        assessment.continuity_ratio,
        UnitInterval::from_basis_points(4_000).unwrap(),
    );
    assert!(!assessment.uninterrupted);
}
