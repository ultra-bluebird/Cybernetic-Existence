package org.augmentedhub.hearthline.accessibility

import java.time.Clock
import java.time.Instant
import java.util.UUID

enum class ReminderDeliveryClass {
    CLASS_A_LOCAL_UI_ONLY,
    CLASS_B_NEUTRAL_DEVICE_NOTIFICATION,
    CLASS_C_USER_INITIATED_GUIDANCE
}

enum class NeutralAction {
    OPEN_APP_WHEN_READY,
    REVIEW_ACCOUNT_STEP,
    REVIEW_PRIVACY_CHOICES,
    CONTINUE_USER_SELECTED_SETUP,
    REVIEW_CONNECTION_PREFERENCES
}

data class ReminderPreference(
    val enabled: Boolean,
    val deliveryClass: ReminderDeliveryClass,
    val neutralAction: NeutralAction
)

data class DeviceBoundCredentialMetadata(
    val credentialAlias: String,
    val setupState: String,
    val lastConfirmedAt: Instant?
)

data class MemoryAidReminder(
    val reminderId: String,
    val subjectRef: String,
    val deliveryClass: ReminderDeliveryClass,
    val neutralAction: NeutralAction,
    val scheduledAt: Instant,
    val credentialAlias: String?,
    val notificationContentSecretFree: Boolean = true,
    val credentialMaterialIncluded: Boolean = false,
    val recoveryMaterialIncluded: Boolean = false,
    val recipientDataIncluded: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

class MemoryAidCoordinator(
    private val clock: Clock
) {
    fun createReminder(
        subjectRef: String,
        preference: ReminderPreference,
        metadata: DeviceBoundCredentialMetadata?,
        scheduledAt: Instant
    ): MemoryAidReminder {
        require(subjectRef.isNotBlank()) {
            "subjectRef must not be blank"
        }
        require(preference.enabled) {
            "Reminder preference must be enabled"
        }
        require(!scheduledAt.isBefore(clock.instant())) {
            "scheduledAt must not be in the past"
        }

        val safeAlias = metadata?.credentialAlias
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?.take(64)

        return MemoryAidReminder(
            reminderId = UUID.randomUUID().toString().replace("-", ""),
            subjectRef = subjectRef,
            deliveryClass = preference.deliveryClass,
            neutralAction = preference.neutralAction,
            scheduledAt = scheduledAt,
            credentialAlias = safeAlias
        )
    }

    fun renderNeutralNotification(reminder: MemoryAidReminder): String {
        require(reminder.notificationContentSecretFree)
        require(!reminder.credentialMaterialIncluded)
        require(!reminder.recoveryMaterialIncluded)
        require(!reminder.recipientDataIncluded)

        return when (reminder.neutralAction) {
            NeutralAction.OPEN_APP_WHEN_READY ->
                "Hearthline is ready when you are."
            NeutralAction.REVIEW_ACCOUNT_STEP ->
                "A saved account step is ready for review."
            NeutralAction.REVIEW_PRIVACY_CHOICES ->
                "You asked for a privacy check-in."
            NeutralAction.CONTINUE_USER_SELECTED_SETUP ->
                "You can continue a setup step when ready."
            NeutralAction.REVIEW_CONNECTION_PREFERENCES ->
                "A connection setting is ready for review."
        }
    }
}
