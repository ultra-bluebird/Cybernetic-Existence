function result = remedy_followup(followupDays, recurrenceDays, horizonDays)
% REMEDY_FOLLOWUP Descriptive durability and unresolved-outcome bounds.
%
% followupDays:
%   Documented observation duration after each verified correction.
%
% recurrenceDays:
%   First observed recurrence time, or NaN if none observed.
%
% horizonDays:
%   Positive follow-up horizon; recurrence at the horizon counts as failure.
%
% Assumes documented observation can establish recurrence-free follow-up.
% Does not infer unobserved events or establish causal remedy effectiveness.
%
% Target: MATLAB R2020b or newer; base MATLAB.
%
% Sovereign attribution, document credit only:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
%
% SPDX-License-Identifier: MIT OR Apache-2.0

    if nargin ~= 3
        error('consentlens:ArgumentCount', ...
            'Supply follow-up durations, recurrence times, and horizon.');
    end

    validateattributes(horizonDays, {'numeric'}, ...
        {'real', 'finite', 'scalar', 'positive'});

    if ~isnumeric(followupDays) || ~isreal(followupDays) || ...
            ~isnumeric(recurrenceDays) || ~isreal(recurrenceDays)
        error('consentlens:InvalidType', ...
            'Durations must be real numeric arrays.');
    end

    if (~isempty(followupDays) && ~isvector(followupDays)) || ...
            (~isempty(recurrenceDays) && ~isvector(recurrenceDays))
        error('consentlens:InvalidShape', ...
            'Inputs must be vectors or empty arrays.');
    end

    followup = double(followupDays(:));
    recurrence = double(recurrenceDays(:));
    horizon = double(horizonDays);

    if numel(followup) ~= numel(recurrence)
        error('consentlens:LengthMismatch', ...
            'Each correction needs one follow-up and recurrence entry.');
    end

    if any(~isfinite(followup)) || any(followup < 0)
        error('consentlens:InvalidFollowup', ...
            'Follow-up durations must be finite and nonnegative.');
    end

    observed = ~isnan(recurrence);

    if any(~isfinite(recurrence(observed))) || ...
            any(recurrence(observed) < 0) || ...
            any(recurrence(observed) > followup(observed))
        error('consentlens:InvalidRecurrence', ...
            'Observed recurrence must lie within documented follow-up.');
    end

    failed = observed & recurrence <= horizon;
    complete = followup >= horizon;
    succeeded = complete & ~failed;
    unresolved = ~failed & ~succeeded;

    N = numel(followup);
    s = sum(succeeded);
    f = sum(failed);
    u = sum(unresolved);
    b = sum(complete);

    status = repmat("unresolved", N, 1);
    status(failed) = "recurrence_observed";
    status(succeeded) = "recurrence_free_through_horizon";

    result = struct();
    result.SchemaVersion = "1.0.0";
    result.HorizonDays = horizon;
    result.CorrectionCount = N;
    result.CompleteFollowupCount = b;
    result.RecurrenceFreeCount = s;
    result.KnownRecurrenceCount = f;
    result.PartialFollowupRecurrenceCount = sum(failed & ~complete);
    result.UnresolvedCount = u;
    result.Status = status;
    result.AuthorizesExternalAction = false;

    result.CompleteCaseRate = ratio(s, b);

    if N == 0
        result.EventualDurabilityBounds = [NaN, NaN];
        result.BoundsStatus = "undefined_empty_cohort";
        result.OutcomeResolutionCoverage = NaN;
    else
        result.EventualDurabilityBounds = [s / N, (s + u) / N];
        result.BoundsStatus = "defined";
        result.OutcomeResolutionCoverage = (s + f) / N;
    end

    result.Interpretation = ...
        "Observed-cohort description and logical bounds, not confidence intervals.";
    result.RuntimeVersion = version;
end

function value = ratio(numerator, denominator)
    value = struct( ...
        'Numerator', numerator, ...
        'Denominator', denominator, ...
        'Value', NaN, ...
        'Status', "undefined_zero_denominator");

    if denominator > 0
        value.Value = numerator / denominator;
        value.Status = "defined";
    end
end
