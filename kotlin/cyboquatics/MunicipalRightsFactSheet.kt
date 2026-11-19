package cyboquatics

object MunicipalRightsFactSheet {
    data class FactSheet(
        val sheetId: String,
        val title: String,
        val jurisdiction: String,
        val officialSourceUrl: String,
        val officialPublicationDate: String,
        val lastReviewedDate: String,
        val plainLanguageSummary: String,
        val serviceOrProcessDescription: String,
        val notLegalAdviceNotice: String,
        val accessibleFeedbackRoute: String,
        val personalDataRequested: Boolean,
        val eligibilityDecisionMade: Boolean,
        val outcomePredictionMade: Boolean
    )

    data class ValidationResult(
        val valid: Boolean,
        val reasons: List<String>
    )

    fun validate(sheet: FactSheet): ValidationResult {
        val reasons = mutableListOf<String>()

        if (sheet.sheetId.isBlank()) reasons += "A fact-sheet identifier is required."
        if (sheet.title.isBlank()) reasons += "A plain-language title is required."
        if (sheet.jurisdiction.isBlank()) reasons += "A jurisdiction is required."
        if (!sheet.officialSourceUrl.startsWith("https://")) {
            reasons += "An official HTTPS source URL is required."
        }
        if (sheet.officialPublicationDate.isBlank()) reasons += "An official publication date is required."
        if (sheet.lastReviewedDate.isBlank()) reasons += "A last-reviewed date is required."
        if (sheet.plainLanguageSummary.length !in 1..1200) {
            reasons += "The plain-language summary must be between 1 and 1200 characters."
        }
        if (sheet.serviceOrProcessDescription.isBlank()) {
            reasons += "A service or process description is required."
        }
        if (!sheet.notLegalAdviceNotice.contains("not legal advice", ignoreCase = true)) {
            reasons += "The required not-legal-advice notice is missing."
        }
        if (sheet.accessibleFeedbackRoute.isBlank()) {
            reasons += "An accessible feedback route is required."
        }
        if (sheet.personalDataRequested) reasons += "Fact sheets may not request personal data."
        if (sheet.eligibilityDecisionMade) reasons += "Fact sheets may not make eligibility decisions."
        if (sheet.outcomePredictionMade) reasons += "Fact sheets may not predict legal or administrative outcomes."

        return ValidationResult(reasons.isEmpty(), reasons)
    }
}
