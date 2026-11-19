function tests = test_report_binary_forecasts
% Proposed verification suite; execution evidence is generated separately.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
tests = functiontests(localfunctions);
end

function testHandComputedTerms(testCase)
r = report_binary_forecasts( ...
    [0;0.4;0.6;1], [false;true;false;true], [0;0.5;1]);

verifyEqual(testCase,r.brier,0.15,"AbsTol",1e-14);
verifyEqual(testCase,r.binReliability,0.10,"AbsTol",1e-14);
verifyEqual(testCase,r.binResolution,0,"AbsTol",1e-14);
verifyEqual(testCase,r.outcomeUncertainty,0.25,"AbsTol",1e-14);
verifyEqual(testCase,r.withinBinPredictionVariance,0.05,"AbsTol",1e-14);
verifyEqual(testCase,r.normalizedWithinBinCrossTerm,0.125,"AbsTol",1e-14);
verifyTrue(testCase,r.numericalIdentityCheckPassed);

wrongSign = r.binReliability-r.binResolution+r.outcomeUncertainty ...
    +r.withinBinPredictionVariance+2*r.normalizedWithinBinCrossTerm;
wrongCoefficient = r.binReliability-r.binResolution ...
    +r.outcomeUncertainty+r.withinBinPredictionVariance ...
    +r.normalizedWithinBinCrossTerm;

verifyGreaterThan(testCase,abs(r.brier-wrongSign),0.1);
verifyGreaterThan(testCase,abs(r.brier-wrongCoefficient),0.1);
end

function testBinningChangesComponentsNotScore(testCase)
p = [0;0.4;0.6;1];
y = [false;true;false;true];
a = report_binary_forecasts(p,y,[0;1]);
b = report_binary_forecasts(p,y,[0;0.2;0.5;0.8;1]);

verifyEqual(testCase,a.brier,b.brier,"AbsTol",1e-14);
verifyNotEqual(testCase,a.binReliability,b.binReliability);
verifyNotEqual(testCase, ...
    a.withinBinPredictionVariance,b.withinBinPredictionVariance);
verifyTrue(testCase,a.numericalIdentityCheckPassed);
verifyTrue(testCase,b.numericalIdentityCheckPassed);
end

function testEndpointsSingletonAndSingleClass(testCase)
perfect = report_binary_forecasts([0;1],[false;true],[0;0.5;1]);
verifyEqual(testCase,perfect.logLoss,0);

wrong = report_binary_forecasts([0;1],[true;false],[0;1]);
verifyTrue(testCase,isinf(wrong.logLoss));
verifyEqual(testCase,wrong.zeroProbabilityErrors,2);

singleRow = report_binary_forecasts(0.25,false,[0;1]);
verifyEqual(testCase,singleRow.brier,0.0625);

allPositive = report_binary_forecasts([0.2;0.8],[true;true],[0;1]);
allNegative = report_binary_forecasts([0.2;0.8],[false;false],[0;1]);
verifyEqual(testCase,allPositive.outcomeUncertainty,0);
verifyEqual(testCase,allNegative.outcomeUncertainty,0);
end

function testEmptyBinAndFinalEndpoint(testCase)
r = report_binary_forecasts([0;1],[false;true],[0;0.2;0.8;1]);
verifyEqual(testCase,r.bins.count,[1;0;1]);
verifyTrue(testCase,isnan(r.bins.meanProbability(2)));
verifyEqual(testCase,sum(r.bins.count),2);
end

function testInputRejections(testCase)
verifyError(testCase,@() report_binary_forecasts( ...
    [],false,[0;1]),"AugmentedHub:InputShape");
verifyError(testCase,@() report_binary_forecasts( ...
    [0.1;0.2],true,[0;1]),"AugmentedHub:InputConsistency");
verifyError(testCase,@() report_binary_forecasts( ...
    1.1,true,[0;1]),"AugmentedHub:InputValue");
verifyError(testCase,@() report_binary_forecasts( ...
    single(0.5),true,[0;1]),"AugmentedHub:InputType");

invalidEdges = {[0.1;1],[0;0.9],[0;0.5;0.5;1],[0;0.7;0.3;1]};
for index = 1:numel(invalidEdges)
    verifyError(testCase,@() report_binary_forecasts( ...
        0.5,true,invalidEdges{index}),"AugmentedHub:InputValue");
end
end

function testSeededCrossMomentBound(testCase)
previous = rng;
restore = onCleanup(@() rng(previous)); %#ok<NASGU>
rng(1729,"twister");

p = rand(5000,1);
y = rand(5000,1) > 0.7;
r = report_binary_forecasts(p,y,linspace(0,1,17));

bound = sqrt(r.withinBinPredictionVariance ...
    *r.withinBinOutcomeVariance);

verifyLessThanOrEqual(testCase, ...
    abs(r.normalizedWithinBinCrossTerm),bound+1e-14);
verifyTrue(testCase,r.numericalIdentityCheckPassed);
end
