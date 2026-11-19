package org.augmentedhub.policy;

import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * Adapter that converts a validated charter payload into the existing
 * PolicyEnforcer interface for local policy evaluation.
 *
 * This adapter:
 * - Accepts a JSON-compatible Map<String, Object>
 * - Rejects null input or missing required sections
 * - Invokes only a provided PolicyEnforcer.LocalPolicyEvaluator
 * - Returns a structured PolicyEnforcer.PolicyDecision
 * - Fails closed as needs_review on errors or malformed results
 * - Never makes HTTP requests
 * - Never loads remote policies
 * - Never writes data
 * - Never controls machinery or denies service
 * - Always provides a non-empty plain-language explanation
 */
public final class LocalPolicyDecisionAdapter {

    private final PolicyEnforcer.LocalPolicyEvaluator evaluator;

    public LocalPolicyDecisionAdapter(PolicyEnforcer.LocalPolicyEvaluator evaluator) {
        this.evaluator = Objects.requireNonNull(evaluator, "evaluator");
    }

    /**
     * Converts a charter payload into a policy decision.
     *
     * @param charterPayload a JSON-compatible map containing ker, evidence,
     *                       uncertainty, governance, runtime, policy_bundle, and sync sections
     * @return a PolicyDecision with allow, state, reasons, and plainLanguageExplanation
     */
    public PolicyEnforcer.PolicyDecision adaptCharterPayload(
            Map<String, Object> charterPayload
    ) {
        if (charterPayload == null) {
            return safeFailure("The charter payload was null.");
        }

        if (!charterPayload.containsKey("ker")) {
            return safeFailure("The charter payload is missing the 'ker' section.");
        }

        if (!charterPayload.containsKey("evidence")) {
            return safeFailure("The charter payload is missing the 'evidence' section.");
        }

        if (!charterPayload.containsKey("uncertainty")) {
            return safeFailure("The charter payload is missing the 'uncertainty' section.");
        }

        if (!charterPayload.containsKey("governance")) {
            return safeFailure("The charter payload is missing the 'governance' section.");
        }

        if (!charterPayload.containsKey("runtime")) {
            return safeFailure("The charter payload is missing the 'runtime' section.");
        }

        if (!charterPayload.containsKey("policy_bundle")) {
            return safeFailure("The charter payload is missing the 'policy_bundle' section.");
        }

        try {
            PolicyEnforcer.PolicyDecision decision = evaluator.evaluate(charterPayload);

            if (decision == null) {
                return safeFailure(
                        "The local policy evaluator did not return a decision."
                );
            }

            return enforceDecisionShape(decision);
        } catch (Exception e) {
            return safeFailure(
                    "The local policy evaluator threw an exception: " + e.getMessage()
            );
        }
    }

    private PolicyEnforcer.PolicyDecision enforceDecisionShape(
            PolicyEnforcer.PolicyDecision decision
    ) {
        String state = decision.state();

        if (state == null || state.isBlank()) {
            return safeFailure("The policy decision state was null or blank.");
        }

        List<String> reasons = decision.reasons();
        if (reasons == null) {
            return safeFailure("The policy decision reasons were null.");
        }

        String explanation = decision.plainLanguageExplanation();
        if (explanation == null || explanation.isBlank()) {
            return safeFailure(
                    "The policy decision explanation was null or blank."
            );
        }

        if (decision.allow() &&
                !"approved_for_advisory_use".equals(state)) {
            return safeFailure(
                    "The policy result claimed allow=true but state was '" + state +
                            "' which requires review."
            );
        }

        if (!decision.allow() && reasons.isEmpty()) {
            return safeFailure(
                    "The policy result did not provide a reviewable reason."
            );
        }

        return decision;
    }

    private PolicyEnforcer.PolicyDecision safeFailure(String reason) {
        return new PolicyEnforcer.PolicyDecision(
                false,
                "needs_review",
                List.of(reason),
                "This result needs review before use. " +
                        "An accessible correction and appeal path must remain available. " +
                        reason
        );
    }
}
