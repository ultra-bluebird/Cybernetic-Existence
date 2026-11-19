package org.augmentedhub.events

import java.time.Instant

@JvmInline
value class AggregateReference(val value: String) {
    init {
        require(value.isNotBlank())
        require(value.length <= 256)
    }
}

@JvmInline
value class EventDigest(val value: String) {
    init {
        require(value.matches(Regex("^[A-Fa-f0-9]{64}$")))
    }
}

enum class EventType {
    CASE_OPENED,
    CORRECTION_REQUESTED,
    EVIDENCE_ATTACHED,
    REVIEW_REQUESTED,
    REVIEW_COMPLETED,
    DECISION_ISSUED,
    APPEAL_REQUESTED,
    CASE_CLOSED,
    CASE_REOPENED
}

data class EventSubmission(
    val aggregateReference: AggregateReference,
    val expectedSequence: Long,
    val eventType: EventType,
    val canonicalPayload: ByteArray,
    val purposeReference: String,
    val policyRevision: String,
    val clientObservedAt: Instant?
) {
    init {
        require(expectedSequence >= 0)
        require(canonicalPayload.isNotEmpty())
        require(canonicalPayload.size <= 65_536)
        require(purposeReference.isNotBlank())
        require(policyRevision.isNotBlank())
    }
}

data class AcceptedEvent(
    val eventReference: String,
    val aggregateReference: AggregateReference,
    val sequence: Long,
    val eventType: EventType,
    val eventDigest: EventDigest,
    val previousEventDigest: EventDigest?,
    val recordedAt: Instant,
    val validationRecordReference: String,
    val auditRecordReference: String
) {
    init {
        require(eventReference.isNotBlank())
        require(sequence >= 0)
        require(validationRecordReference.isNotBlank())
        require(auditRecordReference.isNotBlank())
    }
}

sealed interface EventSubmissionResult {
    data class Accepted(val event: AcceptedEvent) : EventSubmissionResult

    data class Rejected(
        val reasonCode: String,
        val accessibleExplanation: String,
        val correctionPathReference: String
    ) : EventSubmissionResult {
        init {
            require(reasonCode.isNotBlank())
            require(accessibleExplanation.isNotBlank())
            require(correctionPathReference.isNotBlank())
        }
    }

    data class ReviewRequired(
        val reasonCode: String,
        val accessibleExplanation: String,
        val correctionPathReference: String
    ) : EventSubmissionResult {
        init {
            require(reasonCode.isNotBlank())
            require(accessibleExplanation.isNotBlank())
            require(correctionPathReference.isNotBlank())
        }
    }
}

interface EventApi {
    fun submit(submission: EventSubmission): EventSubmissionResult
}
