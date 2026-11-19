package augmentedhub.privacy

import augmentedhub.common.Bounds
import augmentedhub.common.CommonCode
import augmentedhub.common.CommonResult
import augmentedhub.common.ContentBearing
import augmentedhub.common.EvidenceBasis
import augmentedhub.common.EvidenceMarker
import augmentedhub.common.RedactedContent
import augmentedhub.common.ResultState
import java.time.Instant
import java.util.Collections

enum class GazeAlternative {
    KEYBOARD,
    SWITCH,
    POINTER,
    ACCESSIBLE_TEXT_CONTROLS
}

enum class InteractionStage {
    FOCUS,
    PRESELECTION,
    CONFIRMATION,
    RECOVERY
}

enum class HiddenGazeDeclaration {
    NO_GAZE_DEPENDENCY_DECLARED,
    GAZE_DEPENDENCY_DECLARED,
    NOT_ESTABLISHED
}

enum class TaskTestDeclaration {
    PASS_DECLARED,
    FAIL_DECLARED,
    NOT_ESTABLISHED
}

enum class GazeContractIssue {
    INVALID_STRUCTURE,
    CONTRACT_SCOPE_MISMATCH,
    REVIEW_WINDOW_NOT_CURRENT,
    TASK_OUTCOME_MISMATCH,
    TASK_TEST_NOT_ESTABLISHED,
    TASK_TEST_FAILURE_DECLARED,
    HIDDEN_STAGE_MISSING,
    HIDDEN_STAGE_DUPLICATED,
    HIDDEN_STAGE_NOT_ESTABLISHED,
    HIDDEN_GAZE_DEPENDENCY_DECLARED
}

@ContentBearing
class EssentialTaskContract(
    val taskName: String,
    val outcomeContractReference: String,
    val environment: String,
    val configuration: String,
    val permittedAlternative: GazeAlternative
) : RedactedContent()

@ContentBearing
class HiddenGazeReview(
    val stage: InteractionStage,
    val declaration: HiddenGazeDeclaration,
    val evidenceReference: String
) : RedactedContent()

@ContentBearing
class GazeAlternativeDeclaration(
    val taskName: String,
    val outcomeContractReference: String,
    val alternative: GazeAlternative,
    val configuration: String,
    val environment: String,
    val taskTestDeclaration: TaskTestDeclaration,
    val taskTestEvidenceReference: String,
    hiddenGazeReviews: List<HiddenGazeReview>,
    val validFrom: Instant,
    val validUntil: Instant
) : RedactedContent() {
    val schemaVersion = "1"
    val hiddenGazeReviews: List<HiddenGazeReview> =
        Collections.unmodifiableList(hiddenGazeReviews.toList())
}

class GazeAlternativeAssessment(
    @field:EvidenceMarker(EvidenceBasis.DECLARATION_RATIO)
    val declaredHiddenStageCompleteness: Double,

    @field:EvidenceMarker(EvidenceBasis.DECLARATION_BOOLEAN)
    val taskEquivalenceDeclared: Boolean,

    issues: List<GazeContractIssue>
) : RedactedContent() {
    val schemaVersion = "1"
    val issues: List<GazeContractIssue> =
        Collections.unmodifiableList(issues.toList())

    val actualGazeAbsenceVerified: Boolean get() = false
    val actualTaskSuccessVerified: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

object GazeAlternativeReview {
    private fun textAccepted(value: String): Boolean =
        value.isNotBlank() &&
            Bounds.checkString(value).state ==
                ResultState.DECLARED_CHECKS_MET

    fun review(
        task: EssentialTaskContract,
        declaration: GazeAlternativeDeclaration,
        now: Instant
    ): CommonResult<GazeAlternativeAssessment> {
        val textFields = listOf(
            task.taskName,
            task.outcomeContractReference,
            task.environment,
            task.configuration,
            declaration.taskName,
            declaration.outcomeContractReference,
            declaration.configuration,
            declaration.environment,
            declaration.taskTestEvidenceReference
        )

        if (textFields.any { !textAccepted(it) } ||
            declaration.hiddenGazeReviews.size >
                Bounds.MAX_COLLECTION_ELEMENTS ||
            declaration.hiddenGazeReviews.any {
                !textAccepted(it.evidenceReference)
            } ||
            declaration.validUntil <= declaration.validFrom
        ) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "The task-equivalence declaration is structurally invalid.",
                GazeAlternativeAssessment(
                    0.0, false,
                    listOf(GazeContractIssue.INVALID_STRUCTURE)
                )
            )
        }

        val conflicts = mutableListOf<GazeContractIssue>()
        val missing = mutableListOf<GazeContractIssue>()

        if (task.taskName != declaration.taskName ||
            task.environment != declaration.environment ||
            task.configuration != declaration.configuration ||
            task.permittedAlternative != declaration.alternative
        ) {
            conflicts += GazeContractIssue.CONTRACT_SCOPE_MISMATCH
        }

        if (task.outcomeContractReference !=
            declaration.outcomeContractReference
        ) {
            conflicts += GazeContractIssue.TASK_OUTCOME_MISMATCH
        }

        if (now < declaration.validFrom ||
            now >= declaration.validUntil
        ) {
            missing += GazeContractIssue.REVIEW_WINDOW_NOT_CURRENT
        }

        when (declaration.taskTestDeclaration) {
            TaskTestDeclaration.PASS_DECLARED -> Unit
            TaskTestDeclaration.FAIL_DECLARED ->
                conflicts += GazeContractIssue.TASK_TEST_FAILURE_DECLARED
            TaskTestDeclaration.NOT_ESTABLISHED ->
                missing += GazeContractIssue.TASK_TEST_NOT_ESTABLISHED
        }

        var explicitlyReviewedStages = 0

        for (stage in InteractionStage.entries) {
            val records = declaration.hiddenGazeReviews.filter {
                it.stage == stage
            }

            // Preserve adverse evidence even when records conflict.
            if (records.any {
                it.declaration ==
                    HiddenGazeDeclaration.GAZE_DEPENDENCY_DECLARED
            }) {
                conflicts +=
                    GazeContractIssue.HIDDEN_GAZE_DEPENDENCY_DECLARED
            }

            when {
                records.isEmpty() -> {
                    missing += GazeContractIssue.HIDDEN_STAGE_MISSING
                }

                records.size != 1 -> {
                    conflicts += GazeContractIssue.HIDDEN_STAGE_DUPLICATED
                }

                records.single().declaration ==
                    HiddenGazeDeclaration.NOT_ESTABLISHED -> {
                    missing +=
                        GazeContractIssue.HIDDEN_STAGE_NOT_ESTABLISHED
                }

                else -> explicitlyReviewedStages++
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
            "This assessment checks declared task equivalence and hidden-gaze " +
                "review completeness. Sensor behavior and actual task success " +
                "require independent integration testing.",
            GazeAlternativeAssessment(
                explicitlyReviewedStages.toDouble() /
                    InteractionStage.entries.size.toDouble(),
                state == ResultState.DECLARED_CHECKS_MET,
                (conflicts + missing).distinct()
            )
        )
    }
}
