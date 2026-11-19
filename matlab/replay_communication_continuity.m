function report = replay_communication_continuity( ...
    timeSeconds, signals, primaryNeedsRemote)
%REPLAY_COMMUNICATION_CONTINUITY Offline communication-route state model.
% Each row is a complete supplied snapshot, not a partial update.
% First entry into primary requires selectPrimary=true.
% selectPrimary and pause are supplied user-control observations.
% No device control, credential bypass, networking, or assistance request.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit metadata only; not consent, identity, or operating authority.

arguments
    timeSeconds {mustBeA(timeSeconds,"double"), mustBeReal, mustBeFinite}
    signals {mustBeA(signals,"table")}
    primaryNeedsRemote {mustBeA(primaryNeedsRemote,"logical")}
end

required = ["decoderReady","networkReady","credentialValid", ...
    "localHealthy","localAuthorized","assistanceAvailable", ...
    "selectPrimary","pause"];

if isempty(timeSeconds) || ~isvector(timeSeconds) || ...
        ~isscalar(primaryNeedsRemote)
    error("AugmentedHub:InputShape", ...
        "Supply a nonempty time vector and scalar route declaration.");
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
        "Signal rows must match timestamps and include required columns.");
end

for name = required
    column = signals.(char(name));
    if ~isa(column,"logical") || size(column,2) ~= 1
        error("AugmentedHub:InputType", ...
            "Required signal columns must be actual logical columns.");
    end
end

primaryEligible = signals.decoderReady;
if primaryNeedsRemote
    primaryEligible = primaryEligible & ...
        signals.networkReady & signals.credentialValid;
end

fallbackEligible = signals.localHealthy & signals.localAuthorized;

state = strings(N,1);
indicator = strings(N,1);
changed = false(N,1);
previous = "unavailable";

for index = 1:N
    if signals.pause(index)
        current = "paused";
        message = "Communication paused by your selection.";
    elseif primaryEligible(index) && ...
            (previous == "primary" || signals.selectPrimary(index))
        current = "primary";
        message = "Primary communication available.";
    elseif fallbackEligible(index)
        current = "local_fallback";
        message = "Local communication available; features may be limited.";
    elseif signals.assistanceAvailable(index)
        current = "assistance_needed";
        message = "Communication route unavailable; assistance is needed.";
    else
        current = "unavailable";
        message = "Communication unavailable through this interface.";
    end

    state(index) = current;
    indicator(index) = message;
    changed(index) = current ~= previous;
    previous = current;
end

report = struct();
report.mode = "offline-communication-continuity-replay";
report.primaryNeedsRemote = primaryNeedsRemote;
report.initialState = "unavailable";
report.physicalCommunicationSuccessMeasured = false;
report.medicalFallbackSpecified = false;

report.observations = table( ...
    t, primaryEligible, fallbackEligible, state, changed, indicator, ...
    "VariableNames", ["timeSeconds","primaryEligible", ...
    "fallbackEligible","state","stateChanged","indicator"]);
end
