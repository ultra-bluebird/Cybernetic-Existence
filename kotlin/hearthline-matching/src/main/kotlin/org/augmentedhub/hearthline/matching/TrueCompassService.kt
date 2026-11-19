package org.augmentedhub.hearthline.matching

data class CandidateView(
    val candidateRef: String,
    val connectionIntent: Set<String>,
    val interests: Set<String>,
    val pacingPreference: String?,
    val broadAreas: Set<String>
)

data class ViewerPreference(
    val acceptedAges: IntRange,
    val connectionIntent: Set<String>,
    val interests: Set<String>,
    val pacingPreference: String?,
    val broadAreas: Set<String>,
    val interestWeight: Double,
    val pacingWeight: Double,
    val broadAreaWeight: Double,
    val intentWeight: Double
)

data class AlignmentExplanation(
    val eligible: Boolean,
    val explanation: List<String>,
    val privateOrderingValue: Double?,
    val publicScoreCreated: Boolean = false,
    val crossUserAggregationPerformed: Boolean = false,
    val recoveryAttributeUsed: Boolean = false,
    val lanternStateUsed: Boolean = false,
    val externalActionAuthorized: Boolean = false
)

class TrueCompassService {
    fun align(
        viewer: ViewerPreference,
        candidate: CandidateView,
        viewerAge: Int,
        candidateAge: Int,
        visibleFields: Set<String>
    ): AlignmentExplanation {
        require(viewerAge >= 18) { "Viewer must be an adult" }
        require(candidateAge >= 18) { "Candidate must be an adult" }
        require(candidateAge in viewer.acceptedAges) {
            "Candidate age is outside the viewer's declared range"
        }

        if ("connectionIntent" !in visibleFields) {
            return AlignmentExplanation(
                eligible = false,
                explanation = listOf("Connection intent is not available."),
                privateOrderingValue = null
            )
        }

        val sharedIntent = viewer.connectionIntent.intersect(candidate.connectionIntent)

        if (sharedIntent.isEmpty()) {
            return AlignmentExplanation(
                eligible = false,
                explanation = listOf("Connection intentions do not overlap."),
                privateOrderingValue = null
            )
        }

        val weights = normalize(
            viewer.interestWeight,
            viewer.pacingWeight,
            viewer.broadAreaWeight,
            viewer.intentWeight
        )

        var orderingValue = weights.intent
        val explanation = mutableListOf(
            "You selected compatible connection intentions."
        )

        if ("interests" in visibleFields
            && viewer.interests.intersect(candidate.interests).isNotEmpty()) {
            orderingValue += weights.interest
            explanation += "You share interests that you both chose to list."
        }

        if ("pacingPreference" in visibleFields
            && viewer.pacingPreference != null
            && viewer.pacingPreference == candidate.pacingPreference) {
            orderingValue += weights.pacing
            explanation += "You selected compatible conversation pacing."
        }

        if ("broadArea" in visibleFields
            && viewer.broadAreas.intersect(candidate.broadAreas).isNotEmpty()) {
            orderingValue += weights.broadArea
            explanation += "Your chosen broad areas overlap."
        }

        return AlignmentExplanation(
            eligible = true,
            explanation = explanation,
            privateOrderingValue = orderingValue
        )
    }

    private fun normalize(
        interests: Double,
        pacing: Double,
        broadArea: Double,
        intent: Double
    ): Weights {
        require(interests >= 0.0 && pacing >= 0.0
            && broadArea >= 0.0 && intent >= 0.0) {
            "Weights must be non-negative"
        }

        val total = interests + pacing + broadArea + intent
        require(total > 0.0) { "At least one weight must be positive" }

        return Weights(
            interest = interests / total,
            pacing = pacing / total,
            broadArea = broadArea / total,
            intent = intent / total
        )
    }

    private data class Weights(
        val interest: Double,
        val pacing: Double,
        val broadArea: Double,
        val intent: Double
    )
}
