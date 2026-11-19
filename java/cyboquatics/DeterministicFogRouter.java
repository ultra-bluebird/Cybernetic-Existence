package cyboquatics;

import java.util.Set;

public final class DeterministicFogRouter {
    private DeterministicFogRouter() {
    }

    public enum Route {
        KNOWN_MEDIA_REVIEWABLE,
        FOG_REVIEW,
        REJECTED_INPUT
    }

    public enum Reason {
        ELIGIBLE,
        INVALID_INPUT,
        UNKNOWN_MEDIA,
        HAZARD_FLAG,
        UNCERTAINTY_FLAG,
        CONFIDENCE_BELOW_700,
        COMPLETENESS_BELOW_900,
        KNOWLEDGE_BELOW_700,
        HARM_RISK_ABOVE_300
    }

    public record Input(
        String mediaClass,
        int confidenceMilli,
        int completenessMilli,
        int knowledgeFactorMilli,
        int harmRiskMilli,
        boolean uncertaintyFlag,
        boolean hazardFlag
    ) {
    }

    public record Result(Route route, Reason reason) {
    }

    private static final Set<String> APPROVED_MEDIA =
        Set.of("AQUEOUS", "SEDIMENT", "BIOREACTOR", "ORGANIC_DEBRIS");

    public static Result evaluate(Input input) {
        if (input == null ||
            !inMilliRange(input.confidenceMilli()) ||
            !inMilliRange(input.completenessMilli()) ||
            !inMilliRange(input.knowledgeFactorMilli()) ||
            !inMilliRange(input.harmRiskMilli())) {
            return new Result(Route.REJECTED_INPUT, Reason.INVALID_INPUT);
        }
        if (input.mediaClass() == null || !APPROVED_MEDIA.contains(input.mediaClass())) {
            return new Result(Route.REJECTED_INPUT, Reason.UNKNOWN_MEDIA);
        }
        if (input.hazardFlag()) {
            return new Result(Route.FOG_REVIEW, Reason.HAZARD_FLAG);
        }
        if (input.uncertaintyFlag()) {
            return new Result(Route.FOG_REVIEW, Reason.UNCERTAINTY_FLAG);
        }
        if (input.confidenceMilli() < 700) {
            return new Result(Route.FOG_REVIEW, Reason.CONFIDENCE_BELOW_700);
        }
        if (input.completenessMilli() < 900) {
            return new Result(Route.FOG_REVIEW, Reason.COMPLETENESS_BELOW_900);
        }
        if (input.knowledgeFactorMilli() < 700) {
            return new Result(Route.FOG_REVIEW, Reason.KNOWLEDGE_BELOW_700);
        }
        if (input.harmRiskMilli() > 300) {
            return new Result(Route.FOG_REVIEW, Reason.HARM_RISK_ABOVE_300);
        }
        return new Result(Route.KNOWN_MEDIA_REVIEWABLE, Reason.ELIGIBLE);
    }

    private static boolean inMilliRange(int value) {
        return value >= 0 && value <= 1000;
    }
}
