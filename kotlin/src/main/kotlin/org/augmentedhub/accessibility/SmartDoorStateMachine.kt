package org.augmentedhub.accessibility

enum class DoorMode {
    NORMAL,
    SLOW_OPEN,
    VOICE_GUIDED,
    EMI_SHIELDED,
    EMERGENCY_FAIL_SAFE,
}

enum class EvidenceStatus {
    VERIFIED,
    PENDING_REVIEW,
    UNAVAILABLE,
}

data class CapabilityWindow(
    val capability: String,
    val startsAtMillis: Long,
    val endsAtMillisExclusive: Long,
    val evidenceStatus: EvidenceStatus,
    val satisfied: Boolean,
    val explanation: String,
) {
    init {
        require(capability.isNotBlank()) { "capability must not be blank" }
        require(startsAtMillis >= 0) { "startsAtMillis must be non-negative" }
        require(endsAtMillisExclusive > startsAtMillis) {
            "endsAtMillisExclusive must be greater than startsAtMillis"
        }
    }
}

data class DoorSensorInput(
    val observedAtMillis: Long,
    val obstacleDetected: Boolean,
    val emergencySignalActive: Boolean,
    val manualReleaseActivated: Boolean,
    val wheelchairAssistRequested: Boolean,
    val voiceGuidanceRequested: Boolean,
    val emiShieldingRequested: Boolean,
    val emiShieldIntegrityVerified: Boolean,
    val doorwayClear: Boolean,
) {
    init {
        require(observedAtMillis >= 0) { "observedAtMillis must be non-negative" }
    }
}

data class DoorConfiguration(
    val normalOpenDurationMillis: Long,
    val slowOpenDurationMillis: Long,
    val voiceGuidanceDurationMillis: Long,
    val emiShieldedOpenDurationMillis: Long,
    val emergencyFailSafeDurationMillis: Long,
) {
    init {
        require(normalOpenDurationMillis > 0) {
            "normalOpenDurationMillis must be positive"
        }
        require(slowOpenDurationMillis >= normalOpenDurationMillis) {
            "slowOpenDurationMillis must be at least normalOpenDurationMillis"
        }
        require(voiceGuidanceDurationMillis > 0) {
            "voiceGuidanceDurationMillis must be positive"
        }
        require(emiShieldedOpenDurationMillis > 0) {
            "emiShieldedOpenDurationMillis must be positive"
        }
        require(emergencyFailSafeDurationMillis > 0) {
            "emergencyFailSafeDurationMillis must be positive"
        }
    }
}

data class DoorAssessment(
    val mode: DoorMode,
    val capabilityWindow: CapabilityWindow,
    val transitionExplanation: String,
)

class SmartDoorStateMachine(
    private val configuration: DoorConfiguration,
) {
    fun transition(input: DoorSensorInput): DoorAssessment {
        val mode = selectMode(input)
        val capabilityWindow = createCapabilityWindow(mode, input)

        return DoorAssessment(
            mode = mode,
            capabilityWindow = capabilityWindow,
            transitionExplanation = transitionExplanation(mode, input),
        )
    }

    private fun selectMode(input: DoorSensorInput): DoorMode {
        if (input.emergencySignalActive || input.manualReleaseActivated || input.obstacleDetected) {
            return DoorMode.EMERGENCY_FAIL_SAFE
        }

        if (!input.doorwayClear) {
            return DoorMode.EMERGENCY_FAIL_SAFE
        }

        if (input.emiShieldingRequested && input.emiShieldIntegrityVerified) {
            return DoorMode.EMI_SHIELDED
        }

        if (input.wheelchairAssistRequested) {
            return DoorMode.SLOW_OPEN
        }

        if (input.voiceGuidanceRequested) {
            return DoorMode.VOICE_GUIDED
        }

        return DoorMode.NORMAL
    }

    private fun createCapabilityWindow(
        mode: DoorMode,
        input: DoorSensorInput,
    ): CapabilityWindow {
        return when (mode) {
            DoorMode.NORMAL -> CapabilityWindow(
                capability = "standard_automatic_door_access",
                startsAtMillis = input.observedAtMillis,
                endsAtMillisExclusive =
                    input.observedAtMillis + configuration.normalOpenDurationMillis,
                evidenceStatus = EvidenceStatus.VERIFIED,
                satisfied = input.doorwayClear,
                explanation =
                    "The door provides standard automatic access while the doorway-clear sensor is verified.",
            )

            DoorMode.SLOW_OPEN -> CapabilityWindow(
                capability = "wheelchair_and_mobility_device_access",
                startsAtMillis = input.observedAtMillis,
                endsAtMillisExclusive =
                    input.observedAtMillis + configuration.slowOpenDurationMillis,
                evidenceStatus = EvidenceStatus.VERIFIED,
                satisfied = input.doorwayClear,
                explanation =
                    "The door provides a longer, slower opening window for wheelchair and mobility-device passage.",
            )

            DoorMode.VOICE_GUIDED -> CapabilityWindow(
                capability = "voice_guided_door_access",
                startsAtMillis = input.observedAtMillis,
                endsAtMillisExclusive =
                    input.observedAtMillis + configuration.voiceGuidanceDurationMillis,
                evidenceStatus = EvidenceStatus.VERIFIED,
                satisfied = input.doorwayClear,
                explanation =
                    "The door provides audible orientation and timing guidance while preserving a clear passage.",
            )

            DoorMode.EMI_SHIELDED -> CapabilityWindow(
                capability = "emi_shielded_neural_interface_access",
                startsAtMillis = input.observedAtMillis,
                endsAtMillisExclusive =
                    input.observedAtMillis + configuration.emiShieldedOpenDurationMillis,
                evidenceStatus = EvidenceStatus.VERIFIED,
                satisfied = input.doorwayClear && input.emiShieldIntegrityVerified,
                explanation =
                    "The door provides a verified EMI-shielded opening interval while maintaining a clear physical passage.",
            )

            DoorMode.EMERGENCY_FAIL_SAFE -> CapabilityWindow(
                capability = "emergency_fail_safe_door_access",
                startsAtMillis = input.observedAtMillis,
                endsAtMillisExclusive =
                    input.observedAtMillis + configuration.emergencyFailSafeDurationMillis,
                evidenceStatus = EvidenceStatus.VERIFIED,
                satisfied = true,
                explanation =
                    "The door enters an emergency fail-safe state that preserves a non-locking exit path and requires accessible incident review.",
            )
        }
    }

    private fun transitionExplanation(
        mode: DoorMode,
        input: DoorSensorInput,
    ): String {
        return when (mode) {
            DoorMode.NORMAL ->
                "No higher-priority access or safety signal was active."

            DoorMode.SLOW_OPEN ->
                "A mobility-assistance request was active, so slow-open mode superseded normal mode."

            DoorMode.VOICE_GUIDED ->
                "A voice-guidance request was active and no higher-priority safety or mobility mode was required."

            DoorMode.EMI_SHIELDED ->
                "A shielding request and verified shielding integrity were both present, so EMI-shielded mode superseded other non-emergency modes."

            DoorMode.EMERGENCY_FAIL_SAFE ->
                if (input.emergencySignalActive) {
                    "An emergency signal was active, so emergency fail-safe mode took priority."
                } else if (input.manualReleaseActivated) {
                    "Manual release was activated, so emergency fail-safe mode took priority."
                } else if (input.obstacleDetected) {
                    "An obstacle was detected, so emergency fail-safe mode took priority."
                } else {
                    "Doorway clearance was not verified, so emergency fail-safe mode took priority."
                }
        }
    }
}
