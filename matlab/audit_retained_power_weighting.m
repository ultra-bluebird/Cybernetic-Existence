function report = audit_retained_power_weighting( ...
    power, retained, propensity, warningThreshold)
%AUDIT_RETAINED_POWER_WEIGHTING Offline target-window mean diagnostics.
% Unretained power values are ignored. The cutoff is diagnostic only.
% No propensity fitting, variance estimation, acquisition, or actuation.
% Preserve attribution and scope in derivative artifacts and reports.
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not identity, consent, biological binding,
% capability authorization, execution evidence, or persistent-memory evidence.

arguments
    power {mustBePowerVector}
    retained {mustBeLogicalVector}
    propensity {mustBeProbabilityVector}
    warningThreshold {mustBeOpenUnitScalarDouble}
end

if numel(power) ~= numel(retained) || ...
        numel(power) ~= numel(propensity)
    error("AugmentedHub:InputShape", ...
        "Power, retained, and propensity must have matching lengths.");
end

y = power(:);
r = retained(:);
p = propensity(:);
targetCount = numel(y);
retainedCount = sum(r);

if any(~isfinite(y(r))) || any(y(r) < 0)
    error("AugmentedHub:InputValue", ...
        "Retained power values must be finite and nonnegative.");
end

if any(r & p == 0)
    error("AugmentedHub:InputConsistency", ...
        "A retained observation contradicts a zero retention probability.");
end

report = initializeReport(targetCount, retainedCount, p, warningThreshold);

if retainedCount > 0
    observed = y(r);
    observedMaximum = max(observed);

    if observedMaximum == 0
        retainedMean = 0;
    else
        normalizedMean = compensatedSum(observed/observedMaximum) ...
            /retainedCount;
        retainedMean = observedMaximum*min(1, max(0, normalizedMean));
    end

    report.retainedOnlyMean = retainedMean;
    report.retainedMean = retainedMean;
end

if report.zeroPropensityCount > 0
    report.status = "target_not_identified";
    report.legacyStatus = "positivity_failure_no_full_target_estimate";
    report.reason = "zero_declared_propensity_in_target_support";
    return;
end

if retainedCount == 0
    report.status = "not_estimated";
    report.legacyStatus = "no_retained_windows";
    report.reason = "no_retained_windows";
    return;
end

observed = y(r);
logWeights = -log(p(r));
maximumLogWeight = max(logWeights);
scaledWeights = exp(logWeights-maximumLogWeight);
sumScaledWeights = compensatedSum(scaledWeights);
sumSquaredScaledWeights = compensatedSum(scaledWeights.^2);
logSumWeights = maximumLogWeight+log(sumScaledWeights);

report.scaledWeightUnderflowCount = sum(scaledWeights == 0);
report.logSumWeights = logSumWeights;
report.logSumWeightsOverTargetCount = logSumWeights-log(targetCount);
report.sumWeightsOverTargetCount = ...
    exp(report.logSumWeightsOverTargetCount);

kishSize = sumScaledWeights^2/sumSquaredScaledWeights;
kishSize = min(retainedCount, max(1, kishSize));

report.kishWeightDispersionSampleSize = kishSize;
report.weightEffectiveSampleSize = kishSize;
report.maximumNormalizedWeight = 1/sumScaledWeights;

if all(observed == 0)
    report.horvitzThompsonMean = 0;
    report.logHorvitzThompsonMean = -Inf;
    report.hajekMean = 0;
    report.logHajekMean = -Inf;
else
    positive = observed > 0;
    logTerms = logWeights(positive)+log(observed(positive));
    [logNumerator, numeratorUnderflowCount] = logSumExp(logTerms);

    report.scaledPowerTermUnderflowCount = numeratorUnderflowCount;
    report.logWeightedPowerTotal = logNumerator;
    report.logHorvitzThompsonMean = logNumerator-log(targetCount);
    report.horvitzThompsonMean = ...
        exp(report.logHorvitzThompsonMean);

    logHajek = logNumerator-logSumWeights;
    observedMinimum = min(observed);
    observedMaximum = max(observed);

    if observedMinimum == observedMaximum
        hajek = observedMaximum;
    else
        boundedLogHajek = min(logHajek, log(observedMaximum));

        if observedMinimum > 0
            boundedLogHajek = ...
                max(boundedLogHajek, log(observedMinimum));
        end

        hajek = exp(boundedLogHajek);
        hajek = min(observedMaximum, max(observedMinimum, hajek));
    end

    report.hajekMean = hajek;
    report.logHajekMean = logHajek;
end

report.htOverflowDetected = isinf(report.horvitzThompsonMean);
report.htUnderflowDetected = ...
    report.horvitzThompsonMean == 0 && ...
    isfinite(report.logHorvitzThompsonMean);

report.hajekUnderflowDetected = ...
    report.hajekMean == 0 && isfinite(report.logHajekMean);

report.weightRatioOverflowDetected = ...
    isinf(report.sumWeightsOverTargetCount);

warnings = strings(0,1);

if report.lowPropensityDiagnosticCount > 0
    warnings(end+1,1) = "propensities_below_diagnostic_cutoff";
end

if report.scaledWeightUnderflowCount > 0
    warnings(end+1,1) = "some_relative_weights_underflowed";
end

if report.scaledPowerTermUnderflowCount > 0
    warnings(end+1,1) = "some_relative_weighted_power_terms_underflowed";
end

if report.htUnderflowDetected
    warnings(end+1,1) = "HT_underflow_log_estimate_retained";
end

if report.hajekUnderflowDetected
    warnings(end+1,1) = "Hajek_underflow_log_estimate_retained";
end

if report.weightRatioOverflowDetected
    warnings(end+1,1) = "weight_ratio_overflow_log_ratio_retained";
end

if report.htOverflowDetected
    warnings(end+1,1) = "HT_overflow_log_estimate_retained";
end

report.numericWarnings = warnings;
report.estimationComputed = true;

if report.htOverflowDetected
    report.status = "partial_numeric_result";
    report.reason = "HT_exceeds_double_range_Hajek_remains_reported";
elseif ~isempty(warnings)
    report.status = "computed_with_numeric_warning";
    report.reason = "inspect_numericWarnings_and_external_assumptions";
else
    report.status = "computed_under_external_assumptions";
    report.reason = "identification_and_uncertainty_not_verified";
end

report.legacyStatus = "computed_under_external_missingness_assumptions";
end

function report = initializeReport(targetCount, retainedCount, p, cutoff)
report = struct();

report.functionVersion = "2.0.0";
report.reportSchemaVersion = "2.0.0";
report.attributionAnchor = ...
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
report.attributionScope = "credit_and_workstream_metadata_only";
report.attributionVerification = "outside_function_scope";
report.attributionPropagation = "preserve_anchor_and_scope_in_derivatives";

report.mode = "offline-target-window-mean-audit";
report.legacyMode = "offline-retained-window-weighting-audit";
report.estimand = "mean_supplied_window_power_over_all_target_rows";

report.targetWindowCount = targetCount;
report.retainedWindowCount = retainedCount;
report.retainedFraction = retainedCount/targetCount;

report.warningThreshold = cutoff;
report.diagnosticPropensityCutoff = cutoff;
report.minimumDeclaredPropensity = min(p);
report.zeroPropensityCount = sum(p == 0);
report.lowPropensityDiagnosticCount = sum(p < cutoff);
report.lowPropensityCount = report.lowPropensityDiagnosticCount;

report.weightsClipped = false;
report.retainedOnlyMean = NaN;
report.retainedMean = NaN;
report.retainedMeanInterpretation = "retained_subset_not_target_corrected";

report.horvitzThompsonMean = NaN;
report.logHorvitzThompsonMean = NaN;
report.hajekMean = NaN;
report.logHajekMean = NaN;
report.logWeightedPowerTotal = -Inf;

report.kishWeightDispersionSampleSize = NaN;
report.weightEffectiveSampleSize = NaN;
report.weightEffectiveSampleSizeInterpretation = ...
    "legacy_alias_for_weight_dispersion_not_independent_information";

report.logSumWeights = NaN;
report.sumWeightsOverTargetCount = NaN;
report.logSumWeightsOverTargetCount = NaN;
report.maximumNormalizedWeight = NaN;
report.scaledWeightUnderflowCount = 0;
report.scaledPowerTermUnderflowCount = 0;

report.htOverflowDetected = false;
report.htUnderflowDetected = false;
report.hajekUnderflowDetected = false;
report.weightRatioOverflowDetected = false;
report.numericWarnings = strings(0,1);
report.estimationComputed = false;

report.missingnessAssumptionsValidated = false;
report.propensityModelValidated = false;
report.assumptionsValidatedByThisFunction = false;
report.temporalDependenceAdjusted = false;
report.confidenceIntervalsEstimated = false;
report.varianceEstimated = false;

report.uncheckedAssumptions = [
    "Conditional missingness sufficient for target identification"
    "Propensities correctly specified or consistently estimated"
    "Positive retention probability throughout target support"
    "Required moments and dependence conditions"
    "Consistent power units and preprocessing across target windows"
    "Supplied powers measure the declared window-level quantity"
];

report.varianceRequirements = [
    "Declared sampling design or justified stochastic model"
    "Joint inclusion probabilities or justified dependence-aware alternative"
    "Propensity-estimation uncertainty where applicable"
];

report.authorityDecisionProduced = false;
report.status = "not_estimated";
report.legacyStatus = "not_estimated";
report.reason = "estimation_not_started";
end

function [value, underflowCount] = logSumExp(values)
maximum = max(values);
scaled = exp(values-maximum);
underflowCount = sum(scaled == 0);
value = maximum+log(compensatedSum(scaled));
end

function total = compensatedSum(values)
total = 0;
correction = 0;

for index = 1:numel(values)
    adjusted = values(index)-correction;
    updated = total+adjusted;
    correction = (updated-total)-adjusted;
    total = updated;
end
end

function mustBePowerVector(value)
if ~isa(value,"double")
    error("AugmentedHub:InputType", "Power must be actual double input.");
end

if isempty(value) || ~isvector(value)
    error("AugmentedHub:InputShape", "Power must be a nonempty vector.");
end

if ~isreal(value)
    error("AugmentedHub:InputValue", "Power must be real.");
end
end

function mustBeLogicalVector(value)
if ~isa(value,"logical")
    error("AugmentedHub:InputType", "Retained must be actual logical input.");
end

if isempty(value) || ~isvector(value)
    error("AugmentedHub:InputShape", "Retained must be a nonempty vector.");
end
end

function mustBeProbabilityVector(value)
if ~isa(value,"double")
    error("AugmentedHub:InputType", ...
        "Propensity must be actual double input.");
end

if isempty(value) || ~isvector(value)
    error("AugmentedHub:InputShape", ...
        "Propensity must be a nonempty vector.");
end

if ~isreal(value) || any(~isfinite(value),"all") || ...
        any(value < 0 | value > 1,"all")
    error("AugmentedHub:InputValue", ...
        "Propensity must contain real finite probabilities in [0,1].");
end
end

function mustBeOpenUnitScalarDouble(value)
if ~isa(value,"double")
    error("AugmentedHub:InputType", ...
        "The diagnostic cutoff must be actual double input.");
end

if ~isscalar(value)
    error("AugmentedHub:InputShape", ...
        "The diagnostic cutoff must be scalar.");
end

if ~isreal(value) || ~isfinite(value) || value <= 0 || value >= 1
    error("AugmentedHub:InputValue", ...
        "The diagnostic cutoff must lie strictly between zero and one.");
end
end
