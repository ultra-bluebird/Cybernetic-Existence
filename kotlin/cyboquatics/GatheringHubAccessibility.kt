package cyboquatics

object GatheringHubAccessibility {
    data class HubMetricInput(
        val hubId: String,
        val entranceClearWidthM: Double,
        val requiredEntranceClearWidthM: Double,
        val rampSlopeRatio: Double,
        val shadeScore: Double,
        val seatingScore: Double,
        val transitProximityScore: Double,
        val routeContinuityScore: Double,
        val informationAccessScore: Double,
        val individualTrackingPresent: Boolean,
        val personalDataPresent: Boolean
    )

    data class ComponentScores(
        val entranceScore: Double,
        val rampScore: Double,
        val shadeScore: Double,
        val seatingScore: Double,
        val transitProximityScore: Double,
        val routeContinuityScore: Double,
        val informationAccessScore: Double
    )

    fun components(input: HubMetricInput): ComponentScores? {
        if (
            input.hubId.isBlank() ||
            !input.entranceClearWidthM.isFinite() ||
            !input.requiredEntranceClearWidthM.isFinite() ||
            input.entranceClearWidthM <= 0.0 ||
            input.requiredEntranceClearWidthM <= 0.0 ||
            !input.rampSlopeRatio.isFinite() ||
            input.rampSlopeRatio < 0.0 ||
            listOf(
                input.shadeScore,
                input.seatingScore,
                input.transitProximityScore,
                input.routeContinuityScore,
                input.informationAccessScore
            ).any { !it.isFinite() || it !in 0.0..1.0 }
        ) {
            return null
        }

        val entranceScore = (input.entranceClearWidthM / input.requiredEntranceClearWidthM)
            .coerceIn(0.0, 1.0)
        val rampScore = if (input.rampSlopeRatio <= 1.0 / 12.0) 1.0 else 0.0

        return ComponentScores(
            entranceScore,
            rampScore,
            input.shadeScore,
            input.seatingScore,
            input.transitProximityScore,
            input.routeContinuityScore,
            input.informationAccessScore
        )
    }
}
