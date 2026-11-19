package cyboquatics

object ConsentRevocationWorkflow {
    enum class ConsentState {
        ACTIVE,
        REVOKED
    }

    enum class RevocationOutcome {
        REVOCATION_ACCEPTED,
        REJECTED_INPUT
    }

    data class RevocationRequest(
        val consentId: String,
        val purposeId: String,
        val requestedAtUtc: String,
        val exportRequested: Boolean,
        val deletionRequested: Boolean,
        val accessibleSupportRequested: Boolean
    )

    data class RevocationPlan(
        val outcome: RevocationOutcome,
        val nextConsentState: ConsentState?,
        val actions: List<String>,
        val auditEventType: String?,
        val personalDataIncludedInAudit: Boolean
    )

    fun plan(request: RevocationRequest): RevocationPlan {
        if (
            request.consentId.isBlank() ||
            request.purposeId.isBlank() ||
            request.requestedAtUtc.isBlank()
        ) {
            return RevocationPlan(
                outcome = RevocationOutcome.REJECTED_INPUT,
                nextConsentState = null,
                actions = listOf("Reject incomplete revocation request and offer accessible human support."),
                auditEventType = null,
                personalDataIncludedInAudit = false
            )
        }

        val actions = mutableListOf(
            "Set consent state to REVOKED for the specified purpose and scope.",
            "Stop new collection, inference, sharing, and processing for the revoked purpose.",
            "Freeze queued work and invalidate local purpose-scoped cache entries.",
            "Inventory active records, derived records, local copies, and registered downstream processors.",
            "Run retention review and delete records without an independently documented retention basis.",
            "Send minimized revocation notices to registered downstream processors.",
            "Offer accessible correction, appeal, and human-support routes."
        )

        if (request.exportRequested) {
            actions += "Prepare a scoped export after checking that it does not expose another person's data."
        }

        if (request.deletionRequested) {
            actions += "Prioritize deletion review for records within the revoked scope."
        }

        if (request.accessibleSupportRequested) {
            actions += "Provide the selected accessible support channel without requiring identity disclosure beyond what is necessary."
        }

        actions += "Write a minimized audit event without raw environmental, neural, biometric, or identity data."

        return RevocationPlan(
            outcome = RevocationOutcome.REVOCATION_ACCEPTED,
            nextConsentState = ConsentState.REVOKED,
            actions = actions,
            auditEventType = "CONSENT_REVOCATION",
            personalDataIncludedInAudit = false
        )
    }
}
