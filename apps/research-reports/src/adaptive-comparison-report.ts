// mk-bluebird/Cybercore/apps/research-reports/src/adaptive-comparison-report.ts
export type ComparisonDisposition =
  | "advances-evidence"
  | "mixed-evidence"
  | "does-not-advance-evidence";

export interface AssistiveWeights {
  accuracy: number;
  reliability: number;
  latency: number;
  falseActivation: number;
  usability: number;
}

export interface AssistiveMetrics {
  accuracy: number;
  reliability: number;
  normalizedLatency: number;
  falseActivationRate: number;
  usability: number;
}

export interface AdaptiveComparisonReport {
  reportId: string;
  researchObjectId: "R-DECODER-002";
  fixedReferenceId: string;
  adaptiveReferenceId: string;
  lockedWeights: AssistiveWeights;
  falseActivationTolerance: number;
  usabilityTolerance: number;
  fixed: AssistiveMetrics;
  adaptive: AssistiveMetrics;
  fixedScore: number;
  adaptiveScore: number;
  scoreDelta: number;
  falseActivationDelta: number;
  usabilityDelta: number;
  disposition: ComparisonDisposition;
  interpretation: string;
}

function assertNormalized(value: number, label: string): void {
  if (!Number.isFinite(value) || value < 0 || value > 1) {
    throw new Error(`${label} must be finite and within [0, 1]`);
  }
}

function validateWeights(weights: AssistiveWeights): void {
  const values = [
    weights.accuracy,
    weights.reliability,
    weights.latency,
    weights.falseActivation,
    weights.usability,
  ];
  values.forEach((value, index) => assertNormalized(value, `weight[${index}]`));
  const total = values.reduce((sum, value) => sum + value, 0);
  if (Math.abs(total - 1) > 1e-12) {
    throw new Error("locked weights must sum exactly to 1");
  }
}

function validateMetrics(metrics: AssistiveMetrics): void {
  Object.entries(metrics).forEach(([label, value]) => assertNormalized(value, label));
}

export function scoreAssistive(
  metrics: AssistiveMetrics,
  weights: AssistiveWeights,
): number {
  validateMetrics(metrics);
  validateWeights(weights);

  return (
    weights.accuracy * metrics.accuracy +
    weights.reliability * metrics.reliability +
    weights.latency * (1 - metrics.normalizedLatency) +
    weights.falseActivation * (1 - metrics.falseActivationRate) +
    weights.usability * metrics.usability
  );
}

export function createAdaptiveComparisonReport(input: {
  reportId: string;
  fixedReferenceId: string;
  adaptiveReferenceId: string;
  lockedWeights: AssistiveWeights;
  falseActivationTolerance: number;
  usabilityTolerance: number;
  fixed: AssistiveMetrics;
  adaptive: AssistiveMetrics;
}): AdaptiveComparisonReport {
  if (
    !Number.isFinite(input.falseActivationTolerance) ||
    !Number.isFinite(input.usabilityTolerance) ||
    input.falseActivationTolerance < 0 ||
    input.usabilityTolerance < 0
  ) {
    throw new Error("comparison tolerances must be finite and non-negative");
  }

  const fixedScore = scoreAssistive(input.fixed, input.lockedWeights);
  const adaptiveScore = scoreAssistive(input.adaptive, input.lockedWeights);
  const scoreDelta = adaptiveScore - fixedScore;
  const falseActivationDelta =
    input.adaptive.falseActivationRate - input.fixed.falseActivationRate;
  const usabilityDelta = input.adaptive.usability - input.fixed.usability;

  const advances =
    scoreDelta >= 0 &&
    falseActivationDelta <= input.falseActivationTolerance &&
    usabilityDelta >= -input.usabilityTolerance;

  const mixed =
    !advances &&
    (scoreDelta >= 0 || falseActivationDelta <= input.falseActivationTolerance);

  const disposition: ComparisonDisposition = advances
    ? "advances-evidence"
    : mixed
      ? "mixed-evidence"
      : "does-not-advance-evidence";

  const interpretation =
    disposition === "advances-evidence"
      ? "The adaptive configuration meets the locked composite-performance, false-activation, and usability conditions."
      : disposition === "mixed-evidence"
        ? "The comparison contains favorable and unfavorable dimensions; retain the evidence as mixed and inspect the metric-level record."
        : "The adaptive configuration does not satisfy the locked comparison conditions.";

  return {
    reportId: input.reportId,
    researchObjectId: "R-DECODER-002",
    fixedReferenceId: input.fixedReferenceId,
    adaptiveReferenceId: input.adaptiveReferenceId,
    lockedWeights: input.lockedWeights,
    falseActivationTolerance: input.falseActivationTolerance,
    usabilityTolerance: input.usabilityTolerance,
    fixed: input.fixed,
    adaptive: input.adaptive,
    fixedScore,
    adaptiveScore,
    scoreDelta,
    falseActivationDelta,
    usabilityDelta,
    disposition,
    interpretation,
  };
}
