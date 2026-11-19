package org.augmentedhub.hearthline.identity

import java.time.Clock
import java.time.Instant

enum class IdentityState {
    IDENTITY_ACTIVE,
    IDENTITY_PAUSED_BY_USER,
    IDENTITY_DORMANT,
    IDENTITY_REACTIVATED,
    IDENTITY_CREDENTIAL_CONTINUITY_PENDING,
    IDENTITY_CREDENTIALS_REVOKED,
    IDENTITY_CLOSED_BY_USER
}

enum class CredentialState {
    CREDENTIALS_ACTIVE,
    CREDENTIAL_CONTINUITY_PENDING,
    CREDENTIALS_REVOKED
}

enum class IdentityEvent {
    USER_PAUSED,
    USER_RESUMED,
    DORMANCY_RECORDED,
    CREDENTIAL_CONTINUITY_STARTED,
    CREDENTIAL_CONTINUITY_COMPLETED,
    CREDENTIALS_REVOKED,
    USER_CLOSED_ACCOUNT
}

data class IdentityContinuityRecord(
    val subjectRef: String,
    val identityState: IdentityState,
    val credentialState: CredentialState,
    val consentRevision: Long,
    val pacingProfileRef: String,
    val createdAt: Instant,
    val updatedAt: Instant,
    val dormantSince: Instant? = null,
    val closedAt: Instant? = null,
    val recoveryStateStored: Boolean = false,
    val healthStateStored: Boolean = false,
    val recoveryStateInferenceAllowed: Boolean = false,
    val healthStateInferenceAllowed: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

class IdentityContinuityService(
    private val clock: Clock
) {
    fun transition(
        record: IdentityContinuityRecord,
        event: IdentityEvent,
        now: Instant = clock.instant()
    ): IdentityContinuityRecord {
        require(record.subjectRef.isNotBlank()) {
            "subjectRef must not be blank"
        }
        require(record.pacingProfileRef.isNotBlank()) {
            "pacingProfileRef must not be blank"
        }
        require(!record.recoveryStateStored) {
            "Recovery stage cannot be stored in identity continuity"
        }
        require(!record.healthStateStored) {
            "Health state cannot be stored in identity continuity"
        }
        require(!record.recoveryStateInferenceAllowed) {
            "Recovery-state inference is prohibited"
        }
        require(!record.healthStateInferenceAllowed) {
            "Health-state inference is prohibited"
        }

        return when (event) {
            IdentityEvent.USER_PAUSED -> record.copy(
                identityState = IdentityState.IDENTITY_PAUSED_BY_USER,
                updatedAt = now,
                externalActionAuthorized = false
            )

            IdentityEvent.USER_RESUMED -> requireResumable(record, now)

            IdentityEvent.DORMANCY_RECORDED -> record.copy(
                identityState = IdentityState.IDENTITY_DORMANT,
                dormantSince = now,
                updatedAt = now,
                externalActionAuthorized = false
            )

            IdentityEvent.CREDENTIAL_CONTINUITY_STARTED -> record.copy(
                identityState = IdentityState.IDENTITY_CREDENTIAL_CONTINUITY_PENDING,
                credentialState = CredentialState.CREDENTIAL_CONTINUITY_PENDING,
                updatedAt = now,
                externalActionAuthorized = false
            )

            IdentityEvent.CREDENTIAL_CONTINUITY_COMPLETED -> record.copy(
                identityState = IdentityState.IDENTITY_REACTIVATED,
                credentialState = CredentialState.CREDENTIALS_ACTIVE,
                updatedAt = now,
                externalActionAuthorized = false
            )

            IdentityEvent.CREDENTIALS_REVOKED -> record.copy(
                identityState = IdentityState.IDENTITY_CREDENTIALS_REVOKED,
                credentialState = CredentialState.CREDENTIALS_REVOKED,
                updatedAt = now,
                externalActionAuthorized = false
            )

            IdentityEvent.USER_CLOSED_ACCOUNT -> record.copy(
                identityState = IdentityState.IDENTITY_CLOSED_BY_USER,
                closedAt = now,
                updatedAt = now,
                externalActionAuthorized = false
            )
        }
    }

    private fun requireResumable(
        record: IdentityContinuityRecord,
        now: Instant
    ): IdentityContinuityRecord {
        require(
            record.identityState == IdentityState.IDENTITY_PAUSED_BY_USER
                || record.identityState == IdentityState.IDENTITY_DORMANT
        ) {
            "Only paused or dormant identities can resume"
        }
        require(record.credentialState == CredentialState.CREDENTIALS_ACTIVE) {
            "A current credential path is required to resume"
        }

        return record.copy(
            identityState = IdentityState.IDENTITY_REACTIVATED,
            updatedAt = now,
            externalActionAuthorized = false
        )
    }
}
