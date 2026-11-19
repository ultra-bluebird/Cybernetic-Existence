package augmentedhub.fog;

import java.util.Objects;

public final class FogKerReviewUrgency {

    public record UrgencyWeights(
            double lowKnowledgeWeight,
            double ecologicalValueWeight,
            double riskWeight
    ) {
        public UrgencyWeights {
            validateUnitInterval(lowKnowledgeWeight, "lowKnowledgeWeight");
            validateUnitInterval(ecologicalValueWeight,
                    "ecologicalValueWeight");
            validateUnitInterval(riskWeight, "riskWeight");

            double sum = lowKnowledgeWeight
                    + ecologicalValueWeight
                    + riskWeight;

            if (Math.abs(sum - 1.0) > 1.0e-9) {
                throw new IllegalArgumentException(
                        "Urgency weights must sum to 1.0"
                );
            }
        }
    }

    public record FogKerInput(
            String queueId,
            double knowledgeFactor,
            double ecologicalValue,
            double riskFactor,
            double fogUncertainty,
            boolean humanReviewRequired,
            boolean containsPersonalData,
            boolean containsCommunityRankingData
    ) {
        public FogKerInput {
            Objects.requireNonNull(queueId, "queueId");

            if (!queueId.matches("^[A-Za-z0-9_-]{8,128}$")) {
                throw new IllegalArgumentException(
                        "queueId must be an opaque bounded identifier"
                );
            }

            validateUnitInterval(knowledgeFactor, "knowledgeFactor");
            validateUnitInterval(ecologicalValue, "ecologicalValue");
            validateUnitInterval(riskFactor, "riskFactor");
            validateUnitInterval(fogUncertainty, "fogUncertainty");

            if (containsPersonalData || containsCommunityRankingData) {
                throw new IllegalArgumentException(
                        "FOG review priority must not contain personal or community-ranking data"
                );
            }
        }
    }

    public record UrgencyResult(
            String queueId,
            double reviewUrgency,
            double originalFormulaScore,
            boolean advisoryOnly,
            boolean eligibleForReviewOrdering,
            String explanation
    ) {}

    private FogKerReviewUrgency() {}

    public static UrgencyResult score(
            FogKerInput input,
            UrgencyWeights weights
    ) {
        Objects.requireNonNull(input, "input");
        Objects.requireNonNull(weights, "weights");

        if (!input.humanReviewRequired()) {
            return new UrgencyResult(
                    input.queueId(),
                    0.0,
                    0.0,
                    true,
                    false,
                    "The item is not in a human-review-required state."
            );
        }

        double riskSensitiveUrgency =
                input.fogUncertainty()
                * (
                    weights.lowKnowledgeWeight()
                        * (1.0 - input.knowledgeFactor())
                    + weights.ecologicalValueWeight()
                        * input.ecologicalValue()
                    + weights.riskWeight()
                        * input.riskFactor()
                );

        double originalFormulaScore =
                input.knowledgeFactor()
                * input.ecologicalValue()
                * (1.0 - input.riskFactor())
                * input.fogUncertainty();

        return new UrgencyResult(
                input.queueId(),
                riskSensitiveUrgency,
                originalFormulaScore,
                true,
                true,
                "Review urgency rises with FOG uncertainty, low knowledge, ecological value, and risk. "
                    + "The original product is retained as a separate diagnostic because it decreases as risk rises."
        );
    }

    private static void validateUnitInterval(double value, String field) {
        if (!Double.isFinite(value) || value < 0.0 || value > 1.0) {
            throw new IllegalArgumentException(
                    field + " must be finite and within [0, 1]"
            );
        }
    }
}
