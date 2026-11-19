package cyboquatics

object RoutingAuditProvenance {
    enum class ReviewStatus {
        PENDING,
        NOT_REQUIRED,
        IN_REVIEW,
        COMPLETE,
        APPEALED
    }

    data class Record(
        val auditEventId: String,
        val observationId: String,
        val nodePseudonym: String,
        val routeCode: String,
        val explanationCode: String,
        val explanationText: String,
        val reviewStatus: ReviewStatus,
        val observedAtUtc: String,
        val policyId: String,
        val inputSchemaVersion: String,
        val rawSensitiveDataPresent: Boolean,
        val exactPersonalLocationPresent: Boolean,
        val directIdentityPresent: Boolean,
        val unboundedFreeTextPresent: Boolean
    )

    data class ValidationResult(
        val valid: Boolean,
        val reasons: List<String>
    )

    fun validate(record: Record): ValidationResult {
        val reasons = mutableListOf<String>()

        if (!token(record.auditEventId, 8, 128)) reasons += "Invalid audit event identifier."
        if (!token(record.observationId, 8, 128)) reasons += "Invalid observation identifier."
        if (!token(record.nodePseudonym, 12, 96)) reasons += "Invalid node pseudonym."
        if (!token(record.routeCode, 3, 80)) reasons += "Invalid route code."
        if (!token(record.explanationCode, 3, 80)) reasons += "Invalid explanation code."
        if (record.explanationText.isBlank() || record.explanationText.length > 240) {
            reasons += "Explanation text must be present and bounded."
        }
        if (record.observedAtUtc.isBlank()) reasons += "Observation timestamp is required."
        if (!token(record.policyId, 3, 128)) reasons += "Invalid policy identifier."
        if (!token(record.inputSchemaVersion, 1, 64)) reasons += "Invalid input schema version."
        if (record.rawSensitiveDataPresent) reasons += "Raw sensitive data is prohibited."
        if (record.exactPersonalLocationPresent) reasons += "Exact personal location is prohibited."
        if (record.directIdentityPresent) reasons += "Direct identity data is prohibited."
        if (record.unboundedFreeTextPresent) reasons += "Unbounded free text is prohibited."

        return ValidationResult(reasons.isEmpty(), reasons)
    }

    private fun token(value: String, minimum: Int, maximum: Int): Boolean {
        return value.length in minimum..maximum &&
            value.all { it.isLetterOrDigit() || it == '-' || it == '_' || it == '.' }
    }
}
