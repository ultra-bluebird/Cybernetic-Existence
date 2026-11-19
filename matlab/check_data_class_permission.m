function decision = check_data_class_permission( ...
    grants, dataClass, operation, purpose, destination, nowSeconds)
%CHECK_DATA_CLASS_PERMISSION Exact-match, default-deny policy evaluation.
% grants must be a table with:
% dataClass, operation, purpose, destination: string columns
% active: logical column
% expiresSeconds: finite double column
% nowSeconds and expiresSeconds must use the same declared timebase.
%
% No wildcard permissions, class inheritance, persistence, or I/O.
% The caller must protect grants against unauthorized modification.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit metadata only; not consent or operating authority.

arguments
    grants {mustBeA(grants,"table")}
    dataClass {mustBeA(dataClass,"string")}
    operation {mustBeA(operation,"string")}
    purpose {mustBeA(purpose,"string")}
    destination {mustBeA(destination,"string")}
    nowSeconds {mustBeA(nowSeconds,"double"), mustBeReal, mustBeFinite}
end

classes = ["raw_recordings","derived_features","decoder_parameters", ...
    "voice_profiles","candidate_outputs","emitted_audio", ...
    "transcripts","authorization_records"];
operations = ["process_transient","retain","read","export","transform","delete"];
required = ["dataClass","operation","purpose","destination", ...
    "active","expiresSeconds"];

if ~all(ismember(required, string(grants.Properties.VariableNames)))
    error("AugmentedHub:GrantSchema", "Required grant columns are missing.");
end

requestText = {dataClass, operation, purpose, destination};
for index = 1:numel(requestText)
    value = requestText{index};
    if ~isscalar(value) || ismissing(value) || strlength(value) == 0
        error("AugmentedHub:RequestText", ...
            "Request fields must be nonempty string scalars.");
    end
end

if ~isscalar(nowSeconds)
    error("AugmentedHub:Time", "nowSeconds must be scalar.");
end

if ~any(dataClass == classes) || ~any(operation == operations)
    error("AugmentedHub:Vocabulary", "Unknown data class or operation.");
end

for name = ["dataClass","operation","purpose","destination"]
    column = grants.(char(name));
    if ~isa(column,"string") || size(column,2) ~= 1 || ...
            any(ismissing(column)) || any(strlength(column) == 0)
        error("AugmentedHub:GrantText", ...
            "Grant text columns must be nonmissing string columns.");
    end
end

if ~isa(grants.active,"logical") || size(grants.active,2) ~= 1 || ...
        ~isa(grants.expiresSeconds,"double") || ...
        size(grants.expiresSeconds,2) ~= 1 || ...
        ~isreal(grants.expiresSeconds) || ...
        any(~isfinite(grants.expiresSeconds))
    error("AugmentedHub:GrantValues", "Invalid active or expiry column.");
end

if any(~ismember(grants.dataClass,classes)) || ...
        any(~ismember(grants.operation,operations))
    error("AugmentedHub:GrantVocabulary", ...
        "Grant contains an unknown data class or operation.");
end

matches = grants.active & ...
    nowSeconds < grants.expiresSeconds & ...
    grants.dataClass == dataClass & ...
    grants.operation == operation & ...
    grants.purpose == purpose & ...
    grants.destination == destination;

decision = struct();
decision.permittedByPolicy = any(matches);
decision.reason = "no_active_exact_scope_match";
if decision.permittedByPolicy
    decision.reason = "active_exact_scope_match";
end
decision.storageOperationPerformed = false;
decision.externalActionPerformed = false;
end
