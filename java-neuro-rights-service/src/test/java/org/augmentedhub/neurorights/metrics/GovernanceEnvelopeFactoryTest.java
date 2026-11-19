package org.augmentedhub.neurights.metrics;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

final class GovernanceEnvelopeFactoryTest {
    @Test
    void standardEnvelopeUsesRequiredAggregateOnlyValues() {
        final Map<String, String> envelope =
            GovernanceEnvelopeFactory.standardEnvelope();

        assertEquals(
            "aggregate_environmental_decision_support_only",
            envelope.get("scope")
        );
        assertEquals(
            "prohibited",
            envelope.get("individual_profiling")
        );
        assertEquals(
            "prohibited",
            envelope.get("automated_adverse_action")
        );
        assertEquals(
            "not_performed",
            envelope.get("external_action")
        );
    }

    @Test
    void standardEnvelopeIsImmutable() {
        final Map<String, String> envelope =
            GovernanceEnvelopeFactory.standardEnvelope();

        assertThrows(
            UnsupportedOperationException.class,
            () -> envelope.put("scope", "changed")
        );
    }

    @Test
    void attachToResponseAddsCanonicalGovernanceWhenMissing() {
        final Map<String, Object> response = Map.of(
            "metric",
            "surface_burn_clock",
            "result",
            Map.of("estimated_surface_temperature_c", 67.2)
        );

        final Map<String, Object> enriched =
            GovernanceEnvelopeFactory.attachToResponse(response);

        assertTrue(
            GovernanceEnvelopeFactory.hasRequiredGovernance(enriched)
        );
        assertEquals(
            GovernanceEnvelopeFactory.standardEnvelope(),
            enriched.get("governance")
        );
        assertEquals(
            "surface_burn_clock",
            enriched.get("metric")
        );
    }

    @Test
    void attachToResponseRetainsCompatibleExistingGovernance() {
        final Map<String, Object> response = new LinkedHashMap<>();
        response.put("metric", "watershed_health");
        response.put(
            "governance",
            new LinkedHashMap<>(
                GovernanceEnvelopeFactory.standardEnvelope()
            )
        );

        final Map<String, Object> enriched =
            GovernanceEnvelopeFactory.attachToResponse(response);

        assertTrue(
            GovernanceEnvelopeFactory.hasRequiredGovernance(enriched)
        );
        assertEquals(
            GovernanceEnvelopeFactory.standardEnvelope(),
            enriched.get("governance")
        );
    }

    @Test
    void attachToResponseRejectsIncompatibleGovernance() {
        final Map<String, Object> response = Map.of(
            "metric",
            "aquifer_recharge",
            "governance",
            Map.of(
                "scope",
                "aggregate_environmental_decision_support_only",
                "individual_profiling",
                "allowed",
                "automated_adverse_action",
                "prohibited",
                "external_action",
                "not_performed"
            )
        );

        assertThrows(
            IllegalArgumentException.class,
            () -> GovernanceEnvelopeFactory.attachToResponse(response)
        );
    }

    @Test
    void missingGovernanceProducesStableValidationState() {
        final GovernanceEnvelopeFactory.GovernanceValidation validation =
            GovernanceEnvelopeFactory.validateGovernance(null);

        assertFalse(validation.present());
        assertFalse(validation.valid());
        assertEquals("governance_missing", validation.reason());
    }

    @Test
    void nonObjectGovernanceProducesStableValidationState() {
        final GovernanceEnvelopeFactory.GovernanceValidation validation =
            GovernanceEnvelopeFactory.validateGovernance(
                "aggregate_environmental_decision_support_only"
            );

        assertTrue(validation.present());
        assertFalse(validation.valid());
        assertEquals("governance_not_object", validation.reason());
    }

    @Test
    void incompatibleScopeIsRejected() {
        final Map<String, Object> governance = new LinkedHashMap<>(
            GovernanceEnvelopeFactory.standardEnvelope()
        );
        governance.put("scope", "person_level_decision_support");

        final GovernanceEnvelopeFactory.GovernanceValidation validation =
            GovernanceEnvelopeFactory.validateGovernance(governance);

        assertTrue(validation.present());
        assertFalse(validation.valid());
        assertEquals("scope_not_aggregate_environmental", validation.reason());
    }

    @Test
    void incompatibleIndividualProfilingStateIsRejected() {
        final Map<String, Object> governance = new LinkedHashMap<>(
            GovernanceEnvelopeFactory.standardEnvelope()
        );
        governance.put("individual_profiling", "allowed");

        final GovernanceEnvelopeFactory.GovernanceValidation validation =
            GovernanceEnvelopeFactory.validateGovernance(governance);

        assertTrue(validation.present());
        assertFalse(validation.valid());
        assertEquals(
            "individual_profiling_not_prohibited",
            validation.reason()
        );
    }

    @Test
    void incompatibleAutomatedAdverseActionStateIsRejected() {
        final Map<String, Object> governance = new LinkedHashMap<>(
            GovernanceEnvelopeFactory.standardEnvelope()
        );
        governance.put("automated_adverse_action", "allowed");

        final GovernanceEnvelopeFactory.GovernanceValidation validation =
            GovernanceEnvelopeFactory.validateGovernance(governance);

        assertTrue(validation.present());
        assertFalse(validation.valid());
        assertEquals(
            "automated_adverse_action_not_prohibited",
            validation.reason()
        );
    }

    @Test
    void incompatibleExternalActionIsRejected() {
        final Map<String, Object> governance = new LinkedHashMap<>(
            GovernanceEnvelopeFactory.standardEnvelope()
        );
        governance.put("external_action", "performed");

        final GovernanceEnvelopeFactory.GovernanceValidation validation =
            GovernanceEnvelopeFactory.validateGovernance(governance);

        assertTrue(validation.present());
        assertFalse(validation.valid());
        assertEquals(
            "external_action_not_not_performed",
            validation.reason()
        );
    }

    @Test
    void missingRequiredGovernanceFieldIsRejected() {
        final Map<String, Object> governance = new LinkedHashMap<>(
            GovernanceEnvelopeFactory.standardEnvelope()
        );
        governance.remove("external_action");

        final GovernanceEnvelopeFactory.GovernanceValidation validation =
            GovernanceEnvelopeFactory.validateGovernance(governance);

        assertTrue(validation.present());
        assertFalse(validation.valid());
        assertEquals("external_action_missing", validation.reason());
    }
}
