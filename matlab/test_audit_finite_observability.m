function test_audit_finite_observability()
% Synthetic dimensionless examples, not physiological models.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

budget = 64000000;

% One scalar observation reveals both states over two observations.
A = [1,1;0,1];
C = [1,0];
observable = audit_finite_observability( ...
    A,C,1,[1;1],2,0.1,1e-10,budget);
assert(observable.fullRankAtDeclaredTolerance);
assert(observable.numericalRank == 2);

% With no coupling, the second state remains unseen.
unobservable = audit_finite_observability( ...
    eye(2),C,1,[1;1],4,0.1,1e-10,budget);
assert(~unobservable.fullRankAtDeclaredTolerance);
assert(unobservable.numericalRank == 1);

% A shorter horizon cannot reveal both states in this example.
short = audit_finite_observability( ...
    A,C,1,[1;1],1,0.1,1e-10,budget);
assert(short.numericalRank == 1);

% Larger observation noise reduces all whitened singular values here.
noisier = audit_finite_observability( ...
    A,C,4,[1;1],2,0.1,1e-10,budget);
assert(max(abs(noisier.singularValues ...
    -observable.singularValues/2)) < 1e-12);

zero = audit_finite_observability( ...
    eye(2),zeros(1,2),1,[1;1],3,0.1,1e-10,budget);
assert(zero.numericalRank == 0);

assert(~observable.physiologicalInterpretationValidated);
end
