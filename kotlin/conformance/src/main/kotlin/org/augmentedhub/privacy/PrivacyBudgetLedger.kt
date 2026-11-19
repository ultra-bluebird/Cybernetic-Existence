package org.augmentedhub.privacy

import java.time.Instant

enum class PrivacyEntryClass {
    QUERY_BUDGET_ENTRY,
    RELEASE_BUDGET_ENTRY,
    VALIDATION_BUDGET_ENTRY,
    REVOCATION_REVALIDATION_ENTRY
}

enum class PrivacyCompositionMethod {
    BASIC,
    ADVANCED,
    ZERO_KNOWLEDGE
}

enum class PrivacyReviewStatus {
    NOT_REQUIRED,
    PENDING,
    APPROVED,
    REJECTED,
    NEEDS_REVIEW
}

enum class PrivacyBudgetDecision {
    ALLOWED_LOCAL_ONLY,
    ALLOWED_PENDING_RELEASE_REVIEW,
    NEEDS_REVIEW,
    BLOCKED
}

data class PrivacyBudgetWindow(
    val purposeScope: String,
    val sensitivityClass: String,
    val windowStart: Instant,
    val expiration: Instant,
    val maximumEpsilon: Double,
    val maximumDelta: Double,
    val minimumGroupSize: Int,
    val compositionMethod: PrivacyCompositionMethod,
    val policyVersion: String
) {
    init {
        require(purposeScope.isNotBlank())
        require(sensitivityClass.isNotBlank())
        require(expiration.isAfter(windowStart))
        require(maximumEpsilon >= 0.0)
        require(maximumDelta in 0.0..1.0)
        require(minimumGroupSize >= 2)
        require(policyVersion.isNotBlank())
    }
}

data class PrivacyBudgetEntry(
    val entryClass: PrivacyEntryClass,
    val purposeScope: String,
    val sensitivityClass: String,
    val epsilonConsumed: Double,
    val deltaConsumed: Double,
    val queryIdentityHash: String,
    val policyVersion: String,
    val reviewStatus: PrivacyReviewStatus,
    val createdAt: Instant,
    val expiration: Instant
) {
    init {
        require(purposeScope.isNotBlank())
        require(sensitivityClass.isNotBlank())
        require(epsilonConsumed >= 0.0)
        require(deltaConsumed in 0.0..1.0)
        require(queryIdentityHash.matches(Regex("[a-f0-9]{64}")))
        require(policyVersion.isNotBlank())
        require(!expiration.isBefore(createdAt))
    }
}

data class PrivacyBudgetEvaluation(
    val decision: PrivacyBudgetDecision,
    val epsilonAlreadyConsumed: Double,
    val deltaAlreadyConsumed: Double,
    val epsilonAfterProposedUse: Double,
    val deltaAfterProposedUse: Double,
    val reasonCodes: Set<String>
)

class PrivacyBudgetLedger(
    private val entries: MutableList<PrivacyBudgetEntry> = mutableListOf()
) {
    fun evaluate(
        window: PrivacyBudgetWindow,
        proposed: PrivacyBudgetEntry,
        now: Instant
    ): PrivacyBudgetEvaluation {
        if (proposed.purposeScope != window.purposeScope) {
            return blocked(window, proposed, setOf("purpose_scope_mismatch"))
        }

        if (proposed.sensitivityClass != window.sensitivityClass) {
            return blocked(window, proposed, setOf("sensitivity_class_mismatch"))
        }

        if (proposed.policyVersion != window.policyVersion) {
            return blocked(window, proposed, setOf("policy_version_mismatch"))
        }

        if (now.isAfter(window.expiration)) {
            return review(window, proposed, setOf("privacy_budget_window_expired"))
        }

        if (proposed.compositionRequiresUnsupportedAccounting(window)) {
            return review(window, proposed, setOf("privacy_composition_method_requires_review"))
        }

        val activeEntries = entries.filter {
            it.purposeScope == window.purposeScope &&
                it.sensitivityClass == window.sensitivityClass &&
                it.policyVersion == window.policyVersion &&
                !it.expiration.isBefore(now)
        }

        val epsilonConsumed = activeEntries.sumOf { it.epsilonConsumed }
        val deltaConsumed = activeEntries.sumOf { it.deltaConsumed }
        val epsilonAfter = epsilonConsumed + proposed.epsilonConsumed
        val deltaAfter = deltaConsumed + proposed.deltaConsumed

        if (epsilonAfter > window.maximumEpsilon || deltaAfter > window.maximumDelta) {
            return PrivacyBudgetEvaluation(
                decision = PrivacyBudgetDecision.NEEDS_REVIEW,
                epsilonAlreadyConsumed = epsilonConsumed,
                deltaAlreadyConsumed = deltaConsumed,
                epsilonAfterProposedUse = epsilonAfter,
                deltaAfterProposedUse = deltaAfter,
                reasonCodes = setOf("privacy_budget_overdraw")
            )
        }

        return PrivacyBudgetEvaluation(
            decision = if (proposed.entryClass == PrivacyEntryClass.RELEASE_BUDGET_ENTRY) {
                PrivacyBudgetDecision.ALLOWED_PENDING_RELEASE_REVIEW
            } else {
                PrivacyBudgetDecision.ALLOWED_LOCAL_ONLY
            },
            epsilonAlreadyConsumed = epsilonConsumed,
            deltaAlreadyConsumed = deltaConsumed,
            epsilonAfterProposedUse = epsilonAfter,
            deltaAfterProposedUse = deltaAfter,
            reasonCodes = setOf("privacy_budget_available", "local_first_required")
        )
    }

    fun appendIfAllowed(
        window: PrivacyBudgetWindow,
        proposed: PrivacyBudgetEntry,
        now: Instant
    ): PrivacyBudgetEvaluation {
        val evaluation = evaluate(window, proposed, now)
        if (
            evaluation.decision == PrivacyBudgetDecision.ALLOWED_LOCAL_ONLY ||
            evaluation.decision == PrivacyBudgetDecision.ALLOWED_PENDING_RELEASE_REVIEW
        ) {
            entries += proposed
        }
        return evaluation
    }

    fun activeEntries(
        purposeScope: String,
        sensitivityClass: String,
        policyVersion: String,
        now: Instant
    ): List<PrivacyBudgetEntry> {
        return entries.filter {
            it.purposeScope == purposeScope &&
                it.sensitivityClass == sensitivityClass &&
                it.policyVersion == policyVersion &&
                !it.expiration.isBefore(now)
        }
    }

    private fun PrivacyBudgetEntry.compositionRequiresUnsupportedAccounting(
        window: PrivacyBudgetWindow
    ): Boolean {
        return window.compositionMethod != PrivacyCompositionMethod.BASIC &&
            entryClass == PrivacyEntryClass.RELEASE_BUDGET_ENTRY
    }

    private fun blocked(
        window: PrivacyBudgetWindow,
        proposed: PrivacyBudgetEntry,
        reasonCodes: Set<String>
    ): PrivacyBudgetEvaluation {
        return PrivacyBudgetEvaluation(
            decision = PrivacyBudgetDecision.BLOCKED,
            epsilonAlreadyConsumed = 0.0,
            deltaAlreadyConsumed = 0.0,
            epsilonAfterProposedUse = proposed.epsilonConsumed,
            deltaAfterProposedUse = proposed.deltaConsumed,
            reasonCodes = reasonCodes + setOf(
                "budget_window_purpose_is_non_transferable",
                "budget_borrowing_not_permitted"
            )
        )
    }

    private fun review(
        window: PrivacyBudgetWindow,
        proposed: PrivacyBudgetEntry,
        reasonCodes: Set<String>
    ): PrivacyBudgetEvaluation {
        return PrivacyBudgetEvaluation(
            decision = PrivacyBudgetDecision.NEEDS_REVIEW,
            epsilonAlreadyConsumed = 0.0,
            deltaAlreadyConsumed = 0.0,
            epsilonAfterProposedUse = proposed.epsilonConsumed,
            deltaAfterProposedUse = proposed.deltaConsumed,
            reasonCodes = reasonCodes
        )
    }
}
