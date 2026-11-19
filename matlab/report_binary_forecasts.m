function report = report_binary_forecasts(probability, outcome, edges)
%REPORT_BINARY_FORECASTS Descriptive scores and exact bin accounting.
% Error categories:
% AugmentedHub:InputType, InputShape, InputValue, InputConsistency.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit metadata only; not consent, identity, or operating authority.
%
% Proposed MATLAB target: R2024b. Not validated by this source file.

arguments
    probability {mustBeDoubleVector}
    outcome {mustBeLogicalVector}
    edges {mustBeDoubleVector}
end

if numel(probability) ~= numel(outcome)
    error("AugmentedHub:InputConsistency", ...
        "Forecast and outcome counts must match.");
end

p = probability(:);
y = double(outcome(:));
edges = edges(:);

if any(p < 0 | p > 1)
    error("AugmentedHub:InputValue", ...
        "Forecast probabilities must lie in [0,1].");
end

if numel(edges) < 2 || edges(1) ~= 0 || edges(end) ~= 1 || ...
        any(diff(edges) <= 0)
    error("AugmentedHub:InputValue", ...
        "Edges must increase strictly from 0 to 1.");
end

N = numel(p);
B = numel(edges)-1;
bin = discretize(p, edges, "IncludedEdge", "left");

count = accumarray(bin, ones(N,1), [B,1], @sum, 0);
sumP = accumarray(bin, p, [B,1], @sum, 0);
sumY = accumarray(bin, y, [B,1], @sum, 0);

meanP = NaN(B,1);
meanY = NaN(B,1);
occupied = count > 0;
meanP(occupied) = sumP(occupied)./count(occupied);
meanY(occupied) = sumY(occupied)./count(occupied);

prevalence = mean(y);
weight = count(occupied)/N;

binReliability = compensatedSum( ...
    weight.*(meanP(occupied)-meanY(occupied)).^2);

binResolution = compensatedSum( ...
    weight.*(meanY(occupied)-prevalence).^2);

ece = compensatedSum( ...
    weight.*abs(meanP(occupied)-meanY(occupied)));

dp = p-meanP(bin);
dy = y-meanY(bin);

withinPredictionVariance = compensatedSum(dp.^2)/N;
withinOutcomeVariance = compensatedSum(dy.^2)/N;
withinCrossTerm = compensatedSum(dp.*dy)/N;

uncertainty = prevalence*(1-prevalence);
brier = compensatedSum((p-y).^2)/N;

signedTerms = [binReliability; -binResolution; uncertainty; ...
    withinPredictionVariance; -2*withinCrossTerm];

reconstructed = compensatedSum(signedTerms);
residual = brier-reconstructed;

scale = max(1, abs(brier)+sum(abs(signedTerms)));
tolerance = 128*eps*max(1,ceil(log2(N+1)))*scale;

positive = outcome(:);
logLossSum = compensatedSum(-log(p(positive))) + ...
    compensatedSum(-log1p(-p(~positive)));

report = struct();
report.count = N;
report.prevalence = prevalence;
report.brier = brier;
report.logLoss = logLossSum/N;
report.logLossUnits = "nats";
report.zeroProbabilityErrors = ...
    sum(p(positive) == 0)+sum(p(~positive) == 1);
report.ece = ece;

report.binReliability = binReliability;
report.binResolution = binResolution;
report.outcomeUncertainty = uncertainty;
report.withinBinPredictionVariance = withinPredictionVariance;
report.withinBinOutcomeVariance = withinOutcomeVariance;
report.normalizedWithinBinCrossTerm = withinCrossTerm;

report.reconstructedBrier = reconstructed;
report.decompositionResidual = residual;
report.residualTolerance = tolerance;
report.numericalIdentityCheckPassed = abs(residual) <= tolerance;

report.populationCalibrationEstimatedExactly = false;
report.uncertaintyIntervalsEstimated = false;
report.authorityDecisionProduced = false;
report.binConvention = "left-inclusive; final bin includes 1";

report.bins = table( ...
    edges(1:end-1), edges(2:end), count, meanP, meanY, ...
    "VariableNames", ["lower","upper","count", ...
    "meanProbability","positiveFraction"]);
end

function total = compensatedSum(values)
% Nonnegative infinity is permitted for unbounded log loss.
if any(isinf(values))
    total = sum(values);
    return;
end
total = 0;
correction = 0;
for index = 1:numel(values)
    adjusted = values(index)-correction;
    updated = total+adjusted;
    correction = (updated-total)-adjusted;
    total = updated;
end
end

function mustBeDoubleVector(value)
if ~isa(value,"double")
    error("AugmentedHub:InputType", "Require actual double input.");
end
if isempty(value) || ~isvector(value)
    error("AugmentedHub:InputShape", "Require a nonempty vector.");
end
if ~isreal(value) || any(~isfinite(value),"all")
    error("AugmentedHub:InputValue", "Require real finite values.");
end
end

function mustBeLogicalVector(value)
if ~isa(value,"logical")
    error("AugmentedHub:InputType", "Require actual logical outcomes.");
end
if isempty(value) || ~isvector(value)
    error("AugmentedHub:InputShape", "Require a nonempty vector.");
end
end
