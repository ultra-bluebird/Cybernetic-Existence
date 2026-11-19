function result = bounded_assurance_metrics( ...
    evidence, positiveSupportValid, unresolvedFailure)
% BOUNDED_ASSURANCE_METRICS
% Classifies bounded reviews and reports unresolved-status bounds.
%
% evidence:
%   N-by-K numeric matrix: pass=1, fail=0, unknown=-1.
%
% positiveSupportValid:
%   N-by-K logical matrix. False invalidates positive support only.
%   It does not erase an observed failure.
%
% unresolvedFailure:
%   N-by-1 logical vector of retained, applicable unresolved findings.
%
% Applicability, scope, expiry, configuration binding, and clock handling
% must be evaluated upstream. This function grants no authority.
%
% With no arguments, runs an explicitly synthetic demonstration.
%
% SPDX-License-Identifier: MIT OR Apache-2.0

    synthetic = (nargin == 0);

    if synthetic
        evidence = -ones(100, 3);
        evidence(1, :) = 1;
        positiveSupportValid = true(size(evidence));
        unresolvedFailure = false(100, 1);
    elseif nargin ~= 3
        error('bounded_assurance_metrics:ArgumentCount', ...
            'Supply all three inputs, or no inputs.');
    end

    if ~isnumeric(evidence) || ~isreal(evidence) || ...
            ~ismatrix(evidence) || isempty(evidence) || ...
            any(~isfinite(evidence(:))) || ...
            any(~ismember(evidence(:), [-1, 0, 1]))
        error('bounded_assurance_metrics:InvalidEvidence', ...
            'Evidence must be a nonempty matrix using only -1, 0, 1.');
    end

    if ~islogical(positiveSupportValid) || ...
            ~isequal(size(positiveSupportValid), size(evidence))
        error('bounded_assurance_metrics:InvalidSupport', ...
            'Support validity must be a same-sized logical matrix.');
    end

    N = size(evidence, 1);

    if ~islogical(unresolvedFailure) || ...
            ~isequal(size(unresolvedFailure), [N, 1])
        error('bounded_assurance_metrics:InvalidFindings', ...
            'Unresolved findings must be an N-by-1 logical vector.');
    end

    effective = double(evidence);
    effective(effective == 1 & ~positiveSupportValid) = -1;

    failed = any(effective == 0, 2) | unresolvedFailure;
    passed = all(effective == 1, 2) & ~failed;

    status = repmat("unknown", N, 1);
    status(passed) = "conforming";
    status(failed) = "nonconforming";

    c = sum(status == "conforming");
    f = sum(status == "nonconforming");
    u = sum(status == "unknown");
    determinate = c + f;

    if determinate == 0
        determinateRate = NaN;
        determinateEstimable = false;
    else
        determinateRate = c / determinate;
        determinateEstimable = true;
    end

    result = struct();
    result.SyntheticExample = synthetic;
    result.Status = status;
    result.EffectiveEvidence = effective;
    result.CohortSize = N;
    result.ConformingCount = c;
    result.NonconformingCount = f;
    result.UnknownCount = u;
    result.DeterminateConformance = determinateRate;
    result.DeterminateConformanceEstimable = determinateEstimable;
    result.DeterminateCoverage = determinate / N;
    result.ResolvedConformanceBounds = [c / N, (c + u) / N];
    result.Interpretation = ...
        "Reviewed-cohort bounds; not confidence intervals or authority.";
    result.RuntimeVersion = version;

    if synthetic
        assert(c == 1 && f == 0 && u == 99);
        assert(result.DeterminateConformance == 1);
        assert(result.DeterminateCoverage == 0.01);
        assert(isequal( ...
            result.ResolvedConformanceBounds, [0.01, 1]));

        precedence = bounded_assurance_metrics( ...
            [0, -1, 1], true(1, 3), false);
        assert(precedence.Status == "nonconforming");

        expired = bounded_assurance_metrics( ...
            [1, 1, 1], [true, false, true], false);
        assert(expired.Status == "unknown");

        retained = bounded_assurance_metrics( ...
            [-1, -1, -1], false(1, 3), true);
        assert(retained.Status == "nonconforming");

        unsupported = bounded_assurance_metrics( ...
            -ones(2, 3), false(2, 3), false(2, 1));
        assert(~unsupported.DeterminateConformanceEstimable);
        assert(isnan(unsupported.DeterminateConformance));
    end
end
