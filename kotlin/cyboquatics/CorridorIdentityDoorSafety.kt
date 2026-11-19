package cyboquatics

import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

object CorridorIdentityDoorSafety {
    enum class DriftState {
        UNINITIALIZED,
        NOMINAL,
        SUSPECT,
        DRIFT_LOCKOUT,
        INVALID_INPUT_LOCKOUT
    }

    data class DriftMachine(
        val state: DriftState = DriftState.UNINITIALIZED,
        val consecutiveExceedances: Int = 0,
        val thresholdSamples: Int
    ) {
        init {
            require(thresholdSamples > 0) {
                "thresholdSamples must be positive."
            }
        }

        fun observe(observed: Double, reference: Double, tolerance: Double): DriftResult {
            if (!observed.isFinite() || !reference.isFinite() || !tolerance.isFinite() || tolerance <= 0.0) {
                return DriftResult(
                    machine = copy(
                        state = DriftState.INVALID_INPUT_LOCKOUT,
                        consecutiveExceedances = 0
                    ),
                    residual = null,
                    safeForAutomatedReliance = false,
                    requiresManualReview = true,
                    reason = "Invalid observation, reference, or tolerance."
                )
            }

            val residual = abs(observed - reference) / tolerance
            if (residual <= 1.0) {
                return DriftResult(
                    machine = copy(
                        state = DriftState.NOMINAL,
                        consecutiveExceedances = 0
                    ),
                    residual = residual,
                    safeForAutomatedReliance = true,
                    requiresManualReview = false,
                    reason = "Residual is within corridor."
                )
            }

            val count = consecutiveExceedances + 1
            val nextState = if (count >= thresholdSamples) {
                DriftState.DRIFT_LOCKOUT
            } else {
                DriftState.SUSPECT
            }

            return DriftResult(
                machine = copy(state = nextState, consecutiveExceedances = count),
                residual = residual,
                safeForAutomatedReliance = false,
                requiresManualReview = nextState == DriftState.DRIFT_LOCKOUT,
                reason = if (nextState == DriftState.DRIFT_LOCKOUT) {
                    "Residual exceeded 1.0 for $count consecutive samples; manual calibration review required."
                } else {
                    "Residual exceeded 1.0; awaiting consecutive-sample confirmation."
                }
            )
        }
    }

    data class DriftResult(
        val machine: DriftMachine,
        val residual: Double?,
        val safeForAutomatedReliance: Boolean,
        val requiresManualReview: Boolean,
        val reason: String
    )

    enum class IdentityProtectionDecision {
        PROTECT_WITHOUT_ADJUDICATION,
        PROTECT_AND_ESCALATE_HARM_CONSTRAINT,
        INVALID_DECLARATION
    }

    data class IdentityDeclaration(
        val voluntarilyProvided: Boolean,
        val selfDescription: String,
        val requestsSensitiveDataCollection: Boolean,
        val requestsIdentityVerification: Boolean,
        val requestsHarmOrRightsDeprivationForOthers: Boolean
    )

    data class IdentityProtectionResult(
        val decision: IdentityProtectionDecision,
        val protectionCommitments: List<String>,
        val reason: String
    )

    fun evaluateIdentityProtection(declaration: IdentityDeclaration): IdentityProtectionResult {
        val description = declaration.selfDescription.trim()

        if (!declaration.voluntarilyProvided || description.isEmpty()) {
            return IdentityProtectionResult(
                IdentityProtectionDecision.INVALID_DECLARATION,
                listOf(
                    "Do not infer identity.",
                    "Maintain ordinary non-discrimination and accessible-service obligations.",
                    "Offer an accessible voluntary correction path."
                ),
                "No voluntary, non-empty declaration was provided."
            )
        }

        if (declaration.requestsHarmOrRightsDeprivationForOthers) {
            return IdentityProtectionResult(
                IdentityProtectionDecision.PROTECT_AND_ESCALATE_HARM_CONSTRAINT,
                listOf(
                    "Protect the declarant from discrimination.",
                    "Do not implement requests that harm, coerce, exclude, or deprive others of rights.",
                    "Offer accessible human review."
                ),
                "Protection remains in force; harmful requests are not implemented."
            )
        }

        val commitments = mutableListOf(
            "Respect self-asserted identity in ordinary service interactions.",
            "Do not require neural, biometric, health, augmentation, or device data.",
            "Do not require identity verification as a condition of protection.",
            "Provide accessible correction, grievance, and review paths."
        )

        if (declaration.requestsSensitiveDataCollection || declaration.requestsIdentityVerification) {
            commitments += "Decline sensitive-data collection and verification while preserving protection."
        }

        return IdentityProtectionResult(
            IdentityProtectionDecision.PROTECT_WITHOUT_ADJUDICATION,
            commitments,
            "Self-description is voluntarily supplied and does not request harm to others."
        )
    }

    enum class DoorTimingDecision {
        CONFIGURATION_READY,
        MANUAL_CONFIGURATION_REVIEW_REQUIRED
    }

    data class DoorTimingInputs(
        val minimumSafeOpenDurationMs: Long,
        val maximumOpenDurationMs: Long,
        val safetyMarginMs: Long,
        val quantile: Double,
        val anonymousCrossingTimesMs: List<Long>,
        val containsBiometricOrPersistentIdentifiers: Boolean
    )

    data class DoorTimingResult(
        val decision: DoorTimingDecision,
        val recommendedOpenDurationMs: Long?,
        val reason: String
    )

    fun recommendDoorOpenDuration(inputs: DoorTimingInputs): DoorTimingResult {
        if (
            inputs.minimumSafeOpenDurationMs <= 0L ||
            inputs.maximumOpenDurationMs < inputs.minimumSafeOpenDurationMs ||
            inputs.safetyMarginMs < 0L ||
            !inputs.quantile.isFinite() ||
            inputs.quantile <= 0.0 ||
            inputs.quantile > 1.0 ||
            inputs.containsBiometricOrPersistentIdentifiers
        ) {
            return DoorTimingResult(
                DoorTimingDecision.MANUAL_CONFIGURATION_REVIEW_REQUIRED,
                null,
                "Invalid timing configuration or prohibited personal-data input."
            )
        }

        if (inputs.anonymousCrossingTimesMs.isEmpty() || inputs.anonymousCrossingTimesMs.any { it <= 0L }) {
            return DoorTimingResult(
                DoorTimingDecision.MANUAL_CONFIGURATION_REVIEW_REQUIRED,
                null,
                "A positive, anonymous crossing-time dataset is required."
            )
        }

        val sorted = inputs.anonymousCrossingTimesMs.sorted()
        val index = max(0, ceil(inputs.quantile * sorted.size).toInt() - 1)
        val quantileDuration = sorted[index]
        val proposed = max(inputs.minimumSafeOpenDurationMs, quantileDuration + inputs.safetyMarginMs)
        val bounded = min(proposed, inputs.maximumOpenDurationMs)

        if (bounded < inputs.minimumSafeOpenDurationMs) {
            return DoorTimingResult(
                DoorTimingDecision.MANUAL_CONFIGURATION_REVIEW_REQUIRED,
                null,
                "The configured maximum would violate the minimum safe open duration."
            )
        }

        return DoorTimingResult(
            DoorTimingDecision.CONFIGURATION_READY,
            bounded,
            "Conservative anonymous-crossing-time configuration passed; validate against manufacturer and local requirements before deployment."
        )
    }
}
