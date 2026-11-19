package augmentedhub.fog

import java.time.Duration
import java.time.Instant
import java.util.UUID

enum class FogQueueState {
    RECEIVED,
    LOCAL_PENDING,
    HUMAN_REVIEW_REQUIRED,
    HUMAN_DECISION_RECORDED,
    RETAINED_WITHHELD,
    EXPIRED
}

enum class MissingEvidenceCategory {
    UNMODELED_MEDIA,
    INSUFFICIENT_COVERAGE,
    TEMPORAL_CONFLICT,
    RESOLUTION_MISMATCH,
    SOURCE_QUALITY_GAP,
    OTHER
}

data class FogThresholds(
    val uncertaintyThreshold: Double,
    val minimumKnowledge: Double,
    val maximumRisk: Double,
    val localQueueCapacity: Int,
    val localRetention: Duration
) {
    init {
        require(uncertaintyThreshold in 0.0..1.0)
        require(minimumKnowledge in 0.0..1.0)
        require(maximumRisk in 0.0..1.0)
        require(localQueueCapacity > 0)
        require(!localRetention.isNegative && !localRetention.isZero)
    }
}

data class FogAssessment(
    val mediaUncertainty: Double,
    val knowledgeFactor: Double,
    val riskScore: Double,
    val aggregationWindow: String,
    val appliedHexResolution: Int,
    val sourceHexResolution: Int,
    val missingEvidenceCategory: MissingEvidenceCategory
) {
    init {
        require(mediaUncertainty in 0.0..1.0)
        require(knowledgeFactor in 0.0..1.0)
        require(riskScore in 0.0..1.0)
        require(appliedHexResolution >= 0)
        require(sourceHexResolution >= 0)
        require(aggregationWindow.isNotBlank())
    }

    fun requiresHumanEscalation(thresholds: FogThresholds): Boolean =
        mediaUncertainty > thresholds.uncertaintyThreshold ||
            knowledgeFactor < thresholds.minimumKnowledge ||
            riskScore > thresholds.maximumRisk
}

data class ReviewerSignature(
    val reviewerReference: String,
    val signedAt: Instant,
    val decision: ReviewDecision
) {
    init {
        require(reviewerReference.isNotBlank())
    }
}

enum class ReviewDecision {
    CONTINUE_WITHHOLDING,
    RELEASE_FOR_FURTHER_PROCESSING
}

data class FogQueueEntry(
    val queueId: UUID = UUID.randomUUID(),
    val mediaReference: String,
    val assessment: FogAssessment,
    val state: FogQueueState = FogQueueState.RECEIVED,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = createdAt,
    val reviewerSignature: ReviewerSignature? = null,
    val statusReason: String = "received"
) {
    init {
        require(mediaReference.isNotBlank())
    }

    fun route(
        thresholds: FogThresholds,
        currentLocalQueueSize: Int,
        at: Instant = Instant.now()
    ): FogQueueEntry {
        require(currentLocalQueueSize >= 0)

        return if (assessment.requiresHumanEscalation(thresholds)) {
            copy(
                state = FogQueueState.HUMAN_REVIEW_REQUIRED,
                updatedAt = at,
                statusReason = "threshold-qualified escalation"
            )
        } else {
            require(currentLocalQueueSize < thresholds.localQueueCapacity) {
                "Local FOG queue is at capacity; bounded retention requires explicit operational handling."
            }

            copy(
                state = FogQueueState.LOCAL_PENDING,
                updatedAt = at,
                statusReason = "low-risk unmodeled media retained locally"
            )
        }
    }

    fun recordHumanDecision(
        signature: ReviewerSignature,
        at: Instant = Instant.now()
    ): FogQueueEntry {
        require(state == FogQueueState.HUMAN_REVIEW_REQUIRED) {
            "A human decision can only be recorded for a human-review entry."
        }

        return copy(
            state = FogQueueState.HUMAN_DECISION_RECORDED,
            updatedAt = at,
            reviewerSignature = signature,
            statusReason = "human signature recorded"
        )
    }

    fun applyHumanDecision(at: Instant = Instant.now()): FogQueueEntry {
        require(state == FogQueueState.HUMAN_DECISION_RECORDED) {
            "Automatic clearing is prohibited: a recorded human signature is required."
        }

        val signature = requireNotNull(reviewerSignature)
        return when (signature.decision) {
            ReviewDecision.CONTINUE_WITHHOLDING -> copy(
                state = FogQueueState.RETAINED_WITHHELD,
                updatedAt = at,
                statusReason = "human reviewer retained withholding"
            )

            ReviewDecision.RELEASE_FOR_FURTHER_PROCESSING -> copy(
                state = FogQueueState.RETAINED_WITHHELD,
                updatedAt = at,
                statusReason = "human reviewer authorized release; downstream handling remains separate"
            )
        }
    }

    fun expireIfPastRetention(
        thresholds: FogThresholds,
        at: Instant = Instant.now()
    ): FogQueueEntry {
        if (state != FogQueueState.LOCAL_PENDING) return this

        return if (Duration.between(createdAt, at) >= thresholds.localRetention) {
            copy(
                state = FogQueueState.EXPIRED,
                updatedAt = at,
                statusReason = "local bounded-retention period elapsed"
            )
        } else {
            this
        }
    }
}
