package org.augmentedhub.cyboquatic

import java.time.Instant

enum class ReviewReason {
    UNKNOWN_PROFILE,
    LOW_CONFIDENCE,
    SCOPE_MISMATCH,
    EVIDENCE_MISSING,
    CLASSIFIER_REVISION_UNAPPROVED,
    MANUAL_ESCALATION
}

enum class QueueStatus {
    OPEN,
    ASSIGNED,
    RESOLVED,
    WITHDRAWN
}

data class MediaReviewRequest(
    val observationId: Long,
    val proposedClass: String,
    val classifierRevisionId: String,
    val confidenceScore: Double,
    val contextDescription: String,
    val reason: ReviewReason,
    val createdAt: Instant
) {
    init {
        require(observationId > 0L) { "observationId must be positive" }
        require(proposedClass in setOf("known_safe", "review_required", "restricted", "unknown")) {
            "proposedClass is not recognized"
        }
        require(classifierRevisionId.isNotBlank() && classifierRevisionId.length <= 128) {
            "classifierRevisionId must be non-empty and at most 128 characters"
        }
        require(confidenceScore.isFinite() && confidenceScore in 0.0..1.0) {
            "confidenceScore must be finite and in [0, 1]"
        }
        require(contextDescription.isNotBlank() && contextDescription.length <= 2_000) {
            "contextDescription must be non-empty and at most 2,000 characters"
        }
    }
}

data class ReviewDecision(
    val observationId: Long,
    val status: QueueStatus,
    val resolution: String,
    val decidedAt: Instant
) {
    init {
        require(observationId > 0L) { "observationId must be positive" }
        require(status == QueueStatus.RESOLVED || status == QueueStatus.WITHDRAWN) {
            "decision status must finalize the queue item"
        }
        require(resolution.isNotBlank() && resolution.length <= 4_000) {
            "resolution must be non-empty and at most 4,000 characters"
        }
    }
}

object FogOperatorReviewPolicy {
    private const val KnownSafeMinimumConfidence = 0.95

    fun requiresReview(
        proposedClass: String,
        confidenceScore: Double,
        classifierRevisionApproved: Boolean,
        evidenceComplete: Boolean,
        scopeMatches: Boolean
    ): ReviewReason? {
        require(confidenceScore.isFinite() && confidenceScore in 0.0..1.0) {
            "confidenceScore must be finite and in [0, 1]"
        }

        if (!classifierRevisionApproved) {
            return ReviewReason.CLASSIFIER_REVISION_UNAPPROVED
        }

        if (!evidenceComplete) {
            return ReviewReason.EVIDENCE_MISSING
        }

        if (!scopeMatches) {
            return ReviewReason.SCOPE_MISMATCH
        }

        if (proposedClass != "known_safe") {
            return ReviewReason.UNKNOWN_PROFILE
        }

        if (confidenceScore < KnownSafeMinimumConfidence) {
            return ReviewReason.LOW_CONFIDENCE
        }

        return null
    }
}
