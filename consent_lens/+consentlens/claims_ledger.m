function ledger = claims_ledger(dispositions, unknownReasons)
% CLAIMS_LEDGER Counts and rates for already-classified review records.
% Named dispositions: conforming, nonconforming, unknown, retired.
% Unknown reasons are required only for unknown records.
%
% Target: MATLAB R2020b or newer; base MATLAB.
% No classification, authentication, publication, or actuation occurs.
%
% Sovereign attribution, document credit only:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
%
% SPDX-License-Identifier: MIT OR Apache-2.0

    if nargin ~= 2
        error('consentlens:ArgumentCount', ...
            'Supply dispositions and unknownReasons.');
    end

    if ~isstring(dispositions) || ~isstring(unknownReasons)
        error('consentlens:InvalidType', ...
            'Both inputs must be string arrays.');
    end

    if (~isempty(dispositions) && ~isvector(dispositions)) || ...
            (~isempty(unknownReasons) && ~isvector(unknownReasons))
        error('consentlens:InvalidShape', ...
            'Inputs must be vectors or empty arrays.');
    end

    dispositions = dispositions(:);
    unknownReasons = unknownReasons(:);

    if numel(dispositions) ~= numel(unknownReasons)
        error('consentlens:LengthMismatch', ...
            'Inputs must contain the same number of records.');
    end

    if any(ismissing(dispositions)) || any(ismissing(unknownReasons))
        error('consentlens:MissingValue', ...
            'Missing strings are not valid states.');
    end

    allowed = ["conforming", "nonconforming", "unknown", "retired"];
    if any(~ismember(dispositions, allowed))
        error('consentlens:InvalidDisposition', ...
            'Unsupported disposition.');
    end

    allowedReasons = [
        "not_started"
        "evidence_incomplete"
        "evidence_expired"
        "conflicting_evidence"
        "applicability_unresolved"
        "multiple_unresolved_causes"
    ];

    isUnknown = dispositions == "unknown";

    if any(isUnknown & ~ismember(unknownReasons, allowedReasons))
        error('consentlens:InvalidUnknownReason', ...
            'Each unknown record requires a supported reason.');
    end

    if any(~isUnknown & unknownReasons ~= "")
        error('consentlens:UnexpectedReason', ...
            'Only unknown records may have an unknown reason.');
    end

    c = sum(dispositions == "conforming");
    f = sum(dispositions == "nonconforming");
    u = sum(isUnknown);
    retired = sum(dispositions == "retired");
    cohort = c + f + u;
    resolved = c + f;

    ledger = struct();
    ledger.SchemaVersion = "1.0.0";
    ledger.TotalRecords = numel(dispositions);
    ledger.CurrentCohortCount = cohort;
    ledger.RetiredCount = retired;
    ledger.ResolvedCount = resolved;
    ledger.ResolvedPassCount = c;
    ledger.ConformingCount = c;
    ledger.NonconformingCount = f;
    ledger.UnknownCount = u;

    ledger.DeterminateConformance = makeRatio(c, resolved);
    ledger.DeterminateCoverage = makeRatio(resolved, cohort);

    if cohort == 0
        ledger.UnresolvedStatusBounds = [NaN, NaN];
        ledger.BoundsStatus = "undefined_empty_cohort";
    else
        ledger.UnresolvedStatusBounds = ...
            [c / cohort, (c + u) / cohort];
        ledger.BoundsStatus = "defined";
    end

    reasonCounts = zeros(numel(allowedReasons), 1);
    for j = 1:numel(allowedReasons)
        reasonCounts(j) = sum( ...
            isUnknown & unknownReasons == allowedReasons(j));
    end

    ledger.UnknownReasonLabels = allowedReasons;
    ledger.UnknownReasonCounts = reasonCounts;

    ledger.Scope = ...
        "Supplied current review cohort; not all deployed workflows.";
    ledger.BoundsAssumption = ...
        "Determinate classifications remain fixed.";
    ledger.AuthorizesExternalAction = false;
    ledger.RuntimeVersion = version;
end

function ratio = makeRatio(numerator, denominator)
    ratio = struct();
    ratio.Numerator = numerator;
    ratio.Denominator = denominator;

    if denominator == 0
        ratio.Value = NaN;
        ratio.MathematicalStatus = "undefined_zero_denominator";
        ratio.DisplayText = "Not available: no applicable denominator.";
    else
        ratio.Value = numerator / denominator;
        ratio.MathematicalStatus = "defined";
        ratio.DisplayText = "";
    end
end
