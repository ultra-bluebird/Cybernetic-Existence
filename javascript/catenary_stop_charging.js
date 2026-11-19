"use strict";

const MILLIS_PER_HOUR = 3_600_000;
const BASIS_POINTS_PER_UNIT = 10_000;

class CatenaryChargingError extends Error {
    constructor(message) {
        super(message);
        this.name = "CatenaryChargingError";
    }
}

function requireFiniteNonNegative(name, value) {
    if (!Number.isFinite(value) || value < 0) {
        throw new CatenaryChargingError(
            `${name} must be a finite non-negative number`,
        );
    }
}

function requirePositive(name, value) {
    if (!Number.isFinite(value) || value <= 0) {
        throw new CatenaryChargingError(
            `${name} must be a finite positive number`,
        );
    }
}

function requireUnitInterval(name, value) {
    if (!Number.isFinite(value) || value < 0 || value > 1) {
        throw new CatenaryChargingError(`${name} must be within [0, 1]`);
    }
}

function minimumChargingPowerKilowatts({
    batteryCapacityKilowattHours,
    minimumStateOfCharge,
    stateOfChargeBeforeStop,
    expectedEnergyUseUntilNextStopKilowattHours,
    dwellTimeMilliseconds,
    chargingEfficiency,
}) {
    requirePositive("batteryCapacityKilowattHours", batteryCapacityKilowattHours);
    requireUnitInterval("minimumStateOfCharge", minimumStateOfCharge);
    requireUnitInterval("stateOfChargeBeforeStop", stateOfChargeBeforeStop);
    requireFiniteNonNegative(
        "expectedEnergyUseUntilNextStopKilowattHours",
        expectedEnergyUseUntilNextStopKilowattHours,
    );
    requirePositive("dwellTimeMilliseconds", dwellTimeMilliseconds);
    requireUnitInterval("chargingEfficiency", chargingEfficiency);

    if (chargingEfficiency === 0) {
        throw new CatenaryChargingError("chargingEfficiency must be greater than zero");
    }

    const minimumEnergyAfterDepartureKilowattHours =
        batteryCapacityKilowattHours * minimumStateOfCharge;

    const requiredEnergyAfterChargeKilowattHours =
        minimumEnergyAfterDepartureKilowattHours +
        expectedEnergyUseUntilNextStopKilowattHours;

    const energyBeforeChargeKilowattHours =
        batteryCapacityKilowattHours * stateOfChargeBeforeStop;

    const requiredChargedEnergyKilowattHours = Math.max(
        0,
        requiredEnergyAfterChargeKilowattHours -
            energyBeforeChargeKilowattHours,
    );

    const dwellTimeHours = dwellTimeMilliseconds / MILLIS_PER_HOUR;

    const minimumChargingPowerKilowatts =
        requiredChargedEnergyKilowattHours /
        (dwellTimeHours * chargingEfficiency);

    return Object.freeze({
        minimumChargingPowerKilowatts,
        requiredChargedEnergyKilowattHours,
        minimumEnergyAfterDepartureKilowattHours,
        requiredEnergyAfterChargeKilowattHours,
        energyBeforeChargeKilowattHours,
        dwellTimeHours,
    });
}

function calculateEnergyStorage({
    batteryCapacityKilowattHours,
    initialStateOfCharge,
    minimumStateOfCharge,
    routeSegments,
    chargingEfficiency,
}) {
    requirePositive("batteryCapacityKilowattHours", batteryCapacityKilowattHours);
    requireUnitInterval("initialStateOfCharge", initialStateOfCharge);
    requireUnitInterval("minimumStateOfCharge", minimumStateOfCharge);
    requireUnitInterval("chargingEfficiency", chargingEfficiency);

    if (!Array.isArray(routeSegments) || routeSegments.length === 0) {
        throw new CatenaryChargingError(
            "routeSegments must contain at least one route segment",
        );
    }

    let storedEnergyKilowattHours =
        batteryCapacityKilowattHours * initialStateOfCharge;

    const minimumReserveKilowattHours =
        batteryCapacityKilowattHours * minimumStateOfCharge;

    const stopAssessments = [];
    let continuityMaintained = storedEnergyKilowattHours >= minimumReserveKilowattHours;

    for (const [stopIndex, segment] of routeSegments.entries()) {
        requireFiniteNonNegative(
            "energyUseFromPreviousStopKilowattHours",
            segment.energyUseFromPreviousStopKilowattHours,
        );
        requireFiniteNonNegative(
            "dwellTimeMilliseconds",
            segment.dwellTimeMilliseconds,
        );
        requireFiniteNonNegative(
            "chargingPowerKilowatts",
            segment.chargingPowerKilowatts,
        );

        storedEnergyKilowattHours -=
            segment.energyUseFromPreviousStopKilowattHours;

        const stateOfChargeOnArrival =
            storedEnergyKilowattHours / batteryCapacityKilowattHours;

        if (storedEnergyKilowattHours < minimumReserveKilowattHours) {
            continuityMaintained = false;
        }

        const dwellTimeHours = segment.dwellTimeMilliseconds / MILLIS_PER_HOUR;

        const energyDeliveredKilowattHours =
            segment.chargingPowerKilowatts *
            dwellTimeHours *
            chargingEfficiency;

        storedEnergyKilowattHours = Math.min(
            batteryCapacityKilowattHours,
            storedEnergyKilowattHours + energyDeliveredKilowattHours,
        );

        const stateOfChargeAfterCharge =
            storedEnergyKilowattHours / batteryCapacityKilowattHours;

        stopAssessments.push(
            Object.freeze({
                stopIndex,
                stateOfChargeOnArrival,
                stateOfChargeAfterCharge,
                energyDeliveredKilowattHours,
                continuityRequirementMet:
                    stateOfChargeOnArrival >= minimumStateOfCharge,
            }),
        );
    }

    return Object.freeze({
        finalStoredEnergyKilowattHours: storedEnergyKilowattHours,
        finalStateOfCharge:
            storedEnergyKilowattHours / batteryCapacityKilowattHours,
        minimumReserveKilowattHours,
        continuityMaintained,
        continuityRatioBasisPoints: continuityMaintained
            ? BASIS_POINTS_PER_UNIT
            : 0,
        stopAssessments,
    });
}

module.exports = {
    CatenaryChargingError,
    calculateEnergyStorage,
    minimumChargingPowerKilowatts,
};
