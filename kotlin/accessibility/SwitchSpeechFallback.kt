package augmentedhub.accessibility

/**
 * Local reference component. No audio capture, ASR implementation,
 * networking, filesystem writes, hardware control, or external submission.
 */
object SwitchSpeechFallback {
    enum class Command {
        NEXT, SELECT, CANCEL, PAUSE, HELP, TEXT_VIEW
    }

    enum class ScanMode {
        SINGLE_SWITCH_AUTO, TWO_SWITCH_MANUAL
    }

    enum class State {
        READY, PAUSED, NOT_ESTABLISHED, NEEDS_REVIEW, INVALID_INPUT
    }

    interface MonotonicClock {
        fun elapsedNanos(): Long
    }

    class SystemMonotonicClock : MonotonicClock {
        private val origin = System.nanoTime()
        override fun elapsedNanos(): Long = System.nanoTime() - origin
    }

    class Notice(
        val state: State,
        val reason: String,
        val message: String
    ) {
        val schemaVersion = "1"
        val externalActionAuthorized: Boolean get() = false
    }

    /**
     * A command request is consumed by an application dispatcher.
     * It does not bypass permissions, review, or external-action approval.
     */
    class CommandRequest(
        val command: Command,
        val selectedLabel: String?,
        val focusRevision: Long
    ) {
        val externalActionAuthorized: Boolean get() = false
        val automaticallySubmitted: Boolean get() = false

        override fun toString(): String =
            "CommandRequest(command=$command,content=redacted)"
    }

    class ScanView(
        val notice: Notice,
        val focusedLabel: String?,
        val focusRevision: Long,
        val request: CommandRequest?
    ) {
        override fun toString(): String =
            "ScanView(state=${notice.state},content=redacted)"
    }

    /**
     * Synchronization protects state; caller owns UI delivery.
     * Call tick() from the local event loop, not a busy loop.
     */
    class Scanner(
        private val mode: ScanMode,
        private val clock: MonotonicClock,
        private val scanIntervalNanos: Long,
        private val debounceNanos: Long
    ) {
        private var labels = emptyList<String>()
        private var index = 0
        private var revision = 0L
        private var paused = false
        private var lastClock: Long? = null
        private var lastAcceptedInput: Long? = null
        private var lastScan: Long? = null

        init {
            // Trusted configuration errors, not user-input exceptions.
            require(scanIntervalNanos in 100_000_000L..60_000_000_000L)
            require(debounceNanos in 0L..5_000_000_000L)
        }

        private fun view(
            state: State,
            reason: String,
            message: String,
            request: CommandRequest? = null
        ) = ScanView(
            Notice(state, reason, message),
            labels.getOrNull(index),
            revision,
            request
        )

        private fun now(): Long? {
            val value = clock.elapsedNanos()
            val prior = lastClock
            if (value < 0 || (prior != null && value < prior)) {
                paused = true
                return null
            }
            lastClock = value
            return value
        }

        private fun changeFocus() {
            if (revision == Long.MAX_VALUE) {
                paused = true
                return
            }
            revision += 1
        }

        @Synchronized
        fun replaceControls(newLabels: List<String>): ScanView {
            if (newLabels.isEmpty() || newLabels.size > 128 ||
                newLabels.any { it.isBlank() || it.length > 256 } ||
                newLabels.toSet().size != newLabels.size
            ) {
                return view(
                    State.INVALID_INPUT, "invalid_control_list",
                    "The control list needs correction. Use assistance."
                )
            }

            val previous = labels.getOrNull(index)
            labels = newLabels.toList()
            index = labels.indexOf(previous).takeIf { it >= 0 } ?: 0
            changeFocus()
            lastScan = now()
            return view(
                if (paused) State.PAUSED else State.READY,
                "controls_updated",
                "Controls changed. Review the current focus before selection."
            )
        }

        @Synchronized
        fun tick(): ScanView {
            val time = now() ?: return view(
                State.NOT_ESTABLISHED, "clock_inconsistent",
                "Scanning is paused because timing is inconsistent."
            )

            if (paused || labels.isEmpty()) {
                return view(
                    State.PAUSED, "scan_inactive",
                    "Scanning is inactive. Text controls remain available."
                )
            }

            if (mode == ScanMode.SINGLE_SWITCH_AUTO) {
                val prior = lastScan
                if (prior == null) {
                    lastScan = time
                } else if (time - prior >= scanIntervalNanos) {
                    // Advance once, rather than rapidly catching up after delay.
                    index = (index + 1) % labels.size
                    changeFocus()
                    lastScan = time
                }
            }

            return view(State.READY, "focus_available", "Review the focused control.")
        }

        @Synchronized
        fun input(command: Command, expectedRevision: Long): ScanView {
            val time = now() ?: return view(
                State.NOT_ESTABLISHED, "clock_inconsistent",
                "Timing is not established. No command was requested."
            )

            // Pause, cancel, help and fallback are never debounce-blocked.
            val navigationInput =
                command == Command.NEXT || command == Command.SELECT

            val prior = lastAcceptedInput
            if (navigationInput && prior != null &&
                time - prior < debounceNanos
            ) {
                return view(
                    State.READY, "repeat_input_ignored",
                    "Repeated navigation input was ignored."
                )
            }

            if (navigationInput && (paused || labels.isEmpty())) {
                return view(
                    State.PAUSED, "navigation_inactive",
                    "Navigation is inactive. Use help or text controls."
                )
            }

            if (command == Command.SELECT && expectedRevision != revision) {
                return view(
                    State.NEEDS_REVIEW, "stale_focus",
                    "Focus changed. Review the current control and select again."
                )
            }

            when (command) {
                Command.NEXT -> {
                    index = (index + 1) % labels.size
                    changeFocus()
                    lastScan = time
                    lastAcceptedInput = time
                    return view(State.READY, "focus_moved", "Focus moved.")
                }
                Command.SELECT -> lastAcceptedInput = time
                Command.PAUSE -> paused = true
                Command.CANCEL -> changeFocus()
                Command.HELP, Command.TEXT_VIEW -> Unit
            }

            return view(
                if (paused) State.PAUSED else State.READY,
                "local_command_request",
                "A local command was requested. No external action was authorized.",
                CommandRequest(
                    command,
                    if (command == Command.SELECT) labels[index] else null,
                    revision
                )
            )
        }

        @Synchronized
        fun resumeScanning(): ScanView {
            val time = now() ?: return view(
                State.NOT_ESTABLISHED, "clock_inconsistent",
                "Scanning cannot resume with inconsistent timing."
            )
            paused = false
            lastScan = time
            lastAcceptedInput = null
            changeFocus()
            return view(
                State.READY, "scan_resumed",
                "Scanning resumed. Review focus; nothing was selected."
            )
        }

        @Synchronized
        fun dispose(): ScanView {
            labels = emptyList()
            index = 0
            paused = true
            changeFocus()
            return view(
                State.PAUSED, "session_closed",
                "This scanner session is closed."
            )
        }
    }

    data class SpeechScope(
        val localProcessingDeclared: Boolean,
        val rawAudioRetentionDisabledDeclared: Boolean,
        val inferenceOutputsDisabledDeclared: Boolean,
        val permittedCommands: Set<Command>
    )

    class SpeechResult(
        val notice: Notice,
        val command: Command?
    ) {
        val upstreamPrivacyVerified: Boolean get() = false
        val externalActionAuthorized: Boolean get() = false
        override fun toString() = "SpeechResult(state=${notice.state})"
    }

    /**
     * Ownership of transcription transfers to this function.
     * The supplied buffer is overwritten in every return path.
     * This cannot erase recognizer, caller, JVM, OS, or device copies.
     */
    fun acceptSpeechCommand(
        transcription: CharArray,
        scope: SpeechScope
    ): SpeechResult {
        try {
            if (transcription.isEmpty() || transcription.size > 128) {
                return SpeechResult(
                    Notice(State.INVALID_INPUT, "transcription_size",
                        "The command was not accepted. Use text or switch controls."),
                    null
                )
            }

            if (!scope.localProcessingDeclared ||
                !scope.rawAudioRetentionDisabledDeclared ||
                !scope.inferenceOutputsDisabledDeclared
            ) {
                return SpeechResult(
                    Notice(State.NOT_ESTABLISHED, "speech_scope_missing",
                        "The declared speech privacy scope is incomplete."),
                    null
                )
            }

            var start = 0
            var end = transcription.size
            while (start < end && transcription[start] == ' ') start++
            while (end > start && transcription[end - 1] == ' ') end--

            // Bounded English grammar; localization requires reviewed mappings.
            val phrases = mapOf(
                "next" to Command.NEXT,
                "select" to Command.SELECT,
                "cancel" to Command.CANCEL,
                "pause" to Command.PAUSE,
                "help" to Command.HELP,
                "text view" to Command.TEXT_VIEW
            )

            val matched = phrases.entries.firstOrNull { (phrase, _) ->
                phrase.length == end - start &&
                    phrase.indices.all { offset ->
                        val c = transcription[start + offset]
                        val folded = if (c in 'A'..'Z') c + 32 else c
                        folded == phrase[offset]
                    }
            }?.value

            if (matched == null || matched !in scope.permittedCommands) {
                return SpeechResult(
                    Notice(State.NEEDS_REVIEW, "command_not_allowed",
                        "No permitted command matched. Nothing was submitted."),
                    null
                )
            }

            return SpeechResult(
                Notice(State.READY, "command_request_only",
                    "A permitted command was recognized. Separate action rules apply."),
                matched
            )
        } finally {
            transcription.fill('\u0000')
        }
    }

    enum class Evidence {
        DECLARED_PRESERVED, FAILED, NOT_ESTABLISHED
    }

    data class FallbackItem(
        val requirementName: String,
        val accessibleText: String,
        val evidence: Evidence,
        val reviewReference: String
    ) {
        override fun toString() = "FallbackItem(content=redacted)"
    }

    class FallbackReview(
        val notice: Notice,
        val declaredInformationCoverage: Double?,
        val declaredActionCoverage: Double?,
        textBlocks: List<String>
    ) {
        val textBlocks = textBlocks.toList()
        val actualTaskSuccessEstablished: Boolean get() = false
        val externalActionAuthorized: Boolean get() = false
        override fun toString() =
            "FallbackReview(state=${notice.state},content=redacted)"
    }

    fun reviewFallback(
        requiredInformation: Set<String>,
        requiredActions: Set<String>,
        information: List<FallbackItem>,
        actions: List<FallbackItem>
    ): FallbackReview {
        val requirements = requiredInformation + requiredActions
        if (requiredInformation.isEmpty() || requiredActions.isEmpty() ||
            requirements.size > 256 ||
            requirements.any { it.isBlank() || it.length > 256 } ||
            information.size > 256 || actions.size > 256 ||
            information.any { it.requirementName !in requiredInformation } ||
            actions.any { it.requirementName !in requiredActions }
        ) {
            return FallbackReview(
                Notice(State.INVALID_INPUT, "invalid_fallback_contract",
                    "The fallback contract needs correction."),
                null, null, emptyList()
            )
        }

        fun established(required: Set<String>, records: List<FallbackItem>) =
            required.count { name ->
                val matching = records.filter { it.requirementName == name }
                matching.size == 1 &&
                    matching.single().evidence == Evidence.DECLARED_PRESERVED &&
                    matching.single().reviewReference.isNotBlank() &&
                    matching.single().reviewReference.length <= 256 &&
                    matching.single().accessibleText.isNotBlank() &&
                    matching.single().accessibleText.length <= 4096
            }

        val infoCount = established(requiredInformation, information)
        val actionCount = established(requiredActions, actions)
        val failed = (information + actions).any {
            it.evidence == Evidence.FAILED
        }

        val state = when {
            failed -> State.NEEDS_REVIEW
            infoCount != requiredInformation.size ||
                actionCount != requiredActions.size -> State.NOT_ESTABLISHED
            else -> State.READY
        }

        return FallbackReview(
            Notice(
                state, "declared_fallback_coverage",
                "This result checks supplied preservation declarations. " +
                    "Action execution and platform accessibility need separate tests."
            ),
            infoCount.toDouble() / requiredInformation.size,
            actionCount.toDouble() / requiredActions.size,
            if (state == State.READY)
                information.map { it.accessibleText } +
                    actions.map { it.accessibleText }
            else emptyList()
        )
    }
}
