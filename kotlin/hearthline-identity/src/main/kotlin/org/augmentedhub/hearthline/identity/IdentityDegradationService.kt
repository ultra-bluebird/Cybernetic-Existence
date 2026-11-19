package org.augmentedhub.hearthline.identity

import java.time.Clock
import java.time.Instant

enum class IdentityAccessState {
    FULL_ACCESS,
    LIMITED_ACCESS,
    READ_ONLY,
    CONTINUITY_AVAILABLE,
    CONTINUITY_ACTIVE,
    RESTORED
}

enum class IdentityDegradationEvent {
    SESSION_EXPIRED,
    PROVIDER_TOKEN_EXPIRED,
    PASSKEY_ASSERTION_FAILED,
    PASSKEY_REVOKED,
    DEVICE_LOSS_REPORTED,
    DEVICE_COMPROMISE_REPORTED,
    BIOMETRIC_OR_DEVICE_UNLOCK_UNAVAILABLE,
    WEBAUTHN_UNAVAILABLE,
    CONTINUITY_STARTED,
    CONTINUITY_CANCELLED,
    CONTINUITY_COMPLETED,
    NEW_AUTHENTICATOR_BOUND,
    FRESH_USER_VERIFICATION_SUCCEEDED,
    COOLDOWN_COMPLETED
}

data class IdentityAccessRecord(
    val accountRef: String,
    val state: IdentityAccessState,
    val updatedAt: Instant,
    val deviceRiskReported: Boolean,
    val continuityReference: String? = null,
    val externalActionAuthorized: Boolean = false
)

class IdentityDegradationService(
    private val clock: Clock
) {
    fun transition(
        record: IdentityAccessRecord,
        event: IdentityDegradationEvent,
        now: Instant = clock.instant()
    ): IdentityAccessRecord {
        require(record.accountRef.isNotBlank()) {
            "accountRef must not be blank"
        }
        require(!record.externalActionAuthorized) {
            "Identity access state cannot authorize external actions"
        }

        val nextState = nextState(record, event)

        return record.copy(
            state = nextState,
            updatedAt = now,
            deviceRiskReported = deviceRiskAfter(record, event),
            continuityReference = continuityReferenceAfter(record, event),
            externalActionAuthorized = false
        )
    }

    private fun nextState(
        record: IdentityAccessRecord,
        event: IdentityDegradationEvent
    ): IdentityAccessState {
        return when (event) {
            IdentityDegradationEvent.SESSION_EXPIRED,
            IdentityDegradationEvent.PROVIDER_TOKEN_EXPIRED,
            IdentityDegradationEvent.PASSKEY_ASSERTION_FAILED,
            IdentityDegradationEvent.BIOMETRIC_OR_DEVICE_UNLOCK_UNAVAILABLE ->
                IdentityAccessState.LIMITED_ACCESS

            IdentityDegradationEvent.PASSKEY_REVOKED,
            IdentityDegradationEvent.DEVICE_LOSS_REPORTED,
            IdentityDegradationEvent.WEBAUTHN_UNAVAILABLE ->
                IdentityAccessState.CONTINUITY_AVAILABLE

            IdentityDegradationEvent.DEVICE_COMPROMISE_REPORTED ->
                IdentityAccessState.READ_ONLY

            IdentityDegradationEvent.CONTINUITY_STARTED ->
                IdentityAccessState.CONTINUITY_ACTIVE

            IdentityDegradationEvent.CONTINUITY_CANCELLED ->
                IdentityAccessState.CONTINUITY_AVAILABLE

            IdentityDegradationEvent.CONTINUITY_COMPLETED,
            IdentityDegradationEvent.NEW_AUTHENTICATOR_BOUND ->
                IdentityAccessState.RESTORED

            IdentityDegradationEvent.FRESH_USER_VERIFICATION_SUCCEEDED ->
                when (record.state) {
                    IdentityAccessState.LIMITED_ACCESS,
                    IdentityAccessState.RESTORED -> IdentityAccessState.FULL_ACCESS

                    IdentityAccessState.READ_ONLY,
                    IdentityAccessState.CONTINUITY_AVAILABLE,
                    IdentityAccessState.CONTINUITY_ACTIVE,
                    IdentityAccessState.FULL_ACCESS -> record.state
                }

            IdentityDegradationEvent.COOLDOWN_COMPLETED ->
                when (record.state) {
                    IdentityAccessState.RESTORED -> IdentityAccessState.FULL_ACCESS
                    else -> record.state
                }
        }
    }

    private fun deviceRiskAfter(
        record: IdentityAccessRecord,
        event: IdentityDegradationEvent
    ): Boolean {
        return when (event) {
            IdentityDegradationEvent.DEVICE_LOSS_REPORTED,
            IdentityDegradationEvent.DEVICE_COMPROMISE_REPORTED -> true

            IdentityDegradationEvent.NEW_AUTHENTICATOR_BOUND,
            IdentityDegradationEvent.FRESH_USER_VERIFICATION_SUCCEEDED,
            IdentityDegradationEvent.COOLDOWN_COMPLETED -> false

            else -> record.deviceRiskReported
        }
    }

    private fun continuityReferenceAfter(
        record: IdentityAccessRecord,
        event: IdentityDegradationEvent
    ): String? {
        return when (event) {
            IdentityDegradationEvent.CONTINUITY_STARTED ->
                requireNotNull(record.continuityReference) {
                    "A continuity reference is required before continuity begins"
                }

            IdentityDegradationEvent.CONTINUITY_COMPLETED,
            IdentityDegradationEvent.NEW_AUTHENTICATOR_BOUND,
            IdentityDegradationEvent.COOLDOWN_COMPLETED ->
                null

            else -> record.continuityReference
        }
    }
}
