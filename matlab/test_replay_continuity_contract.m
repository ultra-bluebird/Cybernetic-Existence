function test_replay_continuity_contract()
% Synthetic contract tests. Not execution evidence until actually run.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

N = 7;
t = [0;0.1;0.2;0.3;0.4;10;10.1];

signals = table();
signals.decoderReady = true(N,1);
signals.primaryAuthorized = true(N,1);
signals.localHealthy = true(N,1);
signals.localAuthorized = true(N,1);
signals.pauseRequested = false(N,1);
signals.selectPrimary = [true;true;false;false;true;false;true];
signals.assistanceReachable = true(N,1);
signals.assistanceRequested = [false;false;true;true;false;false;false];
signals.assistanceAcknowledged = [false;false;false;true;false;false;false];
signals.communicationConfirmed = false(N,1);

dependencies = true(N,2);
dependencies(3:4,1) = false;

r = replay_continuity_contract( ...
    t,signals,dependencies,["network";"credential"],1,0.15);

expected = ["primary";"primary";"local_fallback";"local_fallback"; ...
    "primary";"local_fallback";"primary"];

assert(isequal(r.observations.route,expected));
assert(~r.observations.stateChangedSincePreviousRow(1));
assert(~r.observations.stateChangedSincePreviousRow(6));
assert(r.observations.segmentStart(6));
assert(r.observations.primaryReconfirmed(2));
assert(r.observations.fallbackEntered(3));
assert(r.observations.fallbackExited(5));
assert(r.observations.assistanceStatus(3) == "requested_unacknowledged");
assert(r.observations.assistanceStatus(4) == "acknowledged");
assert(r.observations.failedPrimaryDependencies(3) == "network");
assert(r.stateTransitionCount == 3);
assert(r.flickerDetected);

paused = signals;
paused.pauseRequested(3) = true;
p = replay_continuity_contract( ...
    t,paused,dependencies,["network";"credential"],1,0.15);
assert(p.observations.route(3) == "paused_by_user");
assert(p.observations.assistanceStatus(3) == "requested_unacknowledged");

denied = signals;
denied.localAuthorized(:) = false;
d = replay_continuity_contract( ...
    t,denied,dependencies,["network";"credential"],1,0.15);
assert(d.observations.route(3) == "unavailable");

assert(~r.inputAuthenticityVerified);
assert(~r.physicalRestorationLatencyMeasured);
end
