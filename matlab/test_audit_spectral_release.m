function tests = test_audit_spectral_release
% Proposed verification; execution evidence must be recorded separately.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
tests = functiontests(localfunctions);
end

function testOddEvenAndAllMeanPolicies(testCase)
for N = [63,64,255,256]
    fs = 512;
    t = (0:N-1)'/fs;
    x = [sin(2*pi*17*t)+2, cos(2*pi*61*t)-3];

    for policy = ["none","raw","weighted"]
        r = runAudit(x,policy,100,true);
        scale = max(1,abs(r.integratedPSD)+abs(r.taperWeightedMeanSquare));
        verifyLessThanOrEqual(testCase, ...
            abs(r.parsevalResidual)./scale,1e-10*ones(1,2));
        verifyLessThanOrEqual(testCase, ...
            r.normalizationConversionRelativeResidual,1e-10*ones(1,2));
    end
end
end

function testIndependentCoherentNormalization(testCase)
N = 128;
x = [(1:N)'.^2/N^2, sin(2*pi*(0:N-1)'*7/N)];
r = runAudit(x,"raw",100,true);

w = 0.5-0.5*cos(2*pi*(0:N-1)'/N);
centered = x-mean(x,1);
Z = fft(w.*centered,[],1);
expected = abs(Z(1:N/2+1,:)).^2/sum(w)^2;
expected(2:end-1,:) = 2*expected(2:end-1,:);

verifyEqual(testCase,r.coherentNormalizedSpectrum,expected, ...
    "AbsTol",1e-12);
end

function testWeightedPolicyIndependently(testCase)
N = 65;
x = [(1:N)'/N, ((1:N)'/N).^2];
r = runAudit(x,"weighted",100,true);

w = 0.5-0.5*cos(2*pi*(0:N-1)'/N);
expectedMean = (w.'*x)/sum(w);

verifyEqual(testCase,r.removedMeanMicrovolts,expectedMean, ...
    "AbsTol",1e-13);
verifyEqual(testCase,r.processedFrameMicrovolts, ...
    w.*(x-expectedMean),"AbsTol",1e-13);
verifyLessThanOrEqual(testCase, ...
    abs(sum(r.processedFrameMicrovolts,1)),1e-12*ones(1,2));
end

function testNoneRetainsConstantPower(testCase)
x = 3*ones(64,1);
none = runAudit(x,"none",100,false);
raw = runAudit(x,"raw",100,false);

verifyEqual(testCase,none.integratedPSD,9,"AbsTol",1e-12);
verifyGreaterThan(testCase,none.oneSidedPSD(1),0);
verifyEqual(testCase,raw.integratedPSD,0,"AbsTol",1e-14);
verifyFalse(testCase,isfield(none,"processedFrameMicrovolts"));
end

function testRailBoundariesAndExtremes(testCase)
x = [99.999;100;100.0001;-100];
r = runAudit(x,"none",100,false);
verifyEqual(testCase,r.atOrBeyondDeclaredRailCount,3);

positive = [1;2;3;4];
high = runAudit(positive,"none",40,false);
low = runAudit(positive,"none",0.5,false);
verifyEqual(testCase,high.atOrBeyondDeclaredRailCount,0);
verifyEqual(testCase,low.atOrBeyondDeclaredRailCount,4);
end

function testNonAverageReferenceFixture(testCase)
N = 128;
t = (0:N-1)'/512;
x = [sin(2*pi*32*t), 2*cos(2*pi*64*t)];
referenced = x-x(:,1);

original = runAudit(x,"raw",100,false);
changed = runAudit(referenced,"raw",100,false);

verifyGreaterThan(testCase,original.integratedPSD(1),0);
verifyEqual(testCase,changed.integratedPSD(1),0,"AbsTol",1e-14);
verifyGreaterThan(testCase, ...
    norm(original.oneSidedPSD-changed.oneSidedPSD,"fro"),1e-4);
end

function testStrictPolicyAndBudget(testCase)
x = ones(64,1);
verifyError(testCase,@() runAudit(x,"Raw",100,false), ...
    "AugmentedHub:InputValue");
verifyError(testCase,@() runAudit(x," raw ",100,false), ...
    "AugmentedHub:InputValue");

verifyError(testCase,@() audit_spectral_release( ...
    x,512,"raw",100,"channel",1,false), ...
    "AugmentedHub:ResourceBudget");
end

function report = runAudit(x,policy,rail,includeFrames)
names = "channel_"+string((1:size(x,2)).');
report = audit_spectral_release( ...
    x,512,policy,rail,names,64000000,includeFrames);
end
