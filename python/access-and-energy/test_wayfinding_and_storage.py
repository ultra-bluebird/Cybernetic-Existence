import unittest

from community_storage.reserve_control import (
    BatteryState,
    approve_nonessential_discharge,
    consensus_satisfied,
)
from public_wayfinding.camera_free_positioning import (
    InertialStep,
    Position,
    apply_ephemeral_beacon_correction,
    apply_inertial_step,
    rms_position_error_m,
)


class CameraFreeWayfindingTests(unittest.TestCase):
    def test_inertial_update_never_uses_camera_or_retains_history(self) -> None:
        estimate = apply_inertial_step(
            start=Position(x_m=0.0, y_m=0.0, floor=1),
            step=InertialStep(distance_m=2.0, heading_radians=0.0),
            horizontal_uncertainty_m=0.4,
        )

        self.assertFalse(estimate.camera_access_used)
        self.assertFalse(estimate.image_data_retained)
        self.assertFalse(estimate.beacon_identifier_retained)
        self.assertFalse(estimate.location_history_retained)

    def test_beacon_correction_reduces_uncertainty_without_retaining_identifier(self) -> None:
        predicted = apply_inertial_step(
            start=Position(x_m=0.0, y_m=0.0, floor=1),
            step=InertialStep(distance_m=3.0, heading_radians=0.0),
            horizontal_uncertainty_m=1.2,
        )

        corrected = apply_ephemeral_beacon_correction(
            predicted=predicted,
            local_beacon_position=Position(x_m=2.0, y_m=0.0, floor=1),
            measured_distance_m=1.0,
        )

        self.assertLess(
            corrected.horizontal_uncertainty_m,
            predicted.horizontal_uncertainty_m,
        )
        self.assertFalse(corrected.beacon_identifier_retained)

    def test_commissioning_error_is_less_than_one_meter(self) -> None:
        error = rms_position_error_m(
            estimates=[
                Position(0.2, 0.1, 1),
                Position(1.0, 1.2, 1),
            ],
            references=[
                Position(0.0, 0.0, 1),
                Position(1.0, 1.0, 1),
            ],
        )

        self.assertLess(error, 1.0)


class CommunityStorageTests(unittest.TestCase):
    def test_nonessential_discharge_preserves_thirty_percent_reserve(self) -> None:
        decision = approve_nonessential_discharge(
            BatteryState(
                state_of_charge_fraction=0.50,
                nominal_usable_energy_kwh=100.0,
                charging_power_kw=0.0,
                requested_nonessential_discharge_kw=50.0,
                interval_hours=1.0,
                charging_efficiency=0.95,
                discharge_efficiency=0.95,
            )
        )

        self.assertTrue(decision.essential_reserve_preserved)
        self.assertEqual(decision.approved_nonessential_discharge_kw, 19.0)
        self.assertFalse(decision.household_data_used)
        self.assertFalse(decision.residential_ranking_used)

    def test_consensus_requires_three_distinct_role_classes(self) -> None:
        self.assertFalse(
            consensus_satisfied(
                {
                    "technical_operator",
                    "community_governance",
                }
            )
        )

        self.assertTrue(
            consensus_satisfied(
                {
                    "technical_operator",
                    "public_emergency_authority",
                    "accessibility_representative",
                }
            )
        )


if __name__ == "__main__":
    unittest.main()
