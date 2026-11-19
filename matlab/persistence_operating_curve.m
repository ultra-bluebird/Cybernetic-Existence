function result = persistence_operating_curve( ...
    q, r, W, rho, H, memoryBudgetBytes, updateBudget)
%PERSISTENCE_OPERATING_CURVE Offline IID consecutive-success model.
% q: vector of exceedance probabilities.
% r: required consecutive successes.
% W: observations per block.
% rho: distance to first eligible block completion, in [0,W].
% H: number of eligible blocks evaluated.
% Budgets are explicit project limits, not numerical validity thresholds.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit metadata only; not consent, identity, or operating authority.

arguments
    q {mustBeProbabilityVector}
    r {mustBePositiveIntegerDouble}
    W {mustBePositiveIntegerDouble}
    rho {mustBeNonnegativeScalarDouble}
    H {mustBePositiveIntegerDouble}
    memoryBudgetBytes {mustBePositiveIntegerDouble} = 64000000
    updateBudget {mustBePositiveIntegerDouble} = 100000000
end

q = q(:);
K = numel(q);

if rho > W
    error("AugmentedHub:InvalidPhase", "Require 0 <= rho <= W.");
end

if W > (flintmax-rho)/H
    error("AugmentedHub:DelayRange", ...
        "Requested sample-distance arithmetic exceeds the supported range.");
end

% Conservative estimate of numerical array storage, not total MATLAB RSS.
estimatedArrayBytes = 8*(3*r + 20*K);
if estimatedArrayBytes > memoryBudgetBytes
    error("AugmentedHub:MemoryBudget", ...
        "Estimated numerical array storage exceeds the declared budget.");
end

if r > updateBudget/K/H
    error("AugmentedHub:UpdateBudget", ...
        "K*H*r exceeds the declared state-update budget.");
end

completion = zeros(K,1);
expectedTrials = zeros(K,1);
logExpectedTrials = zeros(K,1);
restrictedTrials = zeros(K,1);
p95Delay = NaN(K,1);
massError = zeros(K,1);

for index = 1:K
    probability = q(index);

    if probability == 0
        expectedTrials(index) = Inf;
        logExpectedTrials(index) = Inf;
        restrictedTrials(index) = H;
        continue;
    end

    if probability == 1
        expectedTrials(index) = r;
        logExpectedTrials(index) = log(r);
        completion(index) = double(H >= r);
        restrictedTrials(index) = min(r,H);
        if H >= r
            p95Delay(index) = rho + W*(r-1);
        end
        continue;
    end

    logMean = log(-expm1(r*log(probability))) ...
        - log1p(-probability) - r*log(probability);

    logExpectedTrials(index) = logMean;
    expectedTrials(index) = exp(logMean);

    state = zeros(1,r);
    state(1) = 1;
    cumulative = 0;
    restricted = 0;
    p95Block = NaN;

    for block = 1:H
        survivalBefore = sum(state);
        restricted = restricted + survivalBefore;

        cumulative = cumulative + probability*state(end);

        next = zeros(1,r);
        next(1) = (1-probability)*survivalBefore;
        if r > 1
            next(2:end) = probability*state(1:end-1);
        end
        state = next;

        if isnan(p95Block) && cumulative >= 0.95
            p95Block = block;
        end
    end

    completion(index) = cumulative;
    restrictedTrials(index) = restricted;
    massError(index) = abs(cumulative + sum(state) - 1);

    if ~isnan(p95Block)
        p95Delay(index) = rho + W*(p95Block-1);
    end
end

expectedDelay = rho + W*(expectedTrials-1);
meanOverflow = isinf(expectedTrials) & q > 0;
outsideProbabilityRange = completion < 0 | completion > 1;

result = struct();
result.mode = "offline-IID-persistence-operating-curve";
result.pathUsed = "structured-run-state-update-with-analytic-mean";
result.complexity = "O(K*H*r) time; O(r+K) numerical storage";
result.estimatedArrayBytes = estimatedArrayBytes;
result.arrayMemoryBudgetBytes = memoryBudgetBytes;
result.stateUpdateBudget = updateBudget;
result.assumedIndependentBlocks = true;
result.assumedConstantProbabilityWithinEachRun = true;
result.phaseConvention = ...
    "rho is distance to the first eligible completion, including endpoints.";
result.restrictedMeanDefinition = "E[min(T_r,H)] in eligible blocks";
result.unconditionalFiniteDelayGuaranteeClaimed = false;
result.hardwareControlAvailable = false;

result.operatingCurve = table( ...
    q, completion, expectedTrials, logExpectedTrials, expectedDelay, ...
    restrictedTrials, p95Delay, meanOverflow, massError, ...
    outsideProbabilityRange);
end

function mustBeProbabilityVector(value)
if ~isa(value,"double") || ~isreal(value) || ...
        isempty(value) || ~isvector(value) || ...
        any(~isfinite(value),"all") || ...
        any(value < 0 | value > 1,"all")
    error("AugmentedHub:ProbabilityVector", ...
        "q must be a nonempty real finite double vector in [0,1].");
end
end

function mustBeNonnegativeScalarDouble(value)
if ~isa(value,"double") || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(value) || ...
        value < 0 || value > flintmax
    error("AugmentedHub:ScalarDouble", ...
        "Require an actual finite nonnegative scalar double <= flintmax.");
end
end

function mustBePositiveIntegerDouble(value)
mustBeNonnegativeScalarDouble(value);
if value < 1 || value ~= fix(value)
    error("AugmentedHub:PositiveIntegerDouble", ...
        "Require a positive integer-valued scalar double.");
end
end
