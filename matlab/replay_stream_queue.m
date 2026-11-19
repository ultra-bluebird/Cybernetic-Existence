function report = replay_stream_queue( ...
    arrivalSeconds, serviceSeconds, audioSeconds, initialBufferSeconds)
%REPLAY_STREAM_QUEUE Offline FCFS queue and ordered-playback simulation.
% Each input row describes one work item producing one audio chunk.
% Service times include all work assigned to this effective single server.
% No dropping, networking, acquisition, audio output, or device control.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Preserve as credit/workstream metadata in derivative artifacts.
% Not consent, verified identity, execution evidence, or authority.

arguments
    arrivalSeconds {mustBeDoubleVector}
    serviceSeconds {mustBeDoubleVector}
    audioSeconds {mustBeDoubleVector}
    initialBufferSeconds {mustBeNonnegativeScalarDouble}
end

a = arrivalSeconds(:);
s = serviceSeconds(:);
d = audioSeconds(:);
N = numel(a);

if numel(s) ~= N || numel(d) ~= N
    error("AugmentedHub:InputConsistency", ...
        "Arrival, service, and audio-duration counts must match.");
end

if any(diff(a) <= 0) || any(s <= 0) || any(d <= 0)
    error("AugmentedHub:InputValue", ...
        "Arrivals must increase; service and audio durations must be positive.");
end

serviceStart = zeros(N,1);
completion = zeros(N,1);
jobsAtArrival = zeros(N,1);
oldestUnfinished = 1;

for index = 1:N
    if index == 1
        serviceStart(index) = a(index);
    else
        serviceStart(index) = max(a(index),completion(index-1));
    end

    completion(index) = serviceStart(index)+s(index);

    if ~isfinite(completion(index))
        error("AugmentedHub:NumericalRange", ...
            "Completion timestamps exceed finite double arithmetic.");
    end

    while oldestUnfinished < index && ...
            completion(oldestUnfinished) <= a(index)
        oldestUnfinished = oldestUnfinished+1;
    end

    % Includes the new arrival and any item currently in service.
    % Completions at the same timestamp are processed before arrival.
    jobsAtArrival(index) = index-oldestUnfinished+1;
end

audioPrefix = [0;cumsum(d(1:end-1))];
plannedStart = a(1)+initialBufferSeconds+audioPrefix;

if any(~isfinite(plannedStart))
    error("AugmentedHub:NumericalRange", ...
        "Planned playback timestamps exceed finite arithmetic.");
end

actualStart = zeros(N,1);
playbackGap = zeros(N,1);
cursor = a(1)+initialBufferSeconds;

for index = 1:N
    playbackGap(index) = max(0,completion(index)-cursor);
    actualStart(index) = max(cursor,completion(index));
    cursor = actualStart(index)+d(index);

    if ~isfinite(cursor)
        error("AugmentedHub:NumericalRange", ...
            "Playback timestamps exceed finite arithmetic.");
    end
end

minimumTraceBuffer = max(0,max(completion-a(1)-audioPrefix));
waiting = serviceStart-a;
sojourn = completion-a;
deadlineMiss = completion > plannedStart;

report = struct();
report.mode = "offline-FCFS-ordered-playback-replay";
report.initialBufferSeconds = initialBufferSeconds;
report.minimumInitialBufferForThisTraceSeconds = minimumTraceBuffer;
report.maximumObservedJobsInSystem = max(jobsAtArrival);
report.deadlineMissFraction = mean(deadlineMiss);
report.playbackGapCountIncludingStartup = sum(playbackGap > 0);
report.totalPlaybackGapSeconds = sum(playbackGap);
report.maximumPlaybackGapSeconds = max(playbackGap);
report.firstOutputDelayFromFirstArrivalSeconds = actualStart(1)-a(1);
report.futureWorkloadGuaranteeEstablished = false;
report.finiteCapacityAdmissionSimulated = false;
report.physicalAudioMeasured = false;

report.observations = table( ...
    a,s,d,serviceStart,completion,waiting,sojourn, ...
    jobsAtArrival,plannedStart,actualStart,playbackGap,deadlineMiss, ...
    "VariableNames", ["arrivalSeconds","serviceSeconds","audioSeconds", ...
    "serviceStartSeconds","completionSeconds","waitingSeconds", ...
    "sojournSeconds","jobsInSystemAtArrival", ...
    "plannedPlaybackStartSeconds","actualPlaybackStartSeconds", ...
    "playbackGapSeconds","deadlineMiss"]);
end

function mustBeDoubleVector(value)
if ~isa(value,"double")
    error("AugmentedHub:InputType", "Require actual double inputs.");
end
if isempty(value) || ~isvector(value)
    error("AugmentedHub:InputShape", "Require nonempty vectors.");
end
if ~isreal(value) || any(~isfinite(value),"all")
    error("AugmentedHub:InputValue", "Require real finite values.");
end
end

function mustBeNonnegativeScalarDouble(value)
if ~isa(value,"double") || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(value) || value < 0
    error("AugmentedHub:InputValue", ...
        "Require an actual finite nonnegative scalar double.");
end
end
