package augmentedhub.continuity

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.util.Collections

/**
 * Local profile codec, review, and exact terminology rendering.
 *
 * No filesystem, network, account lookup, authentication, diagnosis,
 * private-system inspection, hardware commands, or automatic export.
 *
 * Binary format is a local v1 profile, not an interoperability standard.
 */
class PortableInterfaceProfile {
    enum class Preference {
        TEXT_FIRST,
        REDUCED_MOTION,
        MANUAL_PACING,
        KEEP_DRAFT_ON_PAUSE,
        SHOW_FAMILIAR_LABELS
    }

    enum class State {
        VALID_CANDIDATE,
        INVALID_INPUT,
        UNSUPPORTED_VERSION,
        NEEDS_LOCAL_REVIEW,
        EXACTLY_PRESERVED,
        REVIEWED_CHANGE
    }

    class Profile private constructor(
        preferences: Map<Preference, Boolean>,
        terms: List<String>
    ) {
        val schemaVersion = 1
        val preferences: Map<Preference, Boolean> =
            Collections.unmodifiableMap(preferences.toMap())
        val protectedTerms: List<String> =
            Collections.unmodifiableList(terms.toList())

        val authenticationUsePermitted: Boolean get() = false
        val eligibilityUsePermitted: Boolean get() = false
        val privateSystemControlAuthorized: Boolean get() = false
        val automaticSubmissionAuthorized: Boolean get() = false

        override fun toString(): String =
            "InterfaceProfile(version=$schemaVersion,content=redacted)"

        companion object {
            internal fun create(
                preferences: Map<Preference, Boolean>,
                terms: List<String>
            ) = Profile(preferences, terms)
        }
    }

    class Review(
        val state: State,
        val profile: Profile?,
        findings: List<String>,
        val plainText: String
    ) {
        val schemaVersion = 1
        val findings = findings.toList()
        val externalActionAuthorized: Boolean get() = false
        val personAssessmentPerformed: Boolean get() = false
        override fun toString() = "ProfileReview(state=$state)"
    }

    class FidelityReview(
        val state: State,
        val exactPreferenceFidelity: Double?,
        val exactTermContinuity: Double?,
        findings: List<String>
    ) {
        val findings = findings.toList()
        val psychologicalStateEvaluated: Boolean get() = false
        val externalActionAuthorized: Boolean get() = false
    }

    data class TermCorrection(
        val slot: Int,
        val previousText: String,
        val replacementText: String
    ) {
        override fun toString() = "TermCorrection(content=redacted)"
    }

    sealed class Segment {
        data class OrdinaryText(val text: String) : Segment() {
            override fun toString() = "OrdinaryText(content=redacted)"
        }
        data class ProtectedTerm(val slot: Int) : Segment()
    }

    private fun validTerm(value: String): Boolean {
        if (value.isBlank() || value.length > 1024) return false

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

    fun validate(
        preferences: Map<Preference, Boolean>,
        terms: List<String>
    ): Review {
        if (preferences.size > Preference.entries.size ||
            terms.size > 64 ||
            terms.any { !validTerm(it) }
        ) {
            return Review(
                State.INVALID_INPUT, null,
                listOf("profile_content_out_of_bounds"),
                "The profile needs correction. Ordinary access remains available."
            )
        }

        return Review(
            State.VALID_CANDIDATE,
            Profile.create(preferences, terms),
            emptyList(),
            "This is a local presentation candidate, not a credential. " +
                "Review selected preferences before applying them."
        )
    }

    /**
     * Explicit subset export to local bytes only.
     *
     * Term order is preserved. No digest or stable user reference is added.
     * Returned bytes are potentially sensitive and owned by the caller.
     */
    fun encodeSelected(
        profile: Profile,
        selectedPreferences: Set<Preference>,
        selectedTermSlots: Set<Int>
    ): ByteArray? {
        if (!profile.preferences.keys.containsAll(selectedPreferences) ||
            selectedTermSlots.any { it !in profile.protectedTerms.indices }
        ) return null

        val output = ByteArrayOutputStream()
        DataOutputStream(output).use { out ->
            out.writeInt(0x41485046) // Local profile magic.
            out.writeInt(1)

            val preferences = selectedPreferences.sortedBy { it.name }
            out.writeInt(preferences.size)
            for (key in preferences) {
                out.writeUTF(key.name) // ASCII structural name.
                out.writeByte(if (profile.preferences.getValue(key)) 1 else 0)
            }

            val terms = selectedTermSlots.sorted()
                .map { profile.protectedTerms[it] }
            out.writeInt(terms.size)
            for (term in terms) {
                val bytes = term.toByteArray(Charsets.UTF_8)
                out.writeInt(bytes.size)
                out.write(bytes)
            }
        }
        return output.toByteArray()
    }

    /**
     * Bounded strict decoding. Unknown fields/versions are not ignored.
     * Candidate is returned for review, never automatically applied.
     */
    fun decodeForReview(bytes: ByteArray): Review {
        if (bytes.size !in 12..262144) {
            return Review(
                State.INVALID_INPUT, null,
                listOf("encoded_profile_size"),
                "The supplied profile size is invalid."
            )
        }

        // Caller must not mutate its source while this snapshot is copied.
        val snapshot = bytes.copyOf()

        try {
            DataInputStream(ByteArrayInputStream(snapshot)).use { input ->
                if (input.readInt() != 0x41485046) {
                    return Review(
                        State.INVALID_INPUT, null,
                        listOf("wire_profile_mismatch"),
                        "The supplied bytes are not this profile format."
                    )
                }

                if (input.readInt() != 1) {
                    return Review(
                        State.UNSUPPORTED_VERSION, null,
                        listOf("profile_version_not_supported"),
                        "This profile version needs an explicit migration."
                    )
                }

                val preferenceCount = input.readInt()
                if (preferenceCount !in 0..Preference.entries.size) {
                    return malformed()
                }

                val preferences = linkedMapOf<Preference, Boolean>()

                repeat(preferenceCount) {
                    val name = input.readUTF()
                    val key = Preference.entries.firstOrNull {
                        it.name == name
                    } ?: return malformed()

                    if (key in preferences) return malformed()
                    val flag = input.readUnsignedByte()
                    if (flag !in 0..1) return malformed()
                    preferences[key] = flag == 1
                }

                val termCount = input.readInt()
                if (termCount !in 0..64) return malformed()
                val terms = mutableListOf<String>()

                repeat(termCount) {
                    val size = input.readInt()
                    if (size !in 1..4096 || size > input.available()) {
                        return malformed()
                    }

                    val encoded = ByteArray(size)
                    input.readFully(encoded)

                    val decoder = Charsets.UTF_8.newDecoder()
                        .onMalformedInput(CodingErrorAction.REPORT)
                        .onUnmappableCharacter(CodingErrorAction.REPORT)

                    val term = decoder.decode(ByteBuffer.wrap(encoded)).toString()
                    encoded.fill(0)
                    terms += term
                }

                if (input.available() != 0) return malformed()
                return validate(preferences, terms)
            }
        } catch (_: java.io.IOException) {
            return malformed()
        } catch (_: java.nio.charset.CharacterCodingException) {
            return malformed()
        } finally {
            snapshot.fill(0)
        }
    }

    private fun malformed() = Review(
        State.INVALID_INPUT, null,
        listOf("malformed_profile"),
        "The profile could not be safely decoded. Keep the prior settings."
    )

    /**
     * Changes must bind exact prior and replacement wording.
     * Append/remove/reorder requires separate explicit migration design.
     */
    fun reviewUpdate(
        prior: Profile,
        proposed: Profile,
        approvedPreferenceChanges: Map<Preference, Boolean>,
        approvedTermCorrections: List<TermCorrection>
    ): FidelityReview {
        val findings = mutableListOf<String>()
        var exactPreferences = 0
        var exactTerms = 0
        var reviewedChange = false

        if (approvedTermCorrections.size > 64 ||
            approvedTermCorrections.map { it.slot }.toSet().size !=
                approvedTermCorrections.size ||
            approvedTermCorrections.any {
                it.slot !in prior.protectedTerms.indices ||
                    !validTerm(it.previousText) ||
                    !validTerm(it.replacementText)
            }
        ) {
            return FidelityReview(
                State.INVALID_INPUT, null, null,
                listOf("invalid_correction_contract")
            )
        }

        for ((key, oldValue) in prior.preferences) {
            val newValue = proposed.preferences[key]
            if (newValue == oldValue) {
                exactPreferences++
            } else if (newValue != null &&
                approvedPreferenceChanges[key] == newValue
            ) {
                reviewedChange = true
            } else {
                findings += "preference_changed_without_bound_approval"
            }
        }

        for ((key, value) in proposed.preferences) {
            if (key !in prior.preferences) {
                if (approvedPreferenceChanges[key] == value) {
                    reviewedChange = true
                } else {
                    findings += "new_preference_needs_review"
                }
            }
        }

        if (prior.protectedTerms.size != proposed.protectedTerms.size) {
            findings += "term_sequence_size_changed"
        }

        for (slot in prior.protectedTerms.indices) {
            val old = prior.protectedTerms[slot]
            val new = proposed.protectedTerms.getOrNull(slot)

            if (old == new) {
                exactTerms++
                continue
            }

            val correction = approvedTermCorrections.singleOrNull {
                it.slot == slot
            }

            if (new != null &&
                correction?.previousText == old &&
                correction.replacementText == new
            ) {
                reviewedChange = true
            } else {
                findings += "protected_term_changed_without_bound_approval"
            }
        }

        return FidelityReview(
            when {
                findings.isNotEmpty() -> State.NEEDS_LOCAL_REVIEW
                reviewedChange -> State.REVIEWED_CHANGE
                else -> State.EXACTLY_PRESERVED
            },
            if (prior.preferences.isEmpty()) null
            else exactPreferences.toDouble() / prior.preferences.size,
            if (prior.protectedTerms.isEmpty()) null
            else exactTerms.toDouble() / prior.protectedTerms.size,
            findings.distinct()
        )
    }

    /**
     * Exact literal insertion, not semantic paraphrase detection.
     * Output is plain text, not HTML or executable markup.
     */
    fun render(
        profile: Profile,
        segments: List<Segment>
    ): String? {
        if (segments.size > 256) return null
        val output = StringBuilder()

        for (segment in segments) {
            val text = when (segment) {
                is Segment.OrdinaryText -> {
                    if (segment.text.length > 4096) return null
                    segment.text
                }
                is Segment.ProtectedTerm ->
                    profile.protectedTerms.getOrNull(segment.slot)
                        ?: return null
            }

            if (output.length + text.length > 65536) return null
            output.append(text)
        }

        return output.toString()
    }
}
