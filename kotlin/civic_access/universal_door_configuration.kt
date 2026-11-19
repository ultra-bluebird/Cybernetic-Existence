package civic.access

import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

object UniversalDoorConfiguration {
    enum class DoorAccessDecision {
        CONFIGURATION_READY,
        ACCESSIBLE_HUMAN_REVIEW_REQUIRED
    }

    data class DoorAccessInput(
        val minimumSafeOpenDurationMs: Long,
        val maximumOpenDurationMs: Long,
        val safetyMarginMs: Long,
        val selectedQuantile: Double,
        val anonymousCrossingTimesMs: List<Long>,
        val accessibleNonBiometricActivationAvailable: Boolean,
        val manualOperationOrEquivalentFallbackAvailable: Boolean,
        val powerLossFallbackAvailable: Boolean,
        val manufacturerReviewComplete: Boolean,
        val siteAccessibilityReviewComplete: Boolean,
        val biometricGatePresent: Boolean,
        val individualMobilityProfilingPresent: Boolean,
        val continuousPersonTrackingPresent: Boolean
    )

    data class DoorAccessResult(
        val decision: DoorAccessDecision,
        val recommendedOpenDurationMs: Long?,
        val identityDisclosureRequired: Boolean,
        val biometricGateAllowed: Boolean,
        val mayActuateDoor: Boolean,
        val requiredFallbacks: List<String>,
        val reason: String
    )

    /**
     * Generates a configuration recommendation only. It never operates a
     * door controller and it never authorizes a physical command.
     */
    fun assess(input: DoorAccessInput): DoorAccessResult {
        val requiredFallbacks = listOf(
            "Accessible non-biometric activation method",
            "Manual operation or equivalent accessible fallback",
            "Power-loss fallback",
            "Accessible human assistance route"
        )

        val invalidConfiguration =
            input.minimumSafeOpenDurationMs <= 0L ||
                input.maximumOpenDurationMs < input.minimumSafeOpenDurationMs ||
                input.safetyMarginMs < 0L ||
                !input.selectedQuantile.isFinite() ||
                input.selectedQuantile <= 0.0 ||
                input.selectedQuantile > 1.0 ||
                input.anonymousCrossingTimesMs.isEmpty() ||
                input.anonymousCrossingTimesMs.any { it <= 0L } ||
                !input.accessibleNonBiometricActivationAvailable ||
                !input.manualOperationOrEquivalentFallbackAvailable ||
                !input.powerLossFallbackAvailable ||
                !input.manufacturerReviewComplete ||
                !input.siteAccessibilityReviewComplete ||
                input.biometricGatePresent ||
                input.individualMobilityProfilingPresent ||
                input.continuousPersonTrackingPresent

        if (invalidConfiguration) {
            return DoorAccessResult(
                decision = DoorAccessDecision.ACCESSIBLE_HUMAN_REVIEW_REQUIRED,
                recommendedOpenDurationMs = null,
                identityDisclosureRequired = false,
                biometricGateAllowed = false,
                mayActuateDoor = false,
                requiredFallbacks = requiredFallbacks,
                reason =
                    "The configuration is incomplete, relies on prohibited identity or surveillance inputs, lacks required accessible fallbacks, or has not completed required safety and accessibility review."
            )
        }

        val sortedTimes = input.anonymousCrossingTimesMs.sorted()
        val index = max(
            0,
            ceil(input.selectedQuantile * sortedTimes.size).toInt() - 1
        )
        val selectedDuration = sortedTimes[index]

        val candidateDuration = max(
            input.minimumSafeOpenDurationMs,
            selectedDuration + input.safetyMarginMs
        )

        val recommendedDuration = min(
            candidateDuration,
            input.maximumOpenDurationMs
        )

        if (recommendedDuration < input.minimumSafeOpenDurationMs) {
            return DoorAccessResult(
                decision = DoorAccessDecision.ACCESSIBLE_HUMAN_REVIEW_REQUIRED,
                recommendedOpenDurationMs = null,
                identityDisclosureRequired = false,
                biometricGateAllowed = false,
                mayActuateDoor = false,
                requiredFallbacks = requiredFallbacks,
                reason =
                    "The maximum duration conflicts with the validated minimum safe open duration, so accessible human review is required."
            )
        }

        return DoorAccessResult(
            decision = DoorAccessDecision.CONFIGURATION_READY,
            recommendedOpenDurationMs = recommendedDuration,
            identityDisclosureRequired = false,
            biometricGateAllowed = false,
            mayActuateDoor = false,
            requiredFallbacks = requiredFallbacks,
            reason =
                "The recommendation uses anonymous timing data and preserves non-biometric activation, manual or equivalent fallback access, power-loss access, and separate human-authorized deployment."
        )
    }
}
