package augmentedhub.fog;

import java.util.Objects;
import java.util.Set;

public final class FogConformalRuntimeQuery {

    public enum PredictionSetCode {
        UNMODELED_MEDIA_ONLY,
        MODELED_MEDIA_ONLY,
        BOTH_LABELS,
        EMPTY_SET
    }

    public record RuntimePrediction(
            Set<FogMediaLabel> labels,
            double quantile,
            int calibrationSize,
            boolean exchangeabilitySupported,
            boolean nonStationarityWithinEnvelope
    ) {
        public RuntimePrediction {
            Objects.requireNonNull(labels, "labels");

            if (!Double.isFinite(quantile)
                    || quantile < 0.0
                    || quantile > 1.0) {
                throw new IllegalArgumentException(
                        "quantile must be finite and in [0, 1]"
                );
            }

            if (calibrationSize < 0) {
                throw new IllegalArgumentException(
                        "calibrationSize must be non-negative"
                );
            }

            if (labels.size() > 2) {
                throw new IllegalArgumentException(
                        "FOG conformal prediction set must contain at most two labels"
                );
            }
        }

        public PredictionSetCode code() {
            if (labels.isEmpty()) {
                return PredictionSetCode.EMPTY_SET;
            }

            if (labels.size() == 2) {
                return PredictionSetCode.BOTH_LABELS;
            }

            return labels.contains(FogMediaLabel.UNMODELED_MEDIA)
                    ? PredictionSetCode.UNMODELED_MEDIA_ONLY
                    : PredictionSetCode.MODELED_MEDIA_ONLY;
        }

        public boolean requiresConservativeHold() {
            return !exchangeabilitySupported
                    || !nonStationarityWithinEnvelope
                    || labels.isEmpty()
                    || labels.size() == 2;
        }
    }

    private FogConformalRuntimeQuery() {}

    public static RuntimePrediction query(
            double probabilityUnmodeledMedia,
            double quantile,
            int calibrationSize,
            boolean exchangeabilitySupported,
            boolean nonStationarityWithinEnvelope
    ) {
        if (!Double.isFinite(probabilityUnmodeledMedia)
                || probabilityUnmodeledMedia < 0.0
                || probabilityUnmodeledMedia > 1.0) {
            throw new IllegalArgumentException(
                    "probabilityUnmodeledMedia must be finite and in [0, 1]"
            );
        }

        if (!Double.isFinite(quantile)
                || quantile < 0.0
                || quantile > 1.0) {
            throw new IllegalArgumentException(
                    "quantile must be finite and in [0, 1]"
            );
        }

        double unmodeledScore = 1.0 - probabilityUnmodeledMedia;
        double modeledScore = probabilityUnmodeledMedia;

        Set<FogMediaLabel> set;

        if (unmodeledScore <= quantile && modeledScore <= quantile) {
            set = Set.of(
                    FogMediaLabel.UNMODELED_MEDIA,
                    FogMediaLabel.MODELED_MEDIA
            );
        } else if (unmodeledScore <= quantile) {
            set = Set.of(FogMediaLabel.UNMODELED_MEDIA);
        } else if (modeledScore <= quantile) {
            set = Set.of(FogMediaLabel.MODELED_MEDIA);
        } else {
            set = Set.of();
        }

        return new RuntimePrediction(
                set,
                quantile,
                calibrationSize,
                exchangeabilitySupported,
                nonStationarityWithinEnvelope
        );
    }
}
