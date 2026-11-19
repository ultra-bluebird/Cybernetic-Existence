function report = replay_true_hysteresis( ...
    feature, valid, restart, lowerThreshold, upperThreshold, initialState)
%REPLAY_TRUE_HYSTERESIS Offline two-state, segment-scoped hysteresis.
% Equality: x>=upper enters 1; x<=lower enters 0.
% Invalid rows return NaN and break continuity.
% The next valid row initializes from initialState, then applies thresholds.
% No timestamps, physical actuation, or authorization decisions.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit metadata only; not consent, identity, or operating authority.

arguments
    feature {mustBeA(feature,"double"), mustBeReal}
    valid {mustBeA(valid,"logical")}
    restart {mustBeA(restart,"logical")}
    lowerThreshold {mustBeA(lowerThreshold,"double"), mustBeReal, mustBeFinite}
    upperThreshold {mustBeA(upperThreshold,"double"), mustBeReal, mustBeFinite}
    initialState {mustBeA(initialState,"logical")}
end

if isempty(feature) || ~isvector(feature) || ...
        ~isvector(valid) || ~isvector(restart) || ...
        numel(feature) ~= numel(valid) || ...
        numel(feature) ~= numel(restart)
    error("AugmentedHub:InputShape", ...
        "Supply matching nonempty observation vectors.");
end

if ~isscalar(lowerThreshold) || ~isscalar(upperThreshold) || ...
        lowerThreshold >= upperThreshold || ~isscalar(initialState)
    error("AugmentedHub:InputValue", ...
        "Require ordered scalar thresholds and a scalar logical initial state.");
end

x = feature(:);
valid = valid(:);
restart = restart(:);

if any(~isfinite(x(valid)))
    error("AugmentedHub:InputValue", ...
        "Rows declared valid must contain finite features.");
end

N = numel(x);
state = NaN(N,1);
segmentStart = false(N,1);
transition = false(N,1);
initialized = false;
previous = initialState;

for index = 1:N
    if ~valid(index)
        initialized = false;
        continue;
    end

    starting = ~initialized || restart(index);
    if starting
        previous = initialState;
        segmentStart(index) = true;
    end

    current = previous;
    if x(index) >= upperThreshold
        current = true;
    elseif x(index) <= lowerThreshold
        current = false;
    end

    state(index) = double(current);
    transition(index) = ~starting && current ~= previous;
    previous = current;
    initialized = true;
end

report = struct();
report.mode = "offline-true-hysteresis-replay";
report.lowerThreshold = lowerThreshold;
report.upperThreshold = upperThreshold;
report.bandWidth = upperThreshold-lowerThreshold;
report.initialState = initialState;
report.transitionCount = sum(transition);
report.validFraction = mean(valid);
report.authorizationDecisionProduced = false;
report.observations = table( ...
    x, valid, restart, segmentStart, state, transition);
end
