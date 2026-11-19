'use strict';

/**
 * Local-only validation and planning logic for maintenance-bot power cycles.
 * This module does not issue vehicle commands, control chargers, bypass a BMS,
 * track people, store raw routes, or transmit data to external systems.
 */

const POLICY_SCHEMA = 'javasphere.maintenance-bot-ecosystem-power-policy/v1';
const PLAN_SCHEMA = 'javasphere.maintenance-bot-ecosystem-power-plan/v1';

const ECOLOGICAL_WORK_METRICS = new Set([
  'debris-mass-removed',
  'drainage-capacity-restored',
  'bioswale-function-supported',
  'accessibility-obstruction-removed',
  'multi-metric-validated'
]);

function assertPlainObject(value, name) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new TypeError(`${name} must be a plain object.`);
  }
}

function assertBoolean(value, name, expected) {
  if (value !== expected) {
    throw new Error(`${name} must be ${String(expected)}.`);
  }
}

function assertInteger(value, name, minimum, maximum) {
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new RangeError(`${name} must be an integer from ${minimum} through ${maximum}.`);
  }
}

function assertFraction(value, name, minimum = 0, maximum = 1) {
  if (!Number.isFinite(value) || value < minimum || value > maximum) {
    throw new RangeError(`${name} must be a finite number from ${minimum} through ${maximum}.`);
  }
}

function assertFiniteNonNegative(value, name) {
  if (!Number.isFinite(value) || value < 0) {
    throw new RangeError(`${name} must be a finite non-negative number.`);
  }
}

function validatePolicy(policy) {
  assertPlainObject(policy, 'policy');

  if (policy.schema !== POLICY_SCHEMA) {
    throw new Error(`policy.schema must equal "${POLICY_SCHEMA}".`);
  }

  if (
    typeof policy.policyName !== 'string' ||
    !/^[a-z][a-z0-9-]{2,95}$/.test(policy.policyName)
  ) {
    throw new RangeError('policy.policyName must be a lowercase policy identifier.');
  }

  if (Number.isNaN(Date.parse(policy.effectiveFrom))) {
    throw new TypeError('policy.effectiveFrom must be an ISO-8601 date.');
  }

  for (const section of [
    'governance',
    'batterySafety',
    'ecologicalService',
    'equity',
    'privacy',
    'coordination',
    'federatedLearning',
    'humanOversight'
  ]) {
    assertPlainObject(policy[section], `policy.${section}`);
  }

  assertBoolean(
    policy.governance.communityReviewCompleted,
    'policy.governance.communityReviewCompleted',
    true
  );
  assertBoolean(
    policy.governance.manufacturerBatteryProfileVerified,
    'policy.governance.manufacturerBatteryProfileVerified',
    true
  );
  assertBoolean(
    policy.governance.qualifiedMaintenanceReviewRequired,
    'policy.governance.qualifiedMaintenanceReviewRequired',
    true
  );

  if (policy.governance.permittedUse !== 'public-ecological-maintenance-energy-planning') {
    throw new Error('policy.governance.permittedUse is invalid.');
  }

  const safety = policy.batterySafety;

  assertFraction(
    safety.minimumOperationalSocFraction,
    'policy.batterySafety.minimumOperationalSocFraction',
    0.05,
    0.8
  );
  assertFraction(
    safety.maximumOperationalSocFraction,
    'policy.batterySafety.maximumOperationalSocFraction',
    0.2,
    0.98
  );
  assertFraction(
    safety.returnReserveSocFraction,
    'policy.batterySafety.returnReserveSocFraction',
    0.05,
    0.8
  );

  if (safety.minimumOperationalSocFraction >= safety.maximumOperationalSocFraction) {
    throw new Error('The minimum operating state of charge must be below the maximum operating state of charge.');
  }

  if (safety.returnReserveSocFraction < safety.minimumOperationalSocFraction) {
    throw new Error('The return reserve must not be below the minimum operating state of charge.');
  }

  assertBoolean(
    safety.bmsRemainsAuthoritative,
    'policy.batterySafety.bmsRemainsAuthoritative',
    true
  );
  assertBoolean(
    safety.thermalFaultStopsPlanningDispatch,
    'policy.batterySafety.thermalFaultStopsPlanningDispatch',
    true
  );

  assertBoolean(
    policy.ecologicalService.criticalDrainageContinuityRequired,
    'policy.ecologicalService.criticalDrainageContinuityRequired',
    true
  );

  if (!ECOLOGICAL_WORK_METRICS.has(policy.ecologicalService.ecologicalWorkMetricClass)) {
    throw new RangeError('policy.ecologicalService.ecologicalWorkMetricClass is not supported.');
  }

  assertBoolean(
    policy.ecologicalService.hazardClearanceRequired,
    'policy.ecologicalService.hazardClearanceRequired',
    true
  );
  assertBoolean(
    policy.ecologicalService.solarUsedAsPreferenceNotRequirement,
    'policy.ecologicalService.solarUsedAsPreferenceNotRequirement',
    true
  );

  assertBoolean(
    policy.equity.minimumZoneServiceFloorRequired,
    'policy.equity.minimumZoneServiceFloorRequired',
    true
  );
  assertFraction(
    policy.equity.serviceDisparityBound,
    'policy.equity.serviceDisparityBound'
  );
  assertBoolean(
    policy.equity.chargingPlacementReviewedForCoverage,
    'policy.equity.chargingPlacementReviewedForCoverage',
    true
  );
  assertBoolean(
    policy.equity.complaintFrequencyUsedAsSolePriority,
    'policy.equity.complaintFrequencyUsedAsSolePriority',
    false
  );

  for (const name of [
    'rawLocationHistoryStored',
    'residentDataStored',
    'cameraOrAudioRequired',
    'individualProfilingAllowed',
    'cloudExportAllowed'
  ]) {
    assertBoolean(policy.privacy[name], `policy.privacy.${name}`, false);
  }

  assertBoolean(
    policy.coordination.localTaskLeaseEnabled,
    'policy.coordination.localTaskLeaseEnabled',
    true
  );
  assertInteger(
    policy.coordination.leaseExpirySeconds,
    'policy.coordination.leaseExpirySeconds',
    30,
    86400
  );
  assertBoolean(
    policy.coordination.signedMessagesRequired,
    'policy.coordination.signedMessagesRequired',
    true
  );
  assertBoolean(
    policy.coordination.returnReserveRequiredBeforeTaskAcceptance,
    'policy.coordination.returnReserveRequiredBeforeTaskAcceptance',
    true
  );
  assertBoolean(
    policy.coordination.networkLossFallbackEnabled,
    'policy.coordination.networkLossFallbackEnabled',
    true
  );

  assertBoolean(
    policy.federatedLearning.rawTelemetryShared,
    'policy.federatedLearning.rawTelemetryShared',
    false
  );
  assertBoolean(
    policy.federatedLearning.updateClippingRequired,
    'policy.federatedLearning.updateClippingRequired',
    true
  );
  assertBoolean(
    policy.federatedLearning.secureAggregationRequired,
    'policy.federatedLearning.secureAggregationRequired',
    true
  );
  assertInteger(
    policy.federatedLearning.minimumAggregationCohort,
    'policy.federatedLearning.minimumAggregationCohort',
    5,
    100000
  );
  assertBoolean(
    policy.federatedLearning.differentialPrivacyRequired,
    'policy.federatedLearning.differentialPrivacyRequired',
    true
  );
  assertBoolean(
    policy.federatedLearning.loraCarriesFullModelWeights,
    'policy.federatedLearning.loraCarriesFullModelWeights',
    false
  );

  assertBoolean(
    policy.humanOversight.dispatchRequiresHumanApproval,
    'policy.humanOversight.dispatchRequiresHumanApproval',
    true
  );
  assertBoolean(
    policy.humanOversight.modelPromotionRequiresReview,
    'policy.humanOversight.modelPromotionRequiresReview',
    true
  );
  assertBoolean(
    policy.humanOversight.automaticPublicSpaceEnforcementAllowed,
    'policy.humanOversight.automaticPublicSpaceEnforcementAllowed',
    false
  );
  assertBoolean(
    policy.humanOversight.overrideReasonRecorded,
    'policy.humanOversight.overrideReasonRecorded',
    true
  );

  return Object.freeze(structuredClone(policy));
}

function estimateCycleScore(candidate) {
  assertPlainObject(candidate, 'candidate');

  assertFiniteNonNegative(candidate.energyWh, 'candidate.energyWh');
  assertFiniteNonNegative(candidate.ecologicalWorkUnits, 'candidate.ecologicalWorkUnits');
  assertFiniteNonNegative(candidate.degradationCostUnits, 'candidate.degradationCostUnits');
  assertFraction(candidate.solarAvailabilityFraction, 'candidate.solarAvailabilityFraction');
  assertFraction(candidate.zoneServiceGapFraction, 'candidate.zoneServiceGapFraction');

  if (candidate.ecologicalWorkUnits === 0) {
    return Number.POSITIVE_INFINITY;
  }

  const energyPerWork = candidate.energyWh / candidate.ecologicalWorkUnits;

  const degradationPenalty = candidate.degradationCostUnits;
  const solarCredit = candidate.solarAvailabilityFraction * 0.1;
  const equityPenalty = candidate.zoneServiceGapFraction;

  return energyPerWork + degradationPenalty + equityPenalty - solarCredit;
}

function evaluateCandidateCycle(policy, state, candidate) {
  const validatedPolicy = validatePolicy(policy);

  assertPlainObject(state, 'state');
  assertPlainObject(candidate, 'candidate');

  assertFraction(state.stateOfChargeFraction, 'state.stateOfChargeFraction');
  assertFraction(state.stateOfHealthFraction, 'state.stateOfHealthFraction');
  assertFiniteNonNegative(state.estimatedReturnEnergyWh, 'state.estimatedReturnEnergyWh');
  assertFiniteNonNegative(state.availableEnergyWh, 'state.availableEnergyWh');

  const findings = [];

  if (state.bmsStatus !== 'healthy') {
    findings.push({
      code: 'bms-not-healthy',
      severity: 'blocking',
      message: 'The battery-management system is not healthy; no candidate cycle is suitable for dispatch planning.'
    });
  }

  if (state.thermalStatus !== 'within-approved-range') {
    findings.push({
      code: 'thermal-status-not-approved',
      severity: 'blocking',
      message: 'Battery thermal status is outside the approved range.'
    });
  }

  if (
    state.stateOfChargeFraction <
    validatedPolicy.batterySafety.returnReserveSocFraction
  ) {
    findings.push({
      code: 'return-reserve-not-met',
      severity: 'blocking',
      message: 'State of charge is below the configured return-energy reserve.'
    });
  }

  if (candidate.hazardClearance !== 'approved') {
    findings.push({
      code: 'hazard-clearance-required',
      severity: 'blocking',
      message: 'The candidate work bundle lacks approved hazard clearance.'
    });
  }

  if (candidate.zoneServiceFloorSatisfied !== true) {
    findings.push({
      code: 'zone-service-floor-not-satisfied',
      severity: 'blocking',
      message: 'The candidate would violate a declared minimum service floor.'
    });
  }

  if (
    candidate.requiredEnergyWh + state.estimatedReturnEnergyWh >
    state.availableEnergyWh
  ) {
    findings.push({
      code: 'insufficient-energy-with-return-reserve',
      severity: 'blocking',
      message: 'The candidate requires more energy than is available after preserving the return reserve.'
    });
  }

  const cycleScore = estimateCycleScore(candidate);
  const acceptable = !findings.some((finding) => finding.severity === 'blocking');

  return Object.freeze({
    schema: 'javasphere.maintenance-bot-ecosystem-power-evaluation/v1',
    policyName: validatedPolicy.policyName,
    acceptedForHumanReview: acceptable,
    automatedDispatchAuthorized: false,
    cycleScore: Number.isFinite(cycleScore) ? cycleScore : null,
    findings,
    nextStep: acceptable
      ? 'Present the candidate cycle, safety state, ecological benefit estimate, and equity coverage evidence for human review.'
      : 'Do not dispatch. Resolve the blocking safety, hazard, energy-reserve, or equity finding through qualified operations procedures.'
  });
}

function selectLocalFallbackAction(policy, state) {
  const validatedPolicy = validatePolicy(policy);

  assertPlainObject(state, 'state');

  assertFraction(state.stateOfChargeFraction, 'state.stateOfChargeFraction');

  if (state.bmsStatus !== 'healthy' || state.thermalStatus !== 'within-approved-range') {
    return Object.freeze({
      action: 'enter-safe-maintenance-state',
      reason: 'Battery health or thermal state requires qualified maintenance handling.',
      policyName: validatedPolicy.policyName
    });
  }

  if (
    state.stateOfChargeFraction <
    validatedPolicy.batterySafety.returnReserveSocFraction
  ) {
    return Object.freeze({
      action: 'return-to-approved-charge-point',
      reason: 'The battery state is below the configured reserve for continued service.',
      policyName: validatedPolicy.policyName
    });
  }

  return Object.freeze({
    action: 'hold-for-signed-local-task-lease',
    reason: 'Network-loss mode permits only locally authorized, reserve-preserving critical-task coordination.',
    policyName: validatedPolicy.policyName
  });
}

module.exports = {
  PLAN_SCHEMA,
  POLICY_SCHEMA,
  estimateCycleScore,
  evaluateCandidateCycle,
  selectLocalFallbackAction,
  validatePolicy
};
