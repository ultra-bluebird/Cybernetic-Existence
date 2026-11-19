package org.augmentedhub.communityresilience

import java.time.Instant

enum class ResourceState {
    ACTIVE,
    REVIEW_REQUIRED,
    EXPIRED,
    RETIRED
}

data class CommunityResource(
    val resourceRef: String,
    val title: String,
    val serviceScope: String,
    val sourceRef: String,
    val lastReviewedAt: Instant,
    val resourceState: ResourceState,
    val accessibilityInformationAvailable: Boolean,
    val languageSupportInformationAvailable: Boolean,
    val humanContactRouteAvailable: Boolean,
    val lowDisclosureAccessAvailable: Boolean,
    val recommendationExplanationAvailable: Boolean,
    val identityInferenceUsed: Boolean = false,
    val personVulnerabilityScoreCreated: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

data class ResourceValidationResult(
    val valid: Boolean,
    val violations: List<String>
)

fun validateCommunityResource(
    resource: CommunityResource,
    now: Instant
): ResourceValidationResult {
    val violations = mutableListOf<String>()

    if (resource.resourceRef.length !in 16..128) {
        violations += "INVALID_RESOURCE_REFERENCE"
    }

    if (resource.title.isBlank()) {
        violations += "RESOURCE_TITLE_REQUIRED"
    }

    if (resource.serviceScope.isBlank()) {
        violations += "SERVICE_SCOPE_REQUIRED"
    }

    if (resource.sourceRef.length !in 16..128) {
        violations += "SOURCE_PROVENANCE_REQUIRED"
    }

    if (!resource.accessibilityInformationAvailable) {
        violations += "ACCESSIBILITY_INFORMATION_REQUIRED"
    }

    if (!resource.lowDisclosureAccessAvailable) {
        violations += "LOW_DISCLOSURE_ACCESS_REQUIRED"
    }

    if (!resource.recommendationExplanationAvailable) {
        violations += "RECOMMENDATION_EXPLANATION_REQUIRED"
    }

    if (resource.identityInferenceUsed) {
        violations += "IDENTITY_INFERENCE_PROHIBITED"
    }

    if (resource.personVulnerabilityScoreCreated) {
        violations += "PERSON_VULNERABILITY_SCORING_PROHIBITED"
    }

    if (resource.externalActionAuthorized) {
        violations += "EXTERNAL_ACTION_AUTHORIZATION_PROHIBITED"
    }

    if (resource.lastReviewedAt.isAfter(now)) {
        violations += "INVALID_REVIEW_TIMESTAMP"
    }

    return ResourceValidationResult(
        valid = violations.isEmpty(),
        violations = violations
    )
}
