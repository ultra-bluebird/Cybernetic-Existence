package org.augmentedhub.conformance

/**
 * Renderer for accessible, plain-language explanations of conformance decisions.
 * Preserves policy state, uncertainty, and non-compensatory protections.
 */
object ExplanationRenderer {

    /**
     * Render an accessible explanation for a conformance decision.
     */
    @JvmStatic
    fun renderAccessibleExplanation(decision: ConformanceDecision, payload: ExplanationPayload?): String {
        val sb = StringBuilder()

        // Result header
        val resultText = when (decision.outputClass) {
            OutputClass.INFORMATIONAL_ONLY -> "Informational only"
            OutputClass.ADVISORY_ONLY -> "Advisory assessment"
            OutputClass.ELIGIBLE_FOR_PLANNING_USE -> "Eligible for planning use (advisory)"
            OutputClass.NEEDS_REVIEW -> "Needs review"
            OutputClass.INSUFFICIENT_EVIDENCE -> "Insufficient evidence"
            OutputClass.CONFLICTED -> "Conflicted evidence"
            OutputClass.LOCAL_ONLY -> "Local-only processing"
            OutputClass.BLOCKED_BY_POLICY -> "Blocked by policy"
        }

        sb.appendLine("Result: $resultText.")
        sb.appendLine()

        // What was evaluated
        if (payload?.whatWasEvaluated != null) {
            sb.appendLine(payload.whatWasEvaluated)
            sb.appendLine()
        }

        // Advisory nature statement
        sb.appendLine("This is an advisory assessment only. It does not assess any person, identity, disability, health condition, assistive technology, or cybernetic status.")
        sb.appendLine()

        // Evidence status
        if (payload?.evidenceStatus != null) {
            sb.appendLine("Evidence status: ${payload.evidenceStatus}")
        } else {
            sb.appendLine("Evidence status: ${formatEvidenceStatus(decision.outputClass)}")
        }
        sb.appendLine()

        // Uncertainty or missing evidence
        if (payload?.uncertaintyMissingOrStale != null) {
            sb.appendLine("Uncertainty note: ${payload.uncertaintyMissingOrStale}")
            sb.appendLine()
        }

        // Reasons
        if (decision.reasons.isNotEmpty()) {
            sb.appendLine("Reason:")
            for (reason in decision.reasons) {
                sb.appendLine("- $reason")
            }
            sb.appendLine()
        }

        // No automated action statement
        sb.appendLine("No automated service decision or physical action is authorized by this assessment.")
        sb.appendLine()

        // Human review requirement
        if (payload?.humanReviewRequirement != null || decision.reviewState == ReviewState.PENDING) {
            sb.appendLine("Human review is required before this assessment can support planning use.")
        }
        sb.appendLine()

        // Non-digital escalation
        if (payload?.nonDigitalEscalation != null) {
            sb.appendLine("Non-digital options: ${payload.nonDigitalEscalation}")
        } else {
            sb.appendLine("Accessible follow-up and non-digital escalation options are available.")
        }

        return sb.toString()
    }

    /**
     * Render a conformance receipt for audit trail.
     */
    @JvmStatic
    fun renderConformanceReceipt(receipt: ConformanceReceipt): String {
        val sb = StringBuilder()

        sb.appendLine("=== CONFORMANCE RECEIPT ===")
        sb.appendLine()
        sb.appendLine("Timestamp: ${receipt.timestamp}")
        sb.appendLine("Metric: ${receipt.decision.metricName} (version: ${receipt.metricVersion})")
        sb.appendLine()
        sb.appendLine("Decision: ${receipt.decision.outputClass}")
        
        if (receipt.decision.automationState != null) {
            sb.appendLine("Automation State: ${receipt.decision.automationState}")
        }
        
        sb.appendLine("Release Class: ${receipt.decision.releaseClass}")
        sb.appendLine()

        sb.appendLine("Evidence Summary: ${receipt.evidenceSummary}")
        sb.appendLine()
        sb.appendLine("Uncertainty Statement: ${receipt.uncertaintyStatement}")
        sb.appendLine()

        sb.appendLine("Human Review Required: ${if (receipt.humanReviewRequired) "Yes" else "No"}")
        sb.appendLine("Non-Digital Escalation Available: ${if (receipt.nonDigitalEscalationAvailable) "Yes" else "No"}")
        sb.appendLine()
        sb.appendLine("Appeal Path: ${receipt.appealPath}")
        sb.appendLine("Correction Path: ${receipt.correctionPath}")
        sb.appendLine()
        sb.appendLine("=== END RECEIPT ===")

        return sb.toString()
    }

    private fun formatEvidenceStatus(outputClass: OutputClass): String {
        return when (outputClass) {
            OutputClass.INSUFFICIENT_EVIDENCE -> "Available evidence is insufficient for a responsible advisory conclusion"
            OutputClass.NEEDS_REVIEW -> "Evidence requires human review due to staleness, uncertainty, or boundary conditions"
            OutputClass.CONFLICTED -> "Evidence contains conflicts that must be resolved"
            OutputClass.BLOCKED_BY_POLICY -> "Policy constraints prevent processing"
            else -> "Evidence has been processed within declared bounds"
        }
    }

    /**
     * Create an explanation payload from a decision and context.
     */
    @JvmStatic
    fun createExplanationPayload(
        metricName: String,
        decision: ConformanceDecision,
        uncertaintyStatement: String? = null,
        humanReviewRequired: Boolean = true
    ): ExplanationPayload {
        return ExplanationPayload(
            whatWasEvaluated = "This advisory assessment evaluated the metric '$metricName' against available evidence and conformance requirements.",
            advisoryNature = "This result is advisory-only and does not authorize automated actions, service denials, or physical actuation.",
            evidenceStatus = formatEvidenceStatus(decision.outputClass),
            uncertaintyMissingOrStale = uncertaintyStatement,
            noPersonAssessment = "No person, identity, disability, health condition, assistive technology, or cybernetic status was assessed.",
            noAutomatedAction = "No automated service denial, gate closure, transit denial, door closure, service interruption, or autonomous actuation is authorized.",
            humanReviewRequirement = if (humanReviewRequired || decision.reviewState == ReviewState.PENDING) {
                "Human review, accessible follow-up, or non-digital escalation is required."
            } else null,
            nonDigitalEscalation = "Telephone, postal mail, relay service, and accessible in-person support options are available."
        )
    }
}
