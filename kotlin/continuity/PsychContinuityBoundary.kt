package augmentedhub.continuity

import augmentedhub.common.Bounds
import augmentedhub.common.CommonCode
import augmentedhub.common.CommonResult
import augmentedhub.common.RedactedContent
import augmentedhub.common.ResultState
import java.time.Instant
import java.util.Collections

enum class ContinuityEvaluationTarget {
    PRESENTATION_PREFERENCE_PRESERVATION,
    TERMINOLOGY_CONTINUITY,
    PACING_FIDELITY,
    DRAFT_CONTINUITY,
    CORRECTION_AVAILABILITY,

    DIAGNOSIS,
    EMOTIONAL_STATE,
    COMPETENCE,
    FATIGUE,
    COGNITIVE_LOAD,
    INTERNAL_PSYCHOLOGICAL_STATE
}

enum class InterfaceFinding {
    PRESERVED_REPORTED,
    FAILURE_REPORTED,
    NOT_ESTABLISHED
}

enum class ContinuityBoundaryIssue {
    INVALID_CONTRACT,
    OUT_OF_SCOPE_TARGET,
    UNREQUESTED_EVIDENCE,
    DUPLICATE_EVIDENCE,
    MISSING_EVIDENCE,
    EVIDENCE_NOT_CURRENT,
    INTERFACE_FAILURE_REPORTED
}

class InterfaceContinuityEvidence(
    val target: ContinuityEvaluationTarget,
    val finding: InterfaceFinding,
    val environmentReference: String,
    val reviewReference: String,
    val validFrom: Instant,
    val validUntil: Instant
) : RedactedContent()

class InterfaceContinuityAssessment(
    preserved: Set<ContinuityEvaluationTarget>,
    failed: Set<ContinuityEvaluationTarget>,
    unresolved: Set<ContinuityEvaluationTarget>,
    issues: List<ContinuityBoundaryIssue>
) : RedactedContent() {
    val schemaVersion = "1"

    val reportedPreservedProperties =
        Collections.unmodifiableSet(preserved.toSet())
    val reportedFailedProperties =
        Collections.unmodifiableSet(failed.toSet())
    val unresolvedProperties =
        Collections.unmodifiableSet(unresolved.toSet())
    val issues =
        Collections.unmodifiableList(issues.toList())

    val internalPsychologicalStateEvaluated: Boolean get() = false
    val diagnosisPerformed: Boolean get() = false
    val interfaceBehaviorIndependentlyVerified: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

object PsychContinuityBoundary {
    private val allowed = setOf(
        ContinuityEvaluationTarget.PRESENTATION_PREFERENCE_PRESERVATION,
        ContinuityEvaluationTarget.TERMINOLOGY_CONTINUITY,
        ContinuityEvaluationTarget.PACING_FIDELITY,
        ContinuityEvaluationTarget.DRAFT_CONTINUITY,
        ContinuityEvaluationTarget.CORRECTION_AVAILABILITY
    )

    private fun validText(value: String): Boolean =
        value.isNotBlank() &&
            Bounds.checkString(value).state ==
                ResultState.DECLARED_CHECKS_MET

    fun review(
        requestedTargets: Set<ContinuityEvaluationTarget>,
        evidence: List<InterfaceContinuityEvidence>,
        expectedEnvironmentReference: String,
        now: Instant
    ): CommonResult<InterfaceContinuityAssessment> {
        if (requestedTargets.isEmpty() ||
            evidence.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            !validText(expectedEnvironmentReference) ||
            evidence.any {
                !validText(it.environmentReference) ||
                    !validText(it.reviewReference) ||
                    it.validUntil <= it.validFrom
            }
        ) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "The interface-continuity evidence contract is invalid."
            )
        }

        // Reject the whole assessment, including mixed-scope requests.
        if (requestedTargets.any { it !in allowed } ||
            evidence.any { it.target !in allowed }
        ) {
            return CommonResult(
                ResultState.NEEDS_REVIEW,
                CommonCode.REVIEW_REQUIRED,
                "This request crosses the interface-only boundary. " +
                    "No personal assessment was performed.",
                InterfaceContinuityAssessment(
                    emptySet(), emptySet(), emptySet(),
                    listOf(ContinuityBoundaryIssue.OUT_OF_SCOPE_TARGET)
                )
            )
        }

        if (evidence.any { it.target !in requestedTargets }) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "Evidence was supplied for an unrequested interface property.",
                InterfaceContinuityAssessment(
                    emptySet(), emptySet(), requestedTargets,
                    listOf(ContinuityBoundaryIssue.UNREQUESTED_EVIDENCE)
                )
            )
        }

        val preserved = mutableSetOf<ContinuityEvaluationTarget>()
        val failed = mutableSetOf<ContinuityEvaluationTarget>()
        val unresolved = mutableSetOf<ContinuityEvaluationTarget>()
        val issues = mutableListOf<ContinuityBoundaryIssue>()

        for (target in requestedTargets) {
            val records = evidence.filter { it.target == target }

            // An adverse report is not lost when other records conflict.
            if (records.any {
                it.finding == InterfaceFinding.FAILURE_REPORTED
            }) {
                failed += target
                issues += ContinuityBoundaryIssue.INTERFACE_FAILURE_REPORTED
            }

            if (records.size != 1) {
                unresolved += target
                issues += if (records.isEmpty())
                    ContinuityBoundaryIssue.MISSING_EVIDENCE
                else ContinuityBoundaryIssue.DUPLICATE_EVIDENCE
                continue
            }

            val record = records.single()

            if (record.environmentReference != expectedEnvironmentReference ||
                now < record.validFrom || now >= record.validUntil
            ) {
                unresolved += target
                issues += ContinuityBoundaryIssue.EVIDENCE_NOT_CURRENT
                continue
            }

            when (record.finding) {
                InterfaceFinding.PRESERVED_REPORTED ->
                    if (target !in failed) preserved += target
                InterfaceFinding.FAILURE_REPORTED -> Unit
                InterfaceFinding.NOT_ESTABLISHED -> {
                    unresolved += target
                    issues += ContinuityBoundaryIssue.MISSING_EVIDENCE
                }
            }
        }

        val state = when {
            failed.isNotEmpty() ||
                ContinuityBoundaryIssue.DUPLICATE_EVIDENCE in issues ->
                ResultState.NEEDS_REVIEW
            unresolved.isNotEmpty() -> ResultState.NOT_ESTABLISHED
            else -> ResultState.DECLARED_CHECKS_MET
        }

        return CommonResult(
            state,
            when (state) {
                ResultState.NEEDS_REVIEW -> CommonCode.REVIEW_REQUIRED
                ResultState.NOT_ESTABLISHED -> CommonCode.EVIDENCE_UNAVAILABLE
                else -> CommonCode.DECLARED_LOCAL_CHECKS
            },
            "This assessment concerns reported interface properties only. " +
                "It does not evaluate internal psychological continuity, " +
                "health, emotion, competence, fatigue, or cognitive load.",
            InterfaceContinuityAssessment(
                preserved, failed, unresolved, issues.distinct()
            )
        )
    }
}
