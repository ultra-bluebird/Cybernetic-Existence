function report = replay_continuity_contract( ...
    timeSeconds, signals, primaryDependencies, dependencyNames, ...
    maximumGapSeconds, minimumDwellSeconds)
%REPLAY_CONTINUITY_CONTRACT Offline snapshot-based continuity prototype.
% signals columns are complete logical observations:
% decoderReady, primaryAuthorized, localHealthy, localAuthorized,
% pauseRequested, selectPrimary, assistanceReachable,
% assistanceRequested, assistanceAcknowledged, communicationConfirmed.
%
% primaryDependencies: N-by-D logical observations.
% dependencyNames: D distinct declared dependency names.
% No actuation, request submission, physiological inference, or authentication.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; verification is outside this prototype.

arguments
    timeSeconds {mustBeA(timeSeconds,"double"), mustBeReal, mustBeFinite}
    signals {mustBeA(signals,"table")}
    primaryDependencies {mustBeA(primaryDependencies,"logical")}
    dependencyNames {mustBeA(dependencyNames,"string")}
    maximumGapSeconds {mustBePositiveScalarDouble}
    minimumDwellSeconds {mustBeNonnegativeScalarDouble}
end

required = ["decoderReady","primaryAuthorized", ...
    "localHealthy","localAuthorized","pauseRequested","selectPrimary", ...
    "assistanceReachable","assistanceRequested", ...
    "assistanceAcknowledged","communicationConfirmed"];

if isempty(timeSeconds) || ~isvector(timeSeconds)
    error("AugmentedHub:InputShape", ...
        "Supply a nonempty timestamp vector.");
end

t = timeSeconds(:);
N = numel(t);

if any(diff(t) <= 0)
    error("AugmentedHub:InputValue", ...
        "Timestamps must be strictly increasing.");
end

if height(signals) ~= N || ...
        ~all(ismember(required,string(signals.Properties.VariableNames)))
    error("AugmentedHub:InputConsistency", ...
        "Signal rows and required columns must match the contract.");
end

for name = required
    column = signals.(char(name));
    if ~isa(column,"logical") || ~isequal(size(column),[N,1])
        error("AugmentedHub:InputType", ...
            "Required signals must be logical column vectors.");
    end
end

if ~ismatrix(primaryDependencies) || ...
        size(primaryDependencies,1) ~= N || ...
        isempty(dependencyNames) || ~isvector(dependencyNames) || ...
        numel(dependencyNames) ~= size(primaryDependencies,2)
    error("AugmentedHub:InputConsistency", ...
        "Supply matching dependency observations and names.");
end

names = dependencyNames(:);
if any(ismissing(names)) || any(strlength(names) == 0) || ...
        numel(unique(names)) ~= numel(names)
    error("AugmentedHub:InputValue", ...
        "Dependency names must be nonempty, nonmissing, and unique.");
end

if any(signals.assistanceAcknowledged & ~signals.assistanceRequested)
    error("AugmentedHub:InputConsistency", ...
        "Acknowledgment requires a supplied request observation.");
end

gap = [NaN; diff(t)];
segmentStart = [true; diff(t) > maximumGapSeconds];
segment = cumsum(segmentStart);

primaryEligible = signals.decoderReady & ...
    signals.primaryAuthorized & all(primaryDependencies,2);
fallbackEligible = signals.localHealthy & signals.localAuthorized;

route = strings(N,1);
assistance = strings(N,1);
indicator = strings(N,1);
failedDependencies = strings(N,1);
changed = false(N,1);
reconfirmed = false(N,1);

previous = "unavailable";

for index = 1:N
    if segmentStart(index)
        previous = "unavailable";
    end

    failed = names(~primaryDependencies(index,:).');
    failedDependencies(index) = strjoin(failed,", ");

    if signals.assistanceAcknowledged(index)
        assistance(index) = "acknowledged";
    elseif signals.assistanceRequested(index)
        assistance(index) = "requested_unacknowledged";
    else
        assistance(index) = "not_requested";
    end

    reconfirmed(index) = previous == "primary" && ...
        signals.selectPrimary(index) && primaryEligible(index) && ...
        ~signals.pauseRequested(index);

    if signals.pauseRequested(index)
        current = "paused_by_user";
        message = "Communication paused by your selection.";
    elseif primaryEligible(index) && ...
            (previous == "primary" || signals.selectPrimary(index))
        current = "primary";
        message = "Primary communication route is eligible.";
    elseif fallbackEligible(index)
        current = "local_fallback";
        message = "Local communication route is eligible.";
    else
        current = "unavailable";
        message = "No eligible communication route is reported.";
    end

    route(index) = current;
    indicator(index) = message;

    if index > 1 && ~segmentStart(index)
        changed(index) = current ~= previous;
    end

    previous = current;
end

transitionRows = find(changed);
fallbackEntered = changed & route == "local_fallback";
fallbackExited = false(N,1);

for index = 2:N
    fallbackExited(index) = ~segmentStart(index) && ...
        route(index-1) == "local_fallback" && ...
        route(index) ~= "local_fallback";
end

% Only completed replay dwells within an observation segment are scored.
completedDwell = zeros(0,1);
runStart = 1;
for index = 2:N
    if segmentStart(index)
        runStart = index;
    elseif changed(index)
        completedDwell(end+1,1) = t(index)-t(runStart); %#ok<AGROW>
        runStart = index;
    end
end

shortestDwell = NaN;
if ~isempty(completedDwell)
    shortestDwell = min(completedDwell);
end

report = struct();
report.mode = "offline-continuity-contract-replay";
report.observedInitialState = route(1);
report.stateTransitionCount = sum(changed);
report.shortestCompletedReplayDwellSeconds = shortestDwell;
report.flickerDetected = any(completedDwell < minimumDwellSeconds);
report.flickerAssessed = ~isempty(completedDwell);
report.maximumGapSeconds = maximumGapSeconds;
report.minimumDwellSeconds = minimumDwellSeconds;
report.gapPolicy = "new segment; no inherited primary persistence";
report.dwellSemantics = "snapshot replay; not physical dwell measurement";
report.physicalRestorationLatencyMeasured = false;
report.inputAuthenticityVerified = false;

report.observations = table( ...
    t, gap, segment, segmentStart, route, changed, reconfirmed, ...
    primaryEligible, fallbackEligible, failedDependencies, ...
    assistance, signals.assistanceReachable, ...
    signals.communicationConfirmed, fallbackEntered, fallbackExited, ...
    indicator, ...
    "VariableNames", ["timeSeconds","interRowGapSeconds", ...
    "segment","segmentStart","route","stateChangedSincePreviousRow", ...
    "primaryReconfirmed","primaryEligible","fallbackEligible", ...
    "failedPrimaryDependencies","assistanceStatus", ...
    "assistanceReachable","communicationConfirmed", ...
    "fallbackEntered","fallbackExited","indicator"]);

report.transitions = report.observations(transitionRows,:);
end

function mustBeNonnegativeScalarDouble(value)
if ~isa(value,"double") || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(value) || value < 0
    error("AugmentedHub:InputValue", ...
        "Require an actual finite nonnegative scalar double.");
end
end

function mustBePositiveScalarDouble(value)
mustBeNonnegativeScalarDouble(value);
if value == 0
    error("AugmentedHub:InputValue", ...
        "Require a strictly positive scalar double.");
end
end
