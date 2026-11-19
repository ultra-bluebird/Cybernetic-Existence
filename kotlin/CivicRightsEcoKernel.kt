package augmentedhub.civic

import kotlin.math.max
import kotlin.math.min

data class TransitServiceProfile(
    val chargingAvailable: Boolean,
    val quietCarOrLowStimulusAreaAvailable: Boolean,
    val accessibleInformationAvailable: Boolean,
    val privacyPreservingTicketingAvailable: Boolean,
    val climateControlledWaitingAvailable: Boolean,
    val identityBasedFareDifferentiation: Boolean,
    val accessibility: Double,
    val efficiency: Double,
    val dignity: Double
)

data class BotOperationContext(
    val taskNecessary: Boolean,
    val ethicalConstraintSatisfied: Boolean,
    val privacyPreserved: Boolean,
    val uncertaintyPresent: Boolean,
    val personTrackingEnabled: Boolean,
    val biometricCollectionEnabled: Boolean,
    val personalSpaceClear: Boolean,
    val accessibleCommunicationAvailable: Boolean,
    val transparentOperationNoticeAvailable: Boolean,
    val nonDiscriminatoryServiceVerified: Boolean
)

enum class BotDecision {
    PROCEED,
    DEFER,
    AVOID
}

data class EcoMonitoringProfile(
    val environmentalSensorsOnly: Boolean,
    val satelliteResolutionMeters: Int,
    val communityReportsVoluntary: Boolean,
    val communityReportsAnonymous: Boolean,
    val cameraMonitoringForEcoPurposeEnabled: Boolean,
    val exactContributorLocationRetained: Boolean,
    val individualContributionHistoryRetained: Boolean,
    val heatIslandReductionMeasured: Boolean,
    val airQualityImprovementMeasured: Boolean,
    val shadeCoverageIncreaseMeasured: Boolean,
    val biodiversityIndicatorsMeasured: Boolean,
    val waterConservationMeasured: Boolean
)

data class EcoMonitoringDecision(
    val allowed: Boolean,
    val unmetRequirements: List<String>
)

private fun requireUnitInterval(value: Double, fieldName: String) {
    require(value in 0.0..1.0) {
        "$fieldName must be within [0, 1]."
    }
}

fun transitServiceEligible(profile: TransitServiceProfile): Boolean {
    requireUnitInterval(profile.accessibility, "accessibility")
    requireUnitInterval(profile.efficiency, "efficiency")
    requireUnitInterval(profile.dignity, "dignity")

    return profile.chargingAvailable &&
        profile.quietCarOrLowStimulusAreaAvailable &&
        profile.accessibleInformationAvailable &&
        profile.privacyPreservingTicketingAvailable &&
        profile.climateControlledWaitingAvailable &&
        !profile.identityBasedFareDifferentiation
}

fun transitScheduleValue(profile: TransitServiceProfile): Double {
    if (!transitServiceEligible(profile)) {
        return 0.0
    }

    return profile.accessibility * profile.efficiency * profile.dignity
}

fun decideMaintenanceBotAction(context: BotOperationContext): BotDecision {
    val privacyViolated = context.personTrackingEnabled ||
        context.biometricCollectionEnabled ||
        !context.privacyPreserved

    val ethicalFailure = !context.ethicalConstraintSatisfied ||
        !context.personalSpaceClear ||
        !context.accessibleCommunicationAvailable ||
        !context.transparentOperationNoticeAvailable ||
        !context.nonDiscriminatoryServiceVerified

    if (privacyViolated || ethicalFailure) {
        return BotDecision.AVOID
    }

    if (context.uncertaintyPresent || !context.taskNecessary) {
        return BotDecision.DEFER
    }

    return BotDecision.PROCEED
}

fun validateEcoMonitoring(profile: EcoMonitoringProfile): EcoMonitoringDecision {
    val unmet = mutableListOf<String>()

    if (!profile.environmentalSensorsOnly) {
        unmet.add("environmental sensors must not measure or identify people")
    }

    if (profile.satelliteResolutionMeters < 100) {
        unmet.add("satellite data must be aggregated at block-level resolution")
    }

    if (!profile.communityReportsVoluntary) {
        unmet.add("community reports must be voluntary")
    }

    if (!profile.communityReportsAnonymous) {
        unmet.add("community reports must be anonymous")
    }

    if (profile.cameraMonitoringForEcoPurposeEnabled) {
        unmet.add("camera monitoring for eco purposes is prohibited")
    }

    if (profile.exactContributorLocationRetained) {
        unmet.add("exact contributor location must not be retained")
    }

    if (profile.individualContributionHistoryRetained) {
        unmet.add("individual contribution history must not be retained")
    }

    if (!profile.heatIslandReductionMeasured) {
        unmet.add("heat-island reduction metric is required")
    }

    if (!profile.airQualityImprovementMeasured) {
        unmet.add("air-quality improvement metric is required")
    }

    if (!profile.shadeCoverageIncreaseMeasured) {
        unmet.add("shade-coverage metric is required")
    }

    if (!profile.biodiversityIndicatorsMeasured) {
        unmet.add("biodiversity metric is required")
    }

    if (!profile.waterConservationMeasured) {
        unmet.add("water-conservation metric is required")
    }

    return EcoMonitoringDecision(
        allowed = unmet.isEmpty(),
        unmetRequirements = unmet
    )
}

fun boundedEnvironmentalConfidence(
    sensorConfidence: Double,
    calibrationConfidence: Double,
    reportConfidence: Double
): Double {
    requireUnitInterval(sensorConfidence, "sensorConfidence")
    requireUnitInterval(calibrationConfidence, "calibrationConfidence")
    requireUnitInterval(reportConfidence, "reportConfidence")

    return min(
        sensorConfidence,
        min(calibrationConfidence, reportConfidence)
    )
}

fun conservativeEcoPriority(
    heatBurden: Double,
    airQualityBurden: Double,
    shadeDeficit: Double,
    biodiversityRisk: Double,
    waterStress: Double,
    evidenceConfidence: Double
): Double {
    val values = listOf(
        heatBurden,
        airQualityBurden,
        shadeDeficit,
        biodiversityRisk,
        waterStress,
        evidenceConfidence
    )

    values.forEach { requireUnitInterval(it, "eco-priority input") }

    val burden = max(
        heatBurden,
        max(
            airQualityBurden,
            max(shadeDeficit, max(biodiversityRisk, waterStress))
        )
    )

    return burden * evidenceConfidence
}
