import java.util.Set;

public final class FogRouter {
    private static final Set<String> KNOWN_MEDIA =
            Set.of("freshwater", "brackish_water", "wastewater", "stormwater", "sediment");

    private record Observation(
            String nodeId,
            String observedAt,
            String media,
            double confidence,
            double completeness,
            boolean fog,
            double flowM3S,
            double temperatureC,
            double measurementQuality,
            double k,
            double e,
            double r,
            boolean consentActive
    ) {}

    private record Decision(String route, String code, String explanation) {}

    private static boolean finiteInRange(double value, double minimum, double maximum) {
        return Double.isFinite(value) && value >= minimum && value <= maximum;
    }

    private static Decision route(Observation value) {
        if (value.nodeId().isBlank() || value.observedAt().isBlank()) {
            return new Decision("REJECTED_INPUT", "MISSING_REQUIRED_FIELD",
                    "A pseudonymous node identifier and observation time are required.");
        }
        if (!value.consentActive()) {
            return new Decision("REJECTED_INPUT", "CONSENT_NOT_ACTIVE",
                    "The purpose-limited consent state is not active; do not process this observation.");
        }
        if (!finiteInRange(value.confidence(), 0.0, 1.0)
                || !finiteInRange(value.completeness(), 0.0, 1.0)
                || !finiteInRange(value.measurementQuality(), 0.0, 1.0)
                || !finiteInRange(value.k(), 0.0, 1.0)
                || !finiteInRange(value.e(), 0.0, 1.0)
                || !finiteInRange(value.r(), 0.0, 1.0)
                || !finiteInRange(value.flowM3S(), 0.0, 1000.0)
                || !finiteInRange(value.temperatureC(), -5.0, 60.0)) {
            return new Decision("REJECTED_INPUT", "INVALID_BOUNDED_VALUE",
                    "One or more measurements are missing, non-finite, or outside the configured local bounds.");
        }
        if (value.fog() || !KNOWN_MEDIA.contains(value.media())) {
            return new Decision("FOG_REVIEW", "FOG_EXPLICIT",
                    "FOG is explicit or the media is unknown; preserve uncertainty and request qualified human review.");
        }
        if (value.completeness() < 0.90 || value.confidence() < 0.70
                || value.measurementQuality() < 0.70 || value.k() < 0.70) {
            return new Decision("FOG_REVIEW", "EVIDENCE_INCOMPLETE",
                    "Evidence completeness, confidence, measurement quality, or knowledge quality is insufficient for known-media review.");
        }
        if (value.r() > 0.30) {
            return new Decision("QUARANTINED_INPUT", "RISK_ABOVE_AUTOMATION_BOUND",
                    "Risk of harm exceeds 0.30; quarantine the record for qualified human review and do not automate a recommendation.");
        }
        return new Decision("KNOWN_MEDIA", "KNOWN_MEDIA_READY",
                "Known media with complete, authorized evidence is suitable for human review only; no physical action is authorized.");
    }

    private static boolean parseBoolean(String value) {
        if (!value.equals("true") && !value.equals("false")) {
            throw new IllegalArgumentException("Boolean values must be lowercase true or false.");
        }
        return Boolean.parseBoolean(value);
    }

    public static void main(String[] args) {
        if (args.length != 13) {
            System.err.println("usage: FogRouter node_id observed_at media confidence completeness fog flow_m3_s temperature_c measurement_quality K E R consent_active");
            System.exit(2);
        }

        try {
            Observation value = new Observation(
                    args[0], args[1], args[2],
                    Double.parseDouble(args[3]),
                    Double.parseDouble(args[4]),
                    parseBoolean(args[5]),
                    Double.parseDouble(args[6]),
                    Double.parseDouble(args[7]),
                    Double.parseDouble(args[8]),
                    Double.parseDouble(args[9]),
                    Double.parseDouble(args[10]),
                    Double.parseDouble(args[11]),
                    parseBoolean(args[12])
            );

            Decision decision = route(value);
            System.out.println("route=" + decision.route());
            System.out.println("code=" + decision.code());
            System.out.println("explanation=" + decision.explanation());
            if (decision.route().equals("REJECTED_INPUT")) {
                System.exit(1);
            }
        } catch (IllegalArgumentException exception) {
            System.err.println("route=REJECTED_INPUT");
            System.err.println("code=PARSE_FAILURE");
            System.err.println("explanation=" + exception.getMessage());
            System.exit(1);
        }
    }
}
