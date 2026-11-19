function report = check_research_envelope( ...
    candidateLower, candidateUpper, candidateNames, candidateUnits, ...
    envelope, suppliedContext, nowSeconds)
%CHECK_RESEARCH_ENVELOPE Offline robust box-and-linear feasibility.
% envelope fields:
% quantityNames, quantityUnits: distinct/order-sensitive string vectors
% lower, upper: finite bounds
% A, b: finite linear constraints A*x <= b
% context: scalar struct with exact-match text fields
% validFromSeconds, expiresSeconds: finite scalar doubles
%
% No clinical limits are embedded. Caller-supplied bounds require evidence.
% Passing means mathematical membership only, not safety or authorization.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not consent or execution evidence.

arguments
    candidateLower {mustBeA(candidateLower,"double"), ...
        mustBeReal, mustBeFinite}
    candidateUpper {mustBeA(candidateUpper,"double"), ...
        mustBeReal, mustBeFinite}
    candidateNames {mustBeA(candidateNames,"string")}
    candidateUnits {mustBeA(candidateUnits,"string")}
    envelope {mustBeA(envelope,"struct")}
    suppliedContext {mustBeA(suppliedContext,"struct")}
    nowSeconds {mustBeFiniteScalarDouble}
end

required = ["quantityNames","quantityUnits","lower","upper","A","b", ...
    "context","validFromSeconds","expiresSeconds"];

if ~isscalar(envelope) || ~isscalar(suppliedContext) || ...
        ~all(isfield(envelope,cellstr(required)))
    error("AugmentedHub:InputShape", "Invalid envelope or context.");
end

if isempty(candidateLower) || ~isvector(candidateLower) || ...
        ~isvector(candidateUpper) || ...
        numel(candidateLower) ~= numel(candidateUpper)
    error("AugmentedHub:InputShape", ...
        "Supply matching nonempty candidate-bound vectors.");
end

lo = candidateLower(:);
hi = candidateUpper(:);
D = numel(lo);

if any(lo > hi)
    error("AugmentedHub:InputValue", ...
        "Candidate lower bounds must not exceed upper bounds.");
end

mustBeTextVector(candidateNames,D);
mustBeTextVector(candidateUnits,D);
mustBeTextVector(envelope.quantityNames,D);
mustBeTextVector(envelope.quantityUnits,D);

if numel(unique(envelope.quantityNames)) ~= D
    error("AugmentedHub:InputValue", "Quantity names must be distinct.");
end

for name = ["lower","upper","A","b"]
    value = envelope.(char(name));
    if ~isa(value,"double") || ~isreal(value) || ...
            any(~isfinite(value),"all")
        error("AugmentedHub:InputType", ...
            "Envelope numerical fields must be finite real doubles.");
    end
end

if ~isvector(envelope.lower) || ~isvector(envelope.upper) || ...
        numel(envelope.lower) ~= D || numel(envelope.upper) ~= D || ...
        any(envelope.lower(:) > envelope.upper(:)) || ...
        ~ismatrix(envelope.A) || size(envelope.A,2) ~= D || ...
        size(envelope.A,1) ~= numel(envelope.b) || ...
        (~isempty(envelope.b) && ~isvector(envelope.b))
    error("AugmentedHub:InputConsistency", ...
        "Envelope dimensions or bounds are inconsistent.");
end

mustBeFiniteScalarDouble(envelope.validFromSeconds);
mustBeFiniteScalarDouble(envelope.expiresSeconds);

if envelope.validFromSeconds >= envelope.expiresSeconds
    error("AugmentedHub:InputValue", "Envelope validity interval is empty.");
end

if ~isscalar(envelope.context) || ~isstruct(envelope.context)
    error("AugmentedHub:InputShape", "Envelope context must be scalar struct.");
end

contextFields = fieldnames(envelope.context);
if isempty(contextFields) || ...
        ~isequal(sort(contextFields),sort(fieldnames(suppliedContext)))
    error("AugmentedHub:InputConsistency", ...
        "Context fields must match a nonempty declared context schema.");
end

contextMatch = true;
for index = 1:numel(contextFields)
    name = contextFields{index};
    expected = envelope.context.(name);
    supplied = suppliedContext.(name);
    mustBeTextVector(expected,1);
    mustBeTextVector(supplied,1);
    contextMatch = contextMatch && expected == supplied;
end

A = envelope.A;
worstLinear = max(A,0)*hi + min(A,0)*lo;

if any(~isfinite(worstLinear))
    error("AugmentedHub:NumericalRange", ...
        "Constraint arithmetic exceeded finite range.");
end

namesMatch = isequal(candidateNames(:),envelope.quantityNames(:));
unitsMatch = isequal(candidateUnits(:),envelope.quantityUnits(:));
timeCurrent = envelope.validFromSeconds <= nowSeconds && ...
    nowSeconds < envelope.expiresSeconds;

boxSatisfied = lo >= envelope.lower(:) & hi <= envelope.upper(:);
linearSatisfied = worstLinear <= envelope.b(:);

report = struct();
report.mode = "offline-robust-box-linear-membership";
report.contextMatches = contextMatch;
report.quantityNamesMatch = namesMatch;
report.quantityUnitsMatch = unitsMatch;
report.envelopeTimeCurrent = timeCurrent;
report.boxSatisfied = boxSatisfied;
report.linearSatisfied = linearSatisfied;
report.worstCaseLinearValues = worstLinear;
report.linearUpperBounds = envelope.b(:);
report.mathematicallyWithinSuppliedEnvelope = ...
    contextMatch && namesMatch && unitsMatch && timeCurrent && ...
    all(boxSatisfied) && all(linearSatisfied);
report.nonlinearConstraintsEvaluated = false;
report.historyDependentConstraintsEvaluated = false;
report.envelopeEvidenceVerified = false;
report.clinicalSafetyEstablished = false;
report.operationalAuthorizationEstablished = false;
end

function mustBeFiniteScalarDouble(value)
if ~isa(value,"double") || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(value)
    error("AugmentedHub:InputType", ...
        "Require an actual finite real scalar double.");
end
end

function mustBeTextVector(value,count)
if ~isa(value,"string") || ~isvector(value) || ...
        numel(value) ~= count || any(ismissing(value),"all") || ...
        any(strlength(value) == 0,"all")
    error("AugmentedHub:InputValue", ...
        "Supply nonempty string entries with the required length.");
end
end
