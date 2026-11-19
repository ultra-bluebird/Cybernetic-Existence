package augmentedhub.continuity

import augmentedhub.common.Bounds
import augmentedhub.common.CommonCode
import augmentedhub.common.CommonResult
import augmentedhub.common.EvidenceBasis
import augmentedhub.common.EvidenceMarker
import augmentedhub.common.RedactedContent
import augmentedhub.common.ResultState
import java.time.Instant
import java.util.Collections

enum class ServicePromptClass {
    SERVICE_CHOICE,
    PRESENTATION_PREFERENCE,
    ASSISTANCE_REQUEST,
    PUBLIC_TASK_PARAMETER,
    TRANSACTION_PERSONAL_DATA,
    ACCOUNT_OR_CREDENTIAL,
    RESEARCH_PARTICIPATION,
    PRIVATE_COMPANION_DETAILS,
    PRIVATE_NEURAL_MEDICAL_BIOMETRIC_DETAILS,
    PRIVATE_STATUS_OR_TECHNICAL_INVENTORY,
    UNKNOWN
}

class ServicePromptRecord(
    val promptText: String,
    val classificationDeclared: ServicePromptClass,
    val classificationReviewReference: String,

    @field:EvidenceMarker(EvidenceBasis.DECLARATION_BOOLEAN)
    val blocksOrdinaryAccessDeclared: Boolean
) : RedactedContent()

/**
 * Binds a classification declaration to one exact in-process prompt record.
 * The reference binding is not reviewer authentication.
 */
class PromptResolution(
    val reviewedPrompt: ServicePromptRecord,
    val classificationResolved: ServicePromptClass,
    val reviewReference: String,
    val validFrom: Instant,
    val validUntil: Instant
) : RedactedContent()

enum class PromptAuditIssue {
    UNKNOWN_UNRESOLVED,
    CONFLICTING_RESOLUTIONS,
    RESOLUTION_NOT_CURRENT,
    PRIVATE_DISCLOSURE_PROMPT,
    TRANSACTION_DATA_IN_ORDINARY_PATH,
    CREDENTIAL_PROMPT_IN_ORDINARY_PATH,
    RESEARCH_CONDITIONS_ORDINARY_ACCESS,
    UNBOUND_RESOLUTION
}

class PromptClassificationAssessment(
    classifications: List<ServicePromptClass>,
    issues: List<PromptAuditIssue>,

    @field:EvidenceMarker(EvidenceBasis.DECLARATION_RATIO)
    val declaredClassificationCoverage: Double?
) : RedactedContent() {
    val schemaVersion = "1"
    val resolvedClassifications =
        Collections.unmodifiableList(classifications.toList())
    val issues =
        Collections.unmodifiableList(issues.toList())

    val arbitraryPromptMeaningVerified: Boolean get() = false
    val serviceDenialAuthorized: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

object PromptClassifier {
    private fun validText(value: String): Boolean =
        value.isNotBlank() &&
            Bounds.checkString(value).state ==
                ResultState.DECLARED_CHECKS_MET

    private fun privateClass(value: ServicePromptClass): Boolean =
        value == ServicePromptClass.PRIVATE_COMPANION_DETAILS ||
            value ==
                ServicePromptClass.PRIVATE_NEURAL_MEDICAL_BIOMETRIC_DETAILS ||
            value == ServicePromptClass.PRIVATE_STATUS_OR_TECHNICAL_INVENTORY

    /**
     * Ordinary-service metadata audit, not NLP classification.
     * Prompt answers or private field values are never accepted.
     *
     * UNKNOWN can be resolved only through an exact current review record.
     */
    fun auditOrdinaryService(
        prompts: List<ServicePromptRecord>,
        resolutions: List<PromptResolution>,
        now: Instant
    ): CommonResult<PromptClassificationAssessment> {
        if (prompts.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            resolutions.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            prompts.any {
                !validText(it.promptText) ||
                    !validText(it.classificationReviewReference)
            } ||
            resolutions.any {
                !validText(it.reviewReference) ||
                    it.validUntil <= it.validFrom ||
                    it.classificationResolved == ServicePromptClass.UNKNOWN
            }
        ) {
            return CommonResult(
                ResultState.INVALID_INPUT,
                CommonCode.INPUT_CONTRACT_VIOLATION,
                "The prompt-classification contract is invalid."
            )
        }

        // Repeating the same record would make in-process binding ambiguous.
        for (index in prompts.indices) {
            if ((index + 1 until prompts.size).any {
                prompts[index] === prompts[it]
            }) {
                return CommonResult(
                    ResultState.INVALID_INPUT,
                    CommonCode.INPUT_CONTRACT_VIOLATION,
                    "The same prompt record occurs more than once."
                )
            }
        }

        if (resolutions.any { resolution ->
            prompts.none { it === resolution.reviewedPrompt } ||
                resolution.reviewedPrompt.classificationDeclared !=
                    ServicePromptClass.UNKNOWN
        }) {
            return CommonResult(
                ResultState.NEEDS_REVIEW,
                CommonCode.REVIEW_REQUIRED,
                "A resolution is unbound or targets an already classified prompt.",
                PromptClassificationAssessment(
                    emptyList(),
                    listOf(PromptAuditIssue.UNBOUND_RESOLUTION),
                    null
                )
            )
        }

        if (prompts.isEmpty()) {
            return CommonResult(
                ResultState.NOT_APPLICABLE,
                CommonCode.NO_APPLICABLE_SUBJECT,
                "No ordinary-service prompts were submitted.",
                PromptClassificationAssessment(emptyList(), emptyList(), null)
            )
        }

        val classifications = mutableListOf<ServicePromptClass>()
        val issues = mutableListOf<PromptAuditIssue>()

        for (prompt in prompts) {
            var classification = prompt.classificationDeclared

            if (classification == ServicePromptClass.UNKNOWN) {
                val matching = resolutions.filter {
                    it.reviewedPrompt === prompt
                }

                when {
                    matching.isEmpty() -> {
                        issues += PromptAuditIssue.UNKNOWN_UNRESOLVED
                    }

                    matching.size != 1 -> {
                        issues += PromptAuditIssue.CONFLICTING_RESOLUTIONS
                    }

                    now < matching.single().validFrom ||
                        now >= matching.single().validUntil -> {
                        issues += PromptAuditIssue.RESOLUTION_NOT_CURRENT
                    }

                    else -> {
                        classification =
                            matching.single().classificationResolved
                    }
                }

                // Do not discard adverse proposed classifications when
                // resolutions conflict or expire.
                if (matching.any { privateClass(it.classificationResolved) }) {
                    issues += PromptAuditIssue.PRIVATE_DISCLOSURE_PROMPT
                }
            }

            classifications += classification

            when {
                privateClass(classification) ->
                    issues += PromptAuditIssue.PRIVATE_DISCLOSURE_PROMPT

                classification ==
                    ServicePromptClass.TRANSACTION_PERSONAL_DATA ->
                    issues += PromptAuditIssue.TRANSACTION_DATA_IN_ORDINARY_PATH

                classification == ServicePromptClass.ACCOUNT_OR_CREDENTIAL ->
                    issues += PromptAuditIssue.CREDENTIAL_PROMPT_IN_ORDINARY_PATH

                classification == ServicePromptClass.RESEARCH_PARTICIPATION &&
                    prompt.blocksOrdinaryAccessDeclared ->
                    issues += PromptAuditIssue.RESEARCH_CONDITIONS_ORDINARY_ACCESS
            }
        }

        val adverse = issues.any {
            it == PromptAuditIssue.CONFLICTING_RESOLUTIONS ||
                it == PromptAuditIssue.PRIVATE_DISCLOSURE_PROMPT ||
                it == PromptAuditIssue.TRANSACTION_DATA_IN_ORDINARY_PATH ||
                it == PromptAuditIssue.CREDENTIAL_PROMPT_IN_ORDINARY_PATH ||
                it == PromptAuditIssue.RESEARCH_CONDITIONS_ORDINARY_ACCESS
        }

        val unresolved = classifications.count {
            it == ServicePromptClass.UNKNOWN
        }

        val state = when {
            adverse -> ResultState.NEEDS_REVIEW
            unresolved > 0 -> ResultState.NOT_ESTABLISHED
            else -> ResultState.DECLARED_CHECKS_MET
        }

        return CommonResult(
            state,
            when (state) {
                ResultState.NEEDS_REVIEW -> CommonCode.REVIEW_REQUIRED
                ResultState.NOT_ESTABLISHED -> CommonCode.EVIDENCE_UNAVAILABLE
                else -> CommonCode.DECLARED_LOCAL_CHECKS
            },
            "This audit checks declared prompt categories and exact reviewer " +
                "resolutions. It does not independently classify prose. " +
                "Preserve ordinary assistance while correcting findings.",
            PromptClassificationAssessment(
                classifications,
                issues.distinct(),
                (prompts.size - unresolved).toDouble() / prompts.size
            )
        )
    }
}
