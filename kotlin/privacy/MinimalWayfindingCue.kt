package augmentedhub.privacy

/**
 * Session-local cue minimizer.
 *
 * No scene capture, ML extraction, image processing, network, filesystem,
 * pose history, obstacle detection, or hardware commands.
 *
 * Synchronization protects session state. Clock and upstream checkpoint
 * evidence are trusted dependencies with separately reviewed contracts.
 */
class MinimalWayfindingCue(
    private val clock: MonotonicClock,
    route: List<PublicCheckpoint>,
    private val policy: Policy
) {
    interface MonotonicClock {
        fun elapsedNanos(): Long
    }

    class SystemMonotonicClock : MonotonicClock {
        private val origin = System.nanoTime()
        override fun elapsedNanos(): Long = System.nanoTime() - origin
    }

    enum class State {
        CUE_AVAILABLE,
        TEXT_ONLY,
        NOT_ESTABLISHED,
        INVALID_INPUT,
        CLOSED
    }

    enum class Direction {
        CONTINUE, LEFT, RIGHT, ARRIVED
    }

    data class PublicCheckpoint(
        val publicLabel: String,
        val frameDescription: String,
        val semanticInstruction: String,
        val direction: Direction,
        val assistanceInformation: String
    ) {
        override fun toString(): String =
            "PublicCheckpoint(content=redacted)"
    }

    data class Policy(
        val maximumEvidenceAgeNanos: Long,
        val maximumResidualMillimeters: Long,
        val maximumCueLifetimeNanos: Long
    )

    /**
     * A derived observation, not raw scene content.
     * No coordinate arrays or source bytes are accepted.
     */
    data class CheckpointEvidence(
        val routeSlot: Int,
        val residualUpperBoundMillimeters: Long,
        val ageNanos: Long,
        val reviewedContextMatchDeclared: Boolean
    )

    class View internal constructor(
        val state: State,
        val reason: String,
        val statusText: String,
        val checkpointDescription: String?,
        val direction: Direction?,
        val remainingCueLifetimeNanos: Long?
    ) {
        val schemaVersion = "1"
        val externalActionAuthorized: Boolean get() = false
        val physicalRouteValidated: Boolean get() = false
        val liveObstacleDetectionProvided: Boolean get() = false
        val rawSceneRetentionVerified: Boolean get() = false

        override fun toString(): String =
            "WayfindingView(state=$state,reason=$reason,content=redacted)"
    }

    private val checkpoints = route.toList()
    private var activeSlot: Int? = null
    private var expiresAt: Long? = null
    private var lastClock: Long? = null
    private var textOnly = true
    private var closed = false

    init {
        // Trusted deployment configuration, not public input.
        require(checkpoints.isNotEmpty() && checkpoints.size <= 128)
        require(checkpoints.all {
            validText(it.publicLabel, 256) &&
                validText(it.frameDescription, 512) &&
                validText(it.semanticInstruction, 2048) &&
                validText(it.assistanceInformation, 1024)
        })
        require(policy.maximumEvidenceAgeNanos in
            1L..60_000_000_000L)
        require(policy.maximumCueLifetimeNanos in
            1L..60_000_000_000L)
        require(policy.maximumResidualMillimeters in
            1L..1_000_000L)
    }

    private fun validText(value: String, maximum: Int): Boolean =
        value.isNotBlank() &&
            value.length <= maximum &&
            value.none { Character.isISOControl(it) }

    private fun clearCue() {
        activeSlot = null
        expiresAt = null
    }

    private fun time(): Long? {
        val value = clock.elapsedNanos()
        val previous = lastClock

        if (value < 0 || (previous != null && value < previous)) {
            clearCue()
            textOnly = true
            return null
        }

        lastClock = value
        return value
    }

    private fun view(
        state: State,
        reason: String,
        message: String,
        slot: Int? = null,
        remaining: Long? = null
    ): View {
        val checkpoint = slot?.let { checkpoints.getOrNull(it) }

        val description = checkpoint?.let {
            "${it.publicLabel}. " +
                "Reference: ${it.frameDescription}. " +
                "${it.semanticInstruction} " +
                "Assistance: ${it.assistanceInformation}. " +
                "No live obstacle information is provided."
        }

        return View(
            state, reason, message, description,
            checkpoint?.direction, remaining
        )
    }

    /**
     * Enables eligibility for new cue evidence.
     * Does not restore an old cue or activate any sensor.
     */
    @Synchronized
    fun requestCuePresentation(): View {
        if (closed) return view(
            State.CLOSED, "session_closed", "This cue session is closed."
        )

        clearCue()
        textOnly = false

        return view(
            State.NOT_ESTABLISHED,
            "fresh_evidence_required",
            "Fresh reviewed checkpoint evidence is required. " +
                "No scene capture was started."
        )
    }

    @Synchronized
    fun offer(evidence: CheckpointEvidence): View {
        if (closed) return view(
            State.CLOSED, "session_closed", "This cue session is closed."
        )

        if (textOnly) return view(
            State.TEXT_ONLY, "text_preference",
            "Text-only mode remains active. No cue was retained."
        )

        if (evidence.routeSlot !in checkpoints.indices ||
            evidence.residualUpperBoundMillimeters < 0 ||
            evidence.ageNanos < 0
        ) {
            clearCue()
            return view(
                State.INVALID_INPUT, "invalid_checkpoint_evidence",
                "Checkpoint evidence is invalid. Use the reviewed text route."
            )
        }

        if (!evidence.reviewedContextMatchDeclared ||
            evidence.ageNanos > policy.maximumEvidenceAgeNanos ||
            evidence.residualUpperBoundMillimeters >
                policy.maximumResidualMillimeters
        ) {
            clearCue()
            return view(
                State.NOT_ESTABLISHED, "checkpoint_not_established",
                "The checkpoint match is not established. " +
                    "Use text directions or assistance."
            )
        }

        val now = time() ?: return view(
            State.NOT_ESTABLISHED, "clock_inconsistent",
            "Cue timing is inconsistent. Text-only mode is active."
        )

        // Evidence age consumes the freshness allowance.
        val evidenceRemaining =
            policy.maximumEvidenceAgeNanos - evidence.ageNanos

        val lifetime = minOf(
            evidenceRemaining,
            policy.maximumCueLifetimeNanos
        )

        if (lifetime <= 0 || now > Long.MAX_VALUE - lifetime) {
            clearCue()
            return view(
                State.NOT_ESTABLISHED, "usable_lifetime_not_established",
                "No usable cue lifetime is established."
            )
        }

        activeSlot = evidence.routeSlot
        expiresAt = now + lifetime

        return view(
            State.CUE_AVAILABLE, "bounded_cue",
            "A reviewed checkpoint cue is available temporarily. " +
                "This is not a route-safety determination.",
            activeSlot, lifetime
        )
    }

    /**
     * Call before each use and during the application's event loop.
     * No background expiry scheduler is started.
     */
    @Synchronized
    fun current(): View {
        if (closed) return view(
            State.CLOSED, "session_closed", "This cue session is closed."
        )

        if (textOnly) return view(
            State.TEXT_ONLY, "text_preference",
            "Text-only mode is active."
        )

        val now = time() ?: return view(
            State.NOT_ESTABLISHED, "clock_inconsistent",
            "Cue timing is inconsistent. Use text or assistance."
        )

        val deadline = expiresAt
        if (deadline == null || activeSlot == null) {
            return view(
                State.NOT_ESTABLISHED, "no_current_cue",
                "No current checkpoint cue is established."
            )
        }

        if (now >= deadline) {
            clearCue()
            return view(
                State.NOT_ESTABLISHED, "cue_expired",
                "The checkpoint cue expired. The text route remains available."
            )
        }

        return view(
            State.CUE_AVAILABLE, "bounded_cue",
            "The current cue is within its declared lifetime.",
            activeSlot, deadline - now
        )
    }

    /**
     * Explicitly selected route text. No claim that the person is there.
     * The selected slot is not retained.
     */
    @Synchronized
    fun readCheckpointText(routeSlot: Int): View {
        if (closed) return view(
            State.CLOSED, "session_closed", "This cue session is closed."
        )

        if (routeSlot !in checkpoints.indices) return view(
            State.INVALID_INPUT, "unknown_route_slot",
            "The requested route description is unavailable."
        )

        return view(
            State.TEXT_ONLY, "route_text_only",
            "This is the selected route description, not a confirmed location.",
            routeSlot
        )
    }

    @Synchronized
    fun chooseTextOnly(): View {
        clearCue()
        textOnly = true
        return view(
            State.TEXT_ONLY, "user_choice",
            "Text-only mode is active. The retained cue was cleared."
        )
    }

    @Synchronized
    fun close(): View {
        clearCue()
        textOnly = true
        closed = true
        lastClock = null

        return view(
            State.CLOSED, "session_closed",
            "This session no longer retains an active checkpoint cue. " +
                "Caller and platform copies are outside this component."
        )
    }
}
