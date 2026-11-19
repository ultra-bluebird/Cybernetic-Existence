package org.augmentedhub.ardeclaration

enum class ArOutputMode {
    VISUAL,
    TEXT,
    AUDIO_DESCRIPTION,
    HAPTIC,
    HIGH_CONTRAST,
    REDUCED_MOTION
}

enum class ArInputMode {
    TOUCH,
    KEYBOARD,
    SWITCH,
    VOICE_OPTIONAL,
    GESTURE_OPTIONAL,
    NON_AR_INTERFACE
}

data class ArAccessibilityContract(
    val objectRef: String,
    val equivalentNonArPathAvailable: Boolean,
    val equivalentPurposePreserved: Boolean,
    val outputModes: Set<ArOutputMode>,
    val inputModes: Set<ArInputMode>,
    val plainLanguageModeAvailable: Boolean,
    val pacingControlAvailable: Boolean,
    val pauseControlAvailable: Boolean,
    val replayAvailable: Boolean,
    val criticalInstructionChunkingAvailable: Boolean,
    val stopControlAlwaysVisible: Boolean,
    val stopControlImmediate: Boolean,
    val stopControlConfirmationRequired: Boolean = false,
    val stopControlPenaltyAllowed: Boolean = false,
    val cameraTrackingRequired: Boolean = false,
    val handTrackingRequired: Boolean = false,
    val eyeTrackingRequired: Boolean = false,
    val headMovementRequired: Boolean = false,
    val speechRequired: Boolean = false,
    val identityInferenceAllowed: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

data class ArAccessibilityValidationResult(
    val valid: Boolean,
    val violations: List<String>
)

fun validateArAccessibilityContract(
    contract: ArAccessibilityContract
): ArAccessibilityValidationResult {
    val violations = mutableListOf<String>()

    val requiredOutputModes = setOf(
        ArOutputMode.VISUAL,
        ArOutputMode.TEXT,
        ArOutputMode.AUDIO_DESCRIPTION,
        ArOutputMode.HAPTIC,
        ArOutputMode.HIGH_CONTRAST,
        ArOutputMode.REDUCED_MOTION
    )

    val requiredInputModes = setOf(
        ArInputMode.TOUCH,
        ArInputMode.KEYBOARD,
        ArInputMode.SWITCH,
        ArInputMode.NON_AR_INTERFACE
    )

    if (contract.objectRef.length !in 16..128) {
        violations += "INVALID_OBJECT_REFERENCE"
    }

    if (!contract.equivalentNonArPathAvailable) {
        violations += "NON_AR_PATH_REQUIRED"
    }

    if (!contract.equivalentPurposePreserved) {
        violations += "EQUIVALENT_PURPOSE_REQUIRED"
    }

    if (!contract.outputModes.containsAll(requiredOutputModes)) {
        violations += "MULTIMODAL_OUTPUT_REQUIRED"
    }

    if (!contract.inputModes.containsAll(requiredInputModes)) {
        violations += "MOTION_AGNOSTIC_INPUT_REQUIRED"
    }

    if (!contract.plainLanguageModeAvailable) {
        violations += "PLAIN_LANGUAGE_MODE_REQUIRED"
    }

    if (!contract.pacingControlAvailable) {
        violations += "PACING_CONTROL_REQUIRED"
    }

    if (!contract.pauseControlAvailable) {
        violations += "PAUSE_CONTROL_REQUIRED"
    }

    if (!contract.replayAvailable) {
        violations += "REPLAY_CONTROL_REQUIRED"
    }

    if (!contract.criticalInstructionChunkingAvailable) {
        violations += "INSTRUCTION_CHUNKING_REQUIRED"
    }

    if (!contract.stopControlAlwaysVisible) {
        violations += "VISIBLE_STOP_CONTROL_REQUIRED"
    }

    if (!contract.stopControlImmediate) {
        violations += "IMMEDIATE_STOP_CONTROL_REQUIRED"
    }

    if (contract.stopControlConfirmationRequired) {
        violations += "STOP_CONFIRMATION_PROHIBITED"
    }

    if (contract.stopControlPenaltyAllowed) {
        violations += "STOP_PENALTY_PROHIBITED"
    }

    if (
        contract.cameraTrackingRequired
        || contract.handTrackingRequired
        || contract.eyeTrackingRequired
        || contract.headMovementRequired
        || contract.speechRequired
    ) {
        violations += "REQUIRED_PHYSICAL_OR_SPEECH_INPUT_PROHIBITED"
    }

    if (contract.identityInferenceAllowed) {
        violations += "IDENTITY_INFERENCE_PROHIBITED"
    }

    if (contract.externalActionAuthorized) {
        violations += "EXTERNAL_ACTION_AUTHORIZATION_PROHIBITED"
    }

    return ArAccessibilityValidationResult(
        valid = violations.isEmpty(),
        violations = violations
    )
}
