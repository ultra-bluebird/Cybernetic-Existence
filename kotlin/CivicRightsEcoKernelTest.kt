package augmentedhub.civic

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class CivicRightsEcoKernelTest {
    @Test
    fun transitScheduleRequiresAllRightsAndAccessFeatures() {
        val profile = TransitServiceProfile(
            chargingAvailable = true,
            quietCarOrLowStimulusAreaAvailable = true,
            accessibleInformationAvailable = true,
            privacyPreservingTicketingAvailable = true,
            climateControlledWaitingAvailable = true,
            identityBasedFareDifferentiation = false,
            accessibility = 0.95,
            efficiency = 0.86,
            dignity = 0.96
        )

        assertTrue(transitServiceEligible(profile))
        assertTrue(transitScheduleValue(profile) > 0.0)
    }

    @Test
    fun transitScheduleFailsClosedForIdentityBasedFareDifference() {
        val profile = TransitServiceProfile(
            chargingAvailable = true,
            quietCarOrLowStimulusAreaAvailable = true,
            accessibleInformationAvailable = true,
            privacyPreservingTicketingAvailable = true,
            climateControlledWaitingAvailable = true,
            identityBasedFareDifferentiation = true,
            accessibility = 0.95,
            efficiency = 0.86,
            dignity = 0.96
        )

        assertFalse(transitServiceEligible(profile))
        assertEquals(0.0, transitScheduleValue(profile))
    }

    @Test
    fun maintenanceBotAvoidsSurveillanceEnabledOperation() {
        val decision = decideMaintenanceBotAction(
            BotOperationContext(
                taskNecessary = true,
                ethicalConstraintSatisfied = true,
                privacyPreserved = true,
                uncertaintyPresent = false,
                personTrackingEnabled = true,
                biometricCollectionEnabled = false,
                personalSpaceClear = true,
                accessibleCommunicationAvailable = true,
                transparentOperationNoticeAvailable = true,
                nonDiscriminatoryServiceVerified = true
            )
        )

        assertEquals(BotDecision.AVOID, decision)
    }

    @Test
    fun maintenanceBotDefersUnderUncertainty() {
        val decision = decideMaintenanceBotAction(
            BotOperationContext(
                taskNecessary = true,
                ethicalConstraintSatisfied = true,
                privacyPreserved = true,
                uncertaintyPresent = true,
                personTrackingEnabled = false,
                biometricCollectionEnabled = false,
                personalSpaceClear = true,
                accessibleCommunicationAvailable = true,
                transparentOperationNoticeAvailable = true,
                nonDiscriminatoryServiceVerified = true
            )
        )

        assertEquals(BotDecision.DEFER, decision)
    }

    @Test
    fun ecoMonitoringRejectsCameraSurveillance() {
        val decision = validateEcoMonitoring(
            EcoMonitoringProfile(
                environmentalSensorsOnly = true,
                satelliteResolutionMeters = 100,
                communityReportsVoluntary = true,
                communityReportsAnonymous = true,
                cameraMonitoringForEcoPurposeEnabled = true,
                exactContributorLocationRetained = false,
                individualContributionHistoryRetained = false,
                heatIslandReductionMeasured = true,
                airQualityImprovementMeasured = true,
                shadeCoverageIncreaseMeasured = true,
                biodiversityIndicatorsMeasured = true,
                waterConservationMeasured = true
            )
        )

        assertFalse(decision.allowed)
        assertTrue(
            decision.unmetRequirements.contains(
                "camera monitoring for eco purposes is prohibited"
            )
        )
    }
}
