function test_analyze_panel_ctmc_bridge()
% Synthetic specified-model checks; not empirical validation.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

% One-way transition to an absorbing state.
lambda = 2;
Q = [-lambda,lambda;0,0];
T = 1;

r = analyze_panel_ctmc_bridge(Q,1,2,T,2001);
expectedEndpoint = -expm1(-lambda*T);

assert(abs(r.endpointProbability-expectedEndpoint) < 1e-12);
assert(r.noJumpProbability == 0);
assert(abs(r.quadratureMassResidual) < 1e-6);
assert(r.maximumBridgeRowSumResidual < 1e-12);

expectedDensity = lambda*exp( ...
    -lambda*r.timeSinceFirstSnapshotSeconds)/expectedEndpoint;
actualDensity = r.firstDepartureSubdensityPerSecond(:,2);
assert(max(abs(actualDensity-expectedDensity)) < 1e-11);

% Equal endpoint states do not imply absence of intervening transitions.
cyclic = analyze_panel_ctmc_bridge([-1,1;1,-1],1,1,1,2001);
assert(cyclic.noJumpProbability > 0);
assert(cyclic.noJumpProbability < 1);
assert(cyclic.integratedDepartureMass > 0);
assert(abs(cyclic.quadratureMassResidual) < 1e-6);

% A process with no transitions has a unit no-jump atom.
stationary = analyze_panel_ctmc_bridge(zeros(2),1,1,1,101);
assert(stationary.noJumpProbability == 1);
assert(stationary.integratedDepartureMass == 0);

assertRejects(@() analyze_panel_ctmc_bridge( ...
    [-1,-1;0,0],1,2,1,101));
assertRejects(@() analyze_panel_ctmc_bridge( ...
    zeros(2),1,2,1,101));
assertRejects(@() analyze_panel_ctmc_bridge( ...
    single(Q),1,2,1,101));
end

function assertRejects(call)
rejected = false;
try
    call();
catch
    rejected = true;
end
assert(rejected,"Expected invalid or impossible input to be rejected.");
end
