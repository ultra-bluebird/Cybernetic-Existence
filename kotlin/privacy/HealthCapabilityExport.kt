package augmentedhub.privacy

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.security.MessageDigest
import java.time.Instant
import java.time.YearMonth
import java.util.IdentityHashMap

/**
 * Local, in-memory gates.
 *
 * No network, physical building commands, public alert transmission,
 * raw health-record ingestion, person inference, or automatic export.
 *
 * Trusted local application code owns grant issuance and approval UI.
 * This is not a security boundary against hostile code in the same JVM.
 */
object HealthCapabilityExport {
    enum class State {
        READY, BLOCKED, NOT_ESTABLISHED, INVALID_INPUT
    }

    enum class InferenceRequest {
        DISPLAY_AGGREGATE,
        IDENTITY,
        INDIVIDUAL_HEALTH,
        EMOTION,
        COMPETENCE
    }

    enum class HealthMetric {
        REVIEWED_PUBLIC_CASE_COUNT,
        REVIEWED_PUBLIC_SERVICE_COUNT
    }

    class Notice(
        val state: State,
        val code: String,
        val plainText: String
    ) {
        val schemaVersion = "1"
        val externalActionAuthorized: Boolean get() = false
        override fun toString() = "Notice(state=$state,code=$code)"
    }

    data class AggregateCell(
        val metric: HealthMetric,
        val reviewedRegion: String,
        val month: YearMonth,
        val cohortSize: Long,
        val count: Long
    )

    data class ReleasePolicy(
        val permittedRegions: Set<String>,
        val minimumCohortSize: Long,
        val minimumPublishedCount: Long,
        val releaseReviewReference: String,
        val linkageAndRepeatedReleaseReviewDeclared: Boolean,
        val validUntil: Instant
    )

    class HealthDisplay(
        val notice: Notice,
        val approvedText: String?
    ) {
        val individualInferenceResistanceProved: Boolean get() = false
        override fun toString() =
            "HealthDisplay(state=${notice.state},content=redacted)"
    }

    private fun boundedText(value: String, maximum: Int): Boolean =
        value.isNotBlank() && value.length <= maximum &&
            value.none { Character.isISOControl(it) }

    fun reviewHealthDisplay(
        request: InferenceRequest,
        cell: AggregateCell,
        policy: ReleasePolicy,
        now: Instant
    ): HealthDisplay {
        if (request != InferenceRequest.DISPLAY_AGGREGATE) {
            return HealthDisplay(
                Notice(State.BLOCKED, "prohibited_inference_request",
                    "This interface does not provide individual inference."),
                null
            )
        }

        if (policy.permittedRegions.isEmpty() ||
            policy.permittedRegions.size > 128 ||
            policy.permittedRegions.any { !boundedText(it, 128) } ||
            !boundedText(cell.reviewedRegion, 128) ||
            policy.minimumCohortSize <= 0 ||
            policy.minimumPublishedCount <= 0 ||
            cell.cohortSize <= 0 ||
            cell.count < 0 || cell.count > cell.cohortSize
        ) {
            return HealthDisplay(
                Notice(State.INVALID_INPUT, "invalid_aggregate_contract",
                    "The aggregate contract needs correction."),
                null
            )
        }

        if (!boundedText(policy.releaseReviewReference, 256) ||
            !policy.linkageAndRepeatedReleaseReviewDeclared ||
            now >= policy.validUntil ||
            cell.reviewedRegion !in policy.permittedRegions
        ) {
            return HealthDisplay(
                Notice(State.NOT_ESTABLISHED, "release_review_missing",
                    "The aggregate release context is not established."),
                null
            )
        }

        if (cell.cohortSize < policy.minimumCohortSize ||
            cell.count < policy.minimumPublishedCount
        ) {
            return HealthDisplay(
                Notice(State.BLOCKED, "cell_not_released",
                    "This aggregate cell is not released under the policy."),
                null
            )
        }

        // Cohort size and internal review reference are not rendered.
        val text = "${cell.metric.name}: ${cell.count}. " +
            "Region: ${cell.reviewedRegion}. Month: ${cell.month}. " +
            "Reviewed aggregate; not an individual assessment."

        return HealthDisplay(
            Notice(State.READY, "declared_release_checks_met",
                "Declared release checks passed. Inference resistance " +
                    "and source accuracy have not been independently proved."),
            text
        )
    }

    enum class Operation {
        PREPARE_STATUS_REVIEW,
        PREPARE_SETPOINT_REVIEW
    }

    data class CapabilityScope(
        val operation: Operation,
        val resource: String,
        val recipient: String,
        val purpose: String,
        val policySha256: String,
        val expiresAt: Instant
    )

    private val digestPattern = Regex("sha256:[0-9a-f]{64}")

    private fun validScope(scope: CapabilityScope): Boolean =
        boundedText(scope.resource, 256) &&
            boundedText(scope.recipient, 256) &&
            boundedText(scope.purpose, 1024) &&
            digestPattern.matches(scope.policySha256)

    /**
     * Constructor visibility prevents ordinary callers constructing handles.
     * Identity lookup, not editable handle fields, binds stored scope.
     */
    class CapabilityHandle private constructor() {
        companion object {
            internal fun create() = CapabilityHandle()
        }
        override fun toString() = "CapabilityHandle(redacted)"
    }

    class GrantResult(
        val notice: Notice,
        val handle: CapabilityHandle?
    )

    class CapabilityGate(private val capacity: Int) {
        private val grants =
            IdentityHashMap<CapabilityHandle, CapabilityScope>()
        private var lastNow: Instant? = null

        init {
            require(capacity in 1..1024) // Trusted application configuration.
        }

        private fun timeAccepted(now: Instant): Boolean {
            val prior = lastNow
            if (prior != null && now < prior) return false
            lastNow = now
            grants.entries.removeAll { now >= it.value.expiresAt }
            return true
        }

        @Synchronized
        fun issueAfterLocalApproval(
            scope: CapabilityScope,
            approvalDeclared: Boolean,
            now: Instant
        ): GrantResult {
            if (!timeAccepted(now) || !validScope(scope) ||
                scope.expiresAt <= now
            ) return GrantResult(
                Notice(State.INVALID_INPUT, "grant_contract_invalid",
                    "No grant was issued."), null
            )

            if (!approvalDeclared) return GrantResult(
                Notice(State.BLOCKED, "approval_missing",
                    "Local scope approval is missing."), null
            )

            if (grants.size >= capacity) return GrantResult(
                Notice(State.NOT_ESTABLISHED, "grant_capacity",
                    "Local grant capacity was reached."), null
            )

            val handle = CapabilityHandle.create()
            grants[handle] = scope.copy()
            return GrantResult(
                Notice(State.READY, "local_grant_created",
                    "A one-use local preparation scope was recorded. " +
                        "No building action is authorized."),
                handle
            )
        }

        @Synchronized
        fun consumeForLocalPreparation(
            handle: CapabilityHandle,
            requestedScope: CapabilityScope,
            currentPolicySha256: String,
            materialChangePending: Boolean,
            now: Instant
        ): Notice {
            if (!timeAccepted(now)) return Notice(
                State.NOT_ESTABLISHED, "clock_inconsistent",
                "Grant consumption is unavailable with inconsistent time."
            )

            val stored = grants[handle] ?: return Notice(
                State.BLOCKED, "grant_absent_expired_or_consumed",
                "No current unconsumed local grant matches this handle."
            )

            if (stored != requestedScope ||
                stored.policySha256 != currentPolicySha256 ||
                materialChangePending
            ) return Notice(
                State.BLOCKED, "scope_or_policy_mismatch",
                "The request does not match the approved current scope."
            )

            grants.remove(handle)
            return Notice(
                State.READY, "local_preparation_scope_consumed",
                "The exact local preparation scope was consumed once. " +
                    "No physical action was issued."
            )
        }

        @Synchronized
        fun close() {
            grants.clear()
        }
    }

    data class ExportContext(
        val recipient: String,
        val purpose: String,
        val retention: String,
        val policySha256: String,
        val expiresAt: Instant
    )

    class ExportPreview(
        val notice: Notice,
        val reviewText: String?,
        val commitmentSha256: String?
    ) {
        override fun toString() =
            "ExportPreview(state=${notice.state},content=redacted)"
    }

    class PreparedLocalExport(
        val notice: Notice,
        private val ownedBytes: ByteArray?
    ) {
        /**
         * Creates another local copy. Caller owns its lifecycle.
         * Returning bytes does not authorize transmission.
         */
        @Synchronized
        fun copyForLocalReview(): ByteArray? = ownedBytes?.copyOf()

        @Synchronized
        fun close() {
            ownedBytes?.fill(0)
        }

        override fun toString() =
            "PreparedLocalExport(state=${notice.state},content=redacted)"
    }

    /**
     * One pending export at a time, bounded to approved aggregate text.
     * Opening a new preview cancels and overwrites the previous payload.
     */
    class ExportGate {
        private var payload: ByteArray? = null
        private var context: ExportContext? = null
        private var commitment: String? = null
        private var approved = false
        private var lastNow: Instant? = null

        private fun clear() {
            payload?.fill(0)
            payload = null
            context = null
            commitment = null
            approved = false
        }

        private fun acceptTime(now: Instant): Boolean {
            val prior = lastNow
            if (prior != null && now < prior) {
                clear()
                return false
            }
            lastNow = now
            val current = context
            if (current != null && now >= current.expiresAt) clear()
            return true
        }

        private fun encode(bytes: ByteArray, c: ExportContext): ByteArray {
            val buffer = ByteArrayOutputStream()
            DataOutputStream(buffer).use { out ->
                fun text(value: String) {
                    val encoded = value.toByteArray(Charsets.UTF_8)
                    out.writeInt(encoded.size)
                    out.write(encoded)
                }
                text("Augmented-Hub/local-export-review/v1")
                out.writeInt(bytes.size)
                out.write(bytes)
                text(c.recipient)
                text(c.purpose)
                text(c.retention)
                text(c.policySha256)
                out.writeLong(c.expiresAt.epochSecond)
                out.writeInt(c.expiresAt.nano)
            }
            return buffer.toByteArray()
        }

        @Synchronized
        fun preview(
            display: HealthDisplay,
            proposedContext: ExportContext,
            metadataReviewDeclared: Boolean,
            now: Instant
        ): ExportPreview {
            clear()
            if (!acceptTime(now) ||
                display.notice.state != State.READY ||
                display.approvedText == null ||
                display.approvedText.length > 4096 ||
                !boundedText(proposedContext.recipient, 256) ||
                !boundedText(proposedContext.purpose, 1024) ||
                !boundedText(proposedContext.retention, 1024) ||
                !digestPattern.matches(proposedContext.policySha256) ||
                proposedContext.expiresAt <= now ||
                !metadataReviewDeclared
            ) return ExportPreview(
                Notice(State.NOT_ESTABLISHED, "export_review_incomplete",
                    "No export approval context was established."),
                null, null
            )

            val bytes = display.approvedText.toByteArray(Charsets.UTF_8)
            val encoded = encode(bytes, proposedContext)
            val digest = MessageDigest.getInstance("SHA-256")
                .digest(encoded)
                .joinToString("") {
                    (it.toInt() and 255).toString(16).padStart(2, '0')
                }
            encoded.fill(0)

            payload = bytes
            context = proposedContext.copy()
            commitment = "sha256:$digest"

            val text = display.approvedText + "\n" +
                "Recipient: ${proposedContext.recipient}\n" +
                "Purpose: ${proposedContext.purpose}\n" +
                "Retention: ${proposedContext.retention}\n" +
                "Policy: ${proposedContext.policySha256}\n" +
                "Expiry: ${proposedContext.expiresAt}"

            return ExportPreview(
                Notice(State.READY, "exact_preview_available",
                    "Review the exact content and destination metadata. " +
                        "Nothing has been transmitted."),
                text, commitment
            )
        }

        @Synchronized
        fun approvePresentedPreview(
            expectedCommitment: String,
            now: Instant
        ): Notice {
            if (!acceptTime(now) || payload == null ||
                commitment != expectedCommitment
            ) return Notice(
                State.BLOCKED, "preview_missing_or_changed",
                "Approval does not match a current preview."
            )

            approved = true
            return Notice(
                State.READY, "local_preview_approved",
                "The current preview was approved for local preparation only."
            )
        }

        @Synchronized
        fun consumePreparedBytes(
            expectedCommitment: String,
            expectedContext: ExportContext,
            currentPolicySha256: String,
            materialChangePending: Boolean,
            now: Instant
        ): PreparedLocalExport {
            if (!acceptTime(now) || !approved ||
                commitment != expectedCommitment ||
                context != expectedContext ||
                context?.policySha256 != currentPolicySha256 ||
                materialChangePending || payload == null
            ) return PreparedLocalExport(
                Notice(State.BLOCKED, "export_binding_not_accepted",
                    "The payload or approval context is unavailable or changed."),
                null
            )

            val bytes = payload
            payload = null
            context = null
            commitment = null
            approved = false

            return PreparedLocalExport(
                Notice(State.READY, "prepared_local_bytes",
                    "The exact reviewed bytes are available locally. " +
                        "No external transmission was performed or authorized."),
                bytes
            )
        }

        @Synchronized
        fun close() = clear()
    }
}
