function test_audit_cost_effect_frontiers()
% Synthetic units only; not actual assistive-device prices or outcomes.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

% Equal effects; one alternative is front-loaded, the other back-loaded.
cost = [100,0;0,120];
times = [0;10];
effects = [1,1;1,1];

r = audit_cost_effect_frontiers( ...
    cost,times,effects,[-1,-1],true(2,1),[0;0.1]);

assert(isequal(r.paretoMembership(:,1),[true;false]));
assert(isequal(r.paretoMembership(:,2),[false;true]));
assert(all(r.membershipChangesAcrossRateScenarios));

% Adding a meaningful effect can make the more costly option nondominated.
tradeoffEffects = [1,1;2,0];
tradeoff = audit_cost_effect_frontiers( ...
    cost,times,tradeoffEffects,[-1,-1],true(2,1),0);
assert(all(tradeoff.paretoMembership));

% Hard constraints are not weakened to force a recommendation.
none = audit_cost_effect_frontiers( ...
    cost,times,effects,[-1,-1],false(2,1),0);
assert(none.noAdmissibleCandidate);
assert(~any(none.paretoMembership));

% Equivalent alternatives remain a set rather than an arbitrary winner.
ties = audit_cost_effect_frontiers( ...
    [10;10],0,[1;1],-1,true(2,1),0);
assert(all(ties.paretoMembership));
assert(~ties.preferredAlternativeSelected);
end
