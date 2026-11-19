function tests = test_audit_retained_power_weighting
% Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only.
tests = functiontests(localfunctions);
end

function testWeightedFixture(testCase)
r = audit_retained_power_weighting( ...
    [1;1;NaN;3], [true;true;false;true], ...
    [1;1;0.5;0.5], 0.1);

verifyEqual(testCase,r.retainedOnlyMean,5/3,"AbsTol",1e-12);
verifyEqual(testCase,r.horvitzThompsonMean,2,"AbsTol",1e-12);
verifyEqual(testCase,r.hajekMean,2,"AbsTol",1e-12);
verifyEqual(testCase,r.kishWeightDispersionSampleSize,8/3, ...
    "AbsTol",1e-12);
verifyTrue(testCase,r.estimationComputed);
end

function testCompatibilityAliases(testCase)
r = audit_retained_power_weighting([1;2;3],true(3,1),ones(3,1),0.1);

verifyEqual(testCase,r.retainedMean,r.retainedOnlyMean);
verifyEqual(testCase,r.lowPropensityCount,r.lowPropensityDiagnosticCount);
verifyEqual(testCase,r.weightEffectiveSampleSize, ...
    r.kishWeightDispersionSampleSize);
verifyEqual(testCase,r.horvitzThompsonMean,2,"AbsTol",1e-12);
verifyEqual(testCase,r.hajekMean,2,"AbsTol",1e-12);
end

function testSupportAndEmptyRetention(testCase)
blocked = audit_retained_power_weighting( ...
    [1;NaN],[true;false],[1;0],0.1);

verifyEqual(testCase,blocked.status,"target_not_identified");
verifyEqual(testCase,blocked.legacyStatus, ...
    "positivity_failure_no_full_target_estimate");
verifyTrue(testCase,isnan(blocked.horvitzThompsonMean));
verifyEqual(testCase,blocked.retainedOnlyMean,1);

none = audit_retained_power_weighting( ...
    [NaN;NaN],false(2,1),[0.5;0.5],0.1);

verifyEqual(testCase,none.reason,"no_retained_windows");
verifyFalse(testCase,none.estimationComputed);
end

function testScalarAndZeroPower(testCase)
scalar = audit_retained_power_weighting(2,true,1,0.1);
verifyEqual(testCase,scalar.hajekMean,2);

zero = audit_retained_power_weighting(0,true,0.5,0.1);
verifyEqual(testCase,zero.horvitzThompsonMean,0);
verifyEqual(testCase,zero.hajekMean,0);
verifyEqual(testCase,zero.logHorvitzThompsonMean,-Inf);
end

function testExtremeWeights(testCase)
extreme = audit_retained_power_weighting(1,true,realmin/4,0.1);

verifyEqual(testCase,extreme.hajekMean,1);
verifyTrue(testCase,isfinite(extreme.logHorvitzThompsonMean));
verifyTrue(testCase,isinf(extreme.horvitzThompsonMean));
verifyEqual(testCase,extreme.status,"partial_numeric_result");
end

function testZeroOutcomeAtLargestWeight(testCase)
r = audit_retained_power_weighting( ...
    [0;realmax],[true;true],[realmin/4;1],0.1);

verifyTrue(testCase,isfinite(r.hajekMean));
verifyGreaterThan(testCase,r.hajekMean,0);
verifyTrue(testCase,isfinite(r.horvitzThompsonMean));
verifyTrue(testCase,isfinite(r.logHajekMean));
end

function testInputRejections(testCase)
verifyError(testCase,@() audit_retained_power_weighting( ...
    1,true,0,0.1),"AugmentedHub:InputConsistency");

verifyError(testCase,@() audit_retained_power_weighting( ...
    single(1),true,1,0.1),"AugmentedHub:InputType");

verifyError(testCase,@() audit_retained_power_weighting( ...
    [1;2],true,1,0.1),"AugmentedHub:InputShape");

verifyError(testCase,@() audit_retained_power_weighting( ...
    -1,true,1,0.1),"AugmentedHub:InputValue");

verifyError(testCase,@() audit_retained_power_weighting( ...
    1,true,1,1),"AugmentedHub:InputValue");
end
