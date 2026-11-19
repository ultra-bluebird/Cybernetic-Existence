package org.augmentedhub.panel

import java.security.SecureRandom
import java.time.Clock
import java.time.Instant
import java.util.Base64

enum class InteractionType {
    ENVIRONMENTAL_DATA_ACCESS,
    PUBLIC_RESERVE_COMPUTE_REQUEST,
    COOLING_CENTER_DIRECTIONS,
    KER_EXPLANATION,
    ACCESSIBILITY_HELP,
    LANGUAGE_CHANGE,
    SESSION_RESET
}

enum class ServiceOutcome {
    COMPLETED,
    OFFLINE_CONTENT_SERVED,
    ACCESSIBLE_ALTERNATIVE_PROVIDED,
    HUMAN_HELP_ROUTE_PROVIDED,
    UNAVAILABLE_WITH_EXPLANATION
}

data class AssistancePanelSession(
    val sessionKey: String,
    val panelKey: String,
    val occurredAtUtc: Instant,
    val interactionType: InteractionType,
    val serviceOutcome: ServiceOutcome
)

fun interface AssistancePanelSessionSink {
    fun write(session: AssistancePanelSession)
}

class SessionLogWriter(
    private val sink: AssistancePanelSessionSink,
    private val clock: Clock = Clock.systemUTC(),
    private val random: SecureRandom = SecureRandom()
) {
    fun write(
        panelKey: String,
        interactionType: InteractionType,
        serviceOutcome: ServiceOutcome
    ): AssistancePanelSession {
        require(panelKey.isNotBlank()) {
            "panelKey must not be blank."
        }

        val session = AssistancePanelSession(
            sessionKey = newInteractionSessionKey(),
            panelKey = panelKey,
            occurredAtUtc = clock.instant(),
            interactionType = interactionType,
            serviceOutcome = serviceOutcome
        )

        sink.write(session)
        return session
    }

    private fun newInteractionSessionKey(): String {
        val bytes = ByteArray(32)
        random.nextBytes(bytes)

        return Base64.getUrlEncoder()
            .withoutPadding()
            .encodeToString(bytes)
    }
}
