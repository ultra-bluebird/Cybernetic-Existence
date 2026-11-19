"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
    calculateEnergyStorage,
    minimumChargingPowerKilowatts,
} = require("./catenary_stop_charging");

test("calculates the minimum catenary charging power for one stop", () => {
    const result = minimumChargingPowerKilowatts({
        batteryCapacityKilowattHours: 300,
        minimumStateOfCharge: 0.20,
        stateOfChargeBeforeStop: 0.30,
        expectedEnergyUseUntilNextStopKilowattHours: 45,
        dwellTimeMilliseconds: 120000,
        chargingEfficiency: 0.90,
    });

    assert.equal(result.minimumEnergyAfterDepartureKilowattHours, 60);
    assert.equal(result.requiredEnergyAfterChargeKilowattHours, 105);
    assert.equal(result.energyBeforeChargeKilowattHours, 90);
    assert.equal(result.requiredChargedEnergyKilowattHours, 15);
    assert.equal(result.minimumChargingPowerKilowatts, 500);
});

test("keeps a bus above the twenty percent state-of-charge continuity reserve", () => {
    const assessment = calculateEnergyStorage({
        batteryCapacityKilowattHours: 300,
        initialStateOfCharge: 0.50,
        minimumStateOfCharge: 0.20,
        chargingEfficiency: 0.90,
        routeSegments: [
            {
                energyUseFromPreviousStopKilowattHours: 30,
                dwellTimeMilliseconds: 120000,
                chargingPowerKilowatts: 500,
            },
            {
                energyUseFromPreviousStopKilowattHours: 45,
                dwellTimeMilliseconds: 120000,
                chargingPowerKilowatts: 500,
            },
        ],
    });

    assert.equal(assessment.continuityMaintained, true);
    assert.equal(assessment.continuityRatioBasisPoints, 10000);
    assert.equal(assessment.stopAssessments[0].continuityRequirementMet, true);
    assert.equal(assessment.stopAssessments[1].continuityRequirementMet, true);
});

test("reports a continuity failure when the bus falls below reserve before charging", () => {
    const assessment = calculateEnergyStorage({
        batteryCapacityKilowattHours: 300,
        initialStateOfCharge: 0.25,
        minimumStateOfCharge: 0.20,
        chargingEfficiency: 0.90,
        routeSegments: [
            {
                energyUseFromPreviousStopKilowattHours: 20,
                dwellTimeMilliseconds: 60000,
                chargingPowerKilowatts: 100,
            },
        ],
    });

    assert.equal(assessment.continuityMaintained, false);
    assert.equal(assessment.continuityRatioBasisPoints, 0);
    assert.equal(assessment.stopAssessments[0].continuityRequirementMet, false);
});
