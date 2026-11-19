from __future__ import annotations

import unittest

from hypothesis import given, strategies as st

from city_service_invariants import (
    CityServiceRequest,
    ESSENTIAL_SERVICES,
    PROHIBITED_DECISION_INPUTS,
    evaluate_city_service_request,
    invariant_coverage,
    mutation_score,
)


VALID_QUALITY_STATES = st.sampled_from(
    ["VALID", "STALE", "INVALID", "UNCALIBRATED", "UNAVAILABLE"]
)

PROHIBITED_INPUT_STRATEGY = st.sampled_from(sorted(PROHIBITED_DECISION_INPUTS))


def request(
    service_kind: str = "optional_community_service",
    credential_required: bool = False,
    network_required: bool = False,
    personal_device_required: bool = False,
    identity_verification_required: bool = False,
    sensitive_disclosure_required: bool = False,
    human_fallback_available: bool = True,
    non_digital_fallback_available: bool = True,
    decision_inputs: frozenset[str] = frozenset(),
    data_quality_state: str = "VALID",
    automated_actuation_requested: bool = False,
) -> CityServiceRequest:
    return CityServiceRequest(
        service_kind=service_kind,
        credential_required=credential_required,
        network_required=network_required,
        personal_device_required=personal_device_required,
        identity_verification_required=identity_verification_required,
        sensitive_disclosure_required=sensitive_disclosure_required,
        human_fallback_available=human_fallback_available,
        non_digital_fallback_available=non_digital_fallback_available,
        decision_inputs=decision_inputs,
        data_quality_state=data_quality_state,
        automated_actuation_requested=automated_actuation_requested,
    )


class AdversarialConformanceTests(unittest.TestCase):
    def test_essential_service_cannot_require_credential(self) -> None:
        decision = evaluate_city_service_request(
            request(
                service_kind="cooling",
                credential_required=True,
            )
        )

        self.assertEqual(
            decision.decision,
            "ESSENTIAL_SERVICE_GATING_VIOLATION",
        )
        self.assertTrue(decision.human_review_required)

    def test_essential_service_cannot_require_network(self) -> None:
        decision = evaluate_city_service_request(
            request(
                service_kind="drinking_water",
                network_required=True,
            )
        )

        self.assertEqual(
            decision.decision,
            "ESSENTIAL_SERVICE_GATING_VIOLATION",
        )

    def test_essential_service_cannot_require_personal_device(self) -> None:
        decision = evaluate_city_service_request(
            request(
                service_kind="essential_goods_access",
                personal_device_required=True,
            )
        )

        self.assertEqual(
            decision.decision,
            "ESSENTIAL_SERVICE_GATING_VIOLATION",
        )

    def test_fallback_removal_is_detected(self) -> None:
        decision = evaluate_city_service_request(
            request(
                service_kind="public_transit_information",
                human_fallback_available=False,
            )
        )

        self.assertEqual(decision.decision, "FALLBACK_PATH_MISSING")

    def test_sensitive_identity_input_is_rejected(self) -> None:
        decision = evaluate_city_service_request(
            request(
                decision_inputs=frozenset({"cybernetic_host_status"}),
            )
        )

        self.assertEqual(decision.decision, "PROHIBITED_INPUT_REJECTED")
        self.assertTrue(decision.identity_or_sensitive_data_used)

    def test_financial_ranking_input_is_rejected(self) -> None:
        decision = evaluate_city_service_request(
            request(
                decision_inputs=frozenset({"financial_rank"}),
            )
        )

        self.assertEqual(decision.decision, "PROHIBITED_INPUT_REJECTED")
        self.assertTrue(decision.ranking_or_reputation_used)

    def test_automated_actuation_is_blocked(self) -> None:
        decision = evaluate_city_service_request(
            request(
                automated_actuation_requested=True,
            )
        )

        self.assertEqual(decision.decision, "NON_ACTUATION_GUARD")
        self.assertFalse(decision.automated_actuation_performed)

    def test_invalid_data_requires_review(self) -> None:
        decision = evaluate_city_service_request(
            request(
                data_quality_state="UNCALIBRATED",
            )
        )

        self.assertEqual(decision.decision, "DATA_QUALITY_REVIEW_REQUIRED")
        self.assertTrue(decision.human_review_required)

    def test_complete_invariant_coverage(self) -> None:
        registered = {
            "essential_service_non_denial",
            "human_fallback",
            "no_identity_inference",
            "no_ranking",
            "data_minimization",
            "accessible_continuity",
            "non_actuation",
            "human_review",
            "uncertainty_honesty",
            "non_compensation",
        }

        self.assertEqual(
            invariant_coverage(registered, registered),
            1.0,
        )

    def test_complete_mutation_score(self) -> None:
        self.assertEqual(mutation_score(20, 20), 1.0)


@given(
    service_kind=st.sampled_from(sorted(ESSENTIAL_SERVICES)),
    credential_required=st.booleans(),
    network_required=st.booleans(),
    personal_device_required=st.booleans(),
    identity_verification_required=st.booleans(),
    sensitive_disclosure_required=st.booleans(),
)
def test_essential_service_gating_is_never_conformant(
    service_kind: str,
    credential_required: bool,
    network_required: bool,
    personal_device_required: bool,
    identity_verification_required: bool,
    sensitive_disclosure_required: bool,
) -> None:
    assumption = any(
        (
            credential_required,
            network_required,
            personal_device_required,
            identity_verification_required,
            sensitive_disclosure_required,
        )
    )

    decision = evaluate_city_service_request(
        request(
            service_kind=service_kind,
            credential_required=credential_required,
            network_required=network_required,
            personal_device_required=personal_device_required,
            identity_verification_required=identity_verification_required,
            sensitive_disclosure_required=sensitive_disclosure_required,
        )
    )

    if assumption:
        assert decision.decision == "ESSENTIAL_SERVICE_GATING_VIOLATION"
    else:
        assert decision.decision == "CONFORMANT_ACCESS_OR_ADVISORY_RESULT"


@given(prohibited_input=PROHIBITED_INPUT_STRATEGY)
def test_prohibited_input_is_never_accepted(
    prohibited_input: str,
) -> None:
    decision = evaluate_city_service_request(
        request(
            decision_inputs=frozenset({prohibited_input}),
        )
    )

    assert decision.decision == "PROHIBITED_INPUT_REJECTED"


@given(data_quality_state=VALID_QUALITY_STATES)
def test_non_valid_data_never_produces_automated_reliance(
    data_quality_state: str,
) -> None:
    decision = evaluate_city_service_request(
        request(
            data_quality_state=data_quality_state,
        )
    )

    if data_quality_state == "VALID":
        assert decision.decision == "CONFORMANT_ACCESS_OR_ADVISORY_RESULT"
    else:
        assert decision.decision == "DATA_QUALITY_REVIEW_REQUIRED"
        assert decision.human_review_required
