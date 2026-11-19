package augmentedhub.ecology

import kotlin.math.max
import kotlin.math.min

enum class WaterSourceClass {
    HARVESTED_RAINWATER,
    APPROVED_RECLAIMED_WATER,
    APPROVED_POTABLE_BACKUP
}

enum class IrrigationState {
    ENVELOPE_REVIEW_REQUIRED,
    DRAINAGE_REVIEW_REQUIRED,
    PLANT_PROTECTION_PRIORITY,
    SATURATION_PROTECTION,
    WATER_QUALITY_REVIEW_REQUIRED,
    FLOW_LIMIT_EXCEEDED,
    SUPERVISED_RECOMMENDATION_AVAILABLE
}

data class GreenWallZonePolicy(
    val minimumVwcFraction: Double,
    val maximumVwcFraction: Double,
    val maximumIrrigationLitersPerZoneHour: Double,
    val potableBackupAllowed: Boolean,
    val rainwaterPriorityEnabled: Boolean,
    val leakDetectionRequired: Boolean,
    val overflowDetectionRequired: Boolean,
    val drainageHealthRequired: Boolean,
    val automaticIrrigationOnLeakAllowed: Boolean
) {
    fun validate(): GreenWallZonePolicy {
        require(minimumVwcFraction in 0.01..0.95) {
            "minimumVwcFraction must be between 0.01 and 0.95."
        }
        require(maximumVwcFraction in 0.05..0.99) {
            "maximumVwcFraction must be between 0.05 and 0.99."
        }
        require(minimumVwcFraction < maximumVwcFraction) {
            "minimumVwcFraction must be below maximumVwcFraction."
        }
        require(maximumIrrigationLitersPerZoneHour > 0.0) {
            "maximumIrrigationLitersPerZoneHour must be positive."
        }
        require(leakDetectionRequired) {
            "Leak detection is required."
        }
        require(overflowDetectionRequired) {
            "Overflow detection is required."
        }
        require(drainageHealthRequired) {
            "Drainage health monitoring is required."
        }
        require(!automaticIrrigationOnLeakAllowed) {
            "Automatic irrigation on a leak condition is prohibited."
        }
        return this
    }
}

data class GreenWallZoneState(
    val vwcFraction: Double,
    val substrateTemperatureCelsius: Double,
    val airTemperatureCelsius: Double,
    val relativeHumidityFraction: Double,
    val wallIrradianceWattsPerSquareMeter: Double,
    val rainExpectedMillimeters: Double,
    val harvestedRainwaterAvailableLiters: Double,
    val reclaimedWaterAvailableLiters: Double,
    val potableWaterAvailableLiters: Double,
    val leakDetected: Boolean,
    val overflowDetected: Boolean,
    val drainageHealthy: Boolean,
    val waterQualityApproved: Boolean
) {
    fun validate(): GreenWallZoneState {
        require(vwcFraction in 0.0..1.0) {
            "vwcFraction must be between 0 and 1."
        }
        require(substrateTemperatureCelsius.isFinite()) {
            "substrateTemperatureCelsius must be finite."
        }
        require(airTemperatureCelsius.isFinite()) {
            "airTemperatureCelsius must be finite."
        }
        require(relativeHumidityFraction in 0.0..1.0) {
            "relativeHumidityFraction must be between 0 and 1."
        }
        require(wallIrradianceWattsPerSquareMeter >= 0.0 && wallIrradianceWattsPerSquareMeter.isFinite()) {
            "wallIrradianceWattsPerSquareMeter must be finite and non-negative."
        }
        require(rainExpectedMillimeters >= 0.0 && rainExpectedMillimeters.isFinite()) {
            "rainExpectedMillimeters must be finite and non-negative."
        }
        require(harvestedRainwaterAvailableLiters >= 0.0) {
            "harvestedRainwaterAvailableLiters must be non-negative."
        }
        require(reclaimedWaterAvailableLiters >= 0.0) {
            "reclaimedWaterAvailableLiters must be non-negative."
        }
        require(potableWaterAvailableLiters >= 0.0) {
            "potableWaterAvailableLiters must be non-negative."
        }
        return this
    }
}

data class IrrigationRecommendation(
    val state: IrrigationState,
    val recommendedLitersPerHour: Double,
    val preferredWaterSource: WaterSourceClass?,
    val requiresHumanReview: Boolean,
    val explanation: String,
    val individualDataUsed: Boolean,
    val externalExportAllowed: Boolean
)

object GreenWallIrrigationRecommendation {
    fun recommend(
        policy: GreenWallZonePolicy,
        state: GreenWallZoneState,
        requestedLitersPerHour: Double
    ): IrrigationRecommendation {
        policy.validate()
        state.validate()

        require(
            requestedLitersPerHour.isFinite() &&
                requestedLitersPerHour >= 0.0
        ) {
            "requestedLitersPerHour must be finite and non-negative."
        }

        if (state.leakDetected) {
            return blocked(
                IrrigationState.ENVELOPE_REVIEW_REQUIRED,
                "Leak evidence requires qualified building-envelope review before irrigation can continue."
            )
        }

        if (state.overflowDetected || !state.drainageHealthy) {
            return blocked(
                IrrigationState.DRAINAGE_REVIEW_REQUIRED,
                "Overflow or drainage-health evidence requires drainage review before irrigation can continue."
            )
        }

        if (!state.waterQualityApproved) {
            return blocked(
                IrrigationState.WATER_QUALITY_REVIEW_REQUIRED,
                "The available irrigation water source has not passed its required quality validation."
            )
        }

        if (state.vwcFraction >= policy.maximumVwcFraction) {
            return blocked(
                IrrigationState.SATURATION_PROTECTION,
                "Substrate moisture is at or above the approved maximum; irrigation is withheld."
            )
        }

        val source = selectWaterSource(policy, state)

        if (source == null) {
            return blocked(
                IrrigationState.WATER_QUALITY_REVIEW_REQUIRED,
                "No approved water source is currently available."
            )
        }

        val dryingPressure = dryingPressure(state)
        val moistureDeficit = max(0.0, policy.minimumVwcFraction - state.vwcFraction)

        val plantProtectionBoost = if (moistureDeficit > 0.0) {
            1.0 + min(1.0, moistureDeficit / policy.minimumVwcFraction)
        } else {
            1.0
        }

        val forecastReduction = if (state.rainExpectedMillimeters >= 5.0) {
            0.5
        } else {
            1.0
        }

        val recommended = min(
            policy.maximumIrrigationLitersPerZoneHour,
            requestedLitersPerHour *
                (0.5 + dryingPressure) *
                plantProtectionBoost *
                forecastReduction
        )

        val recommendationState = if (state.vwcFraction < policy.minimumVwcFraction) {
            IrrigationState.PLANT_PROTECTION_PRIORITY
        } else {
            IrrigationState.SUPERVISED_RECOMMENDATION_AVAILABLE
        }

        return IrrigationRecommendation(
            state = recommendationState,
            recommendedLitersPerHour = recommended,
            preferredWaterSource = source,
            requiresHumanReview = true,
            explanation = if (recommendationState == IrrigationState.PLANT_PROTECTION_PRIORITY) {
                "Substrate moisture is below the plant-protection minimum. A bounded irrigation recommendation is available using the preferred approved water source."
            } else {
                "A bounded supervisory irrigation recommendation is available within moisture, drainage, leak, overflow, water-quality, and flow constraints."
            },
            individualDataUsed = false,
            externalExportAllowed = false
        )
    }

    private fun selectWaterSource(
        policy: GreenWallZonePolicy,
        state: GreenWallZoneState
    ): WaterSourceClass? {
        if (policy.rainwaterPriorityEnabled && state.harvestedRainwaterAvailableLiters > 0.0) {
            return WaterSourceClass.HARVESTED_RAINWATER
        }

        if (state.reclaimedWaterAvailableLiters > 0.0) {
            return WaterSourceClass.APPROVED_RECLAIMED_WATER
        }

        if (policy.potableBackupAllowed && state.potableWaterAvailableLiters > 0.0) {
            return WaterSourceClass.APPROVED_POTABLE_BACKUP
        }

        return null
    }

    private fun dryingPressure(state: GreenWallZoneState): Double {
        val temperatureTerm = ((state.airTemperatureCelsius - 15.0) / 25.0)
            .coerceIn(0.0, 1.0)

        val irradianceTerm = (state.wallIrradianceWattsPerSquareMeter / 1000.0)
            .coerceIn(0.0, 1.0)

        val humidityTerm = (1.0 - state.relativeHumidityFraction)
            .coerceIn(0.0, 1.0)

        return (
            0.35 * temperatureTerm +
                0.40 * irradianceTerm +
                0.25 * humidityTerm
            ).coerceIn(0.0, 1.0)
    }

    private fun blocked(
        state: IrrigationState,
        explanation: String
    ): IrrigationRecommendation {
        return IrrigationRecommendation(
            state = state,
            recommendedLitersPerHour = 0.0,
            preferredWaterSource = null,
            requiresHumanReview = true,
            explanation = explanation,
            individualDataUsed = false,
            externalExportAllowed = false
        )
    }
}
