function test_persistence_operating_curve()
% Synthetic mathematical cases only.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

a = persistence_operating_curve([0;0.5;1], 2, 64, 0, 2);
v = a.operatingCurve;

assert(isinf(v.expectedTrials(1)));
assert(abs(v.expectedTrials(2)-6) < 1e-12);
assert(v.expectedTrials(3) == 2);
assert(abs(v.completion(2)-0.25) < 1e-12);
assert(v.completion(3) == 1);
assert(v.expectedDelay(3) == 64);
assert(all(v.massError < 1e-12));

b = persistence_operating_curve(1, 2, 64, 64, 2);
assert(b.operatingCurve.expectedDelay == 128);

nearOne = persistence_operating_curve(1-1e-12, 3, 64, 0, 10);
assert(abs(nearOne.operatingCurve.expectedTrials-3) < 1e-9);
assert(nearOne.operatingCurve.completion > 0.999999999);

largeRun = persistence_operating_curve(0.5, 256, 1, 0, 300);
assert(isfinite(largeRun.operatingCurve.logExpectedTrials));
assert(largeRun.operatingCurve.massError < 1e-10);

assertRejects(@() persistence_operating_curve( ...
    single(0.5), 2, 64, 0, 10));
assertRejects(@() persistence_operating_curve( ...
    0.5, uint8(2), 64, 0, 10));
assertRejects(@() persistence_operating_curve( ...
    0.5, 2, int32(64), 0, 10));
assertRejects(@() persistence_operating_curve( ...
    0.5, 2, 64, 65, 10));

assertRejects(@() persistence_operating_curve( ...
    0.5, 20, 1, 0, 20, 100, 100000));
assertRejects(@() persistence_operating_curve( ...
    0.5, 20, 1, 0, 20, 100000, 10));
end

function assertRejects(call)
rejected = false;
try
    call();
catch
    rejected = true;
end
assert(rejected, "Expected invalid input or budget to be rejected.");
end
