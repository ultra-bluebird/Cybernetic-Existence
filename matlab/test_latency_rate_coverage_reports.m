function test_latency_rate_coverage_reports()
% Tests the two numerical reports; JSON schema validation is separate.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

zero = report_unintended_poisson_rate(0,100,0.05);
assert(zero.ratePerHour == 0);
assert(abs(zero.oneSidedUpperPerHour + log(0.05)/100) < 1e-12);
assert(abs(zero.centralIntervalPerHour(2) ...
    + log(0.025)/100) < 1e-12);
assert(zero.centralIntervalPerHour(1) == 0);

nonzero = report_unintended_poisson_rate(4,100,0.05);
assert(nonzero.centralIntervalPerHour(1) < nonzero.ratePerHour);
assert(nonzero.centralIntervalPerHour(2) > nonzero.ratePerHour);

r = report_risk_coverage( ...
    [0.9;0.8;0.8;0.1], ...
    [true;false;true;false],true(4,1));

assert(isequal(r.curve.acceptedCount,[0;1;3;4]));
assert(isnan(r.curve.risk(1)));
assert(abs(r.curve.risk(3)-1/3) < 1e-12);
assert(r.curve.coverage(end) == 1);
assert(abs(r.curve.correctAcceptedFraction(end)-0.5) < 1e-12);

% Permuting a tie does not change the attainable threshold curve.
permuted = report_risk_coverage( ...
    [0.9;0.8;0.8;0.1], ...
    [true;true;false;false],true(4,1));
assert(isequaln(r.curve,permuted.curve));

limited = report_risk_coverage( ...
    [0.9;0.8;0.8;NaN], ...
    [true;false;true;false],[true;true;true;false]);
assert(limited.maximumCoverage == 0.75);

none = report_risk_coverage( ...
    [NaN;NaN],[true;false],false(2,1));
assert(none.maximumCoverage == 0);
assert(isnan(none.curve.risk));
end
