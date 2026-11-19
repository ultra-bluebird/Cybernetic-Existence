package org.augmentedhub.hearthline.identity

import java.time.Clock
import java.time.Instant

enum class RecipientPersonaState {
    PERSONA_DRAFT,
    PERSONA_ACTIVE,
    PERSONA_PAUSED_BY_USER,
    PERSONA_REVOKED_BY_USER,
    PERSONA_EXPIRED
}

data class RecipientPersona(
    val personaRef: String,
    val accountRef: String,
    val recipientRef: String,
    val state: RecipientPersonaState,
    val displayName: String,
    val profileFieldScopeRefs: Set<String>,
    val createdAt: Instant,
    val updatedAt: Instant,
    val expiresAt: Instant? = null,
    val legalNameIncluded: Boolean = false,
    val recoveryContextIncluded: Boolean = false,
    val healthContextIncluded: Boolean = false,
    val externalIdentityIncluded: Boolean = false,
    val crossRecipientLinkageAllowed: Boolean = false,
    val publicPersonaLookupAllowed: Boolean = false,
    val matchingUseAllowed: Boolean = false,
    val lanternUseAllowed: Boolean = false,
    val analyticsPersonLevelUseAllowed: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

data class PersonaView(
    val personaRef: String,
    val displayName: String,
    val profileFieldScopeRefs: Set<String>,
    val resolvedAt: Instant,
    val externalActionAuthorized: Boolean = false
)

interface PersonaRegistry {
    fun findActivePersona(
        accountRef: String,
        recipientRef: String,
        at: Instant
    ): RecipientPersona?
}

interface PersonaConsentGate {
    fun permitsPersonaRender(
        accountRef: String,
        recipientRef: String,
        personaRef: String,
        at: Instant
    ): Boolean
}

class RecipientPersonaResolver(
    private val registry: PersonaRegistry,
    private val consentGate: PersonaConsentGate,
    private val clock: Clock
) {
    fun resolve(
        accountRef: String,
        recipientRef: String,
        now: Instant = clock.instant()
    ): PersonaView {
        require(accountRef.isNotBlank()) {
            "accountRef must not be blank"
        }
        require(recipientRef.isNotBlank()) {
            "recipientRef must not be blank"
        }

        val persona = registry.findActivePersona(
            accountRef = accountRef,
            recipientRef = recipientRef,
            at = now
        ) ?: throw IllegalStateException(
            "No active recipient-scoped persona is available"
        )

        validatePersona(persona, now)

        require(consentGate.permitsPersonaRender(
            accountRef = accountRef,
            recipientRef = recipientRef,
            personaRef = persona.personaRef,
            at = now
        )) {
            "Current consent does not permit persona rendering"
        }

        return PersonaView(
            personaRef = persona.personaRef,
            displayName = persona.displayName,
            profileFieldScopeRefs = persona.profileFieldScopeRefs,
            resolvedAt = now
        )
    }

    private fun validatePersona(
        persona: RecipientPersona,
        now: Instant
    ) {
        require(persona.state == RecipientPersonaState.PERSONA_ACTIVE) {
            "Persona is not active"
        }
        require(persona.displayName.isNotBlank()) {
            "Persona displayName must not be blank"
        }
        require(persona.expiresAt?.isAfter(now) ?: true) {
            "Persona has expired"
        }
        require(!persona.legalNameIncluded) {
            "Legal name cannot be included in a recipient persona"
        }
        require(!persona.recoveryContextIncluded) {
            "Recovery context cannot be included in a recipient persona"
        }
        require(!persona.healthContextIncluded) {
            "Health context cannot be included in a recipient persona"
        }
        require(!persona.externalIdentityIncluded) {
            "External identity cannot be included in a recipient persona"
        }
        require(!persona.crossRecipientLinkageAllowed) {
            "Cross-recipient linkage is prohibited"
        }
        require(!persona.publicPersonaLookupAllowed) {
            "Public persona lookup is prohibited"
        }
        require(!persona.matchingUseAllowed) {
            "Persona state cannot be used by matching"
        }
        require(!persona.lanternUseAllowed) {
            "Persona state cannot be used by Lantern"
        }
        require(!persona.analyticsPersonLevelUseAllowed) {
            "Persona state cannot be used by person-level analytics"
        }
        require(!persona.externalActionAuthorized) {
            "Persona resolution cannot authorize external actions"
        }
    }
}
