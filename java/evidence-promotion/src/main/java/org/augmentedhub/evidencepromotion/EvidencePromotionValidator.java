package org.augmentedhub.evidencepromotion;

import java.util.Objects;

public final class EvidencePromotionValidator {
    public record PromotionInput(
        String evidencePacketId,
        String resultState,
        int independentUnitCount,
        int independentEventWindowCount,
        boolean holdoutValidationPassed,
        boolean uncertaintyAdequate,
        boolean confounderReviewComplete,
        boolean methodQualityApproved,
        boolean hydraulicEvidenceApproved,
        boolean biofilmEvidenceApproved,
        boolean independentReplicationApproved,
        boolean governanceApproved,
        boolean contradictionResolved,
        double evidenceSufficiencyScore,
        double minimumInternalEvidenceSufficiencyScore,
        String evidenceNamespace,
        boolean usedForAccessControl,
        boolean usedForIdentityOrEligibility,
        boolean usedForPublicRanking,
        boolean usedForExternalActionAuthorization,
        boolean externalActionRequested
    ) {
        public PromotionInput {
            requireText(evidencePacketId, "evidencePacketId");
            requireText(resultState, "resultState");
            requireText(evidenceNamespace, "evidenceNamespace");

            if (independentUnitCount < 0 || independentEventWindowCount < 0) {
                throw new IllegalArgumentException("independent counts must be non-negative");
            }

            requireUnitInterval(
                evidenceSufficiencyScore,
                "evidenceSufficiencyScore"
            );
            requireUnitInterval(
                minimumInternalEvidenceSufficiencyScore,
                "minimumInternalEvidenceSufficiencyScore"
            );
        }
    }

    private EvidencePromotionValidator() {
    }

    public static String validate(PromotionInput input) {
        Objects.requireNonNull(input, "input");

        if (input.externalActionRequested()) {
            return "NO_EXTERNAL_ACTION_RETAIN_EVIDENCE";
        }

        if (input.usedForAccessControl()
            || input.usedForIdentityOrEligibility()
            || input.usedForPublicRanking()
            || input.usedForExternalActionAuthorization()
            || !"INTERNAL_RESEARCH_QUALITY".equals(input.evidenceNamespace())) {
            return "REJECT_SCORE_GOVERNANCE_BOUNDARY_VIOLATION";
        }

        if ("NOT_DETECTED".equals(input.resultState())) {
            return "RETAIN_NOT_DETECTED_NO_LOW_RISK_INFERENCE";
        }

        if ("INCONCLUSIVE".equals(input.resultState())) {
            return "RETAIN_INCONCLUSIVE_REQUEST_TARGETED_REPLICATION";
        }

        if ("CONTRADICTORY".equals(input.resultState())
            && !input.contradictionResolved()) {
            return "RETAIN_CONTRADICTORY_ROUTE_TO_SYNTHESIS_REVIEW";
        }

        boolean fullReview =
            input.methodQualityApproved()
            && input.hydraulicEvidenceApproved()
            && input.biofilmEvidenceApproved()
            && input.independentReplicationApproved()
            && input.governanceApproved();

        boolean designEligible =
            input.independentUnitCount() >= 3
            && input.independentEventWindowCount() >= 2
            && input.holdoutValidationPassed()
            && input.uncertaintyAdequate()
            && input.confounderReviewComplete()
            && fullReview
            && input.contradictionResolved()
            && input.evidenceSufficiencyScore()
                >= input.minimumInternalEvidenceSufficiencyScore();

        return designEligible
            ? "ACCEPTED_FOR_DESIGN_NON_ACTUATING_ONLY"
            : "PROVISIONAL_OR_EVIDENCE_QUALIFIED_REQUEST_REVIEW";
    }

    private static void requireUnitInterval(double value, String name) {
        if (!Double.isFinite(value) || value < 0.0 || value > 1.0) {
            throw new IllegalArgumentException(
                name + " must be finite and within [0, 1]"
            );
        }
    }

    private static void requireText(String value, String name) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(name + " must be non-empty");
        }
    }
}
