package augmentedhub.fog

import kotlin.math.max
import kotlin.math.min

enum class AccessibilitySimulationProfile {
    PLAIN_TEXT_READER,
    KEYBOARD_ONLY_FLOW,
    SCREEN_READER_SEMANTICS,
    MAGNIFICATION_REFLOW,
    LOW_BANDWIDTH_OFFLINE,
    COGNITIVE_LOAD_REVIEW,
    TRANSLATION_READINESS
}

enum class AccessibilityAuditDecision {
    ACCESSIBILITY_SCORE_AVAILABLE,
    ACCESSIBILITY_REVIEW_REQUIRED,
    REJECTED_INPUT
}

data class FogTemplateAuditInput(
    val templateId: String,
    val localeTag: String,
    val renderedText: String,
    val hasPlainLanguageStatus: Boolean,
    val hasHumanReviewPath: Boolean,
    val hasProgrammaticLabels: Boolean,
    val hasLogicalHeadingStructure: Boolean,
    val keyboardFlowComplete: Boolean,
    val statusIsNotVisualOnly: Boolean,
    val noForcedTimeLimit: Boolean,
    val offlineTextAvailable: Boolean,
    val communityReviewedTranslation: Boolean,
    val containsPersonalData: Boolean,
    val containsExecutableInstruction: Boolean
) {
    init {
        require(templateId.matches(Regex("^[A-Za-z0-9_-]{8,128}$")))
        require(localeTag.matches(Regex("^[a-z]{2}(-[A-Z]{2})?$")))
        require(renderedText.length in 1..2_000)
        require(!containsPersonalData)
        require(!containsExecutableInstruction)
    }
}

data class AccessibilityProfileResult(
    val profile: AccessibilitySimulationProfile,
    val passed: Boolean,
    val reason: String
)

data class FogAccessibilityAuditResult(
    val decision: AccessibilityAuditDecision,
    val readabilityIndex: Double,
    val normalizedReadability: Double,
    val accessibilityScore: Double,
    val profileResults: List<AccessibilityProfileResult>,
    val reasons: List<String>,
    val advisoryOnly: Boolean = true,
    val personalDataCollected: Boolean = false
)

object FogAccessibilityAudit {

    fun evaluate(input: FogTemplateAuditInput): FogAccessibilityAuditResult {
        val profileResults = listOf(
            AccessibilityProfileResult(
                AccessibilitySimulationProfile.PLAIN_TEXT_READER,
                input.hasPlainLanguageStatus && fleschKincaidGrade(input.renderedText) <= 10.0,
                "Plain-language status must be present and English reading-grade estimate must be at or below 10."
            ),
            AccessibilityProfileResult(
                AccessibilitySimulationProfile.KEYBOARD_ONLY_FLOW,
                input.keyboardFlowComplete,
                "All review-path controls must be reachable by keyboard."
            ),
            AccessibilityProfileResult(
                AccessibilitySimulationProfile.SCREEN_READER_SEMANTICS,
                input.hasProgrammaticLabels
                    && input.hasLogicalHeadingStructure
                    && input.statusIsNotVisualOnly,
                "Labels, headings, and status meaning must be available nonvisually."
            ),
            AccessibilityProfileResult(
                AccessibilitySimulationProfile.MAGNIFICATION_REFLOW,
                input.statusIsNotVisualOnly,
                "Status meaning must not depend on color, position, or visual-only presentation."
            ),
            AccessibilityProfileResult(
                AccessibilitySimulationProfile.LOW_BANDWIDTH_OFFLINE,
                input.offlineTextAvailable,
                "The essential review status and correction path must remain available offline."
            ),
            AccessibilityProfileResult(
                AccessibilitySimulationProfile.COGNITIVE_LOAD_REVIEW,
                input.noForcedTimeLimit && input.hasHumanReviewPath,
                "Users must have adequate time and an accessible human-review route."
            ),
            AccessibilityProfileResult(
                AccessibilitySimulationProfile.TRANSLATION_READINESS,
                input.localeTag == "en" || input.communityReviewedTranslation,
                "Non-English templates require community-reviewed translation status."
            )
        )

        val reasons = mutableListOf<String>()

        if (input.containsPersonalData) {
            reasons += "Personal data is prohibited from accessibility template audits."
        }

        if (input.containsExecutableInstruction) {
            reasons += "Executable or operational instructions are prohibited in correction templates."
        }

        profileResults
            .filterNot { it.passed }
            .forEach { reasons += it.reason }

        val fkgl = fleschKincaidGrade(input.renderedText)
        val normalizedReadability = normalizeReadability(fkgl)

        val semanticScore = if (
            input.hasProgrammaticLabels
            && input.hasLogicalHeadingStructure
            && input.statusIsNotVisualOnly
        ) 1.0 else 0.0

        val keyboardScore = if (input.keyboardFlowComplete) 1.0 else 0.0

        val languageScore = if (
            input.localeTag == "en" || input.communityReviewedTranslation
        ) 1.0 else 0.0

        val accessibilityScore =
            0.35 * normalizedReadability +
                0.30 * semanticScore +
                0.20 * keyboardScore +
                0.15 * languageScore

        val decision = if (reasons.isEmpty()) {
            AccessibilityAuditDecision.ACCESSIBILITY_SCORE_AVAILABLE
        } else {
            AccessibilityAuditDecision.ACCESSIBILITY_REVIEW_REQUIRED
        }

        return FogAccessibilityAuditResult(
            decision = decision,
            readabilityIndex = fkgl,
            normalizedReadability = normalizedReadability,
            accessibilityScore = accessibilityScore,
            profileResults = profileResults,
            reasons = reasons
        )
    }

    fun fleschKincaidGrade(text: String): Double {
        val words = Regex("[A-Za-z]+(?:'[A-Za-z]+)?")
            .findAll(text)
            .map { it.value }
            .toList()

        val sentenceCount = max(
            1,
            Regex("[.!?]+")
                .findAll(text)
                .count()
        )

        if (words.isEmpty()) {
            return 20.0
        }

        val syllables = words.sumOf(::estimateSyllables)
        val averageSentenceLength = words.size.toDouble() / sentenceCount
        val averageSyllablesPerWord = syllables.toDouble() / words.size

        return 0.39 * averageSentenceLength +
            11.8 * averageSyllablesPerWord -
            15.59
    }

    private fun estimateSyllables(word: String): Int {
        val normalized = word
            .lowercase()
            .replace(Regex("[^a-z]"), "")

        if (normalized.isEmpty()) {
            return 1
        }

        var groups = 0
        var previousWasVowel = false

        for (character in normalized) {
            val isVowel = character in "aeiouy"

            if (isVowel && !previousWasVowel) {
                groups += 1
            }

            previousWasVowel = isVowel
        }

        if (normalized.endsWith("e") && groups > 1) {
            groups -= 1
        }

        return max(1, groups)
    }

    private fun normalizeReadability(fkgl: Double): Double =
        min(1.0, max(0.0, (14.0 - fkgl) / 10.0))
}
