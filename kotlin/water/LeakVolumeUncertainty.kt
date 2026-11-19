package water

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.sqrt

private const val MINIMUM_TELEMETRY_QUALITY = 0.90
private const val STANDARD_NORMAL_95 = 1.959963984540054
private const val MAXIMUM_PRESSURE_PA = 100_000_000.0
private const val MAXIMUM_DURATION_SECONDS = 31_536_000.0
private const val MAXIMUM_AREA_M2 = 1.0
private const val MAXIMUM_DENSITY_KG_M3 = 2_000.0

data class LeakVolumeInput(
    val leakReportId: String,
    val pipeAssetId: String,
    val pressurePa: Double,
    val pressureUncertaintyPa: Double,
    val outletPressurePa: Double,
    val leakAreaProxyM2: Double,
    val leakAreaProxyUncertaintyM2: Double,
    val dischargeCoefficient: Double,
    val dischargeCoefficientUncertainty: Double,
    val waterDensityKgM3: Double,
    val durationSeconds: Double,
    val durationUncertaintySeconds: Double,
    val acousticDetectionProbability: Double,
    val acousticModelVersion: String,
    val pipeConditionModelVersion: String,
    val telemetryQuality: Double,
    val modelCalibrationStatus: String,
    val humanReviewStatus: String
)

data class LeakVolumeResult(
    val conditionalLeakFlowM3S: Double,
    val conditionalLeakVolumeM3: Double,
    val conditionalVolumeStandardUncertaintyM3: Double,
    val conditionalVolumeIntervalLowerM3: Double,
    val conditionalVolumeIntervalUpperM3: Double,
    val acousticDetectionProbability: Double,
    val expectedProbabilisticLossM3: Double,
    val reportConfidenceStatus: String,
    val planningOnlyStatus: Boolean,
    val humanReviewRequired: Boolean,
    val explanation: String
)

object LeakVolumeUncertainty {
    fun calculate(input: LeakVolumeInput): LeakVolumeResult {
        validate(input)

        val pressureDifferentialPa = input.pressurePa - input.outletPressurePa

        if (pressureDifferentialPa <= 0.0) {
            return LeakVolumeResult(
                conditionalLeakFlowM3S = 0.0,
                conditionalLeakVolumeM3 = 0.0,
                conditionalVolumeStandardUncertaintyM3 = 0.0,
                conditionalVolumeIntervalLowerM3 = 0.0,
                conditionalVolumeIntervalUpperM3 = 0.0,
                acousticDetectionProbability = input.acousticDetectionProbability,
                expectedProbabilisticLossM3 = 0.0,
                reportConfidenceStatus = "hold_for_review",
                planningOnlyStatus = true,
                humanReviewRequired = true,
                explanation = "Pressure differential is not positive; no conditional flow estimate is produced."
            )
        }

        val velocityMPerS = sqrt(
            2.0 * pressureDifferentialPa / input.waterDensityKgM3
        )

        val conditionalFlowM3S =
            input.dischargeCoefficient * input.leakAreaProxyM2 * velocityMPerS

        val conditionalVolumeM3 =
            conditionalFlowM3S * input.durationSeconds

        val derivativeArea =
            input.dischargeCoefficient
                * input.durationSeconds
                * velocityMPerS

        val derivativePressure =
            input.dischargeCoefficient
                * input.leakAreaProxyM2
                * input.durationSeconds
                / (
                    input.waterDensityKgM3
                        * max(velocityMPerS, 1.0e-12)
                )

        val derivativeDuration = conditionalFlowM3S

        val derivativeDischargeCoefficient =
            input.leakAreaProxyM2
                * input.durationSeconds
                * velocityMPerS

        val areaVariance =
            squared(derivativeArea) * squared(input.leakAreaProxyUncertaintyM2)

        val pressureVariance =
            squared(derivativePressure) * squared(input.pressureUncertaintyPa)

        val durationVariance =
            squared(derivativeDuration) * squared(input.durationUncertaintySeconds)

        val dischargeCoefficientVariance =
            squared(derivativeDischargeCoefficient)
                * squared(input.dischargeCoefficientUncertainty)

        val conditionalVolumeStandardUncertaintyM3 = sqrt(
            areaVariance
                + pressureVariance
                + durationVariance
                + dischargeCoefficientVariance
        )

        val intervalHalfWidth =
            STANDARD_NORMAL_95 * conditionalVolumeStandardUncertaintyM3

        val lowerIntervalM3 = max(
            0.0,
            conditionalVolumeM3 - intervalHalfWidth
        )

        val upperIntervalM3 =
            conditionalVolumeM3 + intervalHalfWidth

        val expectedProbabilisticLossM3 =
            input.acousticDetectionProbability * conditionalVolumeM3

        val qualityApproved =
            input.telemetryQuality >= MINIMUM_TELEMETRY_QUALITY &&
                input.modelCalibrationStatus in setOf("approved", "qualified") &&
                input.humanReviewStatus in setOf("approved", "qualified")

        val relativeUncertainty =
            if (conditionalVolumeM3 > 0.0) {
                conditionalVolumeStandardUncertaintyM3 / conditionalVolumeM3
            } else {
                1.0
            }

        val confidenceStatus = when {
            !qualityApproved -> "hold_for_review"
            relativeUncertainty > 0.50 -> "monitoring_only"
            else -> "qualified"
        }

        val explanation = buildString {
            append(
                "Conditional volume is estimated only if a leak is present, using an "
            )
            append(
                "orifice-style flow model with independent first-order uncertainty propagation. "
            )
            append(
                "Acoustic detection probability is reported separately and is used only to "
            )
            append(
                "calculate a clearly labeled probabilistic planning estimate. "
            )
            append(
                "The result is planning-only and must be confirmed by qualified field inspection."
            )
        }

        return LeakVolumeResult(
            conditionalLeakFlowM3S = conditionalFlowM3S,
            conditionalLeakVolumeM3 = conditionalVolumeM3,
            conditionalVolumeStandardUncertaintyM3 = conditionalVolumeStandardUncertaintyM3,
            conditionalVolumeIntervalLowerM3 = lowerIntervalM3,
            conditionalVolumeIntervalUpperM3 = upperIntervalM3,
            acousticDetectionProbability = input.acousticDetectionProbability,
            expectedProbabilisticLossM3 = expectedProbabilisticLossM3,
            reportConfidenceStatus = confidenceStatus,
            planningOnlyStatus = true,
            humanReviewRequired = true,
            explanation = explanation
        )
    }

    private fun validate(input: LeakVolumeInput) {
        requireNonBlank(input.leakReportId, "leakReportId")
        requireNonBlank(input.pipeAssetId, "pipeAssetId")
        requireNonBlank(input.acousticModelVersion, "acousticModelVersion")
        requireNonBlank(input.pipeConditionModelVersion, "pipeConditionModelVersion")
        requireNonBlank(input.modelCalibrationStatus, "modelCalibrationStatus")
        requireNonBlank(input.humanReviewStatus, "humanReviewStatus")

        requireFiniteRange(input.pressurePa, "pressurePa", 0.0, MAXIMUM_PRESSURE_PA)
        requireFiniteRange(
            input.pressureUncertaintyPa,
            "pressureUncertaintyPa",
            0.0,
            MAXIMUM_PRESSURE_PA
        )
        requireFiniteRange(
            input.outletPressurePa,
            "outletPressurePa",
            0.0,
            MAXIMUM_PRESSURE_PA
        )
        requireFiniteRange(
            input.leakAreaProxyM2,
            "leakAreaProxyM2",
            0.0,
            MAXIMUM_AREA_M2
        )
        requireFiniteRange(
            input.leakAreaProxyUncertaintyM2,
            "leakAreaProxyUncertaintyM2",
            0.0,
            MAXIMUM_AREA_M2
        )
        requireFiniteRange(
            input.dischargeCoefficient,
            "dischargeCoefficient",
            1.0e-9,
            2.0
        )
        requireFiniteRange(
            input.dischargeCoefficientUncertainty,
            "dischargeCoefficientUncertainty",
            0.0,
            2.0
        )
        requireFiniteRange(
            input.waterDensityKgM3,
            "waterDensityKgM3",
            1.0,
            MAXIMUM_DENSITY_KG_M3
        )
        requireFiniteRange(
            input.durationSeconds,
            "durationSeconds",
            0.0,
            MAXIMUM_DURATION_SECONDS
        )
        requireFiniteRange(
            input.durationUncertaintySeconds,
            "durationUncertaintySeconds",
            0.0,
            MAXIMUM_DURATION_SECONDS
        )
        requireFiniteRange(
            input.acousticDetectionProbability,
            "acousticDetectionProbability",
            0.0,
            1.0
        )
        requireFiniteRange(
            input.telemetryQuality,
            "telemetryQuality",
            0.0,
            1.0
        )
    }

    private fun requireFiniteRange(
        value: Double,
        name: String,
        minimum: Double,
        maximum: Double
    ) {
        require(value.isFinite() && value in minimum..maximum) {
            "$name must be finite and within its permitted range"
        }
    }

    private fun requireNonBlank(value: String, name: String) {
        require(value.isNotBlank()) {
            "$name must not be blank"
        }
    }

    private fun squared(value: Double): Double = value * value
}

fun main(args: Array<String>) {
    require(args.size == 18) {
        "Usage: LeakVolumeUncertainty " +
            "leak_report_id pipe_asset_id pressure_pa pressure_uncertainty_pa " +
            "outlet_pressure_pa leak_area_proxy_m2 leak_area_proxy_uncertainty_m2 " +
            "discharge_coefficient discharge_coefficient_uncertainty water_density_kg_m3 " +
            "duration_seconds duration_uncertainty_seconds acoustic_detection_probability " +
            "acoustic_model_version pipe_condition_model_version telemetry_quality " +
            "model_calibration_status human_review_status"
    }

    val input = LeakVolumeInput(
        leakReportId = args[0],
        pipeAssetId = args[1],
        pressurePa = args[2].toDouble(),
        pressureUncertaintyPa = args[3].toDouble(),
        outletPressurePa = args[4].toDouble(),
        leakAreaProxyM2 = args[5].toDouble(),
        leakAreaProxyUncertaintyM2 = args[6].toDouble(),
        dischargeCoefficient = args[7].toDouble(),
        dischargeCoefficientUncertainty = args[8].toDouble(),
        waterDensityKgM3 = args[9].toDouble(),
        durationSeconds = args[10].toDouble(),
        durationUncertaintySeconds = args[11].toDouble(),
        acousticDetectionProbability = args[12].toDouble(),
        acousticModelVersion = args[13],
        pipeConditionModelVersion = args[14],
        telemetryQuality = args[15].toDouble(),
        modelCalibrationStatus = args[16],
        humanReviewStatus = args[17]
    )

    val result = LeakVolumeUncertainty.calculate(input)

    println("conditional_leak_flow_m3_s=%.12f".format(result.conditionalLeakFlowM3S))
    println("conditional_leak_volume_m3=%.12f".format(result.conditionalLeakVolumeM3))
    println(
        "conditional_volume_standard_uncertainty_m3=%.12f".format(
            result.conditionalVolumeStandardUncertaintyM3
        )
    )
    println(
        "conditional_volume_interval_m3=[%.12f,%.12f]".format(
            result.conditionalVolumeIntervalLowerM3,
            result.conditionalVolumeIntervalUpperM3
        )
    )
    println("acoustic_detection_probability=%.12f".format(result.acousticDetectionProbability))
    println("expected_probabilistic_loss_m3=%.12f".format(result.expectedProbabilisticLossM3))
    println("report_confidence_status=${result.reportConfidenceStatus}")
    println("planning_only_status=${result.planningOnlyStatus}")
    println("human_review_required=${result.humanReviewRequired}")
    println("issues_repair_work_orders=false")
    println("affects_billing=false")
    println("identifies_responsible_party=false")
    println("triggers_enforcement=false")
    println("infers_household_behavior=false")
    println("explanation=${result.explanation}")
}
