package org.augmentedhub.policy;

import java.util.List;
import java.util.Map;
import java.util.Objects;

public final class PolicyEnforcer {
    public interface LocalPolicyEvaluator {
        PolicyDecision evaluate(Map<String, Object> input);
    }

    public record PolicyDecision(
            boolean allow,
            String state,
            List<String> reasons,
            String plainLanguageExplanation
    ) {
        public PolicyDecision {
            Objects.requireNonNull(state, "state");
            Objects.requireNonNull(reasons, "reasons");
            Objects.requireNonNull(plainLanguageExplanation, "plainLanguageExplanation");

            if (state.isBlank()) {
                throw new IllegalArgumentException("state must not be blank");
            }

            if (plainLanguageExplanation.isBlank()) {
                throw new IllegalArgumentException(
                        "plainLanguageExplanation must not be blank"
                );
            }
        }
    }

    private final LocalPolicyEvaluator evaluator;

    public PolicyEnforcer(LocalPolicyEvaluator evaluator) {
        this.evaluator = Objects.requireNonNull(evaluator, "evaluator");
    }

    public PolicyDecision evaluateLocally(
            Map<String, Object> policyInput
    ) {
        Objects.requireNonNull(policyInput, "policyInput");

        PolicyDecision decision = evaluator.evaluate(policyInput);

        if (decision == null) {
            return safeFailure(
                    "The local policy evaluator did not return a decision."
            );
        }

        return enforceDecisionShape(decision);
    }

    private PolicyDecision enforceDecisionShape(
            PolicyDecision decision
    ) {
        if (decision.allow() &&
                !"approved_for_advisory_use".equals(decision.state())) {
            return safeFailure(
                    "The policy result was inconsistent and requires review."
            );
        }

        if (!decision.allow() &&
                decision.reasons().isEmpty()) {
            return safeFailure(
                    "The policy result did not provide a reviewable reason."
            );
        }

        return decision;
    }

    private PolicyDecision safeFailure(String reason) {
        return new PolicyDecision(
                false,
                "needs_review",
                List.of(reason),
                "This result needs review before use. " +
                        "An accessible correction and appeal path must remain available."
        );
    }
}
