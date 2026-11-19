function result = review_cumulative_drift( ...
    values, originalBounds, adjacentLimits, fieldNames, units)
% REVIEW_CUMULATIVE_DRIFT
% Compare declared numeric configurations with:
%   1. Original field bounds.
%   2. Maximum absolute adjacent changes.
%
% values:         T-by-D configurations in supplied order.
% originalBounds: 2-by-D [lower; upper].
% adjacentLimits: 1-by-D nonnegative local magnitude limits.
% fieldNames:     D unique nonempty string labels.
% units:          D nonempty string unit labels.
%
% NaN means unresolved, not unlimited.
% Values use exact integer units within the supported range.
%
% Target: MATLAB R2020b or newer; base MATLAB.
% SPDX-License-Identifier: MIT OR Apache-2.0

    if nargin ~= 5
        error('worldsave:ArgumentCount', ...
            'Supply values, bounds, limits, names, and units.');
    end

    if ~isnumeric(values) || ~isreal(values) || ...
            ~ismatrix(values) || isempty(values)
        error('worldsave:InvalidValues', ...
            'Values must be a nonempty real numeric matrix.');
    end

    [T, D] = size(values);

    if ~isnumeric(originalBounds) || ~isreal(originalBounds) || ...
            ~isequal(size(originalBounds), [2, D]) || ...
            ~isnumeric(adjacentLimits) || ~isreal(adjacentLimits) || ...
            ~isequal(size(adjacentLimits), [1, D])
        error('worldsave:InvalidDimensions', ...
            'Bounds and adjacent limits must match the field count.');
    end

    validateNumbers(values);
    validateNumbers(originalBounds);
    validateNumbers(adjacentLimits);

    knownLimits = ~isnan(adjacentLimits);
    if any(adjacentLimits(knownLimits) < 0)
        error('worldsave:NegativeLimit', ...
            'Adjacent magnitude limits cannot be negative.');
    end

    knownBounds = all(~isnan(originalBounds), 1);
    if any(originalBounds(1, knownBounds) > ...
            originalBounds(2, knownBounds))
        error('worldsave:ContradictoryBounds', ...
            'A known lower bound exceeds its upper bound.');
    end

    validateLabels(fieldNames, D, true);
    validateLabels(units, D, false);

    values = double(values);
    originalBounds = double(originalBounds);
    adjacentLimits = double(adjacentLimits);

    originalCells = repmat("U", T, D);
    adjacentCells = repmat("U", T, D);
    originalResult = repmat("U", T, 1);
    adjacentResult = repmat("not_assessed_initial", T, 1);

    for t = 1:T
        for d = 1:D
            value = values(t, d);
            lower = originalBounds(1, d);
            upper = originalBounds(2, d);

            if ~isnan(value)
                if (~isnan(lower) && value < lower) || ...
                        (~isnan(upper) && value > upper)
                    originalCells(t, d) = "F";
                elseif ~isnan(lower) && ~isnan(upper)
                    originalCells(t, d) = "P";
                end
            end

            if t > 1
                previous = values(t - 1, d);
                limit = adjacentLimits(d);

                if ~isnan(value) && ~isnan(previous) && ~isnan(limit)
                    if abs(value - previous) <= limit
                        adjacentCells(t, d) = "P";
                    else
                        adjacentCells(t, d) = "F";
                    end
                end
            end
        end

        originalResult(t) = aggregate(originalCells(t, :));

        if t > 1
            adjacentResult(t) = aggregate(adjacentCells(t, :));
        end
    end

    result = struct();
    result.SchemaVersion = "1.0.0";
    result.SovereignAttribution = ...
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
    result.AttributionUse = "document_credit_only";
    result.FieldNames = fieldNames(:);
    result.Units = units(:);
    result.OriginalEnvelopeByField = originalCells;
    result.AdjacentMagnitudeByField = adjacentCells;
    result.OriginalEnvelopeResult = originalResult;
    result.AdjacentMagnitudeResult = adjacentResult;
    result.LocalPassOriginalFail = ...
        adjacentResult == "P" & originalResult == "F";
    result.FirstEstablishedOriginalExceedance = ...
        find(originalResult == "F", 1);
    result.SemanticMateriality = "not_evaluated";
    result.ChangeAuthorization = "not_evaluated";
    result.RuntimeVersion = version;
end

function validateNumbers(value)
    safeMagnitude = 2^52 - 1;
    known = ~isnan(value);

    if any(isinf(value(:))) || ...
            any(abs(value(known)) > safeMagnitude) || ...
            any(value(known) ~= fix(value(known)))
        error('worldsave:UnsupportedNumber', ...
            'Use supported integer units or NaN for unresolved values.');
    end
end

function validateLabels(value, count, requireUnique)
    if ~isstring(value) || ~isvector(value) || ...
            numel(value) ~= count || any(ismissing(value(:))) || ...
            any(strlength(strtrim(value(:))) == 0)
        error('worldsave:InvalidLabels', ...
            'Supply the required nonempty string labels.');
    end

    if requireUnique && numel(unique(value)) ~= count
        error('worldsave:DuplicateField', ...
            'Field labels must be unique.');
    end
end

function status = aggregate(states)
    if any(states == "F")
        status = "F";
    elseif all(states == "P")
        status = "P";
    else
        status = "U";
    end
end
