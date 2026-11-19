function report = evaluate_scope_lineage( ...
    scopes, parents, revoked, nowSeconds, request)
%EVALUATE_SCOPE_LINEAGE Attenuation and conservative dependency checks.
% scopes fields:
% purposes, dataClasses, operations, destinations: nonempty string vectors
% validFromSeconds, expiresSeconds: finite scalar doubles
%
% request fields: purpose, dataClass, operation, destination
% All times must share a separately declared timebase.
% No signatures, authentication, storage access, deletion, or actuation.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Preserve as credit/workstream metadata in derivatives.
% Not consent, identity verification, execution evidence, or authority.

arguments
    scopes {mustBeA(scopes,"struct")}
    parents {mustBeA(parents,"logical")}
    revoked {mustBeA(revoked,"logical")}
    nowSeconds {mustBeA(nowSeconds,"double"), mustBeReal, mustBeFinite}
    request {mustBeA(request,"struct")}
end

N = numel(scopes);
setFields = ["purposes","dataClasses","operations","destinations"];
timeFields = ["validFromSeconds","expiresSeconds"];
requestFields = ["purpose","dataClass","operation","destination"];

if N == 0 || ~isvector(scopes) || ...
        ~isequal(size(parents),[N,N]) || ...
        ~isvector(revoked) || numel(revoked) ~= N || ...
        ~isscalar(nowSeconds) || ~isscalar(request)
    error("AugmentedHub:InputShape", ...
        "Supply matching scopes, dependency matrix, revocations, and scalars.");
end

if ~all(isfield(scopes,cellstr([setFields,timeFields]))) || ...
        ~all(isfield(request,cellstr(requestFields)))
    error("AugmentedHub:InputConsistency", ...
        "Required scope or request fields are missing.");
end

revoked = revoked(:);

for row = 1:N
    for field = setFields
        value = scopes(row).(char(field));
        if ~isa(value,"string") || isempty(value) || ~isvector(value) || ...
                any(ismissing(value),"all") || ...
                any(strlength(value) == 0,"all") || ...
                numel(unique(value)) ~= numel(value)
            error("AugmentedHub:InputValue", ...
                "Scope sets must contain distinct nonempty strings.");
        end
    end

    for field = timeFields
        value = scopes(row).(char(field));
        if ~isa(value,"double") || ~isscalar(value) || ...
                ~isreal(value) || ~isfinite(value)
            error("AugmentedHub:InputType", ...
                "Scope times must be actual finite scalar doubles.");
        end
    end

    if scopes(row).validFromSeconds >= scopes(row).expiresSeconds
        error("AugmentedHub:InputValue", ...
            "Every scope needs a nonempty validity interval.");
    end
end

for field = requestFields
    value = request.(char(field));
    if ~isa(value,"string") || ~isscalar(value) || ...
            ismissing(value) || strlength(value) == 0
        error("AugmentedHub:InputValue", ...
            "Request fields must be nonempty string scalars.");
    end
end

% Topological ordering. A cycle is an invalid authority-dependency model.
pendingParents = sum(parents,2);
order = zeros(N,1);
processed = false(N,1);

for position = 1:N
    row = find(~processed & pendingParents == 0,1);
    if isempty(row)
        error("AugmentedHub:DependencyCycle", ...
            "Scope dependencies must be acyclic.");
    end

    order(position) = row;
    processed(row) = true;
    children = find(parents(:,row));
    pendingParents(children) = pendingParents(children)-1;
end

% Check attenuation independently of current expiry/revocation status.
for child = 1:N
    for parent = find(parents(child,:))
        for field = setFields
            if ~all(ismember(scopes(child).(char(field)), ...
                    scopes(parent).(char(field))),"all")
                error("AugmentedHub:ScopeExpansion", ...
                    "A child scope expands a required parent scope.");
            end
        end

        if scopes(child).validFromSeconds < ...
                scopes(parent).validFromSeconds || ...
                scopes(child).expiresSeconds > scopes(parent).expiresSeconds
            error("AugmentedHub:ScopeExpansion", ...
                "A child validity interval exceeds a parent interval.");
        end
    end
end

usable = false(N,1);
requestMatches = false(N,1);
reason = strings(N,1);

for position = 1:N
    row = order(position);
    parentRows = find(parents(row,:));

    if revoked(row)
        reason(row) = "locally_revoked";
    elseif nowSeconds < scopes(row).validFromSeconds
        reason(row) = "not_yet_valid";
    elseif nowSeconds >= scopes(row).expiresSeconds
        reason(row) = "expired";
    elseif any(~usable(parentRows))
        reason(row) = "required_ancestor_unavailable";
    else
        usable(row) = true;
        reason(row) = "scope_current_under_supplied_model";
    end

    requestMatches(row) = ...
        any(scopes(row).purposes == request.purpose) && ...
        any(scopes(row).dataClasses == request.dataClass) && ...
        any(scopes(row).operations == request.operation) && ...
        any(scopes(row).destinations == request.destination);
end

report = struct();
report.mode = "offline-scope-and-lineage-evaluation";
report.dependencyRule = "all declared parents required";
report.scopeCurrentlyUsable = usable;
report.requestMatchesScope = requestMatches;
report.permittedBySuppliedModel = usable & requestMatches;
report.reason = reason;
report.topologicalEvaluationOrder = order;
report.grantAuthenticityVerified = false;
report.deletionPerformed = false;
report.externalActionPerformed = false;
end
