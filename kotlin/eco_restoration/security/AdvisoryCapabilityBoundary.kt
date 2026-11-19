package eco_restoration.security

interface ReadOnlyEvidenceStore {
    fun readEvidence(evidenceId: String): String?
}

interface AdvisorySink {
    fun appendAdvisory(advisory: AdvisoryRecord): Boolean
}

data class AdvisoryRecord(
    val advisoryId: String,
    val evidenceId: String,
    val status: String,
    val fogState: String,
    val plainLanguageReason: String
) {
    init {
        require(advisoryId.isNotBlank()) { "advisoryId must not be blank." }
        require(evidenceId.isNotBlank()) { "evidenceId must not be blank." }
        require(status.isNotBlank()) { "status must not be blank." }
        require(fogState.isNotBlank()) { "fogState must not be blank." }
        require(plainLanguageReason.isNotBlank()) {
            "plainLanguageReason must not be blank."
        }
    }
}

class AdvisoryEvaluationService(
    private val evidenceStore: ReadOnlyEvidenceStore,
    private val advisorySink: AdvisorySink
) {
    fun evaluate(evidenceId: String, advisoryId: String): AdvisoryRecord {
        require(evidenceId.isNotBlank()) { "evidenceId must not be blank." }
        require(advisoryId.isNotBlank()) { "advisoryId must not be blank." }

        val evidence = evidenceStore.readEvidence(evidenceId)

        val advisory = if (evidence == null) {
            AdvisoryRecord(
                advisoryId,
                evidenceId,
                "withheld",
                "withhold",
                "Evidence is unavailable in the local read-only evidence store."
            )
        } else {
            AdvisoryRecord(
                advisoryId,
                evidenceId,
                "informational",
                "clear",
                "Local evidence was evaluated through an advisory-only capability boundary."
            )
        }

        advisorySink.appendAdvisory(advisory)
        return advisory
    }
}
