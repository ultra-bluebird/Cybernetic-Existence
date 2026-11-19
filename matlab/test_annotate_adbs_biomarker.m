function tests = test_annotate_adbs_biomarker
% Tests the existing offline annotator using synthetic research values.
% No neural recordings, device access, networking, or file export.
tests = functiontests(localfunctions);
end

function testExactBoundaryLabels(testCase)
t = [0; 1];
x = [-1; 1];

result = annotate_adbs_biomarker( ...
    t, x, true(2,1), -1, 1, 1, 0.5);

verifyEqual(testCase, result.observations.smoothed, x);
verifyEqual(testCase, result.observations.region, ...
    ["within-band"; "within-band"]);
verifyEqual(testCase, result.segmentCount, 2);
end

function testMissingValueRestartsHistory(testCase)
t = [0; 0.1; 0.2; 0.3];
x = [2; NaN; 8; 8];

result = annotate_adbs_biomarker( ...
    t, x, true(4,1), -1, 1, 1, 0.5);

verifyTrue(testCase, isnan(result.observations.smoothed(2)));
verifyEqual(testCase, result.observations.region(2), "unavailable");
verifyEqual(testCase, result.observations.smoothed(3), 8);
verifyEqual(testCase, result.observations.segmentStart, ...
    [true; false; true; false]);
verifyEqual(testCase, result.usableFraction, 0.75);
end

function testGapRestartsEstimate(testCase)
t = [0; 0.1; 2];
x = [0; 1; 9];

result = annotate_adbs_biomarker( ...
    t, x, true(3,1), -1, 1, 1, 0.5);

verifyEqual(testCase, result.observations.smoothed(3), 9);
verifyEqual(testCase, result.observations.segmentStart, ...
    [true; false; true]);
end

function testAllRowsExcluded(testCase)
t = [0; 0.1; 0.2];

result = annotate_adbs_biomarker( ...
    t, [1; 2; 3], false(3,1), -1, 1, 1, 0.5);

verifyTrue(testCase, all(isnan(result.observations.smoothed)));
verifyEqual(testCase, result.observations.region, ...
    repmat("unavailable", 3, 1));
verifyEqual(testCase, result.usableFraction, 0);
verifyEqual(testCase, result.segmentCount, 0);
end

function testPrefixCausality(testCase)
t = (0:0.1:1).';
x = sin(t);
mask = true(size(t));
prefixLength = 6;

fullResult = annotate_adbs_biomarker( ...
    t, x, mask, -0.5, 0.5, 0.4, 0.5);

prefixResult = annotate_adbs_biomarker( ...
    t(1:prefixLength), x(1:prefixLength), ...
    mask(1:prefixLength), -0.5, 0.5, 0.4, 0.5);

verifyEqual(testCase, ...
    fullResult.observations.smoothed(1:prefixLength), ...
    prefixResult.observations.smoothed, "AbsTol", 1e-12);

verifyEqual(testCase, ...
    fullResult.observations.region(1:prefixLength), ...
    prefixResult.observations.region);
end

function testConvexCombinationProperty(testCase)
t = (0:0.1:4).';
x = 2*sin(3*t) + cos(7*t);

result = annotate_adbs_biomarker( ...
    t, x, true(size(t)), -1, 1, 0.7, 0.5);

y = result.observations.smoothed;

for index = 2:numel(t)
    lowerBound = min(x(index), y(index-1));
    upperBound = max(x(index), y(index-1));

    verifyGreaterThanOrEqual(testCase, ...
        y(index), lowerBound - 1e-12);
    verifyLessThanOrEqual(testCase, ...
        y(index), upperBound + 1e-12);
end
end

function testTranslationProperty(testCase)
t = (0:0.1:1).';
x = sin(t);
offset = 5;

baseline = annotate_adbs_biomarker( ...
    t, x, true(size(t)), -0.5, 0.5, 0.4, 0.5);

shifted = annotate_adbs_biomarker( ...
    t, x + offset, true(size(t)), ...
    -0.5 + offset, 0.5 + offset, 0.4, 0.5);

verifyEqual(testCase, shifted.observations.smoothed, ...
    baseline.observations.smoothed + offset, ...
    "AbsTol", 1e-12);

verifyEqual(testCase, shifted.observations.region, ...
    baseline.observations.region);
end

function testInvalidTimeRejected(testCase)
call = @() annotate_adbs_biomarker( ...
    [0; 0], [1; 2], true(2,1), -1, 1, 1, 0.5);

verifyError(testCase, call, "AugmentedHub:InvalidTime");
end

function testInvalidThresholdsRejected(testCase)
call = @() annotate_adbs_biomarker( ...
    [0; 1], [1; 2], true(2,1), 1, 1, 1, 0.5);

verifyError(testCase, call, "AugmentedHub:InvalidThresholds");
end

function testAnalysisMaskIsNotRedaction(testCase)
result = annotate_adbs_biomarker( ...
    [0; 1], [7; 9], [true; false], -1, 1, 1, 2);

verifyTrue(testCase, ...
    isnan(result.observations.smoothed(2)));

verifyEqual(testCase, result.observations.feature(2), 9);
verifyFalse(testCase, result.hardwareControlAvailable);
end
