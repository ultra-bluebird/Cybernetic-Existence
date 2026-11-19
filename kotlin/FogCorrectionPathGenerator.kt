package augmentedhub.fog

import java.util.Locale

enum class CorrectionEvidenceCategory {
    UNMODELED_MEDIA,
    INSUFFICIENT_COVERAGE,
    TEMPORAL_CONFLICT,
    RESOLUTION_MISMATCH,
    SOURCE_QUALITY_GAP,
    OTHER
}

data class CorrectionPathRequest(
    val evidenceCategory: CorrectionEvidenceCategory,
    val humanContactScope: String,
    val locale: Locale = Locale.ENGLISH
) {
    init {
        require(humanContactScope.isNotBlank()) {
            "humanContactScope must not be blank"
        }
    }
}

data class CorrectionPath(
    val evidenceCategory: String,
    val suggestedAction: String,
    val humanContactScope: String,
    val plainLanguageMessage: String,
    val advisoryOnly: Boolean = true,
    val exposesSystemInternals: Boolean = false
)

object FogCorrectionPathGenerator {

    private val approvedContactScopePattern =
        Regex("^[A-Za-z0-9][A-Za-z0-9 .,_:/()\\-]{0,119}$")

    fun generate(request: CorrectionPathRequest): CorrectionPath {
        require(request.locale.language == Locale.ENGLISH.language) {
            "Only the approved English plain-language template set is available."
        }
        require(approvedContactScopePattern.matches(request.humanContactScope)) {
            "humanContactScope contains unsupported characters or exceeds the length limit."
        }

        val action = suggestedActionFor(request.evidenceCategory)

        val message = buildString {
            append("Status: This result is currently withheld because some relevant evidence is incomplete. ")
            append("What may help: ")
            append(action)
            append(" Review: You may request a human review through ")
            append(request.humanContactScope)
            append(". Privacy: You do not need to provide identity, health, augmentation, device, biometric, or private-system information to request review.")
        }

        return CorrectionPath(
            evidenceCategory = request.evidenceCategory.name,
            suggestedAction = action,
            humanContactScope = request.humanContactScope,
            plainLanguageMessage = message
        )
    }

    private fun suggestedActionFor(
        category: CorrectionEvidenceCategory
    ): String =
        when (category) {
            CorrectionEvidenceCategory.UNMODELED_MEDIA ->
                "If you choose, identify an appropriate public, community-authorized, or otherwise permitted evidence source relevant to this result."

            CorrectionEvidenceCategory.INSUFFICIENT_COVERAGE ->
                "If you choose, identify an appropriate evidence source that covers the relevant time or area."

            CorrectionEvidenceCategory.TEMPORAL_CONFLICT ->
                "If you choose, identify an appropriately dated evidence source that may help clarify the timing difference."

            CorrectionEvidenceCategory.RESOLUTION_MISMATCH ->
                "If you choose, identify an evidence source at a more suitable geographic resolution."

            CorrectionEvidenceCategory.SOURCE_QUALITY_GAP ->
                "If you choose, identify a source with clearer provenance, date, or collection context."

            CorrectionEvidenceCategory.OTHER ->
                "If you choose, request a human review to discuss what non-sensitive information may be relevant."
        }
}
