package augmentedhub.continuity

import augmentedhub.common.CommonCode
import augmentedhub.common.CommonResult
import augmentedhub.common.RedactedContent
import augmentedhub.common.ResultState
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.time.Duration
import java.time.Instant
import java.util.Collections

enum class EnvelopePreference {
    TEXT_FIRST,
    REDUCED_MOTION,
    MANUAL_PACING,
    KEEP_DRAFT_ON_PAUSE,
    SHOW_FAMILIAR_LABELS
}

enum class ApprovedContextNote {
    CONTINUE_SELECTED_TASK,
    KEEP_TEXT_PRESENTATION_AVAILABLE,
    REQUEST_REVIEW_BEFORE_IMPORT
}

enum class EnvelopeExclusion {
    PERSON_IDENTIFIERS,
    CREDENTIALS,
    NEURAL_MEDICAL_BIOMETRIC_DATA,
    COMPANION_SYSTEM_INVENTORY,
    RAW_SCENE_AND_TRAJECTORY
}

enum class EnvelopeImportRule {
    PREVIEW_REQUIRED,
    SELECTIVE_REMOVAL_ALLOWED,
    EXPLICIT_LOCAL_APPROVAL_REQUIRED,
    EXPIRED_IMPORT_REJECTED,
    NO_AUTOMATIC_ACTION
}

class PrivateContinuityEnvelope internal constructor(
    preferences: Map<EnvelopePreference, Boolean>,
    notes: Set<ApprovedContextNote>,
    val issuedAt: Instant,
    val expiresAt: Instant
) : RedactedContent() {
    val schemaVersion = 1

    val selectedPreferences =
        Collections.unmodifiableMap(preferences.toMap())
    val approvedContextNotes =
        Collections.unmodifiableSet(notes.toSet())
    val exclusions =
        Collections.unmodifiableSet(EnvelopeExclusion.entries.toSet())
    val importRules =
        Collections.unmodifiableSet(EnvelopeImportRule.entries.toSet())

    val authenticationUsePermitted: Boolean get() = false
    val eligibilityUsePermitted: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

object EnvelopeSchema {
    const val VERSION = 1
    const val MAX_ENCODED_BYTES = 4096
    private const val MAGIC = 0x41484543
    private val maximumLifetime = Duration.ofDays(1)

    private fun failure(
        state: ResultState,
        summary: String
    ): CommonResult<PrivateContinuityEnvelope> =
        CommonResult(
            state,
            if (state == ResultState.INVALID_INPUT)
                CommonCode.INPUT_CONTRACT_VIOLATION
            else CommonCode.EVIDENCE_UNAVAILABLE,
            summary
        )

    /**
     * One-day maximum is this v1 profile's engineering limit,
     * not a universal retention recommendation.
     */
    fun prepare(
        preferences: Map<EnvelopePreference, Boolean>,
        approvedNotes: Set<ApprovedContextNote>,
        issuedAt: Instant,
        expiresAt: Instant,
        now: Instant
    ): CommonResult<PrivateContinuityEnvelope> {
        if (preferences.size > EnvelopePreference.entries.size ||
            approvedNotes.size > ApprovedContextNote.entries.size ||
            expiresAt <= issuedAt ||
            Duration.between(issuedAt, expiresAt) > maximumLifetime
        ) {
            return failure(
                ResultState.INVALID_INPUT,
                "The envelope violates the closed v1 schema or lifetime bound."
            )
        }

        if (issuedAt > now || now >= expiresAt) {
            return failure(
                ResultState.NOT_ESTABLISHED,
                "The envelope is not inside its declared validity window."
            )
        }

        return CommonResult(
            ResultState.DECLARED_CHECKS_MET,
            CommonCode.DECLARED_LOCAL_CHECKS,
            "A closed-schema envelope candidate is available for local preview. " +
                "No transfer or import was performed.",
            PrivateContinuityEnvelope(
                preferences, approvedNotes, issuedAt, expiresAt
            )
        )
    }

    /**
     * Produces local bytes only. Caller owns their retention.
     * Fixed enum names are ASCII; no arbitrary context prose is encoded.
     */
    fun encode(envelope: PrivateContinuityEnvelope): ByteArray {
        val buffer = ByteArrayOutputStream()
        DataOutputStream(buffer).use { out ->
            out.writeInt(MAGIC)
            out.writeInt(VERSION)
            out.writeLong(envelope.issuedAt.epochSecond)
            out.writeInt(envelope.issuedAt.nano)
            out.writeLong(envelope.expiresAt.epochSecond)
            out.writeInt(envelope.expiresAt.nano)

            val preferences =
                envelope.selectedPreferences.entries.sortedBy { it.key.name }
            out.writeInt(preferences.size)
            for ((key, value) in preferences) {
                out.writeUTF(key.name)
                out.writeByte(if (value) 1 else 0)
            }

            val notes = envelope.approvedContextNotes.sortedBy { it.name }
            out.writeInt(notes.size)
            for (note in notes) out.writeUTF(note.name)

            out.writeInt(EnvelopeExclusion.entries.size)
            for (exclusion in EnvelopeExclusion.entries) {
                out.writeUTF(exclusion.name)
            }

            out.writeInt(EnvelopeImportRule.entries.size)
            for (rule in EnvelopeImportRule.entries) {
                out.writeUTF(rule.name)
            }
        }
        return buffer.toByteArray()
    }

    /**
     * Strict decode: unknown fields, enum values, omissions, duplicates,
     * extra bytes, and noncanonical nanoseconds are rejected.
     *
     * No application settings are changed.
     */
    fun decodeForReview(
        bytes: ByteArray,
        now: Instant
    ): CommonResult<PrivateContinuityEnvelope> {
        if (bytes.size !in 32..MAX_ENCODED_BYTES) {
            return failure(ResultState.INVALID_INPUT, "Encoded size is invalid.")
        }

        val snapshot = bytes.copyOf()
        try {
            DataInputStream(ByteArrayInputStream(snapshot)).use { input ->
                if (input.readInt() != MAGIC) {
                    return failure(
                        ResultState.INVALID_INPUT, "Envelope format is unknown."
                    )
                }
                if (input.readInt() != VERSION) {
                    return failure(
                        ResultState.NOT_ESTABLISHED,
                        "This envelope version requires an explicit migration."
                    )
                }

                fun instant(): Instant {
                    val seconds = input.readLong()
                    val nanos = input.readInt()
                    if (nanos !in 0..999_999_999) {
                        throw IllegalArgumentException("Invalid time encoding")
                    }
                    return Instant.ofEpochSecond(seconds, nanos.toLong())
                }

                val issued = instant()
                val expires = instant()

                val preferenceCount = input.readInt()
                if (preferenceCount !in 0..EnvelopePreference.entries.size) {
                    return failure(
                        ResultState.INVALID_INPUT, "Preference count is invalid."
                    )
                }

                val preferences = linkedMapOf<EnvelopePreference, Boolean>()
                repeat(preferenceCount) {
                    val name = input.readUTF()
                    val key = EnvelopePreference.entries.firstOrNull {
                        it.name == name
                    } ?: return failure(
                        ResultState.INVALID_INPUT, "Unknown preference field."
                    )
                    if (key in preferences) return failure(
                        ResultState.INVALID_INPUT, "Duplicate preference field."
                    )
                    val flag = input.readUnsignedByte()
                    if (flag !in 0..1) return failure(
                        ResultState.INVALID_INPUT, "Invalid preference flag."
                    )
                    preferences[key] = flag == 1
                }

                val noteCount = input.readInt()
                if (noteCount !in 0..ApprovedContextNote.entries.size) {
                    return failure(
                        ResultState.INVALID_INPUT, "Context-note count is invalid."
                    )
                }
                val notes = linkedSetOf<ApprovedContextNote>()
                repeat(noteCount) {
                    val name = input.readUTF()
                    val note = ApprovedContextNote.entries.firstOrNull {
                        it.name == name
                    } ?: return failure(
                        ResultState.INVALID_INPUT, "Unknown context-note code."
                    )
                    if (!notes.add(note)) return failure(
                        ResultState.INVALID_INPUT, "Duplicate context-note code."
                    )
                }

                if (input.readInt() != EnvelopeExclusion.entries.size) {
                    return failure(
                        ResultState.INVALID_INPUT, "Exclusion set is incomplete."
                    )
                }
                val exclusions = linkedSetOf<String>()
                repeat(EnvelopeExclusion.entries.size) {
                    if (!exclusions.add(input.readUTF())) return failure(
                        ResultState.INVALID_INPUT, "Duplicate exclusion."
                    )
                }
                if (exclusions != EnvelopeExclusion.entries.map {
                    it.name
                }.toSet()) {
                    return failure(
                        ResultState.INVALID_INPUT, "Exclusion set changed."
                    )
                }

                if (input.readInt() != EnvelopeImportRule.entries.size) {
                    return failure(
                        ResultState.INVALID_INPUT, "Import-rule set is incomplete."
                    )
                }
                val rules = linkedSetOf<String>()
                repeat(EnvelopeImportRule.entries.size) {
                    if (!rules.add(input.readUTF())) return failure(
                        ResultState.INVALID_INPUT, "Duplicate import rule."
                    )
                }
                if (rules != EnvelopeImportRule.entries.map {
                    it.name
                }.toSet() || input.available() != 0) {
                    return failure(
                        ResultState.INVALID_INPUT,
                        "Import rules changed or extra fields are present."
                    )
                }

                return prepare(preferences, notes, issued, expires, now)
            }
        } catch (_: Exception) {
            return failure(
                ResultState.INVALID_INPUT,
                "The envelope could not be decoded under the closed schema."
            )
        } finally {
            snapshot.fill(0)
        }
    }

    /**
     * Removal cannot add content, extend expiry, or weaken import rules.
     * Still returns a candidate, not an applied profile.
     */
    fun selectImportSubset(
        envelope: PrivateContinuityEnvelope,
        preferencesToKeep: Set<EnvelopePreference>,
        notesToKeep: Set<ApprovedContextNote>,
        now: Instant
    ): CommonResult<PrivateContinuityEnvelope> {
        if (!envelope.selectedPreferences.keys.containsAll(preferencesToKeep) ||
            !envelope.approvedContextNotes.containsAll(notesToKeep)
        ) {
            return failure(
                ResultState.INVALID_INPUT,
                "The subset includes content absent from the envelope."
            )
        }

        return prepare(
            envelope.selectedPreferences.filterKeys {
                it in preferencesToKeep
            },
            envelope.approvedContextNotes.filter {
                it in notesToKeep
            }.toSet(),
            envelope.issuedAt,
            envelope.expiresAt,
            now
        )
    }
}
