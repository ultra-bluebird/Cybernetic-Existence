function test_analyze_persistence_wait()
% Deterministic model checks; no acquisition or external action.

singleSuccess = analyze_persistence_wait(0.5, 1, 64, 10, 20);
assert(abs(singleSuccess.expectedTrials - 2) < 1e-12);
assert(abs(singleSuccess.expectedDelaySamples - 74) < 1e-12);

twoSuccesses = analyze_persistence_wait(0.5, 2, 64, 10, 20);
assert(abs(twoSuccesses.expectedTrials - 6) < 1e-12);
assert(abs(twoSuccesses.expectedTrialsFormula - 6) < 1e-12);
assert(abs(twoSuccesses.completionProbability.completionCDF(2) ...
    - 0.25) < 1e-12);

certain = analyze_persistence_wait(1, 3, 64, 10, 10);
assert(certain.expectedTrials == 3);
assert(certain.expectedDelaySamples == 138);
assert(certain.completionProbability.completionCDF(2) == 0);
assert(certain.completionProbability.completionCDF(3) == 1);

impossible = analyze_persistence_wait(0, 3, 64, 10, 10);
assert(isinf(impossible.expectedTrials));
assert(all(impossible.completionProbability.completionCDF == 0));

cdf = twoSuccesses.completionProbability.completionCDF;
assert(all(diff(cdf) >= -1e-12));
assert(all(cdf >= 0 & cdf <= 1));

rejected = false;
try
    analyze_persistence_wait(single(0.5), 2, 64, 10, 20);
catch exception
    rejected = strcmp(exception.identifier, ...
        "AugmentedHub:StrictScalarDouble");
end
assert(rejected);
end
