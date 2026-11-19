package org.augmentedhub.hearthline.safety

import java.time.Clock
import java.time.Instant

data class AccountSafetyInputs(
    val subjectRef: String,
    val activePasskeyCount: Int,
    val backupAccessConfigured: Boolean,
    val privacyControlsReviewedAt: Instant?,
    val pacingControlsConfigured: Boolean,
    val waypointMeetingPlanningEligible: Boolean,
    val userEnabledMeetingPlanning: Boolean,
    val accountContinuityReviewDue: Boolean
)

data class PrivateSafetyReadiness(
    val subjectRef: String,
    val evaluatedAt: Instant,
    val passkeyReady: Boolean,
    val backupAccessReady: Boolean,
    val privacyControlsReviewed: Boolean,
    val pacingControlsReady: Boolean,
    val meetingPlanningAvailable: Boolean,
    val accountContinuityReviewDue: Boolean,
    val visibleOnlyToSubject: Boolean = true,
    val publicTrustScoreCreated: Boolean = false,
    val personRankingCreated: Boolean = false,
    val recoveryAttributeUsed: Boolean = false,
    val relationshipHistoryUsed: Boolean = false,
    val lanternStateUsed: Boolean = false,
    val engagementMetricUsed: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

class PrivateSafetyReadinessService(
    private val clock: Clock
) {
    fun evaluate(
        inputs: AccountSafetyInputs,
        now: Instant = clock.instant()
    ): PrivateSafetyReadiness {
        require(inputs.subjectRef.isNotBlank()) {
            "subjectRef must not be blank"
        }
        require(inputs.activePasskeyCount >= 0) {
            "activePasskeyCount must not be negative"
        }

        val passkeyReady = inputs.activePasskeyCount >= 1

        return PrivateSafetyReadiness(
            subjectRef = inputs.subjectRef,
            evaluatedAt = now,
            passkeyReady = passkeyReady,
            backupAccessReady = inputs.backupAccessConfigured,
            privacyControlsReviewed = inputs.privacyControlsReviewedAt != null,
            pacingControlsReady = inputs.pacingControlsConfigured,
            meetingPlanningAvailable =
                inputs.waypointMeetingPlanningEligible
                    && inputs.userEnabledMeetingPlanning,
            accountContinuityReviewDue = inputs.accountContinuityReviewDue
        )
    }
}
