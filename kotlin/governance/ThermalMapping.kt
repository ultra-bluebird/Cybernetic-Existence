package augmentedhub.governance

import augmentedhub.common.*

enum class ThermalSignalSource {
    ANDROID_POWER_MANAGER_STATUS,
    UNREVIEWED_DEVICE_SOURCE,
    PHYSIOLOGICAL_OR_USER_TEMPERATURE,
    INFERRED_USER_FATIGUE
}

enum class DeviceThermalCategory {
    NONE, LIGHT, MODERATE, SEVERE, CRITICAL, EMERGENCY, SHUTDOWN
}

class ThermalMappingAssessment(
    val deviceCategory: DeviceThermalCategory?,
    val documentedSourceReference: String
) : RedactedContent() {
    val schemaVersion = "1"
    val physiologicalDataProcessed: Boolean get() = false
    val actualDeviceStateVerified: Boolean get() = false
    val platformProtectionOverrideAuthorized: Boolean get() = false
    val externalActionAuthorized: Boolean get() = false
}

object ThermalMapping {
    /**
     * Maps supplied Android status codes only.
     * Does not read a thermal API, accept temperatures, or assess freshness.
     */
    fun map(
        source: ThermalSignalSource,
        statusCode: Int,
        platformReviewReference: String
    ): CommonResult<ThermalMappingAssessment> {
        if (source == ThermalSignalSource.PHYSIOLOGICAL_OR_USER_TEMPERATURE ||
            source == ThermalSignalSource.INFERRED_USER_FATIGUE
        ) return CommonResult(
            ResultState.NEEDS_REVIEW,
            CommonCode.REVIEW_REQUIRED,
            "Personal thermal or fatigue assessment is outside this device mapping."
        )

        if (platformReviewReference.isBlank() ||
            Bounds.checkString(platformReviewReference).state !=
                ResultState.DECLARED_CHECKS_MET
        ) return CommonResult(
            ResultState.INVALID_INPUT,
            CommonCode.INPUT_CONTRACT_VIOLATION,
            "A bounded platform-source review reference is required."
        )

        if (source != ThermalSignalSource.ANDROID_POWER_MANAGER_STATUS)
            return CommonResult(
                ResultState.NOT_ESTABLISHED,
                CommonCode.EVIDENCE_UNAVAILABLE,
                "This device source needs its own reviewed mapping."
            )

        val category = when (statusCode) {
            0 -> DeviceThermalCategory.NONE
            1 -> DeviceThermalCategory.LIGHT
            2 -> DeviceThermalCategory.MODERATE
            3 -> DeviceThermalCategory.SEVERE
            4 -> DeviceThermalCategory.CRITICAL
            5 -> DeviceThermalCategory.EMERGENCY
            6 -> DeviceThermalCategory.SHUTDOWN
            else -> null
        }

        if (category == null) return CommonResult(
            ResultState.NOT_ESTABLISHED,
            CommonCode.EVIDENCE_UNAVAILABLE,
            "The status code is not recognized by this mapping version."
        )

        return CommonResult(
            ResultState.DECLARED_CHECKS_MET,
            CommonCode.DECLARED_LOCAL_CHECKS,
            "A supplied platform status was mapped. Device freshness and " +
                "protective behavior remain separate.",
            ThermalMappingAssessment(category, platformReviewReference)
        )
    }
}
