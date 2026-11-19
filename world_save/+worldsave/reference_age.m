function result = reference_age(nowBounds, checkpointBounds, maxAgeSeconds)
% REFERENCE_AGE
% Three-state age assessment using bounded timestamps.
%
% Inputs:
%   nowBounds:        [earliest, latest] evaluation time, or [].
%   checkpointBounds: [earliest, latest] checkpoint time, or [].
%   maxAgeSeconds:    nonnegative integer age limit.
%
% All timestamps use integer seconds from one declared common origin.
% Bounds model feasible time pairs without additional linking constraints.
%
% Target: MATLAB R2020b or newer; base MATLAB.
%
% This function does not authenticate timestamps, verify commitments,
% establish latest-history status, publish records, or operate systems.
%
% SPDX-License-Identifier: MIT OR Apache-2.0

    if nargin ~= 3
        error('worldsave:ArgumentCount', ...
            'Supply evaluation bounds, checkpoint bounds, and age limit.');
    end

    safeBound = 2^52 - 1;

    if ~isnumeric(maxAgeSeconds) || ~isreal(maxAgeSeconds) || ...
            ~isscalar(maxAgeSeconds) || ~isfinite(maxAgeSeconds) || ...
            maxAgeSeconds < 0 || maxAgeSeconds > safeBound || ...
            maxAgeSeconds ~= fix(maxAgeSeconds)
        error('worldsave:InvalidAgeLimit', ...
            'Maximum age must be a supported nonnegative integer.');
    end

    validateBounds(nowBounds, safeBound, 'evaluation');
    validateBounds(checkpointBounds, safeBound, 'checkpoint');

    result = struct();
    result.SchemaVersion = "1.0.0";
    result.SovereignAttribution = ...
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
    result.AttributionUse = "document_credit_only";
    result.Units = "seconds";
    result.MaximumAgeSeconds = double(maxAgeSeconds);
    result.AgeBoundsSeconds = [NaN, NaN];
    result.AgeResult = "U";
    result.Reason = "time_bounds_unavailable";
    result.Model = "rectangular_bounded_time_pairs";
    result.ReferenceCurrencyEvaluated = false;
    result.TimestampAuthorityEvaluated = false;
    result.ExternalActionAuthorized = false;
    result.RuntimeVersion = version;

    if isempty(nowBounds) || isempty(checkpointBounds)
        return;
    end

    nowBounds = double(nowBounds);
    checkpointBounds = double(checkpointBounds);

    lower = nowBounds(1) - checkpointBounds(2);
    upper = nowBounds(2) - checkpointBounds(1);

    result.AgeBoundsSeconds = [lower, upper];

    if lower >= 0 && upper <= maxAgeSeconds
        result.AgeResult = "P";
        result.Reason = "all_modeled_ages_within_limit";
    elseif upper < 0
        result.AgeResult = "F";
        result.Reason = "checkpoint_definitely_future_dated";
    elseif lower > maxAgeSeconds
        result.AgeResult = "F";
        result.Reason = "checkpoint_definitely_exceeds_age_limit";
    else
        result.AgeResult = "U";
        result.Reason = "modeled_ages_cross_validity_boundary";
    end
end

function validateBounds(value, safeBound, label)
    if ~isnumeric(value) || ~isreal(value)
        error('worldsave:InvalidTimeBounds', ...
            '%s bounds must be real numeric values.', label);
    end

    if isempty(value)
        return;
    end

    if ~isequal(size(value), [1, 2]) || ...
            any(~isfinite(value)) || ...
            any(abs(value) > safeBound) || ...
            any(value ~= fix(value)) || value(1) > value(2)
        error('worldsave:InvalidTimeBounds', ...
            '%s bounds must be ordered supported integer seconds.', label);
    end
end
