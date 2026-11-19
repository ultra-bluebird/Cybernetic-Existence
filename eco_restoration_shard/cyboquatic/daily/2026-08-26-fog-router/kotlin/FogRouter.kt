import kotlin.math.abs

data class Observation(
    val nodeId: String,
    val observedAt: String,
    val media: String,
    val confidence: Double,
    val completeness: Double,
    val fog: Boolean,
    val flowM3S: Double,
    val temperatureC: Double,
    val measurementQuality: Double,
    val k: Double,
    val e: Double,
    val r: Double,
    val consentActive: Boolean
)

data class Decision(
    val route: String,
    val code: String,
    val explanation: String
)

private val knownMedia = setOf(
    "freshwater",
    "brackish_water",
    "wastewater",
    "stormwater",
    "sediment"
)

private fun finiteInRange(value: Double, minimum: Double, maximum: Double): Boolean {
    return value.isFinite() && value >= minimum && value <= maximum
}

fun routeObservation(value: Observation): Decision {
    if (value.nodeId.isBlank() || value.observedAt.isBlank()) {
        return Decision(
            "REJECTED_INPUT",
            "MISSING_REQUIRED_FIELD",
            "A pseudonymous node identifier and observation time are required."
        )
    }
    if (!value.consentActive) {
        return Decision(
            "REJECTED_INPUT",
            "CONSENT_NOT_ACTIVE",
            "The purpose-limited consent state is not active; do not process this observation."
        )
    }
    if (!finiteInRange(value.confidence, 0.0, 1.0) ||
        !finiteInRange(value.completeness, 0.0, 1.0) ||
        !finiteInRange(value.measurementQuality, 0.0, 1.0) ||
        !finiteInRange(value.k, 0.0, 1.0) ||
        !finiteInRange(value.e, 0.0, 1.0) ||
        !finiteInRange(value.r, 0.0, 1.0) ||
        !finiteInRange(value.flowM3S, 0.0, 1000.0) ||
        !finiteInRange(value.temperatureC, -5.0, 60.0)
    ) {
        return Decision(
            "REJECTED_INPUT",
            "INVALID_BOUNDED_VALUE",
            "One or more measurements are missing, non-finite, or outside the configured local bounds."
        )
    }
    if (value.fog || value.media !in knownMedia) {
        return Decision(
            "FOG_REVIEW",
            "FOG_EXPLICIT",
            "FOG is explicit or the media is unknown; preserve uncertainty and request qualified human review."
        )
    }
    if (value.completeness < 0.90 || value.confidence < 0.70 ||
        value.measurementQuality < 0.70 || value.k < 0.70
    ) {
        return Decision(
            "FOG_REVIEW",
            "EVIDENCE_INCOMPLETE",
            "Evidence completeness, confidence, measurement quality, or knowledge quality is insufficient for known-media review."
        )
    }
    if (value.r > 0.30) {
        return Decision(
            "QUARANTINED_INPUT",
            "RISK_ABOVE_AUTOMATION_BOUND",
            "Risk of harm exceeds 0.30; quarantine the record for qualified human review and do not automate a recommendation."
        )
    }
    return Decision(
        "KNOWN_MEDIA",
        "KNOWN_MEDIA_READY",
        "Known media with complete, authorized evidence is suitable for human review only; no physical action is authorized."
    )
}

private fun parseBoolean(text: String): Boolean {
    require(text == "true" || text == "false") {
        "Boolean values must be lowercase true or false."
    }
    return text.toBoolean()
}

fun main(args: Array<String>) {
    if (args.size != 13) {
        System.err.println(
            "usage: FogRouter node_id observed_at media confidence completeness fog flow_m3_s " +
                "temperature_c measurement_quality K E R consent_active"
        )
        return
    }

    try {
        val value = Observation(
            nodeId = args[0],
            observedAt = args[1],
            media = args[2],
            confidence = args[3].toDouble(),
            completeness = args[4].toDouble(),
            fog = parseBoolean(args[5]),
            flowM3S = args[6].toDouble(),
            temperatureC = args[7].toDouble(),
            measurementQuality = args[8].toDouble(),
            k = args[9].toDouble(),
            e = args[10].toDouble(),
            r = args[11].toDouble(),
            consentActive = parseBoolean(args[12])
        )
        val decision = routeObservation(value)
        println("route=${decision.route}")
        println("code=${decision.code}")
        println("explanation=${decision.explanation}")
    } catch (exception: IllegalArgumentException) {
        println("route=REJECTED_INPUT")
        println("code=PARSE_FAILURE")
        println("explanation=${exception.message}")
    }
}
