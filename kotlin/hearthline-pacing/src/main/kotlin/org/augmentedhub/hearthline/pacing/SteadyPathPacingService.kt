package org.augmentedhub.hearthline.pacing

import java.time.Clock
import java.time.Instant

enum class PacingState {
    DISCOVERABLE,
    MUTUAL_INTEREST,
    CONSENT_REVIEWED,
    LIMITED_CONVERSATION,
    USER_CONFIRMED_EXPANSION,
    PAUSED
}

enum class PacingEvent {
    MUTUAL_INTEREST_CONFIRMED,
    CONSENT_REVIEW_COMPLETED,
    LIMITED_CONVERSATION_ACCEPTED,
    EXPANSION_CONFIRMED,
    NARROW_SCOPE,
    PAUSE_REQUESTED,
    RESUME_REQUESTED
}

data class PacingRecord(
    val subjectRef: String,
    val connectionRef: String,
    val state: PacingState,
    val lowEnergyModeEnabled: Boolean,
    val updatedAt: Instant,
    val pausePenaltyProhibited: Boolean = true,
    val streakTrackingProhibited: Boolean = true,
    val urgencyPromptProhibited: Boolean = true,
    val externalActionAuthorized: Boolean = false
)

class SteadyPathPacingService(
    private val clock: Clock
) {
    fun transition(
        current: PacingRecord,
        event: PacingEvent,
        now: Instant = clock.instant()
    ): PacingRecord {
        require(current.subjectRef.isNotBlank()) {
            "subjectRef must not be blank"
        }
        require(current.connectionRef.isNotBlank()) {
            "connectionRef must not be blank"
        }

        val next = when (event) {
            PacingEvent.PAUSE_REQUESTED -> PacingState.PAUSED
            PacingEvent.RESUME_REQUESTED -> {
                if (current.state != PacingState.PAUSED) {
                    throw IllegalStateException("Only a paused state can resume")
                }
                PacingState.DISCOVERABLE
            }
            PacingEvent.MUTUAL_INTEREST_CONFIRMED -> requireTransition(
                current.state,
                PacingState.DISCOVERABLE,
                PacingState.MUTUAL_INTEREST
            )
            PacingEvent.CONSENT_REVIEW_COMPLETED -> requireTransition(
                current.state,
                PacingState.MUTUAL_INTEREST,
                PacingState.CONSENT_REVIEWED
            )
            PacingEvent.LIMITED_CONVERSATION_ACCEPTED -> requireTransition(
                current.state,
                PacingState.CONSENT_REVIEWED,
                PacingState.LIMITED_CONVERSATION
            )
            PacingEvent.EXPANSION_CONFIRMED -> requireTransition(
                current.state,
                PacingState.LIMITED_CONVERSATION,
                PacingState.USER_CONFIRMED_EXPANSION
            )
            PacingEvent.NARROW_SCOPE -> requireTransition(
                current.state,
                PacingState.USER_CONFIRMED_EXPANSION,
                PacingState.LIMITED_CONVERSATION
            )
        }

        return current.copy(
            state = next,
            updatedAt = now,
            pausePenaltyProhibited = true,
            streakTrackingProhibited = true,
            urgencyPromptProhibited = true,
            externalActionAuthorized = false
        )
    }

    fun setLowEnergyMode(
        current: PacingRecord,
        enabled: Boolean,
        now: Instant = clock.instant()
    ): PacingRecord {
        return current.copy(
            lowEnergyModeEnabled = enabled,
            updatedAt = now,
            externalActionAuthorized = false
        )
    }

    private fun requireTransition(
        actual: PacingState,
        expected: PacingState,
        next: PacingState
    ): PacingState {
        if (actual != expected) {
            throw IllegalStateException(
                "Invalid transition from $actual; expected $expected"
            )
        }

        return next
    }
}
