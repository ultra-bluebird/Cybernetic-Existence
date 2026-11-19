function result = analyze_persistence_wait( ...
    successProbability, runLength, blockSize, ...
    firstEligibleDelaySamples, horizonBlocks)
%ANALYZE_PERSISTENCE_WAIT Exact IID Bernoulli run model.
% States 0:(r-1) represent the current consecutive-success count.
% The absorbing state is completion of r consecutive successes.
% This is an offline mathematical model, not a neural-data detector.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit metadata only; not consent, identity, or operating authority.

if nargin ~= 5
    error("AugmentedHub:ArgumentCount", "Supply exactly five inputs.");
end

inputs = {successProbability, runLength, blockSize, ...
    firstEligibleDelaySamples, horizonBlocks};

for index = 1:numel(inputs)
    value = inputs{index};
    if ~isa(value, "double") || ~isscalar(value) || ...
            ~isreal(value) || ~isfinite(value)
        error("AugmentedHub:StrictScalarDouble", ...
            "Inputs must be actual real finite scalar doubles.");
    end
end

q = successProbability;
r = runLength;
W = blockSize;
rho = firstEligibleDelaySamples;
H = horizonBlocks;

if q < 0 || q > 1
    error("AugmentedHub:InvalidProbability", ...
        "successProbability must lie in [0,1].");
end

counts = [r, W, H];
if any(counts < 1) || any(counts ~= fix(counts)) || ...
        r > 256 || H > 100000 || W > flintmax
    error("AugmentedHub:InvalidCount", ...
        "Use positive integer counts; r<=256 and horizon<=100000.");
end

if rho < 0 || rho > flintmax || W > (flintmax-rho)/H
    error("AugmentedHub:InvalidDelayRange", ...
        "Delay values exceed the supported numerical range.");
end

Q = zeros(r, r);
for state = 1:r
    Q(state, 1) = 1-q;
    if state < r
        Q(state, state+1) = q;
    end
end

conditioning = rcond(eye(r)-Q);
expectedTrials = Inf;
expectedTrialsFormula = Inf;
solutionResidual = NaN;

if q == 1
    expectedTrials = r;
    expectedTrialsFormula = r;
    solutionResidual = 0;
elseif q > 0
    logExpectation = log(-expm1(r*log(q))) ...
        - log1p(-q) - r*log(q);
    expectedTrialsFormula = exp(logExpectation);

    if conditioning > 1e-12
        expectedByState = (eye(r)-Q) \ ones(r,1);
        expectedTrials = expectedByState(1);
        solutionResidual = norm( ...
            (eye(r)-Q)*expectedByState - ones(r,1), Inf);
    else
        expectedTrials = expectedTrialsFormula;
    end
end

transientProbability = zeros(1, r);
transientProbability(1) = 1;
absorption = zeros(r, 1);
absorption(end) = q;
completionCDF = zeros(H, 1);
cumulativeCompletion = 0;

for block = 1:H
    cumulativeCompletion = cumulativeCompletion ...
        + transientProbability*absorption;
    completionCDF(block) = min(1, max(0, cumulativeCompletion));
    transientProbability = transientProbability*Q;
end

expectedDelay = Inf;
if isfinite(expectedTrials)
    expectedDelay = rho + W*(expectedTrials-1);
end

p95Block = find(completionCDF >= 0.95, 1);
p95Delay = NaN;
if ~isempty(p95Block)
    p95Delay = rho + W*(p95Block-1);
end

result = struct();
result.model = "IID-Bernoulli-consecutive-run";
result.expectedTrials = expectedTrials;
result.expectedTrialsFormula = expectedTrialsFormula;
result.expectedDelaySamples = expectedDelay;
result.reciprocalConditionEstimate = conditioning;
result.linearSolveResidual = solutionResidual;
result.p95DelayWithinHorizonSamples = p95Delay;
result.unfinishedProbabilityAtHorizon = sum(transientProbability);
result.completionProbability = table( ...
    (1:H).', completionCDF, ...
    "VariableNames", ["eligibleBlock", "completionCDF"]);
result.deterministicUpperBoundClaimed = false;
result.hardwareControlAvailable = false;
end
