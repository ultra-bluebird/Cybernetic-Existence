package augmentedhub.common

import java.util.Collections

enum class FindingDisposition {
    ADDRESSED,
    DEFERRED,
    ACCEPTED_AS_LIMITATION
}

enum class FindingVerification {
    NOT_EXECUTED,
    REPORTED_PASS,
    REPORTED_FAIL
}

class FindingRecord(
    val topic: String,
    val finding: String,
    val disposition: FindingDisposition,
    val rationale: String,
    val implementationReference: String?,
    val testOrReviewReference: String?,
    val verification: FindingVerification,
    val nextActionOrBoundary: String
) : RedactedContent()

class TraceabilityAssessment(
    missingCells: Set<Pair<String, String>>,
    conflictingCells: Set<Pair<String, String>>,
    unverifiedAddressedCells: Set<Pair<String, String>>
) : RedactedContent() {
    val schemaVersion = "1"

    val missingCells =
        Collections.unmodifiableSet(missingCells.toSet())
    val conflictingCells =
        Collections.unmodifiableSet(conflictingCells.toSet())
    val unverifiedAddressedCells =
        Collections.unmodifiableSet(unverifiedAddressedCells.toSet())

    val findingClosureVerified: Boolean get() = false
    val deploymentReadinessEvaluated: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

/**
 * Reviews a bounded declared topic-by-finding matrix.
 * Does not inspect source, execute tests, or decide deployment readiness.
 */
object TraceabilityReview {
    private fun validText(value: String): Boolean =
        value.isNotBlank() &&
            Bounds.checkString(value).state ==
                ResultState.DECLARED_CHECKS_MET

    private fun validOptional(value: String?): Boolean =
        value == null || validText(value)

    fun review(
        expectedTopics: Set<String>,
        expectedFindings: Set<String>,
        records: List<FindingRecord>
    ): CommonResult<TraceabilityAssessment> {
        val expectedCells =
            expectedTopics.size.toLong() * expectedFindings.size.toLong()

        if (expectedTopics.isEmpty() || expectedFindings.isEmpty() ||
            expectedCells > Bounds.MAX_COLLECTION_ELEMENTS ||
            records.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            (expectedTopics + expectedFindings).any { !validText(it) } ||
            records.any {
                it.topic !in expectedTopics ||
                    it.finding !in expectedFindings ||
                    !validText(it.rationale) ||
                    !validText(it.nextActionOrBoundary) ||
                    !validOptional(it.implementationReference) ||
                    !validOptional(it.testOrReviewReference) ||
                    (it.disposition == FindingDisposition.ADDRESSED &&
                        (it.implementationReference == null ||
                            it.testOrReviewReference == null))
            }
        ) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "The traceability matrix is invalid or exceeds common bounds."
            )
        }

        val grouped = records.groupBy { it.topic to it.finding }
        val missing = mutableSetOf<Pair<String, String>>()
        val conflicts = mutableSetOf<Pair<String, String>>()
        val unverified = mutableSetOf<Pair<String, String>>()
        var reportedFailure = false

        for (topic in expectedTopics) {
            for (finding in expectedFindings) {
                val cell = topic to finding
                val entries = grouped[cell].orEmpty()

                if (entries.isEmpty()) {
                    missing += cell
                    continue
                }

                // Duplicate cells are ambiguous even if text appears identical.
                if (entries.size != 1) conflicts += cell

                if (entries.any {
                    it.verification == FindingVerification.REPORTED_FAIL
                }) reportedFailure = true

                if (entries.any {
                    it.disposition == FindingDisposition.ADDRESSED &&
                        it.verification != FindingVerification.REPORTED_PASS
                }) {
                    unverified += cell
                }
            }
        }

        val state = when {
            conflicts.isNotEmpty() || reportedFailure ->
                ResultState.NEEDS_REVIEW
            missing.isNotEmpty() -> ResultState.NOT_ESTABLISHED
            else -> ResultState.DECLARED_CHECKS_MET
        }

        return CommonResult(
            state,
            when (state) {
                ResultState.NEEDS_REVIEW -> CommonCode.REVIEW_REQUIRED
                ResultState.NOT_ESTABLISHED -> CommonCode.EVIDENCE_UNAVAILABLE
                else -> CommonCode.DECLARED_LOCAL_CHECKS
            },
            "This result checks disposition coverage and conflicts. " +
                "Unverified addressed findings remain explicitly unverified.",
            TraceabilityAssessment(missing, conflicts, unverified)
        )
    }
}
