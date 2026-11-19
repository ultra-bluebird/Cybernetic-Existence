package org.augmentedhub.advisory

import java.time.Instant

sealed interface ClassifiedOutput {
    val createdAt: Instant
    val explanation: String
    val evidenceDigest: String
}

sealed interface AdvisoryOutput : ClassifiedOutput {
    val reviewState: ReviewState
}

enum class ReviewState {
    READY_FOR_HUMAN_REVIEW,
    INSUFFICIENT_EVIDENCE,
    CONFLICT_REVIEW_REQUIRED,
    SUPERSEDED
}

data class FogAdvisory(
    override val createdAt: Instant,
    override val explanation: String,
    override val evidenceDigest: String,
    override val reviewState: ReviewState,
    val fogBelief: Double,
    val fogPlausibility: Double,
    val conflictMass: Double
) : AdvisoryOutput {
    init {
        require(fogBelief in 0.0..1.0)
        require(fogPlausibility in 0.0..1.0)
        require(fogBelief <= fogPlausibility)
        require(conflictMass in 0.0..1.0)
        require(explanation.isNotBlank())
        require(evidenceDigest.isNotBlank())
    }
}

data class AdvisoryPresentation(
    val title: String,
    val accessibleSummary: String,
    val advisory: AdvisoryOutput
) {
    init {
        require(title.isNotBlank())
        require(accessibleSummary.isNotBlank())
    }
}

interface AdvisoryPublisher {
    fun publish(presentation: AdvisoryPresentation): PublicationReceipt
}

data class PublicationReceipt(
    val publishedAt: Instant,
    val publicationDigest: String
) {
    init {
        require(publicationDigest.isNotBlank())
    }
}
