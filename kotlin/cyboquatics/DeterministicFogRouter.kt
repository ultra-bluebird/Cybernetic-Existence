package cyboquatics

object DeterministicFogRouter {
    enum class Route {
        KNOWN_MEDIA_REVIEWABLE,
        FOG_REVIEW,
        REJECTED_INPUT
    }

    enum class Reason {
        ELIGIBLE,
        INVALID_INPUT,
        UNKNOWN_MEDIA,
        HAZARD_FLAG,
        UNCERTAINTY_FLAG,
        CONFIDENCE_BELOW_700,
        COMPLETENESS_BELOW_900,
        KNOWLEDGE_BELOW_700,
        HARM_RISK_ABOVE_300
    }

    data class Input(
        val mediaClass: String,
        val confidenceMilli: Int,
        val completenessMilli: Int,
        val knowledgeFactorMilli: Int,
        val harmRiskMilli: Int,
        val uncertaintyFlag: Boolean,
        val hazardFlag: Boolean
    )

    data class Result(val route: Route, val reason: Reason)

    private val approvedMedia = setOf(
        "AQUEOUS",
        "SEDIMENT",
        "BIOREACTOR",
        "ORGANIC_DEBRIS"
    )

    fun evaluate(input: Input): Result {
        if (
            input.confidenceMilli !in 0..1000 ||
            input.completenessMilli !in 0..1000 ||
            input.knowledgeFactorMilli !in 0..1000 ||
            input.harmRiskMilli !in 0..1000
        ) {
            return Result(Route.REJECTED_INPUT, Reason.INVALID_INPUT)
        }
        if (input.mediaClass !in approvedMedia) {
            return Result(Route.REJECTED_INPUT, Reason.UNKNOWN_MEDIA)
        }
        if (input.hazardFlag) {
            return Result(Route.FOG_REVIEW, Reason.HAZARD_FLAG)
        }
        if (input.uncertaintyFlag) {
            return Result(Route.FOG_REVIEW, Reason.UNCERTAINTY_FLAG)
        }
        if (input.confidenceMilli < 700) {
            return Result(Route.FOG_REVIEW, Reason.CONFIDENCE_BELOW_700)
        }
        if (input.completenessMilli < 900) {
            return Result(Route.FOG_REVIEW, Reason.COMPLETENESS_BELOW_900)
        }
        if (input.knowledgeFactorMilli < 700) {
            return Result(Route.FOG_REVIEW, Reason.KNOWLEDGE_BELOW_700)
        }
        if (input.harmRiskMilli > 300) {
            return Result(Route.FOG_REVIEW, Reason.HARM_RISK_ABOVE_300)
        }
        return Result(Route.KNOWN_MEDIA_REVIEWABLE, Reason.ELIGIBLE)
    }
}
