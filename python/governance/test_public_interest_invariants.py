import unittest

from public_interest_invariants import (
    DataReleaseRequest,
    LoadArea,
    ServiceAccessRequest,
    evaluate_data_release,
    evaluate_essential_service_access,
    evaluate_fair_load_shedding,
    safe_audit_record,
)


class PublicInterestInvariantTests(unittest.TestCase):
    def test_essential_cooling_cannot_require_a_credential(self) -> None:
        result = evaluate_essential_service_access(
            ServiceAccessRequest(
                service_kind="cooling",
                requires_credential=True,
                requires_network=False,
                requires_personal_device=False,
                requires_identity_verification=False,
                requires_sensitive_disclosure=False,
                human_fallback_available=True,
                non_digital_fallback_available=True,
            )
        )

        self.assertFalse(result.compliant)
        self.assertEqual(result.decision, "ESSENTIAL_SERVICE_GATING_VIOLATION")

    def test_nonessential_optional_service_can_preserve_fallbacks(self) -> None:
        result = evaluate_essential_service_access(
            ServiceAccessRequest(
                service_kind="optional_community_program",
                requires_credential=False,
                requires_network=False,
                requires_personal_device=False,
                requires_identity_verification=False,
                requires_sensitive_disclosure=False,
                human_fallback_available=True,
                non_digital_fallback_available=True,
            )
        )

        self.assertTrue(result.compliant)

    def test_data_release_rejects_cybernetic_host_status_field(self) -> None:
        result = evaluate_data_release(
            DataReleaseRequest(
                fields=frozenset(
                    {
                        "planning_zone",
                        "monthly_mean_temperature",
                        "cybernetic_host_status",
                    }
                ),
                aggregate_only=True,
                small_cell_suppression_applied=True,
                epsilon=0.1,
                reidentification_risk_present=False,
                discriminatory_or_ranking_purpose=False,
                human_review_complete=True,
            )
        )

        self.assertFalse(result.compliant)
        self.assertEqual(result.decision, "PROHIBITED_FIELD_RELEASE")

    def test_data_release_accepts_protected_aggregate(self) -> None:
        result = evaluate_data_release(
            DataReleaseRequest(
                fields=frozenset(
                    {
                        "planning_zone",
                        "monthly_mean_temperature",
                        "tree_canopy_percent",
                        "heat_safe_route_coverage_percent",
                    }
                ),
                aggregate_only=True,
                small_cell_suppression_applied=True,
                epsilon=0.1,
                reidentification_risk_present=False,
                discriminatory_or_ranking_purpose=False,
                human_review_complete=True,
            )
        )

        self.assertTrue(result.compliant)
        self.assertEqual(result.decision, "RELEASE_COMPLIANT")

    def test_fair_load_plan_requires_review_for_unequal_burden(self) -> None:
        result = evaluate_fair_load_shedding(
            [
                LoadArea("zone_a", 10.0, 4.0, 0.5, False),
                LoadArea("zone_b", 12.0, 5.0, 4.0, False),
                LoadArea("zone_c", 9.0, 3.0, 4.0, False),
            ]
        )

        self.assertFalse(result.compliant)
        self.assertTrue(result.requires_human_review)

    def test_balanced_residual_outage_plan_is_compliant(self) -> None:
        result = evaluate_fair_load_shedding(
            [
                LoadArea("zone_a", 10.0, 4.0, 2.0, False),
                LoadArea("zone_b", 12.0, 5.0, 2.0, False),
                LoadArea("zone_c", 9.0, 3.0, 2.0, False),
            ]
        )

        self.assertTrue(result.compliant)
        self.assertGreater(result.jain_fairness_index, 0.9)

    def test_audit_record_excludes_sensitive_identity_and_rank_fields(self) -> None:
        self.assertTrue(
            safe_audit_record(
                {
                    "event_type": "repair_status",
                    "public_zone": "community_district",
                    "status": "ACKNOWLEDGED",
                }
            )
        )
        self.assertFalse(
            safe_audit_record(
                {
                    "event_type": "repair_status",
                    "reputation_score": 1,
                }
            )
        )


if __name__ == "__main__":
    unittest.main()
