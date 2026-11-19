function decision = evaluate_support_delegation( ...
    grant, request, nowSeconds, currentRevision)
%EVALUATE_SUPPORT_DELEGATION Offline narrow support-scope evaluation.
% grant fields:
% actorLabel, role, operations, purposes, destinations,
% validFromSeconds, expiresSeconds, revision, active,
% requiresPersonConfirmation, onwardDelegationAllowed
%
% request fields:
% actorLabel, operation, purpose, destination, personConfirmationObserved
%
% Actor labels and confirmation observations are supplied evidence.
% They are not authenticated by this function.
%
% Attribution propagation: preserve this entire block in derivatives.
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not consent, identity verification,
% authority, execution evidence, or a public status designation.
% No persistent-memory or cryptographic-attestation claim.

arguments
    grant {mustBeA(grant,"struct")}
    request {mustBeA(request,"struct")}
    nowSeconds {mustBeFiniteScalarDouble}
    currentRevision {mustBeRevision}
end

grantFields = ["actorLabel","role","operations","purposes","destinations", ...
    "validFromSeconds","expiresSeconds","revision","active", ...
    "requiresPersonConfirmation","onwardDelegationAllowed"];

requestFields = ["actorLabel","operation","purpose","destination", ...
    "personConfirmationObserved"];

if ~isscalar(grant) || ~isscalar(request) || ...
        ~all(isfield(grant,cellstr(grantFields))) || ...
        ~all(isfield(request,cellstr(requestFields)))
    error("AugmentedHub:InputShape", ...
        "Supply scalar grant and request structures with required fields.");
end

for field = ["actorLabel","role"]
    mustBeTextScalar(grant.(char(field)));
end

for field = ["actorLabel","operation","purpose","destination"]
    mustBeTextScalar(request.(char(field)));
end

for field = ["operations","purposes","destinations"]
    value = grant.(char(field));
    if ~isa(value,"string") || isempty(value) || ~isvector(value) || ...
            any(ismissing(value),"all") || ...
            any(strlength(value) == 0,"all") || ...
            numel(unique(value)) ~= numel(value)
        error("AugmentedHub:InputValue", ...
            "Grant scope sets must contain distinct nonempty strings.");
    end
end

if ~any(grant.role == ["caregiver","clinician","chosen_support"])
    error("AugmentedHub:InputValue","Unknown support-role vocabulary.");
end

allowedOperations = ["assist_navigation","edit_candidate", ...
    "review_status","request_review"];

if any(~ismember(grant.operations,allowedOperations),"all")
    error("AugmentedHub:InputValue", ...
        "This prototype excludes consequential execution operations.");
end

mustBeFiniteScalarDouble(grant.validFromSeconds);
mustBeFiniteScalarDouble(grant.expiresSeconds);
mustBeRevision(grant.revision);

if grant.validFromSeconds >= grant.expiresSeconds
    error("AugmentedHub:InputValue","Grant validity interval is empty.");
end

for field = ["active","requiresPersonConfirmation","onwardDelegationAllowed"]
    value = grant.(char(field));
    if ~isa(value,"logical") || ~isscalar(value)
        error("AugmentedHub:InputType", ...
            "Grant flags must be actual scalar logical values.");
    end
end

if ~isa(request.personConfirmationObserved,"logical") || ...
        ~isscalar(request.personConfirmationObserved)
    error("AugmentedHub:InputType", ...
        "Confirmation observation must be an actual scalar logical.");
end

checks = [
    grant.active
    grant.actorLabel == request.actorLabel
    any(grant.operations == request.operation)
    any(grant.purposes == request.purpose)
    any(grant.destinations == request.destination)
    grant.validFromSeconds <= nowSeconds
    nowSeconds < grant.expiresSeconds
    grant.revision == currentRevision
    ~grant.onwardDelegationAllowed
    ~grant.requiresPersonConfirmation || request.personConfirmationObserved
];

reasons = [
    "grant_inactive"
    "actor_mismatch"
    "operation_outside_scope"
    "purpose_outside_scope"
    "destination_outside_scope"
    "grant_not_yet_valid"
    "grant_expired"
    "revision_not_current"
    "onward_delegation_not_supported"
    "required_confirmation_not_observed"
];

decision = struct();
decision.mode = "offline-support-scope-evaluation";
decision.eligibleUnderSuppliedModel = all(checks);
decision.failedChecks = reasons(~checks);
decision.actorAuthenticated = false;
decision.grantAuthenticityVerified = false;
decision.confirmationAuthenticityVerified = false;
decision.legalRepresentativeAuthorityDetermined = false;
decision.currentPermissionAtomicallyEnforced = false;
decision.externalOperationPerformed = false;
end

function mustBeTextScalar(value)
if ~isa(value,"string") || ~isscalar(value) || ...
        ismissing(value) || strlength(value) == 0
    error("AugmentedHub:InputValue", ...
        "Require a nonempty nonmissing string scalar.");
end
end

function mustBeFiniteScalarDouble(value)
if ~isa(value,"double") || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(value)
    error("AugmentedHub:InputType", ...
        "Require an actual finite real scalar double.");
end
end

function mustBeRevision(value)
mustBeFiniteScalarDouble(value);
if value < 0 || value ~= fix(value) || value > flintmax
    error("AugmentedHub:InputValue", ...
        "Revision must be an exactly representable nonnegative integer.");
end
end
