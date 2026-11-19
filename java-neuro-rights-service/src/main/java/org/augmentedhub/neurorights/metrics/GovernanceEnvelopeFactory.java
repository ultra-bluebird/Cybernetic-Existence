package org.augmentedhub.neuro.rights.metrics;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;

public final class GovernanceEnvelopeFactory {
    public static final String SCOPE =
        "aggregate_environmental_decision_support_only";

    public static final String INDIVIDUAL_PROFILING = "prohibited";
    public static final String AUTOMATED_ADVERSE_ACTION = "prohibited";
    public static final String EXTERNAL_ACTION = "not_performed";

    private static final String GOVERNANCE_KEY = "governance";
    private static final String SCOPE_KEY = "scope";
    private static final String INDIVIDUAL_PROFILING_KEY =
        "individual_profiling";
    private static final String AUTOMATED_ADVERSE_ACTION_KEY =
        "automated_adverse_action";
    private static final String EXTERNAL_ACTION_KEY = "external_action";

    private static final Map<String, String> STANDARD_ENVELOPE = Map.of(
        SCOPE_KEY,
        SCOPE,
        INDIVIDUAL_PROFILING_KEY,
        INDIVIDUAL_PROFILING,
        AUTOMATED_ADVERSE_ACTION_KEY,
        AUTOMATED_ADVERSE_ACTION,
        EXTERNAL_ACTION_KEY,
        EXTERNAL_ACTION
    );

    private GovernanceEnvelopeFactory() {
    }

    public static Map<String, String> standardEnvelope() {
        return STANDARD_ENVELOPE;
    }

    public static Map<String, Object> attachToResponse(
        final Map<String, Object> response
    ) {
        Objects.requireNonNull(response, "response");

        final GovernanceValidation existing =
            validateGovernance(response.get(GOVERNANCE_KEY));

        if (existing.present() && !existing.valid()) {
            throw new IllegalArgumentException(
                "Response contains an incompatible governance envelope."
            );
        }

        final Map<String, Object> enriched = new LinkedHashMap<>(response);
        enriched.put(GOVERNANCE_KEY, STANDARD_ENVELOPE);

        return Map.copyOf(enriched);
    }

    public static void requireStandardGovernance(
        final Map<String, Object> response
    ) throws MetricDispatchClient.MetricDispatchException {
        Objects.requireNonNull(response, "response");

        final GovernanceValidation validation =
            validateGovernance(response.get(GOVERNANCE_KEY));

        if (!validation.valid()) {
            throw new MetricDispatchClient.MetricDispatchException(
                "governance_contract_violation",
                "Local dispatcher governance constraints are incompatible."
            );
        }
    }

    public static boolean hasRequiredGovernance(
        final Map<String, Object> response
    ) {
        Objects.requireNonNull(response, "response");

        return validateGovernance(response.get(GOVERNANCE_KEY)).valid();
    }

    public static GovernanceValidation validateGovernance(
        final Object governanceValue
    ) {
        if (governanceValue == null) {
            return GovernanceValidation.missing();
        }

        if (!(governanceValue instanceof Map<?, ?> governance)) {
            return GovernanceValidation.invalid("governance_not_object");
        }

        final Object scope = governance.get(SCOPE_KEY);
        final Object individualProfiling =
            governance.get(INDIVIDUAL_PROFILING_KEY);
        final Object automatedAdverseAction =
            governance.get(AUTOMATED_ADVERSE_ACTION_KEY);
        final Object externalAction =
            governance.get(EXTERNAL_ACTION_KEY);

        if (!SCOPE.equals(scope)) {
            return GovernanceValidation.invalid("invalid_scope");
        }

        if (!INDIVIDUAL_PROFILING.equals(individualProfiling)) {
            return GovernanceValidation.invalid(
                "individual_profiling_not_prohibited"
            );
        }

        if (!AUTOMATED_ADVERSE_ACTION.equals(automatedAdverseAction)) {
            return GovernanceValidation.invalid(
                "automated_adverse_action_not_prohibited"
            );
        }

        if (!EXTERNAL_ACTION.equals(externalAction)) {
            return GovernanceValidation.invalid(
                "external_action_not_not_performed"
            );
        }

        return GovernanceValidation.valid();
    }

    public record GovernanceValidation(
        boolean present,
        boolean valid,
        String reason
    ) {
        private static GovernanceValidation missing() {
            return new GovernanceValidation(
                false,
                false,
                "governance_missing"
            );
        }

        private static GovernanceValidation invalid(
            final String reason
        ) {
            return new GovernanceValidation(
                true,
                false,
                Objects.requireNonNull(reason, "reason")
            );
        }

        private static GovernanceValidation valid() {
            return new GovernanceValidation(
                true,
                true,
                "governance_valid"
            );
        }
    }
}
