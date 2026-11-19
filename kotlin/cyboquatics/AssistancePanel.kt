package cyboquatics

object AssistancePanel {
    enum class Severity {
        INFO,
        REVIEW,
        ERROR
    }

    data class Message(
        val code: String,
        val severity: Severity,
        val plainSentence: String,
        val nextAction: String,
        val iconName: String,
        val audioText: String,
        val humanSupportAvailable: Boolean
    )

    private val messages = mapOf(
        "AP-1001" to Message(
            code = "AP-1001",
            severity = Severity.ERROR,
            plainSentence = "This panel cannot read the sensor.",
            nextAction = "Ask a worker to check the sensor.",
            iconName = "sensor-off",
            audioText = "Error AP 1001. This panel cannot read the sensor. Ask a worker to check the sensor.",
            humanSupportAvailable = true
        ),
        "AP-2001" to Message(
            code = "AP-2001",
            severity = Severity.REVIEW,
            plainSentence = "This path may be too narrow.",
            nextAction = "Use the marked alternate path or ask for help.",
            iconName = "path-review",
            audioText = "Review AP 2001. This path may be too narrow. Use the marked alternate path or ask for help.",
            humanSupportAvailable = true
        ),
        "AP-3001" to Message(
            code = "AP-3001",
            severity = Severity.REVIEW,
            plainSentence = "This water reading needs a check.",
            nextAction = "Ask a trained reviewer to check the sample record.",
            iconName = "water-review",
            audioText = "Review AP 3001. This water reading needs a check. Ask a trained reviewer to check the sample record.",
            humanSupportAvailable = true
        )
    )

    fun messageFor(code: String): Message {
        return messages[code] ?: Message(
            code = "AP-0000",
            severity = Severity.ERROR,
            plainSentence = "This panel found an unknown problem.",
            nextAction = "Ask a worker for help and show this code.",
            iconName = "unknown-problem",
            audioText = "Error AP 0000. This panel found an unknown problem. Ask a worker for help and show this code.",
            humanSupportAvailable = true
        )
    }
}
