package org.augmentedhub.governance;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

final class NonActuatingResearchGateTest {
    @Test
    void allowsHostApprovedOfflineSimulation() {
        var result = NonActuatingResearchGate.evaluate(
            new NonActuatingResearchGate.Request(
                NonActuatingResearchGate.RequestedCapability.OFFLINE_SIMULATION,
                "Evaluate a documented external thermal-cost model.",
                true,
                false
            )
        );

        assertEquals(
            NonActuatingResearchGate.Decision.ALLOW_ADVISORY_ONLY,
            result.decision()
        );
        assertTrue(!result.requiresHumanReview());
    }

    @Test
    void deniesWirelessActivation() {
        var result = NonActuatingResearchGate.evaluate(
            new NonActuatingResearchGate.Request(
                NonActuatingResearchGate.RequestedCapability.WIRELESS_ACTIVATION,
                "Attempt to activate a physical subsystem.",
                true,
                false
            )
        );

        assertEquals(
            NonActuatingResearchGate.Decision.DENY,
            result.decision()
        );
        assertTrue(result.requiresHumanReview());
    }

    @Test
    void deniesAnyExternalAction() {
        var result = NonActuatingResearchGate.evaluate(
            new NonActuatingResearchGate.Request(
                NonActuatingResearchGate.RequestedCapability.ENVIRONMENTAL_ROUTE_PLANNING,
                "Send a route or control signal to a third-party system.",
                true,
                true
            )
        );

        assertEquals(
            NonActuatingResearchGate.Decision.DENY,
            result.decision()
        );
    }
}
