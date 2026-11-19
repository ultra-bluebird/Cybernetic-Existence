function result = review_chronology_horizon( ...
    timeBounds, availableBounds, requiredBounds)
% REVIEW_CHRONOLOGY_HORIZON
% Time-chain feasibility and non-compensating resource assessment.
%
% timeBounds:
%   N-by-2 [earliest, latest] timestamps in one common time basis.
%   Rows are an explicitly required event order; N must be at least 3.
%
% availableBounds and requiredBounds:
%   T-by-R-by-2 arrays: lower and upper capacity by period and resource.
%   Matching cells must use the same unit and accounting period.
%
% NaN means an unresolved bound. Inputs may not contain Inf.
%
% Target: MATLAB R2020b or newer; base MATLAB.
% Does not verify clocks, authority, resources, or real-world operation.
%
% SPDX-License-Identifier: MIT OR Apache-2.0

    if nargin ~= 3
        error('worldsave:ArgumentCount', ...
            'Supply time bounds, available bounds, and required bounds.');
    end

    if ~isnumeric(timeBounds) || ~isreal(timeBounds) || ...
            ~ismatrix(timeBounds) || size(timeBounds, 2) ~= 2 || ...
            size(timeBounds, 1) < 3 || size(timeBounds, 1) > 256
        error('worldsave:InvalidTimeShape', ...
            'Time bounds must be an N-by-2 matrix, with 3 <= N <= 256.');
    end

    validateFiniteOrUnknown(timeBounds, false);

    if ~isnumeric(availableBounds) || ~isreal(availableBounds) || ...
            ~isnumeric(requiredBounds) || ~isreal(requiredBounds) || ...
            ~isequal(size(availableBounds), size(requiredBounds)) || ...
            ndims(availableBounds) ~= 3 || ...
            size(availableBounds, 3) ~= 2 || ...
            size(availableBounds, 1) < 1 || ...
            size(availableBounds, 1) > 600 || ...
            size(availableBounds, 2) < 1 || ...
            size(availableBounds, 2) > 32
        error('worldsave:InvalidResourceShape', ...
            'Use matching nonempty T-by-R-by-2 resource arrays.');
    end

    validateFiniteOrUnknown(availableBounds, true);
    validateFiniteOrUnknown(requiredBounds, true);

    timeBounds = double(timeBounds);
    availableBounds = double(availableBounds);
    requiredBounds = double(requiredBounds);

    checkIntervals(timeBounds(:, 1), timeBounds(:, 2));

    aLower = availableBounds(:, :, 1);
    aUpper = availableBounds(:, :, 2);
    oLower = requiredBounds(:, :, 1);
    oUpper = requiredBounds(:, :, 2);

    checkIntervals(aLower, aUpper);
    checkIntervals(oLower, oUpper);

    lower = timeBounds(:, 1);
    upper = timeBounds(:, 2);

    lower(isnan(lower)) = -Inf;
    upper(isnan(upper)) = Inf;

    earliest = cummax(lower);
    jointlyFeasible = all(earliest <= upper);
    robustOrder = all(upper(1:end-1) <= lower(2:end));

    if ~jointlyFeasible
        chronology = "F";
        chronologyReason = "no_jointly_ordered_assignment";
    elseif robustOrder
        chronology = "P";
        chronologyReason = "all_modeled_assignments_ordered";
    else
        chronology = "U";
        chronologyReason = "ordering_depends_on_unresolved_times";
    end

    cellState = repmat("U", size(aLower));

    supported = ~isnan(aLower) & ~isnan(oUpper) & ...
        aLower >= oUpper;
    insufficient = ~isnan(aUpper) & ~isnan(oLower) & ...
        aUpper < oLower;

    cellState(supported) = "P";
    cellState(insufficient) = "F";

    periodState = repmat("U", size(cellState, 1), 1);

    for t = 1:size(cellState, 1)
        if any(cellState(t, :) == "F")
            periodState(t) = "F";
        elseif all(cellState(t, :) == "P")
            periodState(t) = "P";
        end
    end

    firstUnsupported = find(periodState ~= "P", 1);

    if isempty(firstUnsupported)
        supportedPrefix = numel(periodState);
    else
        supportedPrefix = firstUnsupported - 1;
    end

    result = struct();
    result.SchemaVersion = "1.0.0";
    result.SovereignAttribution = ...
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
    result.AttributionUse = "document_credit_only";
    result.ChronologyResult = chronology;
    result.ChronologyReason = chronologyReason;
    result.ResourceByPeriod = cellState;
    result.PeriodResult = periodState;
    result.SupportedPrefixPeriods = supportedPrefix;
    result.FirstUnresolvedOrInsufficientPeriod = firstUnsupported;
    result.ClockProvenance = "supplied_not_verified";
    result.ResourceEvidence = "supplied_not_verified";
    result.CommitmentAuthority = "not_evaluated";
    result.OrdinaryAccess = "not_decided";
    result.RuntimeVersion = version;
end

function validateFiniteOrUnknown(value, nonnegative)
    if any(isinf(value(:)))
        error('worldsave:InfiniteInput', ...
            'Use finite values or NaN for unresolved bounds.');
    end

    known = ~isnan(value);
    if nonnegative && any(value(known) < 0)
        error('worldsave:NegativeResource', ...
            'Resource bounds must be nonnegative.');
    end
end

function checkIntervals(lower, upper)
    known = ~isnan(lower) & ~isnan(upper);
    if any(lower(known) > upper(known))
        error('worldsave:ContradictoryInterval', ...
            'A supplied lower bound exceeds its upper bound.');
    end
end
