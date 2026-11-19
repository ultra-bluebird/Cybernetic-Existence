package augmentedhub.fog

enum class ConformalAvailability {
    AVAILABLE,
    UNAVAILABLE_INSUFFICIENT_CALIBRATION,
    UNAVAILABLE_EXCHANGEABILITY_UNSUPPORTED,
    UNAVAILABLE_SHIFT_OUTSIDE_ENVELOPE
}

data class ShiftAwareConformalStatus(
    val calibrationSize: Int,
    val minimumCalibrationSize: Int,
    val exchangeabilitySupported: Boolean,
    val nonStationarityWithinEnvelope: Boolean,
    val advisoryOnly: Boolean = true,
    val autonomousDecisionAllowed: Boolean = false
) {
    init {
        require(calibrationSize >= 0)
        require(minimumCalibrationSize >= 2)
        require(advisoryOnly)
        require(!autonomousDecisionAllowed)
    }

    fun availability(): ConformalAvailability =
        when {
            calibrationSize < minimumCalibrationSize ->
                ConformalAvailability.UNAVAILABLE_INSUFFICIENT_CALIBRATION

            !exchangeabilitySupported ->
                ConformalAvailability.UNAVAILABLE_EXCHANGEABILITY_UNSUPPORTED

            !nonStationarityWithinEnvelope ->
                ConformalAvailability.UNAVAILABLE_SHIFT_OUTSIDE_ENVELOPE

            else ->
                ConformalAvailability.AVAILABLE
        }

    fun requiresConservativeWithhold(): Boolean =
        availability() != ConformalAvailability.AVAILABLE
}
