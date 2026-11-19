package org.augmentedhub.cyboquatic

enum class TreatmentVerificationStatus {
    MEASUREMENT_READY,
    REVIEW_REQUIRED,
    REJECTED
}

data class TreatmentMeasurementInput(
    val treatmentRunId: String,
    val analyteId: String,
    val treatedVolumeM3: Double,
    val energyReqJ: Double,
    val observedAbsDeltaVt: Double,
    val maximumAbsDeltaVt: Double,
    val inputQualityAccepted: Boolean,
    val outputQualityAccepted: Boolean,
    val telemetryQualityAccepted: Boolean,
    val fluorideMassBalanceAccepted: Boolean,
    val transformationProductsAssessed: Boolean
) {
    init {
        require(treatmentRunId.matches(Regex("[a-z0-9][a-z0-9_-]{15,127}"))) {
            "treatmentRunId must use the local stable identifier grammar"
        }
        require(analyteId.isNotBlank() && analyteId.length <= 128) {
            "analyteId must be non-empty and bounded"
        }
        require(treatedVolumeM3.isFinite() && treatedVolumeM3 > 0.0) {
            "treatedVolumeM3 must be finite and positive"
        }
        require(energyReqJ.isFinite() && energyReqJ > 0.0) {
            "energyReqJ must be finite and positive"
        }
        require(observedAbsDeltaVt.isFinite() && observedAbsDeltaVt >= 0.0) {
            "observedAbsDeltaVt must be finite and non-negative"
        }
        require(maximumAbsDeltaVt.isFinite() && maximumAbsDeltaVt >= 0.0) {
            "maximumAbsDeltaVt must be finite and non-negative"
        }
    }
}

data class TreatmentVerificationResult(
    val status: TreatmentVerificationStatus,
    val mayClaimConcentrationChange: Boolean,
    val mayClaimMineralization: Boolean,
    val reason: String
)

object PfasTreatmentVerificationInterface {
    fun verify(input: TreatmentMeasurementInput): TreatmentVerificationResult {
        if (input.observedAbsDeltaVt > input.maximumAbsDeltaVt) {
            return TreatmentVerificationResult(
                TreatmentVerificationStatus.REJECTED,
                mayClaimConcentrationChange = false,
                mayClaimMineralization = false,
                reason = "observed delta-vt exceeds the declared treatment telemetry limit"
            )
        }

        if (!input.inputQualityAccepted
            || !input.outputQualityAccepted
            || !input.telemetryQualityAccepted
        ) {
            return TreatmentVerificationResult(
                TreatmentVerificationStatus.REVIEW_REQUIRED,
                mayClaimConcentrationChange = false,
                mayClaimMineralization = false,
                reason = "paired analytical or telemetry quality evidence is incomplete"
            )
        }

        val mineralizationEvidence =
            input.fluorideMassBalanceAccepted
                && input.transformationProductsAssessed

        return TreatmentVerificationResult(
            TreatmentVerificationStatus.MEASUREMENT_READY,
            mayClaimConcentrationChange = true,
            mayClaimMineralization = mineralizationEvidence,
            reason = if (mineralizationEvidence) {
                "measurement evidence supports concentration-change reporting and separate mineralization review"
            } else {
                "measurement evidence supports concentration-change reporting only; mineralization is not established"
            }
        )
    }
}
