function result = evaluate_brain_spine_decoder( ...
    timeSeconds, probabilities, referenceLabels, ...
    analysisAllowed, minimumConfidence, maximumGapSeconds)
%EVALUATE_BRAIN_SPINE_DECODER Offline classification evaluation.
% Rows are observations; columns are explicitly documented classes.
% Reference labels are integers 1:K. Prediction 0 means abstention.
% analysisAllowed authorizes evaluation, not physical device operation.
% The first row after an excessive timestamp gap is rejected.
% This function performs no acquisition, networking, or stimulation.

arguments
    timeSeconds (:,1) double
    probabilities (:,:) double
    referenceLabels (:,1) double
    analysisAllowed (:,1) logical
    minimumConfidence (1,1) double ...
        {mustBeFinite, mustBeGreaterThanOrEqual( ...
        minimumConfidence, 0), ...
        mustBeLessThanOrEqual(minimumConfidence, 1)}
    maximumGapSeconds (1,1) double ...
        {mustBeFinite, mustBePositive}
end

sampleCount = numel(timeSeconds);
classCount = size(probabilities, 2);

if sampleCount < 2 || classCount < 2
    error("AugmentedHub:InsufficientData", ...
        "Supply at least two observations and two classes.");
end

if size(probabilities, 1) ~= sampleCount || ...
        numel(referenceLabels) ~= sampleCount || ...
        numel(analysisAllowed) ~= sampleCount
    error("AugmentedHub:DimensionMismatch", ...
        "All observation dimensions must match.");
end

if any(~isfinite(timeSeconds)) || any(diff(timeSeconds) <= 0)
    error("AugmentedHub:InvalidTime", ...
        "Timestamps must be finite and strictly increasing.");
end

if any(~isfinite(probabilities), "all") || ...
        any(probabilities < 0, "all") || ...
        any(probabilities > 1, "all")
    error("AugmentedHub:InvalidProbability", ...
        "Probabilities must be finite and within [0, 1].");
end

rowSums = sum(probabilities, 2);
if any(abs(rowSums - 1) > 1e-8)
    error("AugmentedHub:InvalidProbabilitySum", ...
        "Each probability row must sum to one.");
end

if any(~isfinite(referenceLabels)) || ...
        any(referenceLabels ~= fix(referenceLabels)) || ...
        any(referenceLabels < 1) || ...
        any(referenceLabels > classCount)
    error("AugmentedHub:InvalidReference", ...
        "Reference labels must be integers from 1 through K.");
end

[confidence, rawPrediction] = max(probabilities, [], 2);
tieCount = sum(probabilities == confidence, 2);
uniqueMaximum = tieCount == 1;

gapRejected = [false; diff(timeSeconds) > maximumGapSeconds];

accepted = analysisAllowed & ...
    confidence >= minimumConfidence & ...
    uniqueMaximum & ~gapRejected;

prediction = zeros(sampleCount, 1);
prediction(accepted) = rawPrediction(accepted);

confusion = accumarray( ...
    [referenceLabels, prediction + 1], ...
    ones(sampleCount, 1), ...
    [classCount, classCount + 1]);

acceptedCount = sum(accepted);
correct = accepted & prediction == referenceLabels;

conditionalAccuracy = NaN;
if acceptedCount > 0
    conditionalAccuracy = sum(correct) / acceptedCount;
end

perClassRecallIncludingAbstention = NaN(classCount, 1);
for classIndex = 1:classCount
    classRows = referenceLabels == classIndex;
    if any(classRows)
        perClassRecallIncludingAbstention(classIndex) = ...
            sum(correct & classRows) / sum(classRows);
    end
end

result = struct();
result.mode = "offline-evaluation-only";
result.hardwareControlAvailable = false;
result.sampleCount = sampleCount;
result.classCount = classCount;
result.coverage = acceptedCount / sampleCount;
result.conditionalAccuracy = conditionalAccuracy;
result.correctFractionAllRows = sum(correct) / sampleCount;
result.perClassRecallIncludingAbstention = ...
    perClassRecallIncludingAbstention;
result.confusion = confusion;
result.confusionColumnLabels = ["abstain", string(1:classCount)];
result.observations = table( ...
    timeSeconds, referenceLabels, rawPrediction, prediction, ...
    confidence, analysisAllowed, gapRejected, uniqueMaximum, accepted);
end
