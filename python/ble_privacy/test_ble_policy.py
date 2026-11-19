import unittest

from ble_policy import (
    BleFeatureRequest,
    audit_record_is_ble_safe,
    evaluate_ble_feature,
    sanitize_cooperative_upload,
)


class BleFeaturePolicyTests(unittest.TestCase):
    def compliant_request(self) -> BleFeatureRequest:
        return BleFeatureRequest(
            feature_name="local_language_preference",
            service_kind="public_kiosk",
            is_optional=True,
            visible_disable_control=True,
            non_ble_equivalent_available=True,
            ble_identifier_persisted=False,
            ble_identifier_transmitted_off_device=False,
            ble_correlated_with_wifi=False,
            ble_presence_metric_created=False,
            essential_service_available_without_ble=True,
            explicit_consent_received=True,
        )

    def test_approves_local_optional_nonpersistent_feature(self) -> None:
        decision = evaluate_ble_feature(self.compliant_request())

        self.assertTrue(decision.approved)
        self.assertEqual(decision.decision, "BLE_FEATURE_APPROVED")

    def test_rejects_ble_dependency_for_essential_service(self) -> None:
        request = BleFeatureRequest(
            feature_name="cooling_center_check_in",
            service_kind="cooling",
            is_optional=True,
            visible_disable_control=True,
            non_ble_equivalent_available=True,
            ble_identifier_persisted=False,
            ble_identifier_transmitted_off_device=False,
            ble_correlated_with_wifi=False,
            ble_presence_metric_created=False,
            essential_service_available_without_ble=False,
            explicit_consent_received=True,
        )

        decision = evaluate_ble_feature(request)

        self.assertFalse(decision.approved)
        self.assertEqual(decision.decision, "ESSENTIAL_SERVICE_BLE_DEPENDENCY")

    def test_rejects_persistent_identifier_storage(self) -> None:
        request = self.compliant_request()
        request = BleFeatureRequest(
            **{
                **request.__dict__,
                "ble_identifier_persisted": True,
            }
        )

        decision = evaluate_ble_feature(request)

        self.assertFalse(decision.approved)
        self.assertEqual(decision.decision, "BLE_PERSISTENCE_PROHIBITED")

    def test_rejects_wifi_correlation(self) -> None:
        request = self.compliant_request()
        request = BleFeatureRequest(
            **{
                **request.__dict__,
                "ble_correlated_with_wifi": True,
            }
        )

        decision = evaluate_ble_feature(request)

        self.assertFalse(decision.approved)
        self.assertEqual(decision.decision, "BLE_WIFI_CORRELATION_PROHIBITED")

    def test_rejects_identifier_in_audit_record(self) -> None:
        self.assertFalse(
            audit_record_is_ble_safe(
                {
                    "event_type": "kiosk_interaction",
                    "ble_identifier": "prohibited",
                }
            )
        )

    def test_sanitizes_cooperative_upload_without_ble_data(self) -> None:
        output = sanitize_cooperative_upload(
            {
                "region": "broad_zone_id",
                "metric": "leafy_green_yield_density",
                "value": "aggregate_estimate",
                "time_window": "2026-09-01",
                "privacy_class": "regional_aggregate",
            }
        )

        self.assertFalse(output["ble_id_present"])
        self.assertNotIn("ble_identifier", output)

    def test_rejects_cooperative_upload_with_ble_identifier(self) -> None:
        with self.assertRaises(ValueError):
            sanitize_cooperative_upload(
                {
                    "region": "broad_zone_id",
                    "metric": "leafy_green_yield_density",
                    "value": "aggregate_estimate",
                    "time_window": "2026-09-01",
                    "privacy_class": "regional_aggregate",
                    "ble_identifier": "prohibited",
                }
            )


if __name__ == "__main__":
    unittest.main()
