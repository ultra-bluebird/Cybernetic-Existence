package civic_repair;

import java.util.Locale;
import java.util.Objects;

public final class RepairValueAggregation {
    private static final double MINIMUM_EVIDENCE_QUALITY = 0.70;
    private static final double MAXIMUM_ECOLOGICAL_UNCERTAINTY = 0.35;

    private RepairValueAggregation() {
    }

    public record DirectOutcome(
        double value,
        String unit,
        String verificationStatus
    ) {
        public DirectOutcome {
            requireFiniteNonNegative(value, "verified service outcome value");
            requireNonBlank(unit, "direct outcome unit");
            requireNonBlank(verificationStatus, "service verification status");
        }
    }

    public record EcologicalUncertainty(
        double lowerFraction,
        double upperFraction
    ) {
        public EcologicalUncertainty {
            requireUnitInterval(lowerFraction, "ecological uncertainty lower fraction");
            requireUnitInterval(upperFraction, "ecological uncertainty upper fraction");
            if (lowerFraction > upperFraction) {
                throw new IllegalArgumentException(
                    "ecological uncertainty lower fraction must not exceed upper fraction"
                );
            }
        }
    }

    public record ProcessIndicators(
        double voluntaryFeedbackAggregate,
        double accessibilityOutcome,
        boolean followUpWindowAvailable,
        boolean plainLanguageExplanationAvailable,
        boolean complaintPathAvailable
    ) {
        public ProcessIndicators {
            requireUnitInterval(voluntaryFeedbackAggregate, "voluntary feedback aggregate");
            requireUnitInterval(accessibilityOutcome, "accessibility outcome");
        }
    }

    public record RepairInput(
        String repairId,
        String repairCategory,
        DirectOutcome verifiedServiceOutcome,
        String followUpWindow,
        double repairEnergyJ,
        double transportEnergyJ,
        double replacementPartMassKg,
        String avoidedReplacementBaseline,
        double avoidedMaterialMassKg,
        double embodiedEnergyPerKgJ,
        double lifecycleCarbonPerKgKgCo2e,
        double repairLifecycleCarbonKgCo2e,
        EcologicalUncertainty ecologicalUncertainty,
        ProcessIndicators processIndicators,
        double evidenceQuality,
        String reviewStatus
    ) {
        public RepairInput {
            requireNonBlank(repairId, "repair id");
            requireNonBlank(repairCategory, "repair category");
            Objects.requireNonNull(verifiedServiceOutcome, "verified service outcome is required");
            requireNonBlank(followUpWindow, "follow-up window");
            requireFiniteNonNegative(repairEnergyJ, "repair energy");
            requireFiniteNonNegative(transportEnergyJ, "transport energy");
            requireFiniteNonNegative(replacementPartMassKg, "replacement part mass");
            requireNonBlank(avoidedReplacementBaseline, "avoided replacement baseline");
            requireFiniteNonNegative(avoidedMaterialMassKg, "avoided material mass");
            requireFiniteNonNegative(embodiedEnergyPerKgJ, "embodied energy per kg");
            requireFiniteNonNegative(lifecycleCarbonPerKgKgCo2e, "lifecycle carbon per kg");
            requireFiniteNonNegative(repairLifecycleCarbonKgCo2e, "repair lifecycle carbon");
            Objects.requireNonNull(ecologicalUncertainty, "ecological uncertainty is required");
            Objects.requireNonNull(processIndicators, "process indicators are required");
            requireUnitInterval(evidenceQuality, "evidence quality");
            requireNonBlank(reviewStatus, "review status");
        }
    }

    public record RepairValueResult(
        String repairId,
        String repairCategory,
        String directOutcomeValueAndUnit,
        String serviceVerificationStatus,
        double ecologicalEnergyAvoidedJ,
        double ecologicalCarbonAvoidedKgCo2e,
        double ecologicalUncertaintyLowerJ,
        double ecologicalUncertaintyUpperJ,
        String indirectProcessIndicators,
        String aggregationScope,
        boolean candidateForPublicReporting,
        String humanReviewStatus,
        String explanation
    ) {
    }

    public static RepairValueResult aggregate(RepairInput input) {
        Objects.requireNonNull(input, "repair input is required");

        double avoidedEmbodiedEnergyJ =
            input.avoidedMaterialMassKg() * input.embodiedEnergyPerKgJ();

        double repairLifecycleEnergyJ =
            input.repairEnergyJ()
                + input.transportEnergyJ()
                + estimateReplacementPartEmbodiedEnergy(
                    input.replacementPartMassKg(),
                    input.embodiedEnergyPerKgJ()
                );

        double netEnergyAvoidedJ = avoidedEmbodiedEnergyJ - repairLifecycleEnergyJ;

        double avoidedEmbodiedCarbonKgCo2e =
            input.avoidedMaterialMassKg() * input.lifecycleCarbonPerKgKgCo2e();

        double repairComponentCarbonKgCo2e =
            proportionalReplacementPartCarbon(
                input.replacementPartMassKg(),
                input.avoidedMaterialMassKg(),
                avoidedEmbodiedCarbonKgCo2e
            );

        double netCarbonAvoidedKgCo2e =
            avoidedEmbodiedCarbonKgCo2e
                - input.repairLifecycleCarbonKgCo2e()
                - repairComponentCarbonKgCo2e;

        double uncertaintyLowerJ =
            netEnergyAvoidedJ
                * (1.0 - input.ecologicalUncertainty().upperFraction());

        double uncertaintyUpperJ =
            netEnergyAvoidedJ
                * (1.0 - input.ecologicalUncertainty().lowerFraction());

        if (uncertaintyLowerJ > uncertaintyUpperJ) {
            double temporary = uncertaintyLowerJ;
            uncertaintyLowerJ = uncertaintyUpperJ;
            uncertaintyUpperJ = temporary;
        }

        boolean serviceVerified =
            input.verifiedServiceOutcome().verificationStatus().equals("verified");

        boolean reviewApproved =
            input.reviewStatus().equals("approved")
                || input.reviewStatus().equals("qualified");

        boolean uncertaintyAcceptable =
            input.ecologicalUncertainty().upperFraction()
                <= MAXIMUM_ECOLOGICAL_UNCERTAINTY;

        boolean candidateForPublicReporting =
            serviceVerified
                && reviewApproved
                && input.evidenceQuality() >= MINIMUM_EVIDENCE_QUALITY
                && uncertaintyAcceptable;

        String directOutcome =
            String.format(
                Locale.ROOT,
                "%.6f %s",
                input.verifiedServiceOutcome().value(),
                input.verifiedServiceOutcome().unit()
            );

        String processSummary =
            String.format(
                Locale.ROOT,
                "voluntary_feedback_aggregate=%.6f;"
                    + "accessibility_outcome=%.6f;"
                    + "follow_up_window_available=%s;"
                    + "plain_language_explanation_available=%s;"
                    + "complaint_path_available=%s",
                input.processIndicators().voluntaryFeedbackAggregate(),
                input.processIndicators().accessibilityOutcome(),
                input.processIndicators().followUpWindowAvailable(),
                input.processIndicators().plainLanguageExplanationAvailable(),
                input.processIndicators().complaintPathAvailable()
            );

        String aggregationScope =
            "Direct service outcome, ecological lifecycle estimate, and "
                + "privacy-preserving process indicators are reported separately; "
                + "this result is not a universal civic-value score.";

        String humanReviewStatus =
            candidateForPublicReporting ? "pending_publication_review" : "review_required";

        String explanation =
            candidateForPublicReporting
                ? "Candidate for public reporting after final human review. "
                    + "Ecological values depend on the documented replacement baseline and "
                    + "lifecycle assumptions."
                : "Not a candidate for public reporting until service verification, review, "
                    + "evidence quality, or uncertainty requirements are satisfied.";

        return new RepairValueResult(
            input.repairId(),
            input.repairCategory(),
            directOutcome,
            input.verifiedServiceOutcome().verificationStatus(),
            netEnergyAvoidedJ,
            netCarbonAvoidedKgCo2e,
            uncertaintyLowerJ,
            uncertaintyUpperJ,
            processSummary,
            aggregationScope,
            candidateForPublicReporting,
            humanReviewStatus,
            explanation
        );
    }

    private static double estimateReplacementPartEmbodiedEnergy(
        double replacementPartMassKg,
        double embodiedEnergyPerKgJ
    ) {
        return replacementPartMassKg * embodiedEnergyPerKgJ;
    }

    private static double proportionalReplacementPartCarbon(
        double replacementPartMassKg,
        double avoidedMaterialMassKg,
        double avoidedEmbodiedCarbonKgCo2e
    ) {
        if (avoidedMaterialMassKg <= 0.0) {
            return 0.0;
        }

        return (replacementPartMassKg / avoidedMaterialMassKg)
            * avoidedEmbodiedCarbonKgCo2e;
    }

    private static void requireNonBlank(String value, String name) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(name + " must not be blank");
        }
    }

    private static void requireFiniteNonNegative(double value, String name) {
        if (!Double.isFinite(value) || value < 0.0) {
            throw new IllegalArgumentException(name + " must be finite and non-negative");
        }
    }

    private static void requireUnitInterval(double value, String name) {
        if (!Double.isFinite(value) || value < 0.0 || value > 1.0) {
            throw new IllegalArgumentException(name + " must be within 0..1");
        }
    }

    public static void main(String[] args) {
        if (args.length != 19) {
            System.err.println(
                "Usage: java civic_repair.RepairValueAggregation "
                    + "repair_id repair_category direct_value direct_unit verification_status "
                    + "follow_up_window repair_energy_j transport_energy_j replacement_part_mass_kg "
                    + "avoided_replacement_baseline avoided_material_mass_kg "
                    + "embodied_energy_per_kg_j lifecycle_carbon_per_kg_kgco2e "
                    + "repair_lifecycle_carbon_kgco2e uncertainty_lower_fraction "
                    + "uncertainty_upper_fraction voluntary_feedback_aggregate "
                    + "accessibility_outcome evidence_quality review_status"
            );
            System.exit(64);
        }

        try {
            RepairInput input = new RepairInput(
                args[0],
                args[1],
                new DirectOutcome(
                    Double.parseDouble(args[2]),
                    args[3],
                    args[4]
                ),
                args[5],
                Double.parseDouble(args[6]),
                Double.parseDouble(args[7]),
                Double.parseDouble(args[8]),
                args[9],
                Double.parseDouble(args[10]),
                Double.parseDouble(args[11]),
                Double.parseDouble(args[12]),
                Double.parseDouble(args[13]),
                new EcologicalUncertainty(
                    Double.parseDouble(args[14]),
                    Double.parseDouble(args[15])
                ),
                new ProcessIndicators(
                    Double.parseDouble(args[16]),
                    Double.parseDouble(args[17]),
                    true,
                    true,
                    true
                ),
                Double.parseDouble(args[18]),
                args.length > 19 ? args[19] : "pending"
            );

            RepairValueResult result = aggregate(input);

            System.out.printf(Locale.ROOT, "repair_id=%s%n", result.repairId());
            System.out.printf(Locale.ROOT, "repair_category=%s%n", result.repairCategory());
            System.out.printf(
                Locale.ROOT,
                "direct_outcome_value_and_unit=%s%n",
                result.directOutcomeValueAndUnit()
            );
            System.out.printf(
                Locale.ROOT,
                "service_verification_status=%s%n",
                result.serviceVerificationStatus()
            );
            System.out.printf(
                Locale.ROOT,
                "ecological_energy_avoided_j=%.6f%n",
                result.ecologicalEnergyAvoidedJ()
            );
            System.out.printf(
                Locale.ROOT,
                "ecological_carbon_avoided_kgco2e=%.6f%n",
                result.ecologicalCarbonAvoidedKgCo2e()
            );
            System.out.printf(
                Locale.ROOT,
                "ecological_uncertainty_interval_j=[%.6f,%.6f]%n",
                result.ecologicalUncertaintyLowerJ(),
                result.ecologicalUncertaintyUpperJ()
            );
            System.out.printf(
                Locale.ROOT,
                "indirect_process_indicators=%s%n",
                result.indirectProcessIndicators()
            );
            System.out.printf(
                Locale.ROOT,
                "aggregation_scope=%s%n",
                result.aggregationScope()
            );
            System.out.printf(
                Locale.ROOT,
                "candidate_for_public_reporting=%s%n",
                result.candidateForPublicReporting()
            );
            System.out.printf(
                Locale.ROOT,
                "human_review_status=%s%n",
                result.humanReviewStatus()
            );
            System.out.printf(Locale.ROOT, "explanation=%s%n", result.explanation());
        } catch (RuntimeException error) {
            System.err.println("Input error: " + error.getMessage());
            System.exit(65);
        }
    }
}
