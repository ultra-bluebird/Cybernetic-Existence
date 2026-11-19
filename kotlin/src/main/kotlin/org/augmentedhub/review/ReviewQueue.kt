package org.augmentedhub.review

import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

enum class ReviewStatus {
    PENDING,
    APPROVED,
    DENIED,
    EXPIRED,
    CANCELLED
}

enum class FinalDecision {
    PENDING_REVIEW,
    APPROVED,
    DENIED
}

data class ReviewRequest(
    val reviewKey: String,
    val decisionType: String,
    val submittedAt: Instant,
    val expiresAt: Instant,
    val status: ReviewStatus,
    val finalDecision: FinalDecision,
    val explanationCode: String,
    val accessibleExplanation: String,
    val appealPath: String,
    val reviewerReference: String? = null,
    val reviewedAt: Instant? = null
)

class ReviewQueue(
    private val clock: Clock = Clock.systemUTC(),
    private val onTimeout: (ReviewRequest) -> Unit = {}
) : AutoCloseable {
    private val requests = ConcurrentHashMap<String, ReviewRequest>()

    private val scheduler: ScheduledExecutorService =
        Executors.newSingleThreadScheduledExecutor { runnable ->
            Thread(runnable, "review-timeout-monitor").apply {
                isDaemon = true
            }
        }

    init {
        scheduler.scheduleAtFixedRate(
            { expirePendingReviews() },
            1L,
            1L,
            TimeUnit.SECONDS
        )
    }

    fun submit(
        reviewKey: String,
        decisionType: String,
        timeout: Duration,
        explanationCode: String,
        accessibleExplanation: String,
        appealPath: String
    ): ReviewRequest {
        require(reviewKey.isNotBlank()) {
            "reviewKey must not be blank."
        }

        require(decisionType.isNotBlank()) {
            "decisionType must not be blank."
        }

        require(!timeout.isZero && !timeout.isNegative) {
            "timeout must be greater than zero."
        }

        require(explanationCode.isNotBlank()) {
            "explanationCode must not be blank."
        }

        require(accessibleExplanation.length >= 12) {
            "accessibleExplanation must contain a useful explanation."
        }

        require(appealPath.length >= 12) {
            "appealPath must contain a usable appeal route."
        }

        val now = clock.instant()

        val request = ReviewRequest(
            reviewKey = reviewKey,
            decisionType = decisionType,
            submittedAt = now,
            expiresAt = now.plus(timeout),
            status = ReviewStatus.PENDING,
            finalDecision = FinalDecision.PENDING_REVIEW,
            explanationCode = explanationCode,
            accessibleExplanation = accessibleExplanation,
            appealPath = appealPath
        )

        require(requests.putIfAbsent(reviewKey, request) == null) {
            "reviewKey already exists."
        }

        return request
    }

    fun approve(
        reviewKey: String,
        reviewerReference: String
    ): ReviewRequest {
        require(reviewerReference.isNotBlank()) {
            "reviewerReference must not be blank."
        }

        return requests.compute(reviewKey) { _, current ->
            requireNotNull(current) {
                "Review request does not exist."
            }

            val now = clock.instant()

            require(current.status == ReviewStatus.PENDING) {
                "Only pending reviews may be approved."
            }

            require(!now.isAfter(current.expiresAt)) {
                "Expired reviews cannot be approved."
            }

            current.copy(
                status = ReviewStatus.APPROVED,
                finalDecision = FinalDecision.APPROVED,
                reviewerReference = reviewerReference,
                reviewedAt = now
            )
        }!!
    }

    fun deny(
        reviewKey: String,
        reviewerReference: String
    ): ReviewRequest {
        require(reviewerReference.isNotBlank()) {
            "reviewerReference must not be blank."
        }

        return requests.compute(reviewKey) { _, current ->
            requireNotNull(current) {
                "Review request does not exist."
            }

            require(current.status == ReviewStatus.PENDING) {
                "Only pending reviews may be denied."
            }

            current.copy(
                status = ReviewStatus.DENIED,
                finalDecision = FinalDecision.DENIED,
                reviewerReference = reviewerReference,
                reviewedAt = clock.instant()
            )
        }!!
    }

    fun get(reviewKey: String): ReviewRequest? = requests[reviewKey]

    private fun expirePendingReviews() {
        val now = clock.instant()

        requests.forEach { (key, request) ->
            if (
                request.status == ReviewStatus.PENDING &&
                !now.isBefore(request.expiresAt)
            ) {
                val expired = request.copy(
                    status = ReviewStatus.EXPIRED,
                    finalDecision = FinalDecision.DENIED,
                    explanationCode = "HUMAN_REVIEW_TIMEOUT_FAIL_CLOSED",
                    accessibleExplanation =
                        "This request was not approved before its review deadline. " +
                            "It is denied until a person reviews a new or corrected request."
                )

                if (requests.replace(key, request, expired)) {
                    onTimeout(expired)
                }
            }
        }
    }

    override fun close() {
        scheduler.shutdownNow()
    }
}
