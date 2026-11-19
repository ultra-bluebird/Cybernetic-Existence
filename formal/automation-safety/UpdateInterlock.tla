---------------------------- MODULE UpdateInterlock ----------------------------

EXTENDS Naturals, Sequences, TLC

CONSTANTS
    EvidenceStates,
    ConsentStates,
    ReviewStates,
    CapabilityScopes

ASSUME EvidenceStates = {"missing", "satisfied", "disputed"}
ASSUME ConsentStates = {"current", "revoked", "expired"}
ASSUME ReviewStates = {"pending", "approved", "rejected"}
ASSUME CapabilityScopes = {"none", "local_only", "aggregate_only"}

VARIABLES
    evidenceState,
    consentState,
    reviewState,
    capabilityScope,
    updateState,
    unsafeState

vars ==
    <<
        evidenceState,
        consentState,
        reviewState,
        capabilityScope,
        updateState,
        unsafeState
    >>

TypeInvariant ==
    /\ evidenceState \in EvidenceStates
    /\ consentState \in ConsentStates
    /\ reviewState \in ReviewStates
    /\ capabilityScope \in CapabilityScopes
    /\ updateState \in {"idle", "proposed", "applied", "blocked"}
    /\ unsafeState \in BOOLEAN

Initial ==
    /\ evidenceState = "missing"
    /\ consentState = "current"
    /\ reviewState = "pending"
    /\ capabilityScope = "none"
    /\ updateState = "idle"
    /\ unsafeState = FALSE

ProposeUpdate ==
    /\ updateState = "idle"
    /\ updateState' = "proposed"
    /\ UNCHANGED <<
        evidenceState,
        consentState,
        reviewState,
        capabilityScope,
        unsafeState
    >>

ApplyUpdate ==
    /\ updateState = "proposed"
    /\ evidenceState = "satisfied"
    /\ consentState = "current"
    /\ reviewState = "approved"
    /\ updateState' = "applied"
    /\ unsafeState' = FALSE
    /\ UNCHANGED <<
        evidenceState,
        consentState,
        reviewState,
        capabilityScope
    >>

BlockUpdate ==
    /\ updateState = "proposed"
    /\ (
        evidenceState # "satisfied"
        \/ consentState # "current"
        \/ reviewState # "approved"
    )
    /\ updateState' = "blocked"
    /\ unsafeState' = FALSE
    /\ UNCHANGED <<
        evidenceState,
        consentState,
        reviewState,
        capabilityScope
    >>

RevokeConsent ==
    /\ consentState = "current"
    /\ consentState' = "revoked"
    /\ updateState' = IF updateState = "proposed" THEN "blocked" ELSE updateState
    /\ unsafeState' = FALSE
    /\ UNCHANGED <<
        evidenceState,
        reviewState,
        capabilityScope
    >>

Next ==
    \/ ProposeUpdate
    \/ ApplyUpdate
    \/ BlockUpdate
    \/ RevokeConsent

Spec ==
    Initial /\ [][Next]_vars

NoUnsafeState ==
    [](~unsafeState)

AppliedOnlyWithEvidence ==
    [](
        updateState = "applied"
        =>
        evidenceState = "satisfied"
    )

AppliedOnlyWithCurrentConsent ==
    [](
        updateState = "applied"
        =>
        consentState = "current"
    )

AppliedOnlyWithApprovedReview ==
    [](
        updateState = "applied"
        =>
        reviewState = "approved"
    )

=============================================================================
