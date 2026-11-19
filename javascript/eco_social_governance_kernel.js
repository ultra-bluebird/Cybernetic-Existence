"use strict";

function requireUnitInterval(value, label) {
  if (!Number.isFinite(value) || value < 0 || value > 1) {
    throw new RangeError(`${label} must be within [0, 1].`);
  }
}

function requireNonNegative(value, label) {
  if (!Number.isFinite(value) || value < 0) {
    throw new RangeError(`${label} must be non-negative.`);
  }
}

function assessEcoSocialRoi({
  investment,
  ecoBenefit,
  socialBenefit,
  rightsBenefit,
  evidenceConfidence,
  rightsProtectionVerified
}) {
  requireNonNegative(investment, "investment");
  requireNonNegative(ecoBenefit, "ecoBenefit");
  requireNonNegative(socialBenefit, "socialBenefit");
  requireNonNegative(rightsBenefit, "rightsBenefit");
  requireUnitInterval(evidenceConfidence, "evidenceConfidence");

  if (investment <= 0) {
    throw new RangeError("investment must be greater than zero.");
  }

  if (!rightsProtectionVerified) {
    return {
      eligible: false,
      adjustedRoi: 0,
      reason: "rights protection is a non-compensable investment gate"
    };
  }

  const verifiedBenefits =
    (ecoBenefit + socialBenefit + rightsBenefit) * evidenceConfidence;

  return {
    eligible: true,
    adjustedRoi: verifiedBenefits / investment,
    reason: "benefits are confidence-adjusted and rights-gated"
  };
}

function evaluateGovernanceUpdate({
  existingRights,
  proposedRights,
  learningScore,
  communityInputScore,
  incidentReviewComplete,
  publicRationalePublished,
  accessibleAppealAvailable,
  legalOrPolicyReviewComplete
}) {
  requireUnitInterval(learningScore, "learningScore");
  requireUnitInterval(communityInputScore, "communityInputScore");

  const existing = new Set(existingRights);
  const proposed = new Set(proposedRights);
  const removedRights = [...existing].filter((right) => !proposed.has(right));

  const updateScore = 0.5 * learningScore + 0.5 * communityInputScore;

  const admissible =
    removedRights.length === 0 &&
    incidentReviewComplete &&
    publicRationalePublished &&
    accessibleAppealAvailable &&
    legalOrPolicyReviewComplete;

  return {
    admissible,
    updateScore: admissible ? updateScore : 0,
    removedRights,
    addedRights: [...proposed].filter((right) => !existing.has(right)),
    reasons: [
      ...(removedRights.length > 0
        ? ["existing rights may not be reduced"]
        : []),
      ...(!incidentReviewComplete
        ? ["incident and outcome review is incomplete"]
        : []),
      ...(!publicRationalePublished
        ? ["public rationale is not published"]
        : []),
      ...(!accessibleAppealAvailable
        ? ["accessible appeal path is unavailable"]
        : []),
      ...(!legalOrPolicyReviewComplete
        ? ["legal or policy review is incomplete"]
        : [])
    ]
  };
}

function evaluateSmartCityProposal({
  benefits,
  rights,
  privacy,
  safety,
  rightsThresholds,
  privacyThresholds,
  safetyThresholds
}) {
  const dimensions = [
    ["rights", rights, rightsThresholds],
    ["privacy", privacy, privacyThresholds],
    ["safety", safety, safetyThresholds]
  ];

  const unmetConstraints = [];

  for (const [dimensionName, values, thresholds] of dimensions) {
    for (const [name, threshold] of Object.entries(thresholds)) {
      requireUnitInterval(threshold, `${dimensionName}.${name} threshold`);

      const actual = values[name];

      if (actual === undefined) {
        unmetConstraints.push(`${dimensionName}.${name} is missing`);
        continue;
      }

      requireUnitInterval(actual, `${dimensionName}.${name}`);

      if (actual < threshold) {
        unmetConstraints.push(
          `${dimensionName}.${name} is below its required threshold`
        );
      }
    }
  }

  for (const value of Object.values(benefits)) {
    requireUnitInterval(value, "benefit");
  }

  const totalBenefit = Object.values(benefits).reduce(
    (total, value) => total + value,
    0
  );

  return {
    feasible: unmetConstraints.length === 0,
    objectiveValue: unmetConstraints.length === 0 ? totalBenefit : 0,
    unmetConstraints
  };
}

module.exports = {
  assessEcoSocialRoi,
  evaluateGovernanceUpdate,
  evaluateSmartCityProposal
};
