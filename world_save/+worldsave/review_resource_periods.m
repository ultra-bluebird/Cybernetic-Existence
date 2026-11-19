function result = review_resource_periods( ...
    capacityLower, capacityUpper, needLower, needUpper, ...
    periodChecks, resourceNames, units)
% REVIEW_RESOURCE_PERIODS
% T-by-K numeric intervals describe each declared planning period.
% NaN means unresolved, not zero.
% periodChecks: T-by-1 strings P/F/U for required nonnumeric arrangements.
%
% Does not assess queue deadlines, legal duties, authority, or actual service.
% Target: MATLAB R2020b or newer; base MATLAB.
% SPDX-License-Identifier: MIT OR Apache-2.0

    if nargin ~= 7
        error('worldsave:ArgumentCount', 'Supply all seven inputs.');
    end

    arrays = {capacityLower, capacityUpper, needLower, needUpper};

    if ~isnumeric(capacityLower) || ~isreal(capacityLower) || ...
            ~ismatrix(capacityLower) || isempty(capacityLower)
        error('worldsave:InvalidCapacity', ...
            'Supply nonempty period-by-resource matrices.');
    end

    shape = size(capacityLower);
    T = shape(1);
    K = shape(2);

    if T > 240 || K > 16
        error('worldsave:PlanningLimit', ...
            'Local limits are 240 periods and 16 resources.');
    end

    for j = 1:4
        value = arrays{j};
        if ~isnumeric(value) || ~isreal(value) || ...
                ~isequal(size(value), shape) || ...
                any(isinf(value(:))) || ...
                any(value(~isnan(value)) < 0)
            error('worldsave:InvalidResourceInterval', ...
                'Use matching nonnegative matrices or NaN.');
        end
    end

    if any(capacityLower(:) > capacityUpper(:)) || ...
            any(needLower(:) > needUpper(:))
        error('worldsave:ContradictoryResourceInterval', ...
            'A known interval lower bound exceeds its upper bound.');
    end

    if ~isstring(periodChecks) || ...
            ~isequal(size(periodChecks), [T, 1]) || ...
            any(ismissing(periodChecks)) || ...
            any(~ismember(periodChecks, ["P", "F", "U"]))
        error('worldsave:InvalidPeriodChecks', ...
            'Supply one P/F/U arrangement result per period.');
    end

    validateLabels(resourceNames, K, true);
    validateLabels(units, K, false);

    cells = repmat("U", T, K);
    periods = repmat("U", T, 1);

    for t = 1:T
        for k = 1:K
            if ~isnan(capacityLower(t, k)) && ...
                    ~isnan(needUpper(t, k)) && ...
                    capacityLower(t, k) >= needUpper(t, k)
                cells(t, k) = "P";
            elseif ~isnan(capacityUpper(t, k)) && ...
                    ~isnan(needLower(t, k)) && ...
                    capacityUpper(t, k) < needLower(t, k)
                cells(t, k) = "F";
            end
        end

        states = [cells(t, :), periodChecks(t)];
        if any(states == "F")
            periods(t) = "F";
        elseif all(states == "P")
            periods(t) = "P";
        end
    end

    firstNonPass = find(periods ~= "P", 1);
    if isempty(firstNonPass)
        supportedPrefix = T;
    else
        supportedPrefix = firstNonPass - 1;
    end

    result = struct();
    result.SchemaVersion = "1.0.0";
    result.SovereignAttribution = ...
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
    result.AttributionUse = "document_credit_only";
    result.ResourceNames = resourceNames(:);
    result.Units = units(:);
    result.ResourceResults = cells;
    result.PeriodResults = periods;
    result.SupportedPrefixPeriods = supportedPrefix;
    result.FirstNonPassPeriod = firstNonPass;
    result.PeriodCoverageAssumptions = ...
        "Supplied bounds must cover the whole declared period.";
    result.QueueServiceLevels = "not_evaluated";
    result.ExistingObligationsModified = false;
    result.RuntimeVersion = version;
end

function validateLabels(value, count, requireUnique)
    if ~isstring(value) || ~isvector(value) || ...
            numel(value) ~= count || any(ismissing(value(:))) || ...
            any(strlength(strtrim(value(:))) == 0)
        error('worldsave:InvalidLabels', ...
            'Supply nonempty labels for all resources and units.');
    end

    if requireUnique && numel(unique(value)) ~= count
        error('worldsave:DuplicateResource', ...
            'Resource labels must be unique.');
    end
end
