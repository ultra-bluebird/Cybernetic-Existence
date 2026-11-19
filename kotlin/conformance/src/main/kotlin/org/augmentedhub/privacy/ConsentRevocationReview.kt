package org.augmentedhub.privacy

enum class RawDataAction {
    DELETE_LOCAL_RAW_DATA,
    RESTRICT_LOCAL_RAW_DATA_PENDING_REQUIRED_RETENTION_REVIEW,
    NO_RAW_DATA_PRESENT
}

enum class DerivedDataReviewOutcome {
    RETAIN_WITH_REVIEW,
    RECOMPUTE_REQUIRED,
    WITHDRAW_FROM_ACTIVE_USE,
    LOCAL_ONLY,
    NEEDS_REVIEW
}

data class RevocationRequest(
    val revokedRecordReference: String,
    val revocationScope: String,
    val policyVersion: String,
    val rawDataPresent: Boolean,
    val requiredRetentionReview: Boolean
) {
    init {
        require(revokedRecordReference.isNotBlank())
        require(revocationScope.isNotBlank())
        require(policyVersion.isNotBlank())
    }
}

data class DerivedDataAssessment(
    val derivedDataReference: String,
    val sourceRecordCountBefore: Int,
    val revokedContributionCount: Int,
    val minimumGroupSize: Int,
    val privacyBudgetValid: Boolean,
    val contributionIsolable: Boolean,
    val purposeStillValid: Boolean,
    val releaseRiskAccepted: Boolean,
    val canRecomputeWithoutRevokedSources: Boolean
) {
    init {
        require(derivedDataReference.isNotBlank())
        require(sourceRecordCountBefore >= 0)
        require(revokedContributionCount >= 0)
        require(revokedContributionCount <= sourceRecordCountBefore)
        require(minimumGroupSize >= 2)
    }

    val sourceRecordCountAfter: Int
        get() = sourceRecordCountBefore - revokedContributionCount
}

data class RevocationPropagationResult(
    val rawDataAction: RawDataAction,
    val derivativeOutcome: DerivedDataReviewOutcome,
    val sourceRecordCountAfter: Int?,
    val reasonCodes: Set<String>,
    val humanReviewRequired: Boolean,
    val localOnly: Boolean
)

object ConsentRevocationReview {
    fun evaluateRawData(request: RevocationRequest): RawDataAction {
        if (!request.rawDataPresent) {
            return RawDataAction.NO_RAW_DATA_PRESENT
        }

        return if (request.requiredRetentionReview) {
            RawDataAction.RESTRICT_LOCAL_RAW_DATA_PENDING_REQUIRED_RETENTION_REVIEW
        } else {
            RawDataAction.DELETE_LOCAL_RAW_DATA
        }
    }

    fun evaluateDerivative(
        request: RevocationRequest,
        derivative: DerivedDataAssessment
    ): RevocationPropagationResult {
        val rawAction = evaluateRawData(request)

        if (!derivative.purposeStillValid) {
            return result(
                rawAction = rawAction,
                outcome = DerivedDataReviewOutcome.WITHDRAW_FROM_ACTIVE_USE,
                countAfter = derivative.sourceRecordCountAfter,
                reasons = setOf("purpose_no_longer_valid_after_revocation"),
                humanReviewRequired = true
            )
        }

        if (derivative.sourceRecordCountAfter < derivative.minimumGroupSize) {
            return result(
                rawAction = rawAction,
                outcome = DerivedDataReviewOutcome.WITHDRAW_FROM_ACTIVE_USE,
                countAfter = derivative.sourceRecordCountAfter,
                reasons = setOf("minimum_group_size_not_met_after_revocation"),
                humanReviewRequired = true
            )
        }

        if (!derivative.privacyBudgetValid) {
            return result(
                rawAction = rawAction,
                outcome = DerivedDataReviewOutcome.NEEDS_REVIEW,
                countAfter = derivative.sourceRecordCountAfter,
                reasons = setOf("privacy_budget_revalidation_required"),
                humanReviewRequired = true
            )
        }

        if (derivative.contributionIsolable && derivative.canRecomputeWithoutRevokedSources) {
            return result(
                rawAction = rawAction,
                outcome = DerivedDataReviewOutcome.RECOMPUTE_REQUIRED,
                countAfter = derivative.sourceRecordCountAfter,
                reasons = setOf("derivative_recomputation_required_after_revocation"),
                humanReviewRequired = true
            )
        }

        if (!derivative.contributionIsolable && derivative.releaseRiskAccepted) {
            return result(
                rawAction = rawAction,
                outcome = DerivedDataReviewOutcome.RETAIN_WITH_REVIEW,
                countAfter = derivative.sourceRecordCountAfter,
                reasons = setOf(
                    "aggregate_remains_non_isolable",
                    "minimum_group_size_preserved",
                    "privacy_budget_valid"
                ),
                humanReviewRequired = true
            )
        }

        return result(
            rawAction = rawAction,
            outcome = DerivedDataReviewOutcome.LOCAL_ONLY,
            countAfter = derivative.sourceRecordCountAfter,
            reasons = setOf("derivative_requires_local_only_handling_after_revocation"),
            humanReviewRequired = true
        )
    }

    private fun result(
        rawAction: RawDataAction,
        outcome: DerivedDataReviewOutcome,
        countAfter: Int,
        reasons: Set<String>,
        humanReviewRequired: Boolean
    ): RevocationPropagationResult {
        return RevocationPropagationResult(
            rawDataAction = rawAction,
            derivativeOutcome = outcome,
            sourceRecordCountAfter = countAfter,
            reasonCodes = reasons,
            humanReviewRequired = humanReviewRequired,
            localOnly = true
        )
    }
}
