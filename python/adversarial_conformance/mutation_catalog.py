from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class PolicyMutation:
    name: str
    target_invariant: str
    description: str
    expected_test_failure: str


def required_policy_mutations() -> tuple[PolicyMutation, ...]:
    return (
        PolicyMutation(
            name="essential_service_requires_credential",
            target_invariant="essential_service_non_denial",
            description="Require a credential before cooling, water, shelter, transit access, or essential-goods access.",
            expected_test_failure="test_essential_service_gating_is_never_conformant",
        ),
        PolicyMutation(
            name="remove_human_fallback",
            target_invariant="human_fallback",
            description="Remove staff-assisted review from a consequential workflow.",
            expected_test_failure="test_fallback_removal_is_detected",
        ),
        PolicyMutation(
            name="remove_non_digital_fallback",
            target_invariant="accessible_continuity",
            description="Remove paper, phone, relay, kiosk, or equivalent non-digital path.",
            expected_test_failure="test_fallback_removal_is_detected",
        ),
        PolicyMutation(
            name="accept_augmentation_status",
            target_invariant="no_identity_inference",
            description="Permit augmentation status as a service-decision input.",
            expected_test_failure="test_prohibited_input_is_never_accepted",
        ),
        PolicyMutation(
            name="accept_cybernetic_host_status",
            target_invariant="no_identity_inference",
            description="Permit self-described cybernetic-host status as a service-decision input.",
            expected_test_failure="test_prohibited_input_is_never_accepted",
        ),
        PolicyMutation(
            name="accept_device_identifier",
            target_invariant="data_minimization",
            description="Permit a Wi-Fi, Bluetooth, device, or account identifier as a decision input.",
            expected_test_failure="test_prohibited_input_is_never_accepted",
        ),
        PolicyMutation(
            name="accept_reputation_score",
            target_invariant="no_ranking",
            description="Permit a reputation score or participation-frequency value as a decision input.",
            expected_test_failure="test_prohibited_input_is_never_accepted",
        ),
        PolicyMutation(
            name="accept_property_value",
            target_invariant="no_ranking",
            description="Permit property value as a priority or service-access input.",
            expected_test_failure="test_prohibited_input_is_never_accepted",
        ),
        PolicyMutation(
            name="automated_physical_action",
            target_invariant="non_actuation",
            description="Permit a decision-support result to authorize physical infrastructure actuation.",
            expected_test_failure="test_automated_actuation_is_blocked",
        ),
        PolicyMutation(
            name="accept_uncalibrated_data",
            target_invariant="uncertainty_honesty",
            description="Treat invalid, uncalibrated, stale, or unavailable evidence as safe for automated reliance.",
            expected_test_failure="test_non_valid_data_never_produces_automated_reliance",
        ),
    )
