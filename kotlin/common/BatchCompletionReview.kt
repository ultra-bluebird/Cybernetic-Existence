package augmentedhub.common

import java.util.Collections

enum class CompletionBatch {
    PRIVACY,
    PROFILE_AND_TERMINOLOGY,
    DISCRETION_AND_NON_INTERFERENCE
}

enum class DeliveredSection {
    DIRECT_ANSWER,
    MODEL_AND_UNITS,
    COMPLETE_SOURCE,
    COMPLETE_TESTS,
    INTEGRATION_NOTES,
    KNOWN_LIMITATIONS,
    DESIGN_ASSESSMENT
}

enum class CompletionTestCategory {
    INVALID_INPUT,
    BOUNDARY_INPUT,
    STALE_OR_EXPIRED_EVIDENCE,
    CONFLICT_OR_DUPLICATE,
    OUT_OF_SCOPE_REQUEST,
    DIAGNOSTIC_REDACTION,
    EXTERNAL_AUTHORITY,
    CLOCK_FAULT,
    LATCH_OR_RESTART
}

class TestCategoryDisposition(
    val category: CompletionTestCategory,
    val testReference: String?,
    val nonApplicableRationale: String?
) : RedactedContent()

class TopicDelivery(
    val topic: String,
    sections: Set<DeliveredSection>,
    val sourcePath: String,
    val testPath: String,
    tests: List<TestCategoryDisposition>,
    val compilation: VerificationState,
    val testExecution: VerificationState
) : RedactedContent() {
    val sections = Collections.unmodifiableSet(sections.toSet())
    val tests = Collections.unmodifiableList(tests.toList())
}

class BatchCompletionAssessment(
    missingTopics: Set<String>,
    findings: List<String>,
    unvalidatedTopics: Set<String>
) : RedactedContent() {
    val schemaVersion = "1"
    val missingTopics =
        Collections.unmodifiableSet(missingTopics.toSet())
    val findings =
        Collections.unmodifiableList(findings.toList())
    val locallyUnvalidatedTopics =
        Collections.unmodifiableSet(unvalidatedTopics.toSet())

    val sourceFilesInspected: Boolean get() = false
    val deploymentApproved: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

object BatchCompletionReview {
    private fun expected(batch: CompletionBatch): Set<String> = when (batch) {
        CompletionBatch.PRIVACY -> setOf(
            "research-trace",
            "gaze-minimization",
            "local-processing-boundary",
            "wayfinding-minimization"
        )
        CompletionBatch.PROFILE_AND_TERMINOLOGY -> setOf(
            "profile-portability",
            "terminology-continuity",
            "interface-continuity"
        )
        CompletionBatch.DISCRETION_AND_NON_INTERFERENCE -> setOf(
            "companion-discretion",
            "non-interference",
            "research-adapter"
        )
    }

    private fun validText(value: String): Boolean =
        value.isNotBlank() &&
            Bounds.checkString(value).state ==
                ResultState.DECLARED_CHECKS_MET

    private fun validSourcePath(path: String, test: Boolean): Boolean {
        val prefix = if (test) "tests/kotlin/" else "kotlin/"
        return path.startsWith(prefix) &&
            path.endsWith(".kt") &&
            path.length <= 512 &&
            '\\' !in path &&
            path.split("/").all {
                it.isNotEmpty() && it != "." && it != ".." &&
                    Regex("[A-Za-z0-9_.-]+").matches(it)
            }
    }

    fun review(
        batch: CompletionBatch,
        deliveries: List<TopicDelivery>,
        coordinationUpdatesDeclared: Set<String>
    ): CommonResult<BatchCompletionAssessment> {
        val required = expected(batch)
        val requiredUpdates = setOf(
            "file-ledger",
            "schema-registry",
            "red-team-traceability",
            "session-state"
        )

        if (deliveries.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            deliveries.any {
                it.topic !in required ||
                    !validSourcePath(it.sourcePath, false) ||
                    !validSourcePath(it.testPath, true) ||
                    it.tests.size > Bounds.MAX_COLLECTION_ELEMENTS
            } ||
            deliveries.map { it.topic }.toSet().size != deliveries.size ||
            coordinationUpdatesDeclared.any { !validText(it) }
        ) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "The batch-delivery evidence contract is invalid."
            )
        }

        val missingTopics = required - deliveries.map { it.topic }.toSet()
        val findings = mutableListOf<String>()
        val unvalidated = mutableSetOf<String>()

        for (delivery in deliveries) {
            if (delivery.sections != DeliveredSection.entries.toSet()) {
                findings += "required_delivery_section_missing"
            }

            for (category in CompletionTestCategory.entries) {
                val records = delivery.tests.filter {
                    it.category == category
                }

                if (records.size != 1) {
                    findings += "test_category_missing_or_duplicated"
                    continue
                }

                val record = records.single()
                val tested = record.testReference?.let(::validText) == true
                val excluded =
                    record.nonApplicableRationale?.let(::validText) == true

                // Exactly one disposition is required.
                if (tested == excluded) {
                    findings += "test_category_disposition_invalid"
                }
            }

            if (delivery.compilation != VerificationState.REPORTED_PASS ||
                delivery.testExecution != VerificationState.REPORTED_PASS
            ) {
                unvalidated += delivery.topic
            }

            if (delivery.compilation == VerificationState.REPORTED_FAIL ||
                delivery.testExecution == VerificationState.REPORTED_FAIL
            ) {
                findings += "local_validation_failure_reported"
            }
        }

        if (!coordinationUpdatesDeclared.containsAll(requiredUpdates)) {
            findings += "coordination_update_missing"
        }

        val state = when {
            findings.isNotEmpty() -> ResultState.NEEDS_REVIEW
            missingTopics.isNotEmpty() -> ResultState.NOT_ESTABLISHED
            else -> ResultState.DECLARED_CHECKS_MET
        }

        return CommonResult(
            state,
            when (state) {
                ResultState.NEEDS_REVIEW -> CommonCode.REVIEW_REQUIRED
                ResultState.NOT_ESTABLISHED -> CommonCode.EVIDENCE_UNAVAILABLE
                else -> CommonCode.DECLARED_LOCAL_CHECKS
            },
            "This result checks supplied delivery metadata. A complete " +
                "delivery may still be locally unvalidated.",
            BatchCompletionAssessment(
                missingTopics, findings.distinct(), unvalidated
            )
        )
    }
}
