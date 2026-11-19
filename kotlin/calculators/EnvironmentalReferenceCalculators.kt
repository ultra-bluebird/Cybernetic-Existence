package org.augmentedhub.calculators

import kotlin.math.exp
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min

data class KerAssessment(
    val knowledgeFactor: Double,
    val ecoImpactValue: Double,
    val harmRisk: Double,
    val accessibilityImpact: Double,
    val rightsAlignment: Double
) {
    init {
        require(
            listOf(
                knowledgeFactor,
                ecoImpactValue,
                harmRisk,
                accessibilityImpact,
                rightsAlignment
            ).all { it.isFinite() && it in 0.0..1.0 }
        ) {
            "All K/E/R values must be finite and within [0, 1]"
        }
    }
}

data class AdvisoryGateResult(
    val approvedForAdvisoryUse: Boolean,
    val reasons: List<String>
)

object EnvironmentalReferenceCalculators {
    private const val EPSILON = 0.000000001

    @JvmStatic
    fun calculateKnowledgeFactor(
        qualityScores: List<Double>,
        weights: List<Double>
    ): Double {
        require(qualityScores.isNotEmpty()) {
            "qualityScores must not be empty"
        }

        require(qualityScores.size == weights.size) {
            "qualityScores and weights must have the same size"
        }

        require(qualityScores.all { it.isFinite() && it in 0.0..1.0 }) {
            "qualityScores must be finite and within [0, 1]"
        }

        require(weights.all { it.isFinite() && it >= 0.0 }) {
            "weights must be finite and non-negative"
        }

        require(weights.sum() > 0.0) {
            "At least one weight must be positive"
        }

        require(kotlin.math.abs(weights.sum() - 1.0) <= 0.000001) {
            "weights must sum to one"
        }

        if (qualityScores.any { it == 0.0 }) {
            return 0.0
        }

        return exp(
            qualityScores
                .zip(weights)
                .sumOf { (quality, weight) -> weight * ln(quality) }
        )
    }

    @JvmStatic
    fun calculateProvenanceConfidence(
        completeFields: Int,
        requiredFields: Int,
        age: Double,
        ageDecayLambda: Double
    ): Double {
        require(completeFields >= 0) {
            "completeFields must be non-negative"
        }

        require(requiredFields > 0) {
            "requiredFields must be positive"
        }

        require(completeFields <= requiredFields) {
            "completeFields must not exceed requiredFields"
        }

        require(age.isFinite() && age >= 0.0) {
            "age must be finite and non-negative"
        }

        require(ageDecayLambda.isFinite() && ageDecayLambda >= 0.0) {
            "ageDecayLambda must be finite and non-negative"
        }

        val completeness = completeFields.toDouble() / requiredFields.toDouble()
        return completeness * exp(-ageDecayLambda * age)
    }

    @JvmStatic
    fun calculateShadeEquityRatio(
        usableShadeHours: Double,
        targetShadeHours: Double
    ): Double {
        require(usableShadeHours.isFinite() && usableShadeHours >= 0.0) {
            "usableShadeHours must be finite and non-negative"
        }

        require(targetShadeHours.isFinite() && targetShadeHours > 0.0) {
            "targetShadeHours must be finite and positive"
        }

        return clamp01(usableShadeHours / max(targetShadeHours, EPSILON))
    }

    @JvmStatic
    fun calculateCoolingCorridorScore(
        ambientTemperatureC: Double,
        segmentTemperatureC: Double,
        targetTemperatureC: Double,
        shadeFraction: Double,
        accessibilityContinuity: Double,
        evidenceQuality: Double
    ): Double {
        require(
            listOf(
                ambientTemperatureC,
                segmentTemperatureC,
                targetTemperatureC
            ).all { it.isFinite() }
        ) {
            "Temperature values must be finite"
        }

        require(ambientTemperatureC > targetTemperatureC) {
            "ambientTemperatureC must exceed targetTemperatureC"
        }

        requireUnitInterval(shadeFraction, "shadeFraction")
        requireUnitInterval(accessibilityContinuity, "accessibilityContinuity")
        requireUnitInterval(evidenceQuality, "evidenceQuality")

        val thermalEffectiveness = clamp01(
            (ambientTemperatureC - segmentTemperatureC) /
                max(ambientTemperatureC - targetTemperatureC, EPSILON)
        )

        return thermalEffectiveness *
            shadeFraction *
            accessibilityContinuity *
            evidenceQuality
    }

    @JvmStatic
    fun calculateStormwaterRetentionM3(
        rainfallDepthM: Double,
        drainageAreaM2: Double,
        runoffCoefficient: Double,
        effectiveInfiltrationRateM3S: Double,
        eventDurationSeconds: Double,
        availableStorageM3: Double,
        designCapacityM3: Double,
        evidenceQuality: Double
    ): Double {
        requireNonNegativeFinite(rainfallDepthM, "rainfallDepthM")
        requirePositiveFinite(drainageAreaM2, "drainageAreaM2")
        requireUnitInterval(runoffCoefficient, "runoffCoefficient")
        requireNonNegativeFinite(
            effectiveInfiltrationRateM3S,
            "effectiveInfiltrationRateM3S"
        )
        requirePositiveFinite(eventDurationSeconds, "eventDurationSeconds")
        requireNonNegativeFinite(availableStorageM3, "availableStorageM3")
        requireNonNegativeFinite(designCapacityM3, "designCapacityM3")
        requireUnitInterval(evidenceQuality, "evidenceQuality")

        val runoffVolumeM3 =
            rainfallDepthM * drainageAreaM2 * runoffCoefficient

        val capacityVolumeM3 =
            effectiveInfiltrationRateM3S * eventDurationSeconds +
                availableStorageM3

        return min(
            runoffVolumeM3,
            min(capacityVolumeM3, designCapacityM3)
        ) * evidenceQuality
    }

    @JvmStatic
    fun evaluateNonCompensatoryKerGate(
        assessment: KerAssessment
    ): AdvisoryGateResult {
        val reasons = mutableListOf<String>()

        if (assessment.knowledgeFactor < 0.60) {
            reasons += "Knowledge factor is below 0.60."
        }

        if (assessment.ecoImpactValue < 0.50) {
            reasons += "Eco-impact value is below 0.50."
        }

        if (assessment.harmRisk > 0.45) {
            reasons += "Harm risk exceeds 0.45."
        }

        if (assessment.accessibilityImpact < 0.70) {
            reasons += "Accessibility impact is below 0.70."
        }

        if (assessment.rightsAlignment < 0.80) {
            reasons += "Rights alignment is below 0.80."
        }

        return AdvisoryGateResult(
            approvedForAdvisoryUse = reasons.isEmpty(),
            reasons = reasons
        )
    }

    @JvmStatic
    fun calculateResidual(
        risks: List<Double>,
        weights: List<Double>
    ): Double {
        require(risks.isNotEmpty()) {
            "risks must not be empty"
        }

        require(risks.size == weights.size) {
            "risks and weights must have the same size"
        }

        require(risks.all { it.isFinite() && it in 0.0..1.0 }) {
            "risks must be finite and within [0, 1]"
        }

        require(weights.all { it.isFinite() && it >= 0.0 }) {
            "weights must be finite and non-negative"
        }

        require(kotlin.math.abs(weights.sum() - 1.0) <= 0.000001) {
            "weights must sum to one"
        }

        return risks
            .zip(weights)
            .sumOf { (risk, weight) -> weight * risk * risk }
    }

    private fun clamp01(value: Double): Double {
        return min(1.0, max(0.0, value))
    }

    private fun requireUnitInterval(value: Double, label: String) {
        require(value.isFinite() && value in 0.0..1.0) {
            "$label must be finite and within [0, 1]"
        }
    }

    private fun requirePositiveFinite(value: Double, label: String) {
        require(value.isFinite() && value > 0.0) {
            "$label must be finite and positive"
        }
    }

    private fun requireNonNegativeFinite(value: Double, label: String) {
        require(value.isFinite() && value >= 0.0) {
            "$label must be finite and non-negative"
        }
    }
}
