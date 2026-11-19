function test_evaluate_brain_spine_decoder()
% Synthetic, non-clinical tests. No hardware or network access.

timeSeconds = [0; 0.1; 0.2; 0.8; 0.9; 1.0];
probabilities = [
    0.90, 0.10
    0.20, 0.80
    0.55, 0.45
    0.10, 0.90
    0.85, 0.15
    0.50, 0.50
];
referenceLabels = [1; 2; 1; 2; 1; 2];
analysisAllowed = [true; true; true; true; false; true];

result = evaluate_brain_spine_decoder( ...
    timeSeconds, probabilities, referenceLabels, ...
    analysisAllowed, 0.75, 0.25);

assert(isequal(result.observations.prediction, [1; 2; 0; 0; 0; 0]));
assert(abs(result.coverage - 2/6) < 1e-12);
assert(result.conditionalAccuracy == 1);
assert(sum(result.confusion, "all") == numel(timeSeconds));
assert(~result.hardwareControlAvailable);

noneAllowed = evaluate_brain_spine_decoder( ...
    timeSeconds, probabilities, referenceLabels, ...
    false(size(timeSeconds)), 0.75, 0.25);

assert(noneAllowed.coverage == 0);
assert(isnan(noneAllowed.conditionalAccuracy));

tieResult = evaluate_brain_spine_decoder( ...
    [0; 0.1], [0.5, 0.5; 0.5, 0.5], ...
    [1; 2], true(2, 1), 0.4, 0.25);

assert(all(tieResult.observations.prediction == 0));

caughtInvalidProbability = false;
try
    evaluate_brain_spine_decoder( ...
        [0; 0.1], [0.8, 0.8; 0.2, 0.8], ...
        [1; 2], true(2, 1), 0.75, 0.25);
catch exception
    caughtInvalidProbability = strcmp( ...
        exception.identifier, "AugmentedHub:InvalidProbabilitySum");
end
assert(caughtInvalidProbability);
end
