function result = evaluate_binary_calibration( ...
    probability, outcome, stratum, edges, threshold)
%EVALUATE_BINARY_CALIBRATION Descriptive held-out binary calibration.
% probability: declared positive-class probability.
% outcome: actual logical labels for that same declared target.
% stratum: externally supplied, privacy-reviewed evaluation categories.
% edges: increasing bin boundaries beginning at 0 and ending at 1.
% No calibration fitting, confidence intervals, or authorization decisions.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit metadata only; not consent, identity, or execution authority.

arguments
    probability {mustBeA(probability,"double"), mustBeReal, mustBeFinite}
    outcome {mustBeA(outcome,"logical")}
    stratum {mustBeA(stratum,"string")}
    edges {mustBeA(edges,"double"), mustBeReal, mustBeFinite}
    threshold {mustBeA(threshold,"double"), mustBeReal, mustBeFinite}
end

if isempty(probability) || ~isvector(probability) || ...
        ~isvector(outcome) || ~isvector(stratum)
    error("AugmentedHub:Shape", ...
        "Supply nonempty observation vectors.");
end

probability = probability(:);
outcome = outcome(:);
stratum = stratum(:);

if numel(outcome) ~= numel(probability) || ...
        numel(stratum) ~= numel(probability) || ...
        any(ismissing(stratum)) || any(strlength(stratum) == 0)
    error("AugmentedHub:Observations", ...
        "Observation counts must match and strata must be nonmissing.");
end

if any(probability < 0 | probability > 1) || ...
        ~isscalar(threshold) || threshold < 0 || threshold > 1
    error("AugmentedHub:Probability", ...
        "Probabilities and scalar threshold must lie in [0,1].");
end

if ~isvector(edges) || numel(edges) < 2
    error("AugmentedHub:Edges", "Supply at least two bin edges.");
end

edges = edges(:).';
if edges(1) ~= 0 || edges(end) ~= 1 || any(diff(edges) <= 0)
    error("AugmentedHub:Edges", ...
        "Edges must increase strictly from 0 to 1.");
end

groups = unique(stratum, "stable");
summaryRows = cell(numel(groups)+1, 9);
binRows = cell(0, 8);

for groupIndex = 0:numel(groups)
    isAggregate = groupIndex == 0;
    if isAggregate
        selected = true(size(probability));
        groupName = "aggregate";
    else
        groupName = groups(groupIndex);
        selected = stratum == groupName;
    end

    p = probability(selected);
    y = double(outcome(selected));
    prediction = p >= threshold;
    n = numel(p);
    ece = 0;

    for bin = 1:numel(edges)-1
        inBin = p >= edges(bin) & p < edges(bin+1);
        if bin == numel(edges)-1
            inBin = p >= edges(bin) & p <= edges(bin+1);
        end

        count = sum(inBin);
        meanProbability = NaN;
        positiveFraction = NaN;

        if count > 0
            meanProbability = mean(p(inBin));
            positiveFraction = mean(y(inBin));
            ece = ece + count/n * ...
                abs(meanProbability-positiveFraction);
        end

        binRows(end+1,:) = {isAggregate, groupName, bin, ...
            edges(bin), edges(bin+1), count, ...
            meanProbability, positiveFraction}; %#ok<AGROW>
    end

    tp = sum(prediction & y == 1);
    fp = sum(prediction & y == 0);
    fn = sum(~prediction & y == 1);
    tn = sum(~prediction & y == 0);

    sensitivity = NaN;
    specificity = NaN;
    if tp+fn > 0
        sensitivity = tp/(tp+fn);
    end
    if tn+fp > 0
        specificity = tn/(tn+fp);
    end

    summaryRows(groupIndex+1,:) = {isAggregate, groupName, ...
        n, mean(y), mean((p-y).^2), ece, ...
        mean(prediction == y), sensitivity, specificity};
end

result = struct();
result.summary = cell2table(summaryRows, "VariableNames", ...
    ["isAggregate","stratum","count","prevalence","brier", ...
     "ece","accuracy","sensitivity","specificity"]);
result.reliability = cell2table(binRows, "VariableNames", ...
    ["isAggregate","stratum","bin","lower","upper","count", ...
     "meanProbability","positiveFraction"]);
result.threshold = threshold;
result.binEdges = edges;
result.uncertaintyEstimated = false;
result.authorizesOutput = false;
end
