package org.augmentedhub.hearthline.identity

import java.time.Clock
import java.time.Instant
import java.util.UUID

enum class GuardianRelationshipState {
    USER_PROPOSED,
    GUARDIAN_PENDING,
    ACTIVE,
    DECLINED,
    USER_REVOKED,
    GUARDIAN_WITHDRAWN,
    EXPIRED
}

enum class GuardianCapability {
    NOTIFY_ON_CREDENTIAL_CONTINUITY_EVENT,
    CO_SIGN_CREDENTIAL_CONTINUITY,
    RECEIVE_SAFETY_PLAN_CHECKIN,
    RECEIVE_ACCOUNT_SAFETY_NOTICE,
    WITHDRAW_GUARDIAN_CONSENT
}

data class IdentityGuardianRelationship(
    val guardianRelationshipRef: String,
    val subjectRef: String,
    val guardianRef: String,
    val state: GuardianRelationshipState,
    val capabilities: Set<GuardianCapability>,
    val userConsentAt: Instant,
    val guardianConsentAt: Instant?,
    val expiresAt: Instant?,
    val createdAt: Instant,
    val updatedAt: Instant,
    val profileAccessAllowed: Boolean = false,
    val messageAccessAllowed: Boolean = false,
    val matchAccessAllowed: Boolean = false,
    val recoveryContextAccessAllowed: Boolean = false,
    val healthContextAccessAllowed: Boolean = false,
    val credentialMaterialAccessAllowed: Boolean = false,
    val accountControlAllowed: Boolean = false,
    val locationTrackingAllowed: Boolean = false,
    val mandatoryCheckinAllowed: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

class IdentityGuardianService(
    private val clock: Clock
) {
    fun propose(
        subjectRef: String,
        guardianRef: String,
        capabilities: Set<GuardianCapability>,
        expiresAt: Instant? = null
    ): IdentityGuardianRelationship {
        require(subjectRef.isNotBlank()) {
            "subjectRef must not be blank"
        }
        require(guardianRef.isNotBlank()) {
            "guardianRef must not be blank"
        }
        require(subjectRef != guardianRef) {
            "A subject cannot be their own guardian"
        }
        require(capabilities.isNotEmpty()) {
            "At least one guardian capability is required"
        }

        val now = clock.instant()

        if (expiresAt != null) {
            require(expiresAt.isAfter(now)) {
                "expiresAt must be in the future"
            }
        }

        return IdentityGuardianRelationship(
            guardianRelationshipRef = UUID.randomUUID()
                .toString()
                .replace("-", ""),
            subjectRef = subjectRef,
            guardianRef = guardianRef,
            state = GuardianRelationshipState.GUARDIAN_PENDING,
            capabilities = capabilities,
            userConsentAt = now,
            guardianConsentAt = null,
            expiresAt = expiresAt,
            createdAt = now,
            updatedAt = now
        )
    }

    fun accept(
        relationship: IdentityGuardianRelationship,
        guardianRef: String,
        now: Instant = clock.instant()
    ): IdentityGuardianRelationship {
        require(relationship.state == GuardianRelationshipState.GUARDIAN_PENDING) {
            "Only a pending guardian relationship can be accepted"
        }
        require(relationship.guardianRef == guardianRef) {
            "Only the designated guardian can accept"
        }
        require(!isExpired(relationship, now)) {
            "An expired guardian relationship cannot be accepted"
        }

        return relationship.copy(
            state = GuardianRelationshipState.ACTIVE,
            guardianConsentAt = now,
            updatedAt = now
        )
    }

    fun decline(
        relationship: IdentityGuardianRelationship,
        guardianRef: String,
        now: Instant = clock.instant()
    ): IdentityGuardianRelationship {
        require(relationship.state == GuardianRelationshipState.GUARDIAN_PENDING) {
            "Only a pending guardian relationship can be declined"
        }
        require(relationship.guardianRef == guardianRef) {
            "Only the designated guardian can decline"
        }

        return relationship.copy(
            state = GuardianRelationshipState.DECLINED,
            updatedAt = now
        )
    }

    fun revokeByUser(
        relationship: IdentityGuardianRelationship,
        subjectRef: String,
        now: Instant = clock.instant()
    ): IdentityGuardianRelationship {
        require(relationship.subjectRef == subjectRef) {
            "Only the subject can revoke this guardian relationship"
        }

        return relationship.copy(
            state = GuardianRelationshipState.USER_REVOKED,
            updatedAt = now
        )
    }

    fun withdrawByGuardian(
        relationship: IdentityGuardianRelationship,
        guardianRef: String,
        now: Instant = clock.instant()
    ): IdentityGuardianRelationship {
        require(relationship.guardianRef == guardianRef) {
            "Only the guardian can withdraw from this relationship"
        }

        return relationship.copy(
            state = GuardianRelationshipState.GUARDIAN_WITHDRAWN,
            updatedAt = now
        )
    }

    fun canUseCapability(
        relationship: IdentityGuardianRelationship,
        capability: GuardianCapability,
        now: Instant = clock.instant()
    ): Boolean {
        return relationship.state == GuardianRelationshipState.ACTIVE
            && !isExpired(relationship, now)
            && relationship.capabilities.contains(capability)
            && !relationship.profileAccessAllowed
            && !relationship.messageAccessAllowed
            && !relationship.matchAccessAllowed
            && !relationship.recoveryContextAccessAllowed
            && !relationship.healthContextAccessAllowed
            && !relationship.credentialMaterialAccessAllowed
            && !relationship.accountControlAllowed
            && !relationship.locationTrackingAllowed
            && !relationship.mandatoryCheckinAllowed
            && !relationship.externalActionAuthorized
    }

    fun expireIfNeeded(
        relationship: IdentityGuardianRelationship,
        now: Instant = clock.instant()
    ): IdentityGuardianRelationship {
        if (!isExpired(relationship, now)) {
            return relationship
        }

        return relationship.copy(
            state = GuardianRelationshipState.EXPIRED,
            updatedAt = now
        )
    }

    private fun isExpired(
        relationship: IdentityGuardianRelationship,
        now: Instant
    ): Boolean {
        return relationship.expiresAt?.let { !it.isAfter(now) } ?: false
    }
}
