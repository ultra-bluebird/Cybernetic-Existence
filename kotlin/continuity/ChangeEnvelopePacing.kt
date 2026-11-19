package augmentedhub.continuity

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.security.MessageDigest
import java.time.Instant
import java.util.Collections

/**
 * Local contract and continuity reference component.
 *
 * No deployment, networking, profile authentication, person assessment,
 * private-system access, equipment commands, or automatic submission.
 */
object ChangeEnvelopePacing {
    enum class State {
        READY, NEEDS_REVIEW, NOT_ESTABLISHED, INVALID_INPUT, CLOSED
    }

    enum class Facet {
        PRIVACY, RETENTION, INTERACTION, ACCESSIBLE_FALLBACK,
        CONSENT, EXTERNAL_AUTHORITY, NON_INTERFERENCE, DEPENDENCIES
    }

    class Notice(
        val state: State,
        val code: String,
        val plainText: String
    ) {
        val schemaVersion = "1"
        val externalActionAuthorized: Boolean get() = false
        val deploymentAuthorized: Boolean get() = false
        override fun toString() = "Notice(state=$state,code=$code)"
    }

    data class Manifest(
        val artifactSha256: String,
        val facetSha256: Map<Facet, String>
    )

    class ChangeReview(
        val notice: Notice,
        changed: Set<Facet>,
        val reviewBindingSha256: String?
    ) {
        val changedFacets = changed.toSet()
        val undeclaredBehaviorInspected: Boolean get() = false
    }

    data class LocalReviewReceipt(
        val exactBindingSha256: String,
        val reviewReference: String,
        val approvalDeclared: Boolean,
        val validUntil: Instant
    )

    private val digest = Regex("sha256:[0-9a-f]{64}")

    private fun textValid(value: String, limit: Int): Boolean {
        if (value.isBlank() || value.length > limit) return false
        var index = 0
        while (index < value.length) {
            val c = value[index]
            if (Character.isISOControl(c)) return false
            if (Character.isHighSurrogate(c)) {
                if (index + 1 >= value.length ||
                    !Character.isLowSurrogate(value[index + 1])
                ) return false
                index += 2
            } else {
                if (Character.isLowSurrogate(c)) return false
                index++
            }
        }
        return true
    }

    private fun changeBinding(a: Manifest, b: Manifest): String {
        val buffer = ByteArrayOutputStream()
        DataOutputStream(buffer).use { out ->
            fun text(value: String) {
                val bytes = value.toByteArray(Charsets.UTF_8)
                out.writeInt(bytes.size)
                out.write(bytes)
            }
            text("Augmented-Hub/material-change-review/v1")
            text(a.artifactSha256)
            text(b.artifactSha256)
            for (facet in Facet.entries) {
                text(facet.name)
                text(a.facetSha256.getValue(facet))
                text(b.facetSha256.getValue(facet))
            }
        }

        val bytes = buffer.toByteArray()
        val result = MessageDigest.getInstance("SHA-256").digest(bytes)
        bytes.fill(0)

        return "sha256:" + result.joinToString("") {
            (it.toInt() and 255).toString(16).padStart(2, '0')
        }
    }

    /**
     * Compares supplied artifact/contract commitments, not artifact behavior.
     * Caller must supply commitments obtained from approved local bytes.
     */
    fun reviewChange(
        prior: Manifest,
        proposed: Manifest,
        receipt: LocalReviewReceipt?,
        now: Instant
    ): ChangeReview {
        val a = prior.copy(facetSha256 = prior.facetSha256.toMap())
        val b = proposed.copy(facetSha256 = proposed.facetSha256.toMap())

        val complete = Facet.entries.toSet()
        if (!digest.matches(a.artifactSha256) ||
            !digest.matches(b.artifactSha256) ||
            a.facetSha256.keys != complete ||
            b.facetSha256.keys != complete ||
            (a.facetSha256.values + b.facetSha256.values)
                .any { !digest.matches(it) }
        ) return ChangeReview(
            Notice(State.INVALID_INPUT, "manifest_contract_invalid",
                "The supplied change manifests are incomplete or invalid."),
            emptySet(), null
        )

        val changed = Facet.entries.filter {
            a.facetSha256[it] != b.facetSha256[it]
        }.toSet()

        val artifactChanged = a.artifactSha256 != b.artifactSha256
        val binding = changeBinding(a, b)

        if (!artifactChanged && changed.isEmpty()) return ChangeReview(
            Notice(State.READY, "declared_manifests_unchanged",
                "Supplied commitments are unchanged. Actual deployment " +
                    "behavior was not inspected."),
            changed, binding
        )

        if (!artifactChanged && changed.isNotEmpty()) return ChangeReview(
            Notice(State.NEEDS_REVIEW, "manifest_relationship_inconsistent",
                "Contract commitments changed while the artifact commitment " +
                    "did not. Review the manifest relationship."),
            changed, binding
        )

        val receiptAccepted =
            receipt != null &&
                receipt.exactBindingSha256 == binding &&
                receipt.approvalDeclared &&
                textValid(receipt.reviewReference, 256) &&
                now < receipt.validUntil

        return ChangeReview(
            Notice(
                if (receiptAccepted) State.READY else State.NEEDS_REVIEW,
                if (receiptAccepted) "exact_local_review_declared"
                else if (changed.isEmpty()) "artifact_change_unclassified"
                else "material_change_review_required",
                if (receiptAccepted)
                    "A current local review declaration matches this exact " +
                    "proposal. Deployment is not authorized by this result."
                else
                    "Review the exact change before relying on the successor. " +
                    "Preserve existing accessible service."
            ),
            changed, binding
        )
    }

    enum class Preference {
        TEXT_FIRST, REDUCED_MOTION, MANUAL_PACING, FAMILIAR_LABELS
    }

    enum class Exclusion {
        PERSON_IDENTIFIERS,
        CREDENTIALS,
        NEURAL_MEDICAL_BIOMETRIC_DATA,
        COMPANION_SYSTEM_INVENTORY,
        RAW_SCENE_AND_TRAJECTORY
    }

    /**
     * Immutable local snapshot. Does not provide a network transfer format.
     * Context content remains potentially sensitive.
     */
    class Envelope private constructor(
        preferences: Map<Preference, Boolean>,
        contextNotes: List<String>,
        val expiresAt: Instant
    ) {
        val schemaVersion = 1
        val preferences: Map<Preference, Boolean> =
            Collections.unmodifiableMap(preferences.toMap())
        val contextNotes: List<String> =
            Collections.unmodifiableList(contextNotes.toList())
        val exclusions: Set<Exclusion> =
            Collections.unmodifiableSet(Exclusion.entries.toSet())

        val importRequiresLocalReview: Boolean get() = true
        val authenticationUsePermitted: Boolean get() = false
        val eligibilityUsePermitted: Boolean get() = false
        val externalActionAuthorized: Boolean get() = false

        override fun toString() = "Envelope(version=1,content=redacted)"

        companion object {
            internal fun create(
                preferences: Map<Preference, Boolean>,
                notes: List<String>,
                expiresAt: Instant
            ) = Envelope(preferences, notes, expiresAt)
        }
    }

    class EnvelopeReview(
        val notice: Notice,
        val candidate: Envelope?
    ) {
        val contentClassificationVerified: Boolean get() = false
        override fun toString() =
            "EnvelopeReview(state=${notice.state},content=redacted)"
    }

    /**
     * Notes must be explicitly selected and reviewed outside this function.
     * A declaration is not automatic detection of sensitive prose.
     */
    fun prepareEnvelope(
        selectedPreferences: Map<Preference, Boolean>,
        selectedContextNotes: List<String>,
        contextExclusionsReviewedDeclared: Boolean,
        expiresAt: Instant,
        now: Instant
    ): EnvelopeReview {
        if (selectedPreferences.size > Preference.entries.size ||
            selectedContextNotes.size > 16 ||
            selectedContextNotes.any { !textValid(it, 1024) } ||
            expiresAt <= now
        ) return EnvelopeReview(
            Notice(State.INVALID_INPUT, "envelope_contract_invalid",
                "The selected envelope content or expiry is invalid."),
            null
        )

        if (selectedContextNotes.isNotEmpty() &&
            !contextExclusionsReviewedDeclared
        ) return EnvelopeReview(
            Notice(State.NOT_ESTABLISHED, "context_review_missing",
                "Review context notes for excluded content before transfer."),
            null
        )

        return EnvelopeReview(
            Notice(State.READY, "local_envelope_candidate",
                "A selective local envelope is ready for preview. " +
                    "No transfer or import was performed."),
            Envelope.create(
                selectedPreferences, selectedContextNotes, expiresAt
            )
        )
    }

    fun reviewImportSubset(
        envelope: Envelope,
        keepPreferences: Set<Preference>,
        keepContextPositions: Set<Int>,
        localImportApprovalDeclared: Boolean,
        now: Instant
    ): EnvelopeReview {
        if (now >= envelope.expiresAt) return EnvelopeReview(
            Notice(State.NOT_ESTABLISHED, "envelope_expired",
                "This envelope is expired. Keep ordinary access available."),
            null
        )

        if (!envelope.preferences.keys.containsAll(keepPreferences) ||
            keepContextPositions.any { it !in envelope.contextNotes.indices }
        ) return EnvelopeReview(
            Notice(State.INVALID_INPUT, "subset_not_in_envelope",
                "The selected import subset is invalid."),
            null
        )

        if (!localImportApprovalDeclared) return EnvelopeReview(
            Notice(State.NEEDS_REVIEW, "import_review_required",
                "Review selected settings before local application."),
            null
        )

        return EnvelopeReview(
            Notice(State.READY, "reviewed_subset_candidate",
                "The selected subset is available for local application. " +
                    "It is not a credential or an external-action grant."),
            Envelope.create(
                envelope.preferences.filterKeys { it in keepPreferences },
                keepContextPositions.sorted().map {
                    envelope.contextNotes[it]
                },
                envelope.expiresAt
            )
        )
    }

    interface MonotonicClock {
        fun elapsedNanos(): Long
    }

    class SystemMonotonicClock : MonotonicClock {
        private val origin = System.nanoTime()
        override fun elapsedNanos(): Long = System.nanoTime() - origin
    }

    enum class PacingMode {
        ACTIVE, PAUSED, RESPONSE_WINDOW_ENDED, CLOSED
    }

    class PacingView(
        val mode: PacingMode,
        val activeElapsedNanos: Long,
        val remainingNanos: Long?,
        val plainText: String
    ) {
        val ageAssessed: Boolean get() = false
        val automaticSubmissionAuthorized: Boolean get() = false
        val externalActionAuthorized: Boolean get() = false
    }

    /**
     * Tracks active response time, not selection dwell or authentication.
     * Paused time is excluded. No automatic deadline callback is issued.
     * Draft storage belongs to a separate reviewed continuity component.
     */
    class PacingController(
        private val clock: MonotonicClock
    ) {
        private var mode = PacingMode.PAUSED
        private var elapsed = 0L
        private var limit: Long? = null
        private var lastTime: Long? = null

        private fun view(message: String) = PacingView(
            mode,
            elapsed,
            limit?.let { maxOf(0L, it - elapsed) },
            message
        )

        private fun account(): Boolean {
            val now = clock.elapsedNanos()
            val previous = lastTime
            if (now < 0 || (previous != null && now < previous)) {
                mode = PacingMode.PAUSED
                lastTime = null
                return false
            }

            if (mode == PacingMode.ACTIVE && previous != null) {
                val delta = now - previous
                elapsed = if (delta > Long.MAX_VALUE - elapsed)
                    Long.MAX_VALUE else elapsed + delta

                val boundary = limit
                if (boundary != null && elapsed >= boundary) {
                    mode = PacingMode.RESPONSE_WINDOW_ENDED
                }
            }
            lastTime = now
            return true
        }

        @Synchronized
        fun configureResponseWindow(nanos: Long?): PacingView {
            if (mode == PacingMode.CLOSED) return view("Session closed.")
            if (nanos != null &&
                nanos !in 1_000_000_000L..86_400_000_000_000L
            ) return view("The response-window setting is outside local limits.")

            if (!account()) return view(
                "Timing is inconsistent. Work should remain available."
            )

            limit = nanos
            // Changing the setting preserves accumulated active time.
            if (mode == PacingMode.RESPONSE_WINDOW_ENDED &&
                (nanos == null || elapsed < nanos)
            ) {
                mode = PacingMode.PAUSED
            } else if (nanos != null && elapsed >= nanos) {
                mode = PacingMode.RESPONSE_WINDOW_ENDED
            }

            return view(
                "Response timing changed. Work was not submitted. " +
                    "Resume explicitly when ready."
            )
        }

        @Synchronized
        fun resume(): PacingView {
            if (mode == PacingMode.CLOSED) return view("Session closed.")
            if (!account()) return view("Timing needs review.")
            val boundary = limit
            if (boundary != null && elapsed >= boundary) {
                return view("Extend or disable the response window to continue.")
            }
            mode = PacingMode.ACTIVE
            return view("Resumed with accumulated active time preserved.")
        }

        @Synchronized
        fun pause(): PacingView {
            if (mode == PacingMode.CLOSED) return view("Session closed.")
            account()
            mode = PacingMode.PAUSED
            return view("Paused. Paused time does not consume the response window.")
        }

        @Synchronized
        fun tick(): PacingView {
            if (mode == PacingMode.CLOSED) return view("Session closed.")
            if (!account()) return view("Timing needs review; interaction paused.")
            return view(
                if (mode == PacingMode.RESPONSE_WINDOW_ENDED)
                    "The response window ended. Preserve work and offer " +
                        "extension, correction, and assistance."
                else "Current response-window state."
            )
        }

        @Synchronized
        fun close(): PacingView {
            mode = PacingMode.CLOSED
            elapsed = 0
            limit = null
            lastTime = null
            return view("This pacing session is closed.")
        }
    }
}
