function report = analyze_panel_ctmc_bridge( ...
    generator, startState, endState, durationSeconds, gridCount)
%ANALYZE_PANEL_CTMC_BRIDGE Conditional analysis for a specified CTMC.
% Generator units: inverse seconds. Time grid: seconds since first snapshot.
% First departure may be followed by additional transitions.
% This function does not estimate generator parameters from observations.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not consent or operating authority.

arguments
    generator {mustBeA(generator,"double"), mustBeReal, mustBeFinite}
    startState {mustBePositiveIntegerDouble}
    endState {mustBePositiveIntegerDouble}
    durationSeconds {mustBePositiveScalarDouble}
    gridCount {mustBePositiveIntegerDouble}
end

[K,L] = size(generator);
if isempty(generator) || K ~= L || K > 32
    error("AugmentedHub:InputShape", ...
        "Supply a square generator with 1 through 32 states.");
end

if startState > K || endState > K || ...
        gridCount < 3 || gridCount > 10001
    error("AugmentedHub:InputValue", ...
        "State positions must exist; gridCount must be 3 through 10001.");
end

Q = generator;
offDiagonal = Q;
offDiagonal(1:K+1:end) = 0;

tolerance = 1e-12*max(1,norm(Q,Inf));
rowResidual = max(abs(sum(Q,2)));

if any(offDiagonal < 0,"all") || any(diag(Q) > 0) || ...
        rowResidual > tolerance
    error("AugmentedHub:Generator", ...
        "Require nonnegative off-diagonals and approximately zero row sums.");
end

T = durationSeconds;
P = expm(Q*T);
endpointProbability = P(startState,endState);

if ~isfinite(endpointProbability) || endpointProbability <= 0
    error("AugmentedHub:ConditioningEvent", ...
        "The supplied endpoint event has no positive computed probability.");
end

time = linspace(0,T,gridCount).';
bridge = zeros(gridCount,K);
firstDeparture = zeros(gridCount,K);

for index = 1:gridCount
    u = time(index);
    left = expm(Q*u);
    right = expm(Q*(T-u));

    bridge(index,:) = ...
        left(startState,:).*right(:,endState).' / endpointProbability;

    survivalBeforeDeparture = exp(Q(startState,startState)*u);

    for nextState = 1:K
        if nextState ~= startState
            firstDeparture(index,nextState) = ...
                survivalBeforeDeparture * Q(startState,nextState) ...
                * right(nextState,endState) / endpointProbability;
        end
    end
end

noJumpProbability = 0;
if startState == endState
    noJumpProbability = ...
        exp(Q(startState,startState)*T)/endpointProbability;
end

departureMassByNextState = trapz(time,firstDeparture,1);
totalDepartureMass = sum(departureMassByNextState);

report = struct();
report.mode = "specified-model-panel-CTMC-bridge";
report.generatorPerSecond = Q;
report.generatorRowSumResidual = rowResidual;
report.generatorValidationTolerance = tolerance;
report.generatorEstimatedFromData = false;
report.endpointProbability = endpointProbability;
report.noJumpProbability = noJumpProbability;
report.departureMassByNextState = departureMassByNextState;
report.integratedDepartureMass = totalDepartureMass;
report.quadratureMassResidual = ...
    totalDepartureMass + noJumpProbability - 1;
report.maximumBridgeRowSumResidual = max(abs(sum(bridge,2)-1));
report.minimumBridgeProbability = min(bridge,[],"all");
report.minimumDepartureDensity = min(firstDeparture,[],"all");
report.timeSinceFirstSnapshotSeconds = time;
report.conditionalStateProbabilities = bridge;
report.firstDepartureSubdensityPerSecond = firstDeparture;
report.hiddenTransitionsDirectlyObserved = false;
report.inputAuthenticityVerified = false;
report.numericalValuesClippedOrRenormalized = false;
end

function mustBePositiveScalarDouble(value)
if ~isa(value,"double") || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(value) || value <= 0
    error("AugmentedHub:InputValue", ...
        "Require an actual positive finite scalar double.");
end
end

function mustBePositiveIntegerDouble(value)
mustBePositiveScalarDouble(value);
if value ~= fix(value) || value > flintmax
    error("AugmentedHub:InputValue", ...
        "Require an exactly representable positive integer double.");
end
end
