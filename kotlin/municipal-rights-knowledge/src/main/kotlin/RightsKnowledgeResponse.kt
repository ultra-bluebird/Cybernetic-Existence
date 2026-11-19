package org.augmentedhub.rightsknowledge

enum class ReviewState {
    SOURCE_CAPTURED,
    PLAIN_LANGUAGE_REVIEWED,
    JURISDICTION_REVIEW_PENDING,
    RETIRED
}

data class RightsKnowledgeResponse(
    val responseRef: String,
    val jurisdictionScope: String,
    val serviceContext: String,
    val sourceRef: String,
    val sourceEffectiveDate: String?,
    val reviewState: ReviewState,
    val plainLanguageExplanation: String,
    val limitations: String,
    val keyboardOperationAvailable: Boolean,
    val screenReaderCompatibleOutputAvailable: Boolean,
    val plainLanguageModeAvailable: Boolean,
    val languageSelectionUserControlled: Boolean,
    val humanFallbackRouteAvailable: Boolean,
    val correctionRouteAvailable: Boolean,
    val individualLegalOutcomeClaimed: Boolean = false,
    val eligibilityDecisionClaimed: Boolean = false,
    val userIdentityInferenceUsed: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

data class RightsKnowledgeValidationResult(
    val valid: Boolean,
    val violations: List<String>
)

fun validateRightsKnowledgeResponse(
    response: RightsKnowledgeResponse
): RightsKnowledgeValidationResult {
    val violations = mutableListOf<String>()

    if (response.responseRef.length !in 16..128) {
        violations += "INVALID_RESPONSE_REFERENCE"
    }

    if (response.jurisdictionScope.isBlank()) {
        violations += "JURISDICTION_SCOPE_REQUIRED"
    }

    if (response.serviceContext.isBlank()) {
        violations += "SERVICE_CONTEXT_REQUIRED"
    }

    if (response.sourceRef.length !in 16..128) {
        violations += "SOURCE_PROVENANCE_REQUIRED"
    }

    if (response.plainLanguageExplanation.isBlank()) {
        violations += "PLAIN_LANGUAGE_EXPLANATION_REQUIRED"
    }

    if (response.limitations.isBlank()) {
        violations += "LIMITATIONS_REQUIRED"
    }

    if (!response.keyboardOperationAvailable) {
        violations += "KEYBOARD_OPERATION_UNAVAILABLE"
    }

    if (!response.screenReaderCompatibleOutputAvailable) {
        violations += "SCREEN_READER_OUTPUT_UNAVAILABLE"
    }

    if (!response.plainLanguageModeAvailable) {
        violations += "PLAIN_LANGUAGE_MODE_UNAVAILABLE"
    }

    if (!response.languageSelectionUserControlled) {
        violations += "LANGUAGE_SELECTION_NOT_USER_CONTROLLED"
    }

    if (!response.humanFallbackRouteAvailable) {
        violations += "HUMAN_FALLBACK_UNAVAILABLE"
    }

    if (!response.correctionRouteAvailable) {
        violations += "CORRECTION_ROUTE_UNAVAILABLE"
    }

    if (response.individualLegalOutcomeClaimed) {
        violations += "INDIVIDUAL_LEGAL_OUTCOME_CLAIM_PROHIBITED"
    }

    if (response.eligibilityDecisionClaimed) {
        violations += "ELIGIBILITY_DECISION_CLAIM_PROHIBITED"
    }

    if (response.userIdentityInferenceUsed) {
        violations += "USER_IDENTITY_INFERENCE_PROHIBITED"
    }

    if (response.externalActionAuthorized) {
        violations += "EXTERNAL_ACTION_AUTHORIZATION_PROHIBITED"
    }

    return RightsKnowledgeValidationResult(
        valid = violations.isEmpty(),
        violations = violations
    )
}
