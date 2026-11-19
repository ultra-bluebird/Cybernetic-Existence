function result = consent_lens_review_metrics(counts)
% CONSENT_LENS_REVIEW_METRICS
% Aggregate review metrics for a defined cohort and review scope.
%
% Usage:
%   result = consent_lens_review_metrics();
%   result = consent_lens_review_metrics([72, 8, 20]);
%
% Input order:
%   [conforming, nonconforming, unknown]
%
% Bounds concern unresolved classifications in the supplied cohort.
% They are not confidence intervals or population generalizations.
%
% SPDX-License-Identifier: MIT OR Apache-2.0

    synthetic = (nargin == 0);

    if synthetic
        counts = [72, 8, 20];
    end

    if ~isnumeric(counts) || ~isreal(counts) || ...
            ~isvector(counts) || numel(counts) ~= 3
        error('consent_lens_review_metrics:InvalidInput', ...
            'Supply three real numeric counts: [conforming, nonconforming, unknown].');
    end

    counts = double(counts(:).');

    if any(~isfinite(counts)) || any(counts < 0) || ...
            any(counts ~= fix(counts)) || any(counts > flintmax)
        error('consent_lens_review_metrics:InvalidCount', ...
            'Counts must be finite, nonnegative, exactly representable integers.');
    end

    total = 0;
    for k = 1:3
        if counts(k) > flintmax - total
            error('consent_lens_review_metrics:TotalTooLarge', ...
                'Combined counts exceed the supported exact integer range.');
        end
        total = total + counts(k);
    end

    conforming = counts(1);
    nonconforming = counts(2);
    unknown = counts(3);
    resolved = conforming + nonconforming;

    result = struct();
    result.SyntheticExample = synthetic;
    result.Conforming = conforming;
    result.Nonconforming = nonconforming;
    result.Unknown = unknown;
    result.Reviewed = total;
    result.Resolved = resolved;
    result.RuntimeVersion = version;
    result.Method = "Resolved-case rate and missing-evidence bounds";
    result.Scope = "Supplied reviewed cohort only";
    result.AuthorizesExternalAction = false;
    result.IsCertification = false;
    result.IsConfidenceInterval = false;

    if resolved > 0
        result.ResolvedConformanceRate = conforming / resolved;
        result.ResolvedRateStatus = "estimable";
    else
        result.ResolvedConformanceRate = NaN;
        result.ResolvedRateStatus = "not estimable";
    end

    if total > 0
        result.ResolutionCoverage = resolved / total;
        result.UnknownRate = unknown / total;
        result.ConformanceLower = conforming / total;
        result.ConformanceUpper = (conforming + unknown) / total;
        result.NonconformanceLower = nonconforming / total;
        result.NonconformanceUpper = (nonconforming + unknown) / total;
        result.BoundWidth = unknown / total;
        result.CohortRateStatus = "estimable";

        tolerance = 64 * eps;
        calculatedWidth = ...
            result.ConformanceUpper - result.ConformanceLower;

        assert(abs(calculatedWidth - result.BoundWidth) <= tolerance);
        assert(result.ConformanceLower <= result.ConformanceUpper);
        assert(result.ConformanceLower >= 0);
        assert(result.ConformanceUpper <= 1);
    else
        result.ResolutionCoverage = NaN;
        result.UnknownRate = NaN;
        result.ConformanceLower = NaN;
        result.ConformanceUpper = NaN;
        result.NonconformanceLower = NaN;
        result.NonconformanceUpper = NaN;
        result.BoundWidth = NaN;
        result.CohortRateStatus = "not estimable";
    end

    result.Interpretation = ...
        ["Valid only if review units share the stated scope and period; " + ...
         "resolved classifications remain valid; unknown cases resolve " + ...
         "to conforming or nonconforming."];

    if synthetic
        assert(abs(result.ResolvedConformanceRate - 0.90) < 1e-12);
        assert(abs(result.ConformanceLower - 0.72) < 1e-12);
        assert(abs(result.ConformanceUpper - 0.92) < 1e-12);

        updated = consent_lens_review_metrics([77, 18, 5]);
        assert(abs(updated.ResolvedConformanceRate - 77 / 95) < 1e-12);
        assert(abs(updated.ConformanceLower - 0.77) < 1e-12);
        assert(abs(updated.ConformanceUpper - 0.82) < 1e-12);

        unresolved = consent_lens_review_metrics([0, 0, 100]);
        assert(isnan(unresolved.ResolvedConformanceRate));
        assert(unresolved.ConformanceLower == 0);
        assert(unresolved.ConformanceUpper == 1);

        empty = consent_lens_review_metrics([0, 0, 0]);
        assert(isnan(empty.UnknownRate));
        assert(isnan(empty.ConformanceLower));

        failed = consent_lens_review_metrics([0, 10, 0]);
        assert(failed.ResolvedConformanceRate == 0);
        assert(failed.ConformanceUpper == 0);

        passed = consent_lens_review_metrics([10, 0, 0]);
        assert(passed.ResolvedConformanceRate == 1);
        assert(passed.ConformanceLower == 1);
    end
end
