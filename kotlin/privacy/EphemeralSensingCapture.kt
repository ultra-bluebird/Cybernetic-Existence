package augmentedhub.privacy

/**
 * Local reference component.
 *
 * No filesystem, network, backup, sensor acquisition, lamp control,
 * camera command, person classification, or automatic external action.
 *
 * Hardware adapters and their evidence must be reviewed separately.
 */
object EphemeralSensingCapture {
    interface MonotonicClock {
        fun elapsedNanos(): Long
    }

    class SystemMonotonicClock : MonotonicClock {
        private val origin = System.nanoTime()
        override fun elapsedNanos(): Long = System.nanoTime() - origin
    }

    enum class Status {
        READY, NOT_ESTABLISHED, NEEDS_REVIEW, INVALID_INPUT, CLOSED
    }

    class Notice(
        val status: Status,
        val code: String,
        val plainText: String
    ) {
        val schemaVersion = "1"
        val externalActionAuthorized: Boolean get() = false
        override fun toString() = "Notice(status=$status,code=$code)"
    }

    /**
     * Owns a copy of the supplied bytes.
     * Does not erase caller input or certify JVM/OS/media erasure.
     * No content-bearing toString or automatic log is provided.
     */
    class MapVault(
        private val clock: MonotonicClock,
        private val lifetimeNanos: Long,
        private val maximumBytes: Int
    ) {
        private var owned: ByteArray? = null
        private var storedAt: Long? = null
        private var previousTime: Long? = null
        private var closed = false

        init {
            require(lifetimeNanos in 1L..3_600_000_000_000L)
            require(maximumBytes in 1..16_777_216)
        }

        private fun clearOwned() {
            owned?.fill(0)
            owned = null
            storedAt = null
        }

        private fun checkTime(): Long? {
            val time = clock.elapsedNanos()
            val previous = previousTime
            if (time < 0 || (previous != null && time < previous)) {
                clearOwned()
                closed = true
                return null
            }
            previousTime = time
            return time
        }

        @Synchronized
        fun store(bytes: ByteArray): Notice {
            if (closed) return Notice(
                Status.CLOSED, "vault_closed",
                "This map session is closed."
            )
            if (bytes.isEmpty() || bytes.size > maximumBytes) {
                return Notice(
                    Status.INVALID_INPUT, "map_size_invalid",
                    "The map exceeds the declared local storage boundary."
                )
            }

            val time = checkTime() ?: return Notice(
                Status.NOT_ESTABLISHED, "clock_inconsistent",
                "The owned map was cleared because timing is inconsistent."
            )

            clearOwned()
            owned = bytes.copyOf()
            storedAt = time

            return Notice(
                Status.READY, "owned_map_stored",
                "A bounded map copy is held in memory only. " +
                    "Caller and platform copies are outside this vault."
            )
        }

        /**
         * Local processing copy, not export authorization.
         * Caller owns its retention and deletion after return.
         */
        @Synchronized
        fun copyForLocalProcessing(): ByteArray? {
            if (closed) return null
            val time = checkTime() ?: return null
            val start = storedAt ?: return null
            if (time - start >= lifetimeNanos) {
                clearOwned()
                return null
            }
            return owned?.copyOf()
        }

        /**
         * Caller must invoke during normal processing.
         * No background expiry timer is started.
         */
        @Synchronized
        fun expireIfDue(): Notice {
            if (closed) return Notice(
                Status.CLOSED, "vault_closed", "This map session is closed."
            )
            val time = checkTime() ?: return Notice(
                Status.NOT_ESTABLISHED, "clock_inconsistent",
                "Owned map access ended; other-copy deletion is not established."
            )
            val start = storedAt
            if (start == null) return Notice(
                Status.READY, "no_owned_map", "No map is held by this vault."
            )
            if (time - start >= lifetimeNanos) {
                clearOwned()
                return Notice(
                    Status.READY, "owned_buffer_overwritten",
                    "The vault overwrote its owned buffer and removed access. " +
                        "This does not certify deletion of other copies."
                )
            }
            return Notice(
                Status.READY, "retention_window_active",
                "The owned map remains inside its declared retention window."
            )
        }

        @Synchronized
        fun dispose(): Notice {
            clearOwned()
            closed = true
            return Notice(
                Status.CLOSED, "owned_buffer_overwritten",
                "The session is closed and its owned buffer was overwritten. " +
                    "Physical-media and backup deletion are not established."
            )
        }
    }

    enum class DeletionScope {
        OWNED_BUFFER, CALLER_COPY, RENDERER_COPY, BACKUP, PHYSICAL_MEDIA
    }

    enum class ReceiptState {
        REPORTED_VERIFIED, REPORTED_FAILED, NOT_ESTABLISHED
    }

    data class DeletionReceipt(
        val scope: DeletionScope,
        val state: ReceiptState,
        val reviewReference: String
    )

    class DeletionReview(
        val notice: Notice,
        val declaredVerifiedFraction: Double?
    ) {
        val universalErasureClaimed: Boolean get() = false
    }

    fun reviewDeletion(
        declaredScopes: Set<DeletionScope>,
        receipts: List<DeletionReceipt>,
        copyInventoryReviewed: Boolean
    ): DeletionReview {
        if (declaredScopes.isEmpty() ||
            receipts.size > DeletionScope.entries.size ||
            receipts.any { it.scope !in declaredScopes } ||
            receipts.map { it.scope }.toSet().size != receipts.size
        ) return DeletionReview(
            Notice(Status.INVALID_INPUT, "deletion_contract_invalid",
                "The deletion evidence contract needs correction."),
            null
        )

        val verified = declaredScopes.count { scope ->
            receipts.any {
                it.scope == scope &&
                    it.state == ReceiptState.REPORTED_VERIFIED &&
                    it.reviewReference.isNotBlank() &&
                    it.reviewReference.length <= 256
            }
        }
        val failure = receipts.any {
            it.state == ReceiptState.REPORTED_FAILED
        }

        val status = when {
            failure -> Status.NEEDS_REVIEW
            !copyInventoryReviewed || verified != declaredScopes.size ->
                Status.NOT_ESTABLISHED
            else -> Status.READY
        }

        return DeletionReview(
            Notice(status, "declared_deletion_evidence",
                "This result evaluates supplied receipts within the declared " +
                    "copy scope. It does not independently verify erasure."),
            verified.toDouble() / declaredScopes.size
        )
    }

    enum class LightingAdvice {
        BASELINE_REVIEW, PRESENCE_RESPONSE_REVIEW, DAYLIGHT_REVIEW
    }

    class LightingReview(
        val notice: Notice,
        val advice: LightingAdvice?
    ) {
        val lampActuationAuthorized: Boolean get() = false
        val inferenceFirewallEffectivenessVerified: Boolean get() = false
    }

    /**
     * Metadata map allows rejection of unknown/prohibited fields.
     * Never log the supplied payload.
     */
    fun filterLightingInput(
        payload: Map<String, Any?>,
        maximumAgeSeconds: Double,
        reviewedDaylightThresholdLux: Double
    ): LightingReview {
        val allowed = setOf(
            "ambient_light_lux", "motion_presence", "observation_age_seconds"
        )

        if (payload.keys != allowed ||
            !maximumAgeSeconds.isFinite() || maximumAgeSeconds <= 0 ||
            !reviewedDaylightThresholdLux.isFinite() ||
            reviewedDaylightThresholdLux < 0
        ) return LightingReview(
            Notice(Status.INVALID_INPUT, "purpose_schema_rejected",
                "The payload does not match the declared lighting purpose."),
            null
        )

        val lux = payload["ambient_light_lux"] as? Double
        val presence = payload["motion_presence"] as? Boolean
        val age = payload["observation_age_seconds"] as? Double

        if (lux == null || !lux.isFinite() || lux < 0 ||
            presence == null || age == null || !age.isFinite() || age < 0
        ) return LightingReview(
            Notice(Status.INVALID_INPUT, "invalid_environment_values",
                "Environmental values are invalid. Preserve the independently " +
                    "reviewed lighting baseline."),
            null
        )

        if (age > maximumAgeSeconds) return LightingReview(
            Notice(Status.NOT_ESTABLISHED, "environment_observation_stale",
                "The observation is stale. Do not infer absence of people."),
            null
        )

        val advice = when {
            presence -> LightingAdvice.PRESENCE_RESPONSE_REVIEW
            lux >= reviewedDaylightThresholdLux ->
                LightingAdvice.DAYLIGHT_REVIEW
            else -> LightingAdvice.BASELINE_REVIEW
        }

        return LightingReview(
            Notice(Status.READY, "purpose_filter_passed",
                "The supplied fields match the local lighting purpose. " +
                    "No raw payload is retained by this function. " +
                    "No lamp command or inference guarantee is issued."),
            advice
        )
    }

    enum class CaptureState {
        OFF_CONFIRMED, START_PENDING, ACTIVE, STOP_PENDING, UNKNOWN
    }

    class CaptureView(
        val state: CaptureState,
        val revision: Long,
        val framesMayBeAdmitted: Boolean,
        val stopRequested: Boolean,
        val plainText: String
    ) {
        val externalActionAuthorized: Boolean get() = false
        val bystanderIdentified: Boolean get() = false
        val textFallbackRequired: Boolean get() = true
    }

    /**
     * Initial hardware capture status is UNKNOWN.
     * Tokens bind adapter receipts to the current local transition.
     * This controller never operates capture hardware.
     */
    class CaptureController {
        private var state = CaptureState.UNKNOWN
        private var revision = 0L
        private var indicatorReady = false
        private var optOutLatched = false

        private fun view(message: String) = CaptureView(
            state, revision,
            state == CaptureState.ACTIVE &&
                indicatorReady && !optOutLatched,
            state == CaptureState.STOP_PENDING,
            message
        )

        private fun advance(): Boolean {
            if (revision == Long.MAX_VALUE) {
                state = CaptureState.UNKNOWN
                indicatorReady = false
                return false
            }
            revision++
            return true
        }

        @Synchronized
        fun requestStop(): CaptureView {
            if (!advance()) return view("Transition scope exhausted.")
            indicatorReady = false
            state = CaptureState.STOP_PENDING
            return view(
                "New frame admission is blocked. Capture stop is pending " +
                    "adapter confirmation. Text assistance remains available."
            )
        }

        @Synchronized
        fun optOut(): CaptureView {
            optOutLatched = true
            return requestStop()
        }

        @Synchronized
        fun confirmStopped(expectedRevision: Long): CaptureView {
            if (expectedRevision != revision ||
                state != CaptureState.STOP_PENDING
            ) return view("Stop receipt does not match the pending transition.")

            state = CaptureState.OFF_CONFIRMED
            return view(
                "The adapter reported capture stopped. This controller " +
                    "has not independently inspected sensor hardware."
            )
        }

        @Synchronized
        fun requestNewSession(explicitLocalApproval: Boolean): CaptureView {
            if (!explicitLocalApproval ||
                state != CaptureState.OFF_CONFIRMED
            ) return view("Capture remains unavailable.")

            if (!advance()) return view("Transition scope exhausted.")
            optOutLatched = false
            indicatorReady = false
            state = CaptureState.START_PENDING
            return view(
                "A new session is pending. No frames may be admitted yet."
            )
        }

        @Synchronized
        fun confirmStarted(
            expectedRevision: Long,
            indicatorHealthDeclared: Boolean
        ): CaptureView {
            if (expectedRevision != revision ||
                state != CaptureState.START_PENDING
            ) return view("Start receipt does not match the pending transition.")

            if (!indicatorHealthDeclared) return requestStop()

            indicatorReady = true
            state = CaptureState.ACTIVE
            return view(
                "The adapter reported capture and its indicator active. " +
                    "Indicator visibility and hardware behavior need testing."
            )
        }

        @Synchronized
        fun indicatorFailure(): CaptureView = requestStop()

        @Synchronized
        fun current(): CaptureView =
            view("Current local capture-admission state.")
    }
}
