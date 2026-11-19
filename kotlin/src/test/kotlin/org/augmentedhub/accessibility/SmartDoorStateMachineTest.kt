package org.augmentedhub.accessibility

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SmartDoorStateMachineTest {
    private val machine = SmartDoorStateMachine(
        DoorConfiguration(
            normalOpenDurationMillis = 5_000,
            slowOpenDurationMillis = 12_000,
            voiceGuidanceDurationMillis = 8_000,
            emiShieldedOpenDurationMillis = 10_000,
            emergencyFailSafeDurationMillis = 30_000,
        ),
    )

    @Test
    fun wheelchairRequestEntersSlowOpenMode() {
        val assessment = machine.transition(
            DoorSensorInput(
                observedAtMillis = 1_000,
                obstacleDetected = false,
                emergencySignalActive = false,
                manualReleaseActivated = false,
                wheelchairAssistRequested = true,
                voiceGuidanceRequested = false,
                emiShieldingRequested = false,
                emiShieldIntegrityVerified = false,
                doorwayClear = true,
            ),
        )

        assertEquals(DoorMode.SLOW_OPEN, assessment.mode)
        assertEquals(
            "wheelchair_and_mobility_device_access",
            assessment.capabilityWindow.capability,
        )
        assertEquals(13_000, assessment.capabilityWindow.endsAtMillisExclusive)
        assertTrue(assessment.capabilityWindow.satisfied)
    }

    @Test
    fun verifiedShieldingSupersedesVoiceGuidance() {
        val assessment = machine.transition(
            DoorSensorInput(
                observedAtMillis = 2_000,
                obstacleDetected = false,
                emergencySignalActive = false,
                manualReleaseActivated = false,
                wheelchairAssistRequested = false,
                voiceGuidanceRequested = true,
                emiShieldingRequested = true,
                emiShieldIntegrityVerified = true,
                doorwayClear = true,
            ),
        )

        assertEquals(DoorMode.EMI_SHIELDED, assessment.mode)
        assertEquals(
            "emi_shielded_neural_interface_access",
            assessment.capabilityWindow.capability,
        )
        assertTrue(assessment.capabilityWindow.satisfied)
    }

    @Test
    fun obstacleAlwaysTriggersEmergencyFailSafe() {
        val assessment = machine.transition(
            DoorSensorInput(
                observedAtMillis = 3_000,
                obstacleDetected = true,
                emergencySignalActive = false,
                manualReleaseActivated = false,
                wheelchairAssistRequested = true,
                voiceGuidanceRequested = true,
                emiShieldingRequested = true,
                emiShieldIntegrityVerified = true,
                doorwayClear = false,
            ),
        )

        assertEquals(DoorMode.EMERGENCY_FAIL_SAFE, assessment.mode)
        assertEquals(
            "emergency_fail_safe_door_access",
            assessment.capabilityWindow.capability,
        )
        assertTrue(assessment.capabilityWindow.satisfied)
    }
}
