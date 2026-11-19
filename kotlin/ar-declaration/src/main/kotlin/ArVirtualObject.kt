package org.augmentedhub.ardeclaration

enum class ArVirtualObjectType {
    VISUAL_OVERLAY,
    TEXT_ANNOTATION,
    AUDIO_CUE,
    HAPTIC_CUE,
    LOCAL_WAYFINDING_MARKER,
    ACCESSIBILITY_GUIDANCE,
    ENVIRONMENTAL_DATA_VISUALIZATION,
    LOCAL_SPATIAL_ANCHOR,
    USER_REQUESTED_CAPTURE_CONTROL
}

enum class ArVirtualObjectAction {
    RENDER,
    ANNOUNCE,
    HIGHLIGHT,
    GUIDE,
    DESCRIBE,
    PAUSE_SESSION,
    END_SESSION,
    REQUEST_LOCAL_EXPORT
}

data class ArVirtualObject(
    val objectRef: String,
    val objectType: ArVirtualObjectType,
    val action: ArVirtualObjectAction,
    val purpose: String,
    val sensorDeclarationsPresent: Boolean,
    val dataReadDeclared: Boolean,
    val dataWrittenDeclared: Boolean,
    val recipientEffectDeclared: Boolean,
    val reversible: Boolean,
    val userVisibleDeclaration: Boolean,
    val localOnly: Boolean,
    val sessionLocalOnly: Boolean,
    val nonArFallbackAvailable: Boolean,
    val identityInferenceAllowed: Boolean = false,
    val bodyInferenceAllowed: Boolean = false,
    val healthInferenceAllowed: Boolean = false,
    val locationInferenceAllowed: Boolean = false,
    val relationshipInferenceAllowed: Boolean = false,
    val matchingUseAllowed: Boolean = false,
    val safetyScoringAllowed: Boolean = false,
    val profileVisibilityChangeAllowed: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

data class ArVirtualObjectValidationResult(
    val valid: Boolean,
    val violations: List<String>
)

fun validateArVirtualObject(
    arObject: ArVirtualObject
): ArVirtualObjectValidationResult {
    val violations = mutableListOf<String>()

    if (arObject.objectRef.length !in 16..128) {
        violations += "INVALID_OBJECT_REFERENCE"
    }

    if (arObject.purpose.isBlank()) {
        violations += "PURPOSE_REQUIRED"
    }

    if (!arObject.sensorDeclarationsPresent) {
        violations += "SENSOR_DECLARATIONS_REQUIRED"
    }

    if (!arObject.dataReadDeclared) {
        violations += "DATA_READ_DECLARATION_REQUIRED"
    }

    if (!arObject.dataWrittenDeclared) {
        violations += "DATA_WRITTEN_DECLARATION_REQUIRED"
    }

    if (!arObject.recipientEffectDeclared) {
        violations += "RECIPIENT_EFFECT_DECLARATION_REQUIRED"
    }

    if (!arObject.reversible) {
        violations += "REVERSIBILITY_REQUIRED"
    }

    if (!arObject.userVisibleDeclaration) {
        violations += "USER_VISIBLE_DECLARATION_REQUIRED"
    }

    if (!arObject.localOnly || !arObject.sessionLocalOnly) {
        violations += "LOCAL_SESSION_BOUNDARY_REQUIRED"
    }

    if (!arObject.nonArFallbackAvailable) {
        violations += "NON_AR_FALLBACK_REQUIRED"
    }

    if (
        arObject.identityInferenceAllowed
        || arObject.bodyInferenceAllowed
        || arObject.healthInferenceAllowed
        || arObject.locationInferenceAllowed
        || arObject.relationshipInferenceAllowed
    ) {
        violations += "INFERENCE_PROHIBITED"
    }

    if (arObject.matchingUseAllowed) {
        violations += "MATCHING_USE_PROHIBITED"
    }

    if (arObject.safetyScoringAllowed) {
        violations += "SAFETY_SCORING_PROHIBITED"
    }

    if (arObject.profileVisibilityChangeAllowed) {
        violations += "PROFILE_VISIBILITY_CHANGE_PROHIBITED"
    }

    if (arObject.externalActionAuthorized) {
        violations += "EXTERNAL_ACTION_AUTHORIZATION_PROHIBITED"
    }

    return ArVirtualObjectValidationResult(
        valid = violations.isEmpty(),
        violations = violations
    )
}
