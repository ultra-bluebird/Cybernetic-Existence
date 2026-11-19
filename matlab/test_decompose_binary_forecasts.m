function test_decompose_binary_forecasts()
% Synthetic algebraic checks only.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

% A single wide bin makes the omitted within-bin terms visible.
r = decompose_binary_forecasts( ...
    [0.1;0.9], [false;true], [0;1]);

assert(abs(r.brier-0.01) < 1e-12);
assert(abs(r.withinBinVariance-0.16) < 1e-12);
assert(abs(r.withinBinCovariance-0.20) < 1e-12);
assert(abs(r.decompositionResidual) < 1e-12);

constant = decompose_binary_forecasts( ...
    [0.5;0.5], [false;true], [0;0.5;1]);
assert(constant.reliability == 0);
assert(constant.resolution == 0);
assert(constant.brier == 0.25);

perfect = decompose_binary_forecasts( ...
    [0;1], [false;true], [0;0.5;1]);
assert(perfect.brier == 0);
assert(perfect.logLoss == 0);

wrong = decompose_binary_forecasts( ...
    [0;1], [true;false], [0;0.5;1]);
assert(isinf(wrong.logLoss));
assert(wrong.infiniteLogLossCount == 2);

for count = 3:20
    p = linspace(0.01,0.99,count).';
    y = mod((1:count).',3) == 0;
    trial = decompose_binary_forecasts(p,y,[0;0.2;0.6;1]);
    assert(abs(trial.decompositionResidual) < 1e-12);
end
end
