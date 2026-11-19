package org.augmentedhub.hearthline.chat

import java.time.Clock
import java.time.Instant

enum class SuggestionContentState {
    RENDER_REQUIRES_CURRENT_CONSENT,
    INVALIDATED_BY_SCOPE_CHANGE,
    EXPIRED
}

data class SuggestionReference(
    val suggestionId: String,
    val subjectRef: String,
    val recipientRef: String,
    val protectedFields: Set<String>,
    val policyRevisionAtGeneration: Long,
    val expiresAt: Instant?
)

data class ScopeDecision(
    val field: String,
    val allowed: Boolean,
    val policyRevision: Long
)

data class SuggestionInvalidationResult(
    val suggestionId: String,
    val state: SuggestionContentState,
    val renderable: Boolean,
    val invalidatedFieldCount: Int,
    val policyRevision: Long,
    val evaluatedAt: Instant,
    val externalActionAuthorized: Boolean = false
)

interface CurrentScopeResolver {
    fun evaluate(
        recipientRef: String,
        field: String,
        now: Instant
    ): ScopeDecision
}

interface SuggestionInvalidationWriter {
    fun markInvalidated(
        suggestionId: String,
        policyRevision: Long,
        invalidatedAt: Instant,
        invalidatedFieldCount: Int
    )
}

class SuggestionInvalidationService(
    private val scopeResolver: CurrentScopeResolver,
    private val invalidationWriter: SuggestionInvalidationWriter,
    private val clock: Clock
) {
    fun evaluateAtUse(
        suggestion: SuggestionReference,
        now: Instant = clock.instant()
    ): SuggestionInvalidationResult {
        require(suggestion.suggestionId.isNotBlank()) {
            "suggestionId must not be blank"
        }
        require(suggestion.recipientRef.isNotBlank()) {
            "recipientRef must not be blank"
        }

        if (suggestion.expiresAt?.let { !it.isAfter(now) } == true) {
            return SuggestionInvalidationResult(
                suggestionId = suggestion.suggestionId,
                state = SuggestionContentState.EXPIRED,
                renderable = false,
                invalidatedFieldCount = 0,
                policyRevision = suggestion.policyRevisionAtGeneration,
                evaluatedAt = now
            )
        }

        val decisions = suggestion.protectedFields.map {
            scopeResolver.evaluate(
                recipientRef = suggestion.recipientRef,
                field = it,
                now = now
            )
        }

        val invalidatedCount = decisions.count { !it.allowed }
        val currentRevision = decisions.maxOfOrNull { it.policyRevision }
            ?: suggestion.policyRevisionAtGeneration

        if (invalidatedCount > 0) {
            invalidationWriter.markInvalidated(
                suggestionId = suggestion.suggestionId,
                policyRevision = currentRevision,
                invalidatedAt = now,
                invalidatedFieldCount = invalidatedCount
            )

            return SuggestionInvalidationResult(
                suggestionId = suggestion.suggestionId,
                state = SuggestionContentState.INVALIDATED_BY_SCOPE_CHANGE,
                renderable = false,
                invalidatedFieldCount = invalidatedCount,
                policyRevision = currentRevision,
                evaluatedAt = now
            )
        }

        return SuggestionInvalidationResult(
            suggestionId = suggestion.suggestionId,
            state = SuggestionContentState.RENDER_REQUIRES_CURRENT_CONSENT,
            renderable = true,
            invalidatedFieldCount = 0,
            policyRevision = currentRevision,
            evaluatedAt = now
        )
    }
}
