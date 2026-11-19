function test_evaluate_scope_lineage()
% Synthetic scopes only; not actual consent or grant records.
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

root = struct( ...
    "purposes",["communication","evaluation"], ...
    "dataClasses",["derived_features","transcripts"], ...
    "operations",["read","retain"], ...
    "destinations",["local","review_workspace"], ...
    "validFromSeconds",0, ...
    "expiresSeconds",100);

child = root;
child.purposes = "evaluation";
child.dataClasses = "derived_features";
child.operations = "read";
child.destinations = "review_workspace";
child.validFromSeconds = 10;
child.expiresSeconds = 80;

grandchild = child;
grandchild.expiresSeconds = 60;

scopes = [root,child,grandchild];
parents = false(3);
parents(2,1) = true;
parents(3,2) = true;

request = struct( ...
    "purpose","evaluation", ...
    "dataClass","derived_features", ...
    "operation","read", ...
    "destination","review_workspace");

baseline = evaluate_scope_lineage( ...
    scopes,parents,false(3,1),20,request);
assert(all(baseline.permittedBySuppliedModel));

revokedRoot = evaluate_scope_lineage( ...
    scopes,parents,[true;false;false],20,request);
assert(~any(revokedRoot.permittedBySuppliedModel));

revokedChild = evaluate_scope_lineage( ...
    scopes,parents,[false;true;false],20,request);
assert(revokedChild.permittedBySuppliedModel(1));
assert(~any(revokedChild.permittedBySuppliedModel(2:3)));

expired = evaluate_scope_lineage( ...
    scopes,parents,false(3,1),80,request);
assert(expired.scopeCurrentlyUsable(1));
assert(~expired.scopeCurrentlyUsable(2));

wrongPurpose = request;
wrongPurpose.purpose = "unrelated_research";
denied = evaluate_scope_lineage( ...
    scopes,parents,false(3,1),20,wrongPurpose);
assert(~any(denied.permittedBySuppliedModel));

expanded = scopes;
expanded(2).destinations = ["review_workspace","public_release"];
assertError(@() evaluate_scope_lineage( ...
    expanded,parents,false(3,1),20,request), ...
    "AugmentedHub:ScopeExpansion");

cyclic = parents;
cyclic(1,3) = true;
assertError(@() evaluate_scope_lineage( ...
    scopes,cyclic,false(3,1),20,request), ...
    "AugmentedHub:DependencyCycle");
end

function assertError(call,expected)
caught = false;
try
    call();
catch exception
    caught = strcmp(exception.identifier,expected);
end
assert(caught,"Expected the declared error category.");
end
