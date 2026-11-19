function result = claim_readiness(checks)
% CLAIM_READINESS
% Non-compensating readiness for one composite positive assurance claim.
%
% Required fields:
%   schema_compatibility
%   replay_consistency
%   processing_scope
%   requirement_support
%   access_claim_fidelity
%   explanation_fidelity
%
% Each value must be a scalar string: "pass", "fail", or "unknown".
%
% Target: MATLAB R2020b or newer; base MATLAB.
% Supplied statuses are reviewed inputs, not authenticated by this function.
%
% SPDX-License-Identifier: MIT OR Apache-2.0

    if nargin ~= 1 || ~isstruct(checks) || ~isscalar(checks)
        error('consentlens:InvalidChecks', ...
            'Supply one scalar structure of reviewed prerequisite states.');
    end

    required = [
        "schema_compatibility"
        "replay_consistency"
        "processing_scope"
        "requirement_support"
        "access_claim_fidelity"
        "explanation_fidelity"
    ];

    supplied = string(fieldnames(checks));

    if numel(supplied) ~= numel(required) || ...
            ~all(ismember(required, supplied))
        error('consentlens:InvalidPrerequisiteSet', ...
            'Supply exactly the six documented prerequisite fields.');
    end

    values = strings(numel(required), 1);

    for k = 1:numel(required)
        value = checks.(char(required(k)));

        if ~isstring(value) || ~isscalar(value) || ...
                ismissing(value) || ...
                ~ismember(value, ["pass", "fail", "unknown"])
            error('consentlens:InvalidPrerequisiteState', ...
                'Each prerequisite must be pass, fail, or unknown.');
        end

        values(k) = value;
    end

    failed = required(values == "fail");
    unknown = required(values == "unknown");
    passed = required(values == "pass");

    ready = isempty(failed) && isempty(unknown);

    result = struct();
    result.SchemaVersion = "1.0.0";
    result.SovereignAttribution = ...
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
    result.AttributionUse = "document_credit_only";

    result.Prerequisites = required;
    result.PrerequisiteStates = values;
    result.PassedPrerequisites = passed;
    result.FailedPrerequisites = failed;
    result.UnknownPrerequisites = unknown;

    result.PositiveClaimCandidate = ready;
    result.StatusNoticeDraftAvailable = true;
    result.ExternalPublicationAuthorized = false;
    result.ReviewerAuthorityEstablished = false;
    result.InputEvidenceVerified = false;

    if ready
        result.Readiness = "positive_claim_candidate";
        result.Explanation = ...
            "All supplied prerequisites pass; separate release review remains required.";
    elseif ~isempty(failed)
        result.Readiness = "positive_claim_not_supported";
        result.Explanation = ...
            "One or more prerequisites failed; preserve a bounded status and correction route.";
    else
        result.Readiness = "positive_claim_unresolved";
        result.Explanation = ...
            "No failed prerequisite was supplied, but required support remains unresolved.";
    end

    result.RuntimeVersion = version;
end
