package org.augmentedhub.hearthline.consent

import java.time.Clock
import java.time.Instant

enum class ConsentState {
    NO_GRANT,
    GRANTED,
    REVOKED,
    EXPIRED
}

data class ConsentGrant(
    val grantId: String,
    val recipientRef: String,
    val field: String,
    val state: ConsentState,
    val revision: Long,
    val effectiveAt: Instant,
    val expiresAt: Instant?
)

data class DisclosureDecision(
    val allowed: Boolean,
    val state: ConsentState,
    val reason: String,
    val revision: Long?,
    val grantId: String?,
    val evaluatedAt: Instant,
    val externalActionAuthorized: Boolean = false
)

interface ConsentGrantRegistry {
    fun latestGrant(
        recipientRef: String,
        field: String,
        effectiveAtOrBefore: Instant
    ): ConsentGrant?
}

class ConsentDecisionService(
    private val registry: ConsentGrantRegistry,
    private val clock: Clock
) {
    fun evaluateDisclosure(
        recipientRef: String,
        field: String,
        now: Instant = clock.instant()
    ): DisclosureDecision {
        require(recipientRef.isNotBlank()) { "recipientRef must not be blank" }
        require(field.isNotBlank()) { "field must not be blank" }

        val grant = registry.latestGrant(
            recipientRef = recipientRef,
            field = field,
            effectiveAtOrBefore = now
        ) ?: return DisclosureDecision(
            allowed = false,
            state = ConsentState.NO_GRANT,
            reason = "NO_CURRENT_GRANT",
            revision = null,
            grantId = null,
            evaluatedAt = now
        )

        val expired = grant.expiresAt?.let { !it.isAfter(now) } ?: false

        if (grant.state == ConsentState.REVOKED) {
            return denied(grant, now, "CURRENT_GRANT_REVOKED")
        }

        if (grant.state == ConsentState.EXPIRED || expired) {
            return DisclosureDecision(
                allowed = false,
                state = ConsentState.EXPIRED,
                reason = "CURRENT_GRANT_EXPIRED",
                revision = grant.revision,
                grantId = grant.grantId,
                evaluatedAt = now
            )
        }

        if (grant.state != ConsentState.GRANTED) {
            return denied(grant, now, "CURRENT_GRANT_NOT_PERMISSIVE")
        }

        return DisclosureDecision(
            allowed = true,
            state = ConsentState.GRANTED,
            reason = "CURRENT_EXPLICIT_GRANT",
            revision = grant.revision,
            grantId = grant.grantId,
            evaluatedAt = now
        )
    }

    private fun denied(
        grant: ConsentGrant,
        now: Instant,
        reason: String
    ): DisclosureDecision {
        return DisclosureDecision(
            allowed = false,
            state = grant.state,
            reason = reason,
            revision = grant.revision,
            grantId = grant.grantId,
            evaluatedAt = now
        )
    }
}
