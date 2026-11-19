package augmentedhub.privacy

import augmentedhub.common.Bounds
import augmentedhub.common.CommonCode
import augmentedhub.common.CommonResult
import augmentedhub.common.ContentBearing
import augmentedhub.common.RedactedContent
import augmentedhub.common.ResultState
import java.time.Instant
import java.util.Collections

enum class TraceEvidenceClass {
    SYNTHETIC_REPLAY,
    APPROVED_AGGREGATE_REPLAY,
    RESTRICTED_SOURCE_REFERENCE,
    NOT_REPRODUCIBLE_WITHIN_SCOPE
}

enum class TraceExecutionOutcome {
    NOT_EXECUTED,
    REPORTED_MATCH,
    REPORTED_MISMATCH,
    REFERENCE_ONLY,
    OUTSIDE_SCOPE
}

enum class TraceEvidenceIssue {
    INVALID_RECORD,
    EVIDENCE_CLASS_MISSING,
    REQUIRED_REFERENCE_MISSING,
    REVIEW_WINDOW_NOT_CURRENT,
    OUTCOME_CLASS_CONFLICT,
    EXPECTED_REFERENCE_MISMATCH
}

/**
 * Does not contain raw observations or replay parameters.
 *
 * modelReference identifies a reviewed model/version contract.
 * expectedFindingReference and reportedFindingReference identify reviewed
 * outcome records, not participant identities.
 *
 * References are declarations and are not resolved by this component.
 */
@ContentBearing
class TraceFindingRecord(
    val findingLabel: String,
    val evidenceClass: TraceEvidenceClass?,
    val executionOutcome: TraceExecutionOutcome,
    val modelReference: String?,
    val sourceScopeReviewReference: String?,
    val executionReviewReference: String?,
    val expectedFindingReference: String?,
    val reportedFindingReference: String?,
    val limitationStatement: String,
    val validFrom: Instant,
    val validUntil: Instant
) : RedactedContent()

/**
 * No evidence class can silently upgrade to full empirical reproduction.
 */
class TraceFindingAssessment(
    val evidenceClass: TraceEvidenceClass?,
    val executionOutcome: TraceExecutionOutcome,
    issues: List<TraceEvidenceIssue>
) : RedactedContent() {
    val schemaVersion = "1"
    val issues: List<TraceEvidenceIssue> =
        Collections.unmodifiableList(issues.toList())

    val originalEmpiricalCollectionReproduced: Boolean get() = false
    val sourceAuthenticityVerified: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

object TraceEvidenceReview {
    private fun textAccepted(value: String?): Boolean =
        value != null &&
            value.isNotBlank() &&
            Bounds.checkString(value).state ==
                ResultState.DECLARED_CHECKS_MET

    private fun optionalTextAccepted(value: String?): Boolean =
        value == null || textAccepted(value)

    fun review(
        record: TraceFindingRecord,
        now: Instant
    ): CommonResult<TraceFindingAssessment> {
        val references = listOf(
            record.modelReference,
            record.sourceScopeReviewReference,
            record.executionReviewReference,
            record.expectedFindingReference,
            record.reportedFindingReference
        )

        if (!textAccepted(record.findingLabel) ||
            !textAccepted(record.limitationStatement) ||
            references.any { !optionalTextAccepted(it) } ||
            record.validUntil <= record.validFrom
        ) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "The trace-finding contract is invalid.",
                TraceFindingAssessment(
                    record.evidenceClass,
                    record.executionOutcome,
                    listOf(TraceEvidenceIssue.INVALID_RECORD)
                )
            )
        }

        val evidenceClass = record.evidenceClass
        if (evidenceClass == null) {
            return CommonResult(
                ResultState.NOT_ESTABLISHED,
                CommonCode.EVIDENCE_UNAVAILABLE,
                "The finding has no explicit evidence class.",
                TraceFindingAssessment(
                    null,
                    record.executionOutcome,
                    listOf(TraceEvidenceIssue.EVIDENCE_CLASS_MISSING)
                )
            )
        }

        val missing = mutableListOf<TraceEvidenceIssue>()
        val conflicts = mutableListOf<TraceEvidenceIssue>()

        if (now < record.validFrom || now >= record.validUntil) {
            missing += TraceEvidenceIssue.REVIEW_WINDOW_NOT_CURRENT
        }

        when (evidenceClass) {
            TraceEvidenceClass.SYNTHETIC_REPLAY,
            TraceEvidenceClass.APPROVED_AGGREGATE_REPLAY -> {
                if (!textAccepted(record.modelReference) ||
                    !textAccepted(record.sourceScopeReviewReference)
                ) {
                    missing += TraceEvidenceIssue.REQUIRED_REFERENCE_MISSING
                }

                when (record.executionOutcome) {
                    TraceExecutionOutcome.NOT_EXECUTED -> {
                        missing += TraceEvidenceIssue.REQUIRED_REFERENCE_MISSING
                    }

                    TraceExecutionOutcome.REPORTED_MATCH,
                    TraceExecutionOutcome.REPORTED_MISMATCH -> {
                        if (!textAccepted(record.executionReviewReference) ||
                            !textAccepted(record.expectedFindingReference) ||
                            !textAccepted(record.reportedFindingReference)
                        ) {
                            missing += TraceEvidenceIssue.REQUIRED_REFERENCE_MISSING
                        } else {
                            val same =
                                record.expectedFindingReference ==
                                    record.reportedFindingReference

                            if ((record.executionOutcome ==
                                    TraceExecutionOutcome.REPORTED_MATCH) != same
                            ) {
                                conflicts +=
                                    TraceEvidenceIssue.EXPECTED_REFERENCE_MISMATCH
                            }
                        }

                        if (record.executionOutcome ==
                            TraceExecutionOutcome.REPORTED_MISMATCH
                        ) {
                            conflicts +=
                                TraceEvidenceIssue.EXPECTED_REFERENCE_MISMATCH
                        }
                    }

                    TraceExecutionOutcome.REFERENCE_ONLY,
                    TraceExecutionOutcome.OUTSIDE_SCOPE -> {
                        conflicts += TraceEvidenceIssue.OUTCOME_CLASS_CONFLICT
                    }
                }
            }

            TraceEvidenceClass.RESTRICTED_SOURCE_REFERENCE -> {
                if (!textAccepted(record.sourceScopeReviewReference)) {
                    missing += TraceEvidenceIssue.REQUIRED_REFERENCE_MISSING
                }
                if (record.executionOutcome !=
                    TraceExecutionOutcome.REFERENCE_ONLY
                ) {
                    conflicts += TraceEvidenceIssue.OUTCOME_CLASS_CONFLICT
                }
            }

            TraceEvidenceClass.NOT_REPRODUCIBLE_WITHIN_SCOPE -> {
                if (record.executionOutcome !=
                    TraceExecutionOutcome.OUTSIDE_SCOPE
                ) {
                    conflicts += TraceEvidenceIssue.OUTCOME_CLASS_CONFLICT
                }
            }
        }

        val state = when {
            conflicts.isNotEmpty() -> ResultState.NEEDS_REVIEW
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
            when (evidenceClass) {
                TraceEvidenceClass.SYNTHETIC_REPLAY ->
                    "This assessment concerns declared synthetic replay only."
                TraceEvidenceClass.APPROVED_AGGREGATE_REPLAY ->
                    "This assessment concerns declared aggregate replay only."
                TraceEvidenceClass.RESTRICTED_SOURCE_REFERENCE ->
                    "A restricted evidence reference is not reproduction."
                TraceEvidenceClass.NOT_REPRODUCIBLE_WITHIN_SCOPE ->
                    "The finding remains explicitly outside the reproducible scope."
            },
            TraceFindingAssessment(
                evidenceClass,
                record.executionOutcome,
                (conflicts + missing).distinct()
            )
        )
    }

    /**
     * Counts classes without dropping unclassified findings.
     * This checks classification metadata, not successful reproduction.
     */
    fun classificationCoverage(
        records: List<TraceFindingRecord>
    ): CommonResult<Double> {
        if (records.size > Bounds.MAX_COLLECTION_ELEMENTS) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "The trace corpus exceeds the common collection bound."
            )
        }

        if (records.isEmpty()) {
            return CommonResult(
                ResultState.NOT_APPLICABLE,
                CommonCode.NO_APPLICABLE_SUBJECT,
                "No findings were supplied for classification."
            )
        }

        val classified = records.count { it.evidenceClass != null }

        return CommonResult(
            if (classified == records.size)
                ResultState.DECLARED_CHECKS_MET
            else ResultState.NOT_ESTABLISHED,
            if (classified == records.size)
                CommonCode.DECLARED_LOCAL_CHECKS
            else CommonCode.EVIDENCE_UNAVAILABLE,
            "This fraction measures explicit evidence-class presence only.",
            classified.toDouble() / records.size.toDouble()
        )
    }
}
