package org.augmentedhub.governance

import java.time.Duration
import java.time.Instant

enum class AppealState {
    SUBMITTED,
    ACKNOWLEDGED,
    UNDER_REVIEW,
    CORRECTED,
    REJECTED_WITH_REASON,
    ESCALATED
}

enum class EscalationChannel {
    TELEPHONE,
    RELAY_SERVICE,
    POSTAL_MAIL,
    ACCESSIBLE_IN_PERSON,
    STAFF_ASSISTED,
    COMMUNITY_LIAISON,
    ACCESSIBLE_PAPER_FORM
}

data class StateServiceCommitment(
    val maximumDuration: Duration,
    val requiresPlainLanguageExplanation: Boolean,
    val requiresNonDigitalEscalation: Boolean
) {
    init {
        require(!maximumDuration.isNegative && !maximumDuration.isZero) {
            "Maximum duration must be positive"
        }
    }
}

data class AppealCase(
    val caseReference: String,
    val state: AppealState,
    val submittedAt: Instant,
    val updatedAt: Instant,
    val explanation: String,
    val correctionPath: String,
    val escalationChannels: Set<EscalationChannel>
) {
    init {
        require(caseReference.isNotBlank()) {
            "Case reference is required"
        }
        require(explanation.isNotBlank()) {
            "An accessible explanation is required"
        }
        require(correctionPath.isNotBlank()) {
            "A correction path is required"
        }
        require(escalationChannels.isNotEmpty()) {
            "At least one non-digital escalation channel is required"
        }
    }
}

class AppealCorrectionWorkflow(
    private val commitments: Map<AppealState, StateServiceCommitment>
) {
    init {
        require(commitments.keys.containsAll(AppealState.entries)) {
            "Every appeal state requires a service commitment"
        }
    }

    fun canTransition(from: AppealState, to: AppealState): Boolean {
        return when (from) {
            AppealState.SUBMITTED ->
                to == AppealState.ACKNOWLEDGED || to == AppealState.ESCALATED

            AppealState.ACKNOWLEDGED ->
                to == AppealState.UNDER_REVIEW || to == AppealState.ESCALATED

            AppealState.UNDER_REVIEW ->
                to == AppealState.CORRECTED ||
                    to == AppealState.REJECTED_WITH_REASON ||
                    to == AppealState.ESCALATED

            AppealState.CORRECTED ->
                to == AppealState.ESCALATED

            AppealState.REJECTED_WITH_REASON ->
                to == AppealState.ESCALATED

            AppealState.ESCALATED ->
                false
        }
    }

    fun transition(
        current: AppealCase,
        target: AppealState,
        now: Instant,
        explanation: String,
        correctionPath: String
    ): AppealCase {
        require(canTransition(current.state, target)) {
            "Transition from ${current.state} to $target is not allowed"
        }
        require(explanation.isNotBlank()) {
            "An accessible explanation is required for every transition"
        }
        require(correctionPath.isNotBlank()) {
            "A correction or escalation path is required for every transition"
        }

        return current.copy(
            state = target,
            updatedAt = now,
            explanation = explanation,
            correctionPath = correctionPath
        )
    }

    fun isOverdue(caseRecord: AppealCase, now: Instant): Boolean {
        val commitment = commitments.getValue(caseRecord.state)
        return caseRecord.updatedAt.plus(commitment.maximumDuration).isBefore(now)
    }

    fun escalationRequired(caseRecord: AppealCase, now: Instant): Boolean {
        return isOverdue(caseRecord, now) ||
            caseRecord.state == AppealState.REJECTED_WITH_REASON
    }
}

fun defaultAppealCommitments(): Map<AppealState, StateServiceCommitment> {
    return mapOf(
        AppealState.SUBMITTED to StateServiceCommitment(
            maximumDuration = Duration.ofDays(1),
            requiresPlainLanguageExplanation = true,
            requiresNonDigitalEscalation = true
        ),
        AppealState.ACKNOWLEDGED to StateServiceCommitment(
            maximumDuration = Duration.ofDays(5),
            requiresPlainLanguageExplanation = true,
            requiresNonDigitalEscalation = true
        ),
        AppealState.UNDER_REVIEW to StateServiceCommitment(
            maximumDuration = Duration.ofDays(15),
            requiresPlainLanguageExplanation = true,
            requiresNonDigitalEscalation = true
        ),
        AppealState.CORRECTED to StateServiceCommitment(
            maximumDuration = Duration.ofDays(5),
            requiresPlainLanguageExplanation = true,
            requiresNonDigitalEscalation = true
        ),
        AppealState.REJECTED_WITH_REASON to StateServiceCommitment(
            maximumDuration = Duration.ofDays(5),
            requiresPlainLanguageExplanation = true,
            requiresNonDigitalEscalation = true
        ),
        AppealState.ESCALATED to StateServiceCommitment(
            maximumDuration = Duration.ofDays(10),
            requiresPlainLanguageExplanation = true,
            requiresNonDigitalEscalation = true
        )
    )
}
