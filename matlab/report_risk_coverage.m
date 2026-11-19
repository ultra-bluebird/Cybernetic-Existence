function report = report_risk_coverage(score, correct, eligible)
%REPORT_RISK_COVERAGE Descriptive threshold curve with intact score ties.
% Each row is a declared evaluation opportunity with a known outcome.
% Larger score means more likely to be accepted.
% Ineligible rows remain in the total-opportunity coverage denominator.
% Eligibility is supplied research policy, not authorization enforcement.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not consent or operating authority.

arguments
    score {mustBeA(score,"double"), mustBeReal}
    correct {mustBeA(correct,"logical")}
    eligible {mustBeA(eligible,"logical")}
end

if isempty(score) || ~isvector(score) || ...
        ~isvector(correct) || ~isvector(eligible) || ...
        numel(score) ~= numel(correct) || ...
        numel(score) ~= numel(eligible)
    error("AugmentedHub:InputShape", ...
        "Supply matching nonempty opportunity vectors.");
end

score = score(:);
correct = correct(:);
eligible = eligible(:);

if any(~isfinite(score(eligible)))
    error("AugmentedHub:InputValue", ...
        "Eligible opportunities must have finite selection scores.");
end

N = numel(score);
M = sum(eligible);

threshold = Inf;
acceptedCount = 0;
errorCount = 0;
coverage = 0;
risk = NaN;
conditionalAccuracy = NaN;
correctAcceptedFraction = 0;

if M > 0
    selectedScores = score(eligible);
    selectedCorrect = correct(eligible);
    [sortedScores,order] = sort(selectedScores,"descend");
    sortedCorrect = selectedCorrect(order);
    cumulativeErrors = cumsum(~sortedCorrect);

    blockEnds = [find(diff(sortedScores) ~= 0); M];
    threshold = [Inf; sortedScores(blockEnds)];
    acceptedCount = [0; blockEnds];
    errorCount = [0; cumulativeErrors(blockEnds)];
    coverage = acceptedCount/N;

    risk = NaN(size(coverage));
    risk(2:end) = errorCount(2:end)./acceptedCount(2:end);
    conditionalAccuracy = 1-risk;
    correctAcceptedFraction = (acceptedCount-errorCount)/N;
end

partialArea = 0;
if M > 0
    partialArea = sum(diff(coverage).*risk(2:end));
end

report = struct();
report.mode = "held-out-descriptive-risk-coverage";
report.totalOpportunityCount = N;
report.eligibleOpportunityCount = M;
report.maximumCoverage = M/N;
report.tiePolicy = "accept complete equal-score blocks";
report.thresholdPolicy = "eligible AND score>=threshold";
report.zeroCoverageRisk = "undefined";
report.partialRiskAreaRightStep = partialArea;
report.areaCoverageRange = [0,M/N];
report.areaConvention = ...
    "Tie-block endpoint risk held constant over each coverage increment.";
report.fullRangeAURCClaimed = false;
report.confidenceIntervalsEstimated = false;
report.thresholdSelectedForDeployment = false;
report.authorityDecisionProduced = false;

report.curve = table( ...
    threshold,acceptedCount,errorCount,coverage,risk, ...
    conditionalAccuracy,correctAcceptedFraction);
end
