package org.augmentedhub.hearthline.disclosure

import java.time.Clock
import java.time.Instant

enum class RecoveryContextDisclosureMode {
    NONE,
    EXPLICIT_STATEMENT,
    SELF_COMMITMENT_PROOF,
    ATTESTATION_PROOF
}

enum class DisclosurePurpose {
    PRIVATE_CONVERSATION,
    OPTIONAL_CONNECTION_CONTEXT,
    USER_REQUESTED_EXPORT
}

enum class ProofPredicate {
    COMMITMENT_EXISTS_BEFORE_THRESHOLD,
    ISSUER_ATTESTED_DURATION_EXCEEDS_THRESHOLD,
    ISSUER_ATTESTED_USER_SELECTED_CLAIM
}

data class DisclosureChoice(
    val subjectRef: String,
    val recipientRef: String,
    val mode: RecoveryContextDisclosureMode,
    val purpose: DisclosurePurpose,
    val userInitiated: Boolean,
    val proofPredicate: ProofPredicate? = null,
    val issuerRef: String? = null
)

data class DisclosureDecision(
    val allowed: Boolean,
    val reason: String,
    val mode: RecoveryContextDisclosureMode,
    val proofPredicate: ProofPredicate?,
    val evaluatedAt: Instant,
    val recoveryStatusInferenceAllowed: Boolean = false,
    val matchingUseAllowed: Boolean = false,
    val rankingUseAllowed: Boolean = false,
    val publicVisibilityAllowed: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

class RecoveryContextDisclosureService(
    private val clock: Clock
) {
    fun evaluate(choice: DisclosureChoice): DisclosureDecision {
        require(choice.subjectRef.isNotBlank()) {
            "subjectRef must not be blank"
        }
        require(choice.recipientRef.isNotBlank()) {
            "recipientRef must not be blank"
        }
        require(choice.userInitiated) {
            "Recovery-context disclosure must be user initiated"
        }

        validateMode(choice)

        return DisclosureDecision(
            allowed = true,
            reason = explanationFor(choice.mode),
            mode = choice.mode,
            proofPredicate = choice.proofPredicate,
            evaluatedAt = clock.instant()
        )
    }

    private fun validateMode(choice: DisclosureChoice) {
        when (choice.mode) {
            RecoveryContextDisclosureMode.NONE,
            RecoveryContextDisclosureMode.EXPLICIT_STATEMENT -> {
                require(choice.proofPredicate == null) {
                    "No proof predicate is allowed for this disclosure mode"
                }
                require(choice.issuerRef == null) {
                    "No issuer reference is allowed for this disclosure mode"
                }
            }

            RecoveryContextDisclosureMode.SELF_COMMITMENT_PROOF -> {
                require(
                    choice.proofPredicate ==
                        ProofPredicate.COMMITMENT_EXISTS_BEFORE_THRESHOLD
                ) {
                    "Self commitment requires a commitment-time predicate"
                }
                require(choice.issuerRef == null) {
                    "Self commitment must not require an issuer"
                }
            }

            RecoveryContextDisclosureMode.ATTESTATION_PROOF -> {
                require(choice.proofPredicate != null) {
                    "Attestation proof requires a predicate"
                }
                require(!choice.issuerRef.isNullOrBlank()) {
                    "Attestation proof requires a user-selected issuer reference"
                }
            }
        }
    }

    private fun explanationFor(
        mode: RecoveryContextDisclosureMode
    ): String {
        return when (mode) {
            RecoveryContextDisclosureMode.NONE ->
                "No recovery context will be shared."

            RecoveryContextDisclosureMode.EXPLICIT_STATEMENT ->
                "You are choosing your own words without platform verification."

            RecoveryContextDisclosureMode.SELF_COMMITMENT_PROOF ->
                "This shows that a personal commitment existed before a selected date. It does not verify the statement itself."

            RecoveryContextDisclosureMode.ATTESTATION_PROOF ->
                "This presents only the limited claim selected from your optional attestation."
        }
    }
}
