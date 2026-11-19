"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
    boundContinuityRatioError,
    recommendSyncFrequency,
} = require("./digital_twin_sync");

test("bounds continuity-ratio error from stale state and sensor drift", () => {
    const result = boundContinuityRatioError({
        syncIntervalSeconds: 30,
        maximumStateTransitionRatePerSecond: 0.0002,
        sensorDriftBound: 0.004,
    });

    assert.equal(result.stalenessErrorBound, 0.006);
    assert.equal(result.continuityRatioErrorBound, 0.01);
    assert.equal(result.continuityRatioErrorBoundBasisPoints, 100);
});

test("recommends fifteen-second synchronization for thermal refuge conditions", () => {
    const recommendation = recommendSyncFrequency({
        capabilityType: "thermal_comfort_refuge",
        maximumStateTransitionRatePerSecond: 0.0001,
        sensorDriftBound: 0.002,
    });

    assert.equal(recommendation.recommendedMaximumSyncIntervalSeconds, 15);
    assert.equal(recommendation.recommendedMinimumSyncsPerMinute, 4);
    assert.equal(recommendation.predictedContinuityRatioErrorBound, 0.0035);
});

test("reduces the interval when the error budget would otherwise be exceeded", () => {
    const recommendation = recommendSyncFrequency({
        capabilityType: "charging_station_availability",
        maximumStateTransitionRatePerSecond: 0.0005,
        sensorDriftBound: 0.006,
    });

    assert.equal(recommendation.recommendedMaximumSyncIntervalSeconds, 8);
    assert.equal(recommendation.recommendedMinimumSyncsPerMinute, 8);
    assert.equal(recommendation.predictedContinuityRatioErrorBound, 0.01);
});
