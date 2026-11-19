package org.augmentedhub.sensorfusion

data class ScalarKalmanState(
    val estimate: Double,
    val variance: Double,
    val updatedAtSeconds: Double
)

data class TransferCalibration(
    val transferId: String,
    val offset: Double,
    val gain: Double,
    val residualVariance: Double,
    val stationaryVariance: Double,
    val validMinimum: Double,
    val validMaximum: Double,
    val validUntilSeconds: Double,
    val status: String
)

data class FusedEstimate(
    val value: Double,
    val variance: Double,
    val accepted: Boolean,
    val reason: String
)

object ScalarKalmanFilter {
    fun update(
        prior: ScalarKalmanState,
        mobileRawValue: Double,
        calibration: TransferCalibration,
        processVariance: Double,
        observedAtSeconds: Double
    ): FusedEstimate {
        require(prior.estimate.isFinite())
        require(prior.variance.isFinite() && prior.variance >= 0.0)
        require(prior.updatedAtSeconds.isFinite())
        require(mobileRawValue.isFinite())
        require(processVariance.isFinite() && processVariance >= 0.0)
        require(observedAtSeconds.isFinite())
        require(calibration.offset.isFinite())
        require(calibration.gain.isFinite())
        require(calibration.residualVariance.isFinite() && calibration.residualVariance >= 0.0)
        require(calibration.stationaryVariance.isFinite() && calibration.stationaryVariance >= 0.0)

        if (calibration.status != "VALID") {
            return FusedEstimate(
                value = prior.estimate,
                variance = prior.variance,
                accepted = false,
                reason = "CALIBRATION_NOT_VALID"
            )
        }

        if (observedAtSeconds > calibration.validUntilSeconds) {
            return FusedEstimate(
                value = prior.estimate,
                variance = prior.variance,
                accepted = false,
                reason = "CALIBRATION_TRANSFER_EXPIRED"
            )
        }

        if (mobileRawValue < calibration.validMinimum
            || mobileRawValue > calibration.validMaximum) {
            return FusedEstimate(
                value = prior.estimate,
                variance = prior.variance,
                accepted = false,
                reason = "OUTSIDE_TRANSFER_RANGE"
            )
        }

        val transferredValue =
            calibration.offset + calibration.gain * mobileRawValue

        val observationVariance =
            calibration.residualVariance + calibration.stationaryVariance

        val predictedVariance = prior.variance + processVariance
        val gain = predictedVariance / (predictedVariance + observationVariance)
        val updatedEstimate =
            prior.estimate + gain * (transferredValue - prior.estimate)
        val updatedVariance = (1.0 - gain) * predictedVariance

        return FusedEstimate(
            value = updatedEstimate,
            variance = updatedVariance,
            accepted = true,
            reason = "ACCEPTED"
        )
    }
}
