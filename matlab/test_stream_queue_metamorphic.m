function tests = test_stream_queue_metamorphic
% Proposed verification; no execution evidence until actually run.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
tests = functiontests(localfunctions);
end

function testKnownBurst(testCase)
a = [0;0.125;0.250;0.375];
s = [0.0625;0.250;0.0625;0.0625];
d = 0.125*ones(4,1);

r = replay_stream_queue(a,s,d,0.125);

verifyEqual(testCase,r.observations.completionSeconds, ...
    [0.0625;0.375;0.4375;0.5000],"AbsTol",1e-12);
verifyEqual(testCase,r.maximumObservedJobsInSystem,2);
verifyEqual(testCase,r.minimumInitialBufferForThisTraceSeconds,0.25);
verifyEqual(testCase,r.totalPlaybackGapSeconds,0.125,"AbsTol",1e-12);
end

function testTimeOriginShift(testCase)
[a,s,d,B] = fixture();
r = replay_stream_queue(a,s,d,B);
shifted = replay_stream_queue(a+32,s,d,B);

verifyEqual(testCase,shifted.observations.completionSeconds, ...
    r.observations.completionSeconds+32,"AbsTol",1e-12);
verifyEqual(testCase,shifted.observations.waitingSeconds, ...
    r.observations.waitingSeconds,"AbsTol",1e-12);
verifyEqual(testCase,shifted.totalPlaybackGapSeconds, ...
    r.totalPlaybackGapSeconds,"AbsTol",1e-12);
end

function testUnitConsistentScaling(testCase)
[a,s,d,B] = fixture();
r = replay_stream_queue(a,s,d,B);
scaled = replay_stream_queue(8*a,8*s,8*d,8*B);

verifyEqual(testCase,scaled.observations.sojournSeconds, ...
    8*r.observations.sojournSeconds,"AbsTol",1e-12);
verifyEqual(testCase,scaled.totalPlaybackGapSeconds, ...
    8*r.totalPlaybackGapSeconds,"AbsTol",1e-12);
verifyEqual(testCase,scaled.maximumObservedJobsInSystem, ...
    r.maximumObservedJobsInSystem);
end

function testEveryPrefix(testCase)
[a,s,d,B] = fixture();
full = replay_stream_queue(a,s,d,B);

for length = 1:numel(a)-1
    prefix = replay_stream_queue( ...
        a(1:length),s(1:length),d(1:length),B);
    verifyEqual(testCase,prefix.observations.completionSeconds, ...
        full.observations.completionSeconds(1:length),"AbsTol",1e-12);
    verifyEqual(testCase,prefix.observations.actualPlaybackStartSeconds, ...
        full.observations.actualPlaybackStartSeconds(1:length), ...
        "AbsTol",1e-12);
end
end

function testFasterServiceCannotDelayCompletion(testCase)
[a,s,d,B] = fixture();
baseline = replay_stream_queue(a,s,d,B);
faster = replay_stream_queue(a,s/2,d,B);

verifyTrue(testCase,all( ...
    faster.observations.completionSeconds <= ...
    baseline.observations.completionSeconds+1e-12));
end

function testTraceBufferRemovesTraceGaps(testCase)
[a,s,d,B] = fixture();
initial = replay_stream_queue(a,s,d,B);
buffered = replay_stream_queue(a,s,d, ...
    initial.minimumInitialBufferForThisTraceSeconds);

verifyEqual(testCase,buffered.totalPlaybackGapSeconds,0,"AbsTol",1e-12);
end

function testDuplicateArrivalsRejected(testCase)
verifyError(testCase,@() replay_stream_queue( ...
    [0;0],[0.1;0.1],[0.1;0.1],0.1), ...
    "AugmentedHub:InputValue");
end

function [a,s,d,B] = fixture()
a = (0:0.125:0.875).';
s = [0.0625;0.250;0.0625;0.0625; ...
     0.1875;0.0625;0.0625;0.0625];
d = 0.125*ones(size(a));
B = 0.125;
end
