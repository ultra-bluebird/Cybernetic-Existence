package org.augmentedhub.corrections

import java.time.Instant

enum class CorrectionState {
    DRAFT,
    SUBMITTED,
    ACKNOWLEDGED,
    REVIEW_REQUIRED,
    UNDER_REVIEW,
    EVIDENCE_REQUESTED,
    DECISION_ISSUED,
    APPEAL_AVAILABLE,
    HUMAN_ASSISTANCE,
    CLOSED
}

enum class CorrectionEvent {
    SUBMIT,
    ISSUE_RECEIPT,
    REQUIRE_HUMAN_REVIEW,
    ASSIGN_REVIEW,
    REQUEST_EVIDENCE,
    PROVIDE_EVIDENCE,
    ISSUE_DECISION,
    OPEN_APPEAL,
    REQUEST_APPEAL,
    REQUEST_HUMAN_ASSISTANCE,
    RESUME_SELF_SERVICE,
    CLOSE_CASE
}

data class CorrectionCase(
    val caseReference: String,
    val state: CorrectionState,
    val version: Long,
    val updatedAt: Instant,
    val policyRevision: String,
    val lastEventDigest: String?
) {
    init {
        require(caseReference.isNotBlank())
        require(version >= 0)
        require(policyRevision.isNotBlank())
    }
}

sealed interface TransitionResult {
    data class Accepted(
        val nextCase: CorrectionCase,
        val requiredReceipt: Boolean,
        val accessibleExplanation: String
    ) : TransitionResult

    data class Rejected(
        val reasonCode: String,
        val accessibleExplanation: String,
        val humanAssistanceAvailable: Boolean
    ) : TransitionResult
}

object CorrectionLifecycleStateMachine {
    fun transition(
        current: CorrectionCase,
        event: CorrectionEvent,
        now: Instant
    ): TransitionResult {
        val nextState = when (current.state to event) {
            CorrectionState.DRAFT to CorrectionEvent.SUBMIT ->
                CorrectionState.SUBMITTED

            CorrectionState.DRAFT to CorrectionEvent.REQUEST_HUMAN_ASSISTANCE ->
                CorrectionState.HUMAN_ASSISTANCE

            CorrectionState.HUMAN_ASSISTANCE to CorrectionEvent.RESUME_SELF_SERVICE ->
                CorrectionState.DRAFT

            CorrectionState.HUMAN_ASSISTANCE to CorrectionEvent.SUBMIT ->
                CorrectionState.SUBMITTED

            CorrectionState.SUBMITTED to CorrectionEvent.ISSUE_RECEIPT ->
                CorrectionState.ACKNOWLEDGED

            CorrectionState.SUBMITTED to CorrectionEvent.REQUIRE_HUMAN_REVIEW ->
                CorrectionState.REVIEW_REQUIRED

            CorrectionState.ACKNOWLEDGED to CorrectionEvent.ASSIGN_REVIEW ->
                CorrectionState.UNDER_REVIEW

            CorrectionState.REVIEW_REQUIRED to CorrectionEvent.ASSIGN_REVIEW ->
                CorrectionState.UNDER_REVIEW

            CorrectionState.UNDER_REVIEW to CorrectionEvent.REQUEST_EVIDENCE ->
                CorrectionState.EVIDENCE_REQUESTED

            CorrectionState.EVIDENCE_REQUESTED to CorrectionEvent.PROVIDE_EVIDENCE ->
                CorrectionState.UNDER_REVIEW

            CorrectionState.UNDER_REVIEW to CorrectionEvent.ISSUE_DECISION ->
                CorrectionState.DECISION_ISSUED

            CorrectionState.DECISION_ISSUED to CorrectionEvent.OPEN_APPEAL ->
                CorrectionState.APPEAL_AVAILABLE

            CorrectionState.APPEAL_AVAILABLE to CorrectionEvent.REQUEST_APPEAL ->
                CorrectionState.UNDER_REVIEW

            CorrectionState.APPEAL_AVAILABLE to CorrectionEvent.CLOSE_CASE ->
                CorrectionState.CLOSED

            else -> {
                return TransitionResult.Rejected(
                    reasonCode = "INVALID_STATE_TRANSITION",
                    accessibleExplanation = "This action is not available in the current correction stage. "
                        + "Human assistance remains available.",
                    humanAssistanceAvailable = true
                )
            }
        }

        val receiptRequired = event == CorrectionEvent.SUBMIT

        return TransitionResult.Accepted(
            nextCase = current.copy(
                state = nextState,
                version = current.version + 1,
                updatedAt = now
            ),
            requiredReceipt = receiptRequired,
            accessibleExplanation = explanationFor(nextState)
        )
    }

    private fun explanationFor(state: CorrectionState): String = when (state) {
        CorrectionState.SUBMITTED ->
            "Your correction request has been submitted and is awaiting a receipt."

        CorrectionState.ACKNOWLEDGED ->
            "Your correction request was received. A receipt confirms submission, not the outcome of review."

        CorrectionState.REVIEW_REQUIRED ->
            "Your correction request requires accessible human review before it can proceed."

        CorrectionState.UNDER_REVIEW ->
            "Your correction request is under review."

        CorrectionState.EVIDENCE_REQUESTED ->
            "Additional information was requested. You may ask for accessible assistance or explain why you cannot provide it."

        CorrectionState.DECISION_ISSUED ->
            "A decision was recorded. Review the explanation and available correction options."

        CorrectionState.APPEAL_AVAILABLE ->
            "An appeal pathway is available. You may use it directly or request human assistance."

        CorrectionState.HUMAN_ASSISTANCE ->
            "A human-assisted pathway is active. You can continue without losing your place."

        CorrectionState.CLOSED ->
            "The correction pathway is closed subject to the documented reopening and appeal policy."

        CorrectionState.DRAFT ->
            "Your correction request is in progress and has not yet been submitted."
    }
}
