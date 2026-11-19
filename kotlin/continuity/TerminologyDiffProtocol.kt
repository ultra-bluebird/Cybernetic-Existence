package augmentedhub.continuity

import augmentedhub.common.Bounds
import augmentedhub.common.CommonCode
import augmentedhub.common.CommonResult
import augmentedhub.common.RedactedContent
import augmentedhub.common.ResultState
import java.util.Collections

enum class TermChangeKind {
    REWORD, INSERT, DELETE, REORDER
}

enum class TerminologyReviewKind {
    BOUND_CORRECTION,
    EXPLICIT_MIGRATION
}

sealed class TermChange : RedactedContent() {
    class Reword(
        val slot: Int,
        val expectedText: String,
        val replacementText: String
    ) : TermChange()

    class Insert(
        val position: Int,
        val text: String
    ) : TermChange()

    class Delete(
        val slot: Int,
        val expectedText: String
    ) : TermChange()

    class Reorder private constructor(
        order: List<Int>
    ) : TermChange() {
        val order: List<Int> =
            Collections.unmodifiableList(order.toList())

        companion object {
            fun create(order: List<Int>): CommonResult<Reorder> {
                if (order.size > Bounds.MAX_COLLECTION_ELEMENTS) {
                    return CommonResult(
                        ResultState.INVALID_INPUT,
                        CommonCode.INPUT_CONTRACT_VIOLATION,
                        "The reorder declaration exceeds the common bound."
                    )
                }
                return CommonResult(
                    ResultState.DECLARED_CHECKS_MET,
                    CommonCode.DECLARED_LOCAL_CHECKS,
                    "A bounded reorder declaration was constructed.",
                    Reorder(order)
                )
            }
        }
    }
}

class TerminologyProposal internal constructor(
    baseline: List<String>,
    successor: List<String>,
    kinds: List<TermChangeKind>,
    val requiredReviewKind: TerminologyReviewKind
) : RedactedContent() {
    val schemaVersion = "1"
    val baseline = Collections.unmodifiableList(baseline.toList())
    val successor = Collections.unmodifiableList(successor.toList())
    val changeKinds = Collections.unmodifiableList(kinds.toList())

    val automaticallyApplied: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

/**
 * Bound to one immutable in-process proposal.
 * Not a serialized credential or reviewer authentication mechanism.
 */
class BoundTerminologyReview internal constructor(
    internal val proposal: TerminologyProposal,
    val reviewKind: TerminologyReviewKind,
    val reviewReference: String
) : RedactedContent()

object TerminologyDiffProtocol {
    private fun validText(value: String): Boolean =
        value.isNotBlank() &&
            Bounds.checkString(value).state ==
                ResultState.DECLARED_CHECKS_MET

    private fun failure(
        state: ResultState,
        summary: String
    ): CommonResult<TerminologyProposal> =
        CommonResult(
            state,
            when (state) {
                ResultState.INVALID_INPUT ->
                    CommonCode.INPUT_CONTRACT_VIOLATION
                ResultState.NOT_ESTABLISHED ->
                    CommonCode.EVIDENCE_UNAVAILABLE
                ResultState.NOT_APPLICABLE ->
                    CommonCode.NO_APPLICABLE_SUBJECT
                else -> CommonCode.REVIEW_REQUIRED
            },
            summary
        )

    /**
     * Applies explicit operations to an internal candidate only.
     * Caller must not mutate supplied containers while they are snapshotted.
     * No normalization, similarity matching, or inferred migration.
     */
    fun prepare(
        priorTerms: List<String>,
        changes: List<TermChange>
    ): CommonResult<TerminologyProposal> {
        if (priorTerms.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            changes.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            priorTerms.any { !validText(it) }
        ) return failure(
            ResultState.INVALID_INPUT,
            "The terminology input exceeds bounds or contains invalid text."
        )

        if (changes.isEmpty()) return failure(
            ResultState.NOT_APPLICABLE,
            "No terminology changes were proposed."
        )

        val baseline = priorTerms.toList()
        val working = baseline.toMutableList()
        val operations = changes.toList()
        val kinds = mutableListOf<TermChangeKind>()

        for (change in operations) {
            when (change) {
                is TermChange.Reword -> {
                    if (!validText(change.expectedText) ||
                        !validText(change.replacementText)
                    ) return failure(
                        ResultState.INVALID_INPUT, "Rewording text is invalid."
                    )

                    if (change.slot !in working.indices) return failure(
                        ResultState.NOT_ESTABLISHED,
                        "The rewording slot is not established."
                    )

                    if (working[change.slot] != change.expectedText) {
                        return failure(
                            ResultState.NEEDS_REVIEW,
                            "Expected wording does not match the current slot."
                        )
                    }

                    if (change.expectedText == change.replacementText) {
                        return failure(
                            ResultState.INVALID_INPUT,
                            "The rewording operation does not change the wording."
                        )
                    }

                    working[change.slot] = change.replacementText
                    kinds += TermChangeKind.REWORD
                }

                is TermChange.Insert -> {
                    if (!validText(change.text)) return failure(
                        ResultState.INVALID_INPUT, "Insertion text is invalid."
                    )

                    if (change.position !in 0..working.size) return failure(
                        ResultState.NOT_ESTABLISHED,
                        "The insertion position is not established."
                    )

                    if (working.size >= Bounds.MAX_COLLECTION_ELEMENTS) {
                        return failure(
                            ResultState.INVALID_INPUT,
                            "Insertion would exceed the term collection bound."
                        )
                    }

                    working.add(change.position, change.text)
                    kinds += TermChangeKind.INSERT
                }

                is TermChange.Delete -> {
                    if (!validText(change.expectedText)) return failure(
                        ResultState.INVALID_INPUT, "Deletion text is invalid."
                    )

                    if (change.slot !in working.indices) return failure(
                        ResultState.NOT_ESTABLISHED,
                        "The deletion slot is not established."
                    )

                    if (working[change.slot] != change.expectedText) {
                        return failure(
                            ResultState.NEEDS_REVIEW,
                            "Expected deletion wording does not match."
                        )
                    }

                    working.removeAt(change.slot)
                    kinds += TermChangeKind.DELETE
                }

                is TermChange.Reorder -> {
                    val order = change.order
                    if (order.size != working.size) return failure(
                        ResultState.NOT_ESTABLISHED,
                        "The reorder does not describe every current slot."
                    )

                    if (order.any { it !in working.indices }) return failure(
                        ResultState.NOT_ESTABLISHED,
                        "The reorder references an unknown slot."
                    )

                    if (order.toSet().size != order.size) return failure(
                        ResultState.INVALID_INPUT,
                        "The reorder is not a complete permutation."
                    )

                    val reordered = order.map { working[it] }
                    working.clear()
                    working.addAll(reordered)
                    kinds += TermChangeKind.REORDER
                }
            }

            if (Bounds.checkPayload(working).state !=
                ResultState.DECLARED_CHECKS_MET
            ) return failure(
                ResultState.INVALID_INPUT,
                "The proposed terminology exceeds aggregate bounds."
            )
        }

        val reviewKind = if (kinds.all { it == TermChangeKind.REWORD })
            TerminologyReviewKind.BOUND_CORRECTION
        else TerminologyReviewKind.EXPLICIT_MIGRATION

        return CommonResult(
            ResultState.NEEDS_REVIEW,
            CommonCode.REVIEW_REQUIRED,
            "An exact successor candidate was prepared. " +
                "The original terminology was not modified.",
            TerminologyProposal(baseline, working, kinds, reviewKind)
        )
    }

    /**
     * Records a local review declaration, not reviewer authentication.
     */
    fun declareReview(
        proposal: TerminologyProposal,
        reviewKind: TerminologyReviewKind,
        reviewReference: String
    ): CommonResult<BoundTerminologyReview> {
        if (!validText(reviewReference)) return CommonResult(
            ResultState.INVALID_INPUT,
            CommonCode.INPUT_CONTRACT_VIOLATION,
            "The review reference is invalid."
        )

        if (reviewKind != proposal.requiredReviewKind) return CommonResult(
            ResultState.NEEDS_REVIEW,
            CommonCode.REVIEW_REQUIRED,
            "The proposed changes require a different review contract."
        )

        return CommonResult(
            ResultState.DECLARED_CHECKS_MET,
            CommonCode.DECLARED_LOCAL_CHECKS,
            "A review declaration was bound to this exact local proposal.",
            BoundTerminologyReview(proposal, reviewKind, reviewReference)
        )
    }

    /**
     * Returns a reviewed application candidate. Does not mutate a store.
     * Same-proposal reference is meaningful only in this process.
     */
    fun candidateAfterReview(
        currentTerms: List<String>,
        proposal: TerminologyProposal,
        review: BoundTerminologyReview
    ): CommonResult<List<String>> {
        if (currentTerms.size > Bounds.MAX_COLLECTION_ELEMENTS ||
            currentTerms.any { !validText(it) }
        ) return CommonResult(
            ResultState.INVALID_INPUT,
            CommonCode.INPUT_CONTRACT_VIOLATION,
            "The current terminology snapshot is invalid."
        )

        if (review.proposal !== proposal ||
            review.reviewKind != proposal.requiredReviewKind
        ) return CommonResult(
            ResultState.NEEDS_REVIEW,
            CommonCode.REVIEW_REQUIRED,
            "The review does not bind this exact proposal."
        )

        if (currentTerms.toList() != proposal.baseline) return CommonResult(
            ResultState.NEEDS_REVIEW,
            CommonCode.REVIEW_REQUIRED,
            "The active baseline changed. Prepare and review a new proposal."
        )

        return CommonResult(
            ResultState.DECLARED_CHECKS_MET,
            CommonCode.DECLARED_LOCAL_CHECKS,
            "The exact reviewed successor is available for local application. " +
                "No persistent store or external system was changed.",
            proposal.successor
        )
    }
}
