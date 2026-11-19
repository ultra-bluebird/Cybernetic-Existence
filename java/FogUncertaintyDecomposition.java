package augmentedhub.fog;

import java.util.Objects;

public final class FogUncertaintyDecomposition {

    public record Inputs(
            double media,
            double pathway,
            double overlap,
            double interaction
    ) {
        public Inputs {
            validateUnitInterval(media, "media");
            validateUnitInterval(pathway, "pathway");
            validateUnitInterval(overlap, "overlap");
            validateUnitInterval(interaction, "interaction");
        }
    }

    public record Attribution(
            double totalUncertainty,
            double mediaContribution,
            double pathwayContribution,
            double overlapContribution,
            double interactionContribution,
            double reconstructionError
    ) {}

    private FogUncertaintyDecomposition() {}

    public static double totalUncertainty(Inputs inputs) {
        Objects.requireNonNull(inputs, "inputs");

        return clamp(
                inputs.media()
                        + inputs.pathway()
                        - inputs.overlap()
                        + inputs.interaction()
        );
    }

    public static Attribution decompose(Inputs inputs) {
        Objects.requireNonNull(inputs, "inputs");

        double full = model(inputs.media(), inputs.pathway(),
                inputs.overlap(), inputs.interaction());

        double mediaFirst = model(inputs.media(), inputs.pathway(),
                inputs.overlap(), inputs.interaction())
                - model(0.0, inputs.pathway(), inputs.overlap(), inputs.interaction());

        double mediaSecond = model(inputs.media(), 0.0,
                inputs.overlap(), inputs.interaction())
                - model(0.0, 0.0, inputs.overlap(), inputs.interaction());

        double pathwayFirst = model(inputs.media(), inputs.pathway(),
                inputs.overlap(), inputs.interaction())
                - model(inputs.media(), 0.0, inputs.overlap(), inputs.interaction());

        double pathwaySecond = model(0.0, inputs.pathway(),
                inputs.overlap(), inputs.interaction())
                - model(0.0, 0.0, inputs.overlap(), inputs.interaction());

        double mediaContribution = 0.5 * (mediaFirst + mediaSecond);
        double pathwayContribution = 0.5 * (pathwayFirst + pathwaySecond);

        double baselineWithoutOverlap = model(
                inputs.media(),
                inputs.pathway(),
                0.0,
                inputs.interaction()
        );

        double overlapContribution = full - baselineWithoutOverlap;

        double baselineWithoutInteraction = model(
                inputs.media(),
                inputs.pathway(),
                inputs.overlap(),
                0.0
        );

        double interactionContribution = full - baselineWithoutInteraction;

        double reconstructed = mediaContribution
                + pathwayContribution
                + overlapContribution
                + interactionContribution;

        return new Attribution(
                full,
                mediaContribution,
                pathwayContribution,
                overlapContribution,
                interactionContribution,
                Math.abs(full - reconstructed)
        );
    }

    private static double model(
            double media,
            double pathway,
            double overlap,
            double interaction
    ) {
        return clamp(media + pathway - overlap + interaction);
    }

    private static double clamp(double value) {
        return Math.max(0.0, Math.min(1.0, value));
    }

    private static void validateUnitInterval(double value, String fieldName) {
        if (!Double.isFinite(value) || value < 0.0 || value > 1.0) {
            throw new IllegalArgumentException(
                    fieldName + " must be a finite value in [0, 1]"
            );
        }
    }
}
