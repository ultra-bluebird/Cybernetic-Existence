package org.augmentedhub.maturity;

import java.util.Objects;

public final class ModelMaturityProtocol {
    private ModelMaturityProtocol() {
    }

    public enum MaturityStatus {
        EXPLORATORY,
        PRELIMINARY,
        CALIBRATED,
        VALIDATED_ADVISORY,
        CORRIDOR_GATED,
        QUALIFIED,
        SUSPENDED,
        EXPIRED
    }

    public enum AdvisoryDecision {
        PUBLISHABLE_RESEARCH,
        ADVISORY_ONLY,
        PROCEED,
        DERATE,
        HALT,
        INDETERMINATE,
        NOT_CERTIFIABLE
    }

    public record AdequacyProfile(
            boolean methodsDisclosed,
            boolean dataProvenanceDisclosed,
            boolean priorsDisclosed,
            boolean uncertaintyDisclosed,
            boolean domainDeclared,
            boolean statusDeclared,
            boolean codeVerified,
            boolean solutionVerified,
            boolean calibrationPassed,
            boolean blockedHeldOutValidationPassed,
            boolean uncertaintyCoveragePassed,
            boolean independentCheckOrConservativeBoundPassed,
            boolean reproducibilityPassed,
            boolean privacyReviewPassed,
            boolean hardFloorsPassed,
            boolean inDomain,
            long falseSafeCount,
            boolean materialChangeDetected
    ) {
        public AdequacyProfile {
            if (falseSafeCount < 0L) {
                throw new IllegalArgumentException(
                        "falseSafeCount must be non-negative"
                );
            }
        }

        public boolean publishable() {
            return methodsDisclosed
                    && dataProvenanceDisclosed
                    && priorsDisclosed
                    && uncertaintyDisclosed
                    && domainDeclared
                    && statusDeclared;
        }

        public boolean preliminaryEligible() {
            return publishable();
        }

        public boolean calibratedEligible() {
            return publishable()
                    && codeVerified
                    && solutionVerified
                    && calibrationPassed;
        }

        public boolean validatedAdvisoryEligible() {
            return calibratedEligible()
                    && blockedHeldOutValidationPassed
                    && uncertaintyCoveragePassed
                    && reproducibilityPassed
                    && privacyReviewPassed;
        }

        public boolean corridorGatedEligible() {
            return validatedAdvisoryEligible()
                    && independentCheckOrConservativeBoundPassed
                    && hardFloorsPassed
                    && inDomain
                    && falseSafeCount == 0L
                    && !materialChangeDetected;
        }
    }

    public static MaturityStatus classify(AdequacyProfile profile) {
        Objects.requireNonNull(profile, "profile");

        if (profile.materialChangeDetected()) {
            return MaturityStatus.EXPIRED;
        }

        if (!profile.publishable()) {
            return MaturityStatus.EXPLORATORY;
        }

        if (!profile.calibratedEligible()) {
            return MaturityStatus.PRELIMINARY;
        }

        if (!profile.validatedAdvisoryEligible()) {
            return MaturityStatus.CALIBRATED;
        }

        if (profile.corridorGatedEligible()) {
            return MaturityStatus.CORRIDOR_GATED;
        }

        return MaturityStatus.VALIDATED_ADVISORY;
    }

    public static AdvisoryDecision decision(
            MaturityStatus status,
            boolean hardFloorsPassed,
            boolean inDomain,
            long falseSafeCount
    ) {
        Objects.requireNonNull(status, "status");

        if (falseSafeCount < 0L) {
            throw new IllegalArgumentException(
                    "falseSafeCount must be non-negative"
            );
        }

        if (status == MaturityStatus.EXPIRED
                || status == MaturityStatus.SUSPENDED
                || status == MaturityStatus.QUALIFIED) {
            return AdvisoryDecision.NOT_CERTIFIABLE;
        }

        if (!hardFloorsPassed) {
            return AdvisoryDecision.HALT;
        }

        if (!inDomain || falseSafeCount > 0L) {
            return AdvisoryDecision.INDETERMINATE;
        }

        return switch (status) {
            case EXPLORATORY, PRELIMINARY, CALIBRATED ->
                    AdvisoryDecision.PUBLISHABLE_RESEARCH;
            case VALIDATED_ADVISORY ->
                    AdvisoryDecision.ADVISORY_ONLY;
            case CORRIDOR_GATED ->
                    AdvisoryDecision.PROCEED;
            case QUALIFIED, SUSPENDED, EXPIRED ->
                    AdvisoryDecision.NOT_CERTIFIABLE;
        };
    }
}
