package cyboquatics

object TransitFogRouter {
    enum class Route {
        REVIEWABLE_INPUT,
        QUARANTINED_INPUT,
        REJECTED_INPUT
    }

    data class SensorInput(
        val value: Double,
        val minimum: Double,
        val maximum: Double,
        val harmRiskR: Double,
        val sensorId: String,
        val observedAtUtc: String
    )

    data class RouteResult(
        val route: Route,
        val reasons: List<String>,
        val autonomousControlPermitted: Boolean = false
    )

    fun route(input: SensorInput): RouteResult {
        val valid = input.sensorId.isNotBlank() &&
            input.observedAtUtc.isNotBlank() &&
            input.value.isFinite() &&
            input.minimum.isFinite() &&
            input.maximum.isFinite() &&
            input.harmRiskR.isFinite() &&
            input.minimum <= input.maximum &&
            input.value in input.minimum..input.maximum &&
            input.harmRiskR in 0.0..1.0

        if (!valid) {
            return RouteResult(
                Route.REJECTED_INPUT,
                listOf("Required input is non-finite, missing, or outside its declared physical range.")
            )
        }

        if (input.harmRiskR > 0.30) {
            return RouteResult(
                Route.QUARANTINED_INPUT,
                listOf("Input is bounded and valid, but harm risk exceeds 0.30.")
            )
        }

        return RouteResult(
            Route.REVIEWABLE_INPUT,
            listOf("Input is bounded and valid with harm risk at or below 0.30.")
        )
    }
}
