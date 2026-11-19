package org.augmentedhub.governance

import java.time.Instant

enum class ProtectedRecordState {
    CREATED,
    ACTIVE_USE,
    NEEDS_REVIEW,
    UNDER_REVIEW,
    CORRECTED,
    RETRACTED,
    SUPERSEDED,
    CONFLICTED,
    ARCHIVED,
    EXPIRED
}

enum class ProtectedRecordClass {
    CONSENT_RECORD,
    CONSENT_REVOCATION,
    APPEAL_RECORD,
    CORRECTION_RECORD,
    ACCESSIBILITY_REPORT,
    COMMUNITY_OBSERVATION,
    PRIVACY_RELEASE_REVIEW,
    SAFETY_REVIEW,
    POLICY_RECORD
}

enum class ReviewLevel {
    AUTOMATED_STATE_MARKING_ONLY,
    COMMUNITY_REVIEW,
    AUTHORIZED_HUMAN_REVIEW,
    ACCESSIBILITY_REVIEW,
    PRIVACY_REVIEW,
    SAFETY_REVIEW,
    CROSS_DOMAIN_REVIEW
}

data class LifecycleTransitionRequest(
    val recordReference: String,
    val recordClass: ProtectedRecordClass,
    val priorState: ProtectedRecordState,
    val nextState: ProtectedRecordState,
    val actorRole: String,
    val reasonCode: String,
    val policyVersion: String,
    val reviewLevel: ReviewLevel,
    val occurredAt: Instant,
    val evidenceReferences: Set<String> = emptySet(),
    val resolutionRecordReference: String? = null,
    val supersedingRecordReference: String? = null
) {
    init {
        require(recordReference.isNotBlank())
        require(actorRole.isNotBlank())
        require(reasonCode.isNotBlank())
        require(policyVersion.isNotBlank())
    }
}

data class LifecycleTransitionDecision(
    val allowed: Boolean,
    val requiredReview: ReviewLevel?,
    val reasonCodes: Set<String>,
    val originalRecordPreserved: Boolean = true
)

object ProtectedRecordLifecycle {
    fun evaluate(request: LifecycleTransitionRequest): LifecycleTransitionDecision {
        if (request.priorState == ProtectedRecordState.ARCHIVED) {
            return deny("archived_record_cannot_return_to_active_state")
        }

        if (request.nextState == ProtectedRecordState.CREATED) {
            return deny("lifecycle_cannot_return_to_created")
        }

        if (request.priorState == request.nextState) {
            return deny("state_transition_requires_distinct_states")
        }

        return when (request.priorState to request.nextState) {
            ProtectedRecordState.CREATED to ProtectedRecordState.ACTIVE_USE ->
                requireReview(
                    request,
                    ReviewLevel.AUTHORIZED_HUMAN_REVIEW,
                    "protected_record_activation_requires_review"
                )

            ProtectedRecordState.CREATED to ProtectedRecordState.NEEDS_REVIEW ->
                allow("incomplete_or_uncertain_record_requires_review")

            ProtectedRecordState.CREATED to ProtectedRecordState.CONFLICTED ->
                requireReview(
                    request,
                    ReviewLevel.AUTHORIZED_HUMAN_REVIEW,
                    "created_record_has_material_conflict"
                )

            ProtectedRecordState.ACTIVE_USE to ProtectedRecordState.NEEDS_REVIEW ->
                allow("active_record_requires_reassessment")

            ProtectedRecordState.ACTIVE_USE to ProtectedRecordState.CORRECTED ->
                requireEvidenceAndReview(
                    request,
                    ReviewLevel.AUTHORIZED_HUMAN_REVIEW,
                    "correction_requires_rationale_and_evidence"
                )

            ProtectedRecordState.ACTIVE_USE to ProtectedRecordState.RETRACTED ->
                requireReview(
                    request,
                    ReviewLevel.AUTHORIZED_HUMAN_REVIEW,
                    "retraction_requires_review_authority"
                )

            ProtectedRecordState.ACTIVE_USE to ProtectedRecordState.SUPERSEDED ->
                requireSupersedingRecordAndReview(request)

            ProtectedRecordState.ACTIVE_USE to ProtectedRecordState.CONFLICTED ->
                requireReview(
                    request,
                    ReviewLevel.AUTHORIZED_HUMAN_REVIEW,
                    "material_conflict_requires_human_review"
                )

            ProtectedRecordState.ACTIVE_USE to ProtectedRecordState.EXPIRED ->
                allow("declared_validity_period_ended")

            ProtectedRecordState.NEEDS_REVIEW to ProtectedRecordState.UNDER_REVIEW ->
                requireReview(
                    request,
                    request.reviewLevel,
                    "review_process_started"
                )

            ProtectedRecordState.CONFLICTED to ProtectedRecordState.UNDER_REVIEW ->
                requireReview(
                    request,
                    ReviewLevel.AUTHORIZED_HUMAN_REVIEW,
                    "conflict_resolution_requires_human_review"
                )

            ProtectedRecordState.UNDER_REVIEW to ProtectedRecordState.ACTIVE_USE ->
                requireResolutionAndReview(
                    request,
                    ReviewLevel.AUTHORIZED_HUMAN_REVIEW,
                    "active_use_requires_resolution_record"
                )

            ProtectedRecordState.UNDER_REVIEW to ProtectedRecordState.CORRECTED ->
                requireEvidenceAndReview(
                    request,
                    ReviewLevel.AUTHORIZED_HUMAN_REVIEW,
                    "review_correction_requires_evidence"
                )

            ProtectedRecordState.UNDER_REVIEW to ProtectedRecordState.RETRACTED ->
                requireReview(
                    request,
                    ReviewLevel.AUTHORIZED_HUMAN_REVIEW,
                    "review_retraction_requires_authority"
                )

            ProtectedRecordState.UNDER_REVIEW to ProtectedRecordState.SUPERSEDED ->
                requireSupersedingRecordAndReview(request)

            ProtectedRecordState.EXPIRED to ProtectedRecordState.UNDER_REVIEW ->
                requireReview(
                    request,
                    ReviewLevel.AUTHORIZED_HUMAN_REVIEW,
                    "expired_record_revalidation_requires_review"
                )

            ProtectedRecordState.SUPERSEDED to ProtectedRecordState.ARCHIVED,
            ProtectedRecordState.RETRACTED to ProtectedRecordState.ARCHIVED,
            ProtectedRecordState.EXPIRED to ProtectedRecordState.ARCHIVED,
            ProtectedRecordState.CONFLICTED to ProtectedRecordState.ARCHIVED,
            ProtectedRecordState.CORRECTED to ProtectedRecordState.ARCHIVED,
            ProtectedRecordState.NEEDS_REVIEW to ProtectedRecordState.ARCHIVED ->
                allow("protected_record_retained_for_audit")

            else -> deny("transition_not_permitted_for_protected_record")
        }
    }

    private fun requireSupersedingRecordAndReview(
        request: LifecycleTransitionRequest
    ): LifecycleTransitionDecision {
        if (request.supersedingRecordReference.isNullOrBlank()) {
            return deny("supersession_requires_successor_reference")
        }

        return requireReview(
            request,
            ReviewLevel.AUTHORIZED_HUMAN_REVIEW,
            "supersession_requires_review"
        )
    }

    private fun requireResolutionAndReview(
        request: LifecycleTransitionRequest,
        requiredReview: ReviewLevel,
        reason: String
    ): LifecycleTransitionDecision {
        if (request.resolutionRecordReference.isNullOrBlank()) {
            return deny("resolution_record_required")
        }

        return requireReview(request, requiredReview, reason)
    }

    private fun requireEvidenceAndReview(
        request: LifecycleTransitionRequest,
        requiredReview: ReviewLevel,
        reason: String
    ): LifecycleTransitionDecision {
        if (request.evidenceReferences.isEmpty()) {
            return deny("evidence_reference_required")
        }

        return requireReview(request, requiredReview, reason)
    }

    private fun requireReview(
        request: LifecycleTransitionRequest,
        requiredReview: ReviewLevel,
        reason: String
    ): LifecycleTransitionDecision {
        if (request.reviewLevel == ReviewLevel.AUTOMATED_STATE_MARKING_ONLY) {
            return deny("human_review_level_required")
        }

        return LifecycleTransitionDecision(
            allowed = true,
            requiredReview = requiredReview,
            reasonCodes = setOf(reason)
        )
    }

    private fun allow(reason: String): LifecycleTransitionDecision {
        return LifecycleTransitionDecision(
            allowed = true,
            requiredReview = null,
            reasonCodes = setOf(reason)
        )
    }

    private fun deny(reason: String): LifecycleTransitionDecision {
        return LifecycleTransitionDecision(
            allowed = false,
            requiredReview = null,
            reasonCodes = setOf(reason)
        )
    }
}
