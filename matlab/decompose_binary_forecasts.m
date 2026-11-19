function result = decompose_binary_forecasts(probability, outcome, edges)
%DECOMPOSE_BINARY_FORECASTS Exact finite-sample binned decomposition.
% Inputs are supplied held-out predictions and matching binary outcomes.
% No calibration fitting, deployment guarantee, or authorization decision.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit metadata only; not consent, identity, or operating authority.

arguments
    probability {mustBeA(probability,"double"), mustBeReal, mustBeFinite}
    outcome {mustBeA(outcome,"logical")}
    edges {mustBeA(edges,"double"), mustBeReal, mustBeFinite}
end

if isempty(probability) || ~isvector(probability) || ...
        ~isvector(outcome) || numel(probability) ~= numel(outcome)
    error("AugmentedHub:Observations", ...
        "Supply matching nonempty prediction and logical-outcome vectors.");
end

if ~isvector(edges) || numel(edges) < 2
    error("AugmentedHub:Edges", "Supply at least two bin edges.");
end

p = probability(:);
y = double(outcome(:));
edges = edges(:);

if any(p < 0 | p > 1) || edges(1) ~= 0 || ...
        edges(end) ~= 1 || any(diff(edges) <= 0)
    error("AugmentedHub:ProbabilityRange", ...
        "Probabilities must lie in [0,1]; edges must increase from 0 to 1.");
end

N = numel(p);
B = numel(edges)-1;
prevalence = mean(y);

count = zeros(B,1);
meanProbability = NaN(B,1);
positiveFraction = NaN(B,1);
reliability = 0;
resolution = 0;
withinVariance = 0;
withinCovariance = 0;
ece = 0;

for bin = 1:B
    selected = p >= edges(bin) & p < edges(bin+1);
    if bin == B
        selected = p >= edges(bin) & p <= edges(bin+1);
    end

    count(bin) = sum(selected);
    if count(bin) == 0
        continue;
    end

    pb = p(selected);
    yb = y(selected);
    mp = mean(pb);
    my = mean(yb);
    weight = count(bin)/N;

    meanProbability(bin) = mp;
    positiveFraction(bin) = my;

    reliability = reliability + weight*(mp-my)^2;
    resolution = resolution + weight*(my-prevalence)^2;
    withinVariance = withinVariance + sum((pb-mp).^2)/N;
    withinCovariance = withinCovariance ...
        + sum((pb-mp).*(yb-my))/N;
    ece = ece + weight*abs(mp-my);
end

uncertainty = prevalence*(1-prevalence);
brier = mean((p-y).^2);
reconstructed = reliability-resolution+uncertainty ...
    + withinVariance-2*withinCovariance;

trueClassProbability = p;
negative = y == 0;
trueClassProbability(negative) = 1-p(negative);
logLossTerms = -log(trueClassProbability);

result = struct();
result.count = N;
result.prevalence = prevalence;
result.brier = brier;
result.logLoss = mean(logLossTerms);
result.infiniteLogLossCount = sum(isinf(logLossTerms));
result.ece = ece;
result.reliability = reliability;
result.resolution = resolution;
result.uncertainty = uncertainty;
result.withinBinVariance = withinVariance;
result.withinBinCovariance = withinCovariance;
result.reconstructedBrier = reconstructed;
result.decompositionResidual = brier-reconstructed;
result.uncertaintyEstimated = false;
result.authorizesOutput = false;

result.bins = table( ...
    edges(1:end-1), edges(2:end), count, ...
    meanProbability, positiveFraction, ...
    "VariableNames", ["lower","upper","count", ...
    "meanProbability","positiveFraction"]);
end
