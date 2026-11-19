"use strict";

const BASIS_POINTS_PER_UNIT = 10_000;
const MILLIS_PER_SECOND = 1_000;
const SECONDS_PER_MINUTE = 60;

class DigitalTwinSyncError extends Error {
    constructor(message) {
        super(message);
        this.name = "DigitalTwinSyncError";
    }
}

function requireFiniteNonNegative(name, value) {
    if (!Number.isFinite(value) || value < 0) {
        throw new DigitalTwinSyncError(`${name} must be a finite non-negative number`);
    }
}

function requirePositive(name, value) {
    if (!Number.isFinite(value) || value <= 0) {
        throw new DigitalTwinSyncError(`${name} must be a finite positive number`);
    }
}

function clampUnitInterval(value) {
    return Math.min(1, Math.max(0, value));
}

function toBasisPoints(unitValue) {
    requireFiniteNonNegative("unitValue", unitValue);

    if (unitValue > 1) {
        throw new DigitalTwinSyncError("unitValue must not exceed 1");
    }

    return Math.floor(unitValue * BASIS_POINTS_PER_UNIT);
}

function capabilitySyncProfile(capabilityType) {
    const profiles = {
        corridor_sensor_continuity: {
            maximumSyncIntervalSeconds: 60,
            maximumPermittedError: 0.02,
            rationale: "Sensor-derived continuity can affect environmental operations and should be refreshed at least once per minute under ordinary validated conditions.",
        },
        charging_station_availability: {
            maximumSyncIntervalSeconds: 30,
            maximumPermittedError: 0.01,
            rationale: "Charging availability is an access-critical service condition and benefits from at least thirty-second synchronization.",
        },
        thermal_comfort_refuge: {
            maximumSyncIntervalSeconds: 15,
            maximumPermittedError: 0.005,
            rationale: "Cooling-zone availability and thermal safety should be refreshed at least every fifteen seconds because conditions can change quickly during high-heat periods.",
        },
        low_latency_handoff: {
            maximumSyncIntervalSeconds: 1,
            maximumPermittedError: 0.001,
            rationale: "Network handoff continuity requires near-real-time state because a stale state can create an immediate connectivity gap.",
        },
        long_horizon_ecological_metric: {
            maximumSyncIntervalSeconds: 900,
            maximumPermittedError: 0.05,
            rationale: "Slow-moving ecological aggregate metrics can use a fifteen-minute synchronization interval when the sensor-drift bound remains validated.",
        },
    };

    const profile = profiles[capabilityType];

    if (!profile) {
        throw new DigitalTwinSyncError(`Unsupported capability type: ${capabilityType}`);
    }

    return Object.freeze({ capabilityType, ...profile });
}

/**
 * Computes a conservative upper bound for continuity-ratio error.
 *
 * The bound is:
 *
 * epsilon <= min(1, rho * delta_t + sigma_drift)
 *
 * where:
 * rho is the maximum verified continuity-state transition rate per second;
 * delta_t is the synchronization interval in seconds;
 * sigma_drift is the unit-interval sensor-drift uncertainty bound.
 *
 * The model intentionally uses a bounded worst-case formulation. It does not
 * infer individual movement, disability, identity, device class, or health data.
 */
function boundContinuityRatioError({
    syncIntervalSeconds,
    maximumStateTransitionRatePerSecond,
    sensorDriftBound,
}) {
    requireFiniteNonNegative("syncIntervalSeconds", syncIntervalSeconds);
    requireFiniteNonNegative(
        "maximumStateTransitionRatePerSecond",
        maximumStateTransitionRatePerSecond,
    );
    requireFiniteNonNegative("sensorDriftBound", sensorDriftBound);

    if (sensorDriftBound > 1) {
        throw new DigitalTwinSyncError("sensorDriftBound must not exceed 1");
    }

    const stalenessErrorBound =
        maximumStateTransitionRatePerSecond * syncIntervalSeconds;

    const rawErrorBound = stalenessErrorBound + sensorDriftBound;
    const continuityRatioErrorBound = clampUnitInterval(rawErrorBound);

    return Object.freeze({
        syncIntervalSeconds,
        maximumStateTransitionRatePerSecond,
        sensorDriftBound,
        stalenessErrorBound,
        continuityRatioErrorBound,
        continuityRatioErrorBoundBasisPoints: toBasisPoints(
            continuityRatioErrorBound,
        ),
    });
}

/**
 * Calculates the maximum synchronization interval permitted by an
 * application-defined continuity-ratio error budget.
 *
 * delta_t_max = max(0, (epsilon_max - sigma_drift) / rho)
 *
 * If rho is zero, no observed state transition is possible according to the
 * supplied model, so interval length is bounded only by operational policy.
 */
function maximumSyncIntervalSeconds({
    maximumPermittedError,
    maximumStateTransitionRatePerSecond,
    sensorDriftBound,
}) {
    requireFiniteNonNegative("maximumPermittedError", maximumPermittedError);
    requireFiniteNonNegative(
        "maximumStateTransitionRatePerSecond",
        maximumStateTransitionRatePerSecond,
    );
    requireFiniteNonNegative("sensorDriftBound", sensorDriftBound);

    if (maximumPermittedError > 1 || sensorDriftBound > 1) {
        throw new DigitalTwinSyncError(
            "maximumPermittedError and sensorDriftBound must not exceed 1",
        );
    }

    const remainingErrorBudget = Math.max(
        0,
        maximumPermittedError - sensorDriftBound,
    );

    if (maximumStateTransitionRatePerSecond === 0) {
        return Object.freeze({
            maximumSyncIntervalSeconds: Number.POSITIVE_INFINITY,
            remainingErrorBudget,
            explanation:
                "The model reports no state-transition rate. Apply an explicit operational maximum synchronization interval rather than treating infinity as a deployment setting.",
        });
    }

    return Object.freeze({
        maximumSyncIntervalSeconds:
            remainingErrorBudget / maximumStateTransitionRatePerSecond,
        remainingErrorBudget,
        explanation:
            "The interval bound is the remaining continuity-error budget divided by the verified maximum continuity-state transition rate.",
    });
}

function recommendSyncFrequency({
    capabilityType,
    maximumStateTransitionRatePerSecond,
    sensorDriftBound,
}) {
    const profile = capabilitySyncProfile(capabilityType);

    const mathematicalBound = maximumSyncIntervalSeconds({
        maximumPermittedError: profile.maximumPermittedError,
        maximumStateTransitionRatePerSecond,
        sensorDriftBound,
    });

    const recommendedMaximumSyncIntervalSeconds = Math.min(
        profile.maximumSyncIntervalSeconds,
        mathematicalBound.maximumSyncIntervalSeconds,
    );

    const recommendedMinimumSyncsPerMinute =
        recommendedMaximumSyncIntervalSeconds === Number.POSITIVE_INFINITY
            ? 0
            : Math.ceil(
                  SECONDS_PER_MINUTE /
                      Math.max(recommendedMaximumSyncIntervalSeconds, 0.001),
              );

    const predictedBound = boundContinuityRatioError({
        syncIntervalSeconds: recommendedMaximumSyncIntervalSeconds,
        maximumStateTransitionRatePerSecond,
        sensorDriftBound,
    });

    return Object.freeze({
        capabilityType,
        recommendedMaximumSyncIntervalSeconds,
        recommendedMinimumSyncsPerMinute,
        policyMaximumSyncIntervalSeconds: profile.maximumSyncIntervalSeconds,
        maximumPermittedError: profile.maximumPermittedError,
        predictedContinuityRatioErrorBound:
            predictedBound.continuityRatioErrorBound,
        predictedContinuityRatioErrorBoundBasisPoints:
            predictedBound.continuityRatioErrorBoundBasisPoints,
        rationale: profile.rationale,
        mathematicalExplanation: mathematicalBound.explanation,
    });
}

module.exports = {
    BASIS_POINTS_PER_UNIT,
    MILLIS_PER_SECOND,
    DigitalTwinSyncError,
    boundContinuityRatioError,
    capabilitySyncProfile,
    maximumSyncIntervalSeconds,
    recommendSyncFrequency,
};
