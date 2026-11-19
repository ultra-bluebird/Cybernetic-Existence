import unittest

from qos_policy import (
    QosConfiguration,
    build_qos_plan,
    validate_essential_domain_policy,
)


class QosPolicyTests(unittest.TestCase):
    def test_reserves_essential_capacity_without_identity(self) -> None:
        plan = build_qos_plan(
            QosConfiguration(
                total_backhaul_mbps=200.0,
                essential_reservation_mbps=50.0,
            ),
            active_anonymous_connections=100,
        )

        self.assertEqual(plan.essential_capacity_mbps, 50.0)
        self.assertEqual(plan.theoretical_general_share_mbps, 1.5)
        self.assertTrue(plan.one_mbps_target_met)
        self.assertFalse(plan.user_identity_required)
        self.assertFalse(plan.mac_address_retained)
        self.assertFalse(plan.browsing_history_retained)

    def test_uses_anonymous_best_effort_shaping_during_congestion(self) -> None:
        plan = build_qos_plan(
            QosConfiguration(
                total_backhaul_mbps=50.0,
                essential_reservation_mbps=10.0,
            ),
            active_anonymous_connections=80,
        )

        self.assertFalse(plan.one_mbps_target_met)
        self.assertEqual(
            plan.congestion_mode,
            "ANONYMOUS_FAIR_QUEUEING_WITH_BEST_EFFORT_SHAPING",
        )

    def test_accepts_signed_essential_destination_allowlist(self) -> None:
        self.assertTrue(
            validate_essential_domain_policy(
                classification_basis="signed_public_destination_allowlist",
                records_user_destination_history=False,
                requires_user_identity=False,
            )
        )

    def test_rejects_destination_history_collection(self) -> None:
        self.assertFalse(
            validate_essential_domain_policy(
                classification_basis="signed_public_destination_allowlist",
                records_user_destination_history=True,
                requires_user_identity=False,
            )
        )


if __name__ == "__main__":
    unittest.main()
