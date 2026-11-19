function result = report_task_vector(counts)
% REPORT_TASK_VECTOR
% Descriptive comprehension reporting by task type.
%
% Required columns:
%   TaskType, Correct, Incorrect, ExplicitUncertainty, Missing
%
% Required task types:
%   meaning, derived, inference, consent, correction
%
% Counts must represent the stated study condition and scoring rubric.
% No independence, population representativeness, or validity is inferred.
%
% Target: MATLAB R2020b or newer; base MATLAB.
% SPDX-License-Identifier: MIT OR Apache-2.0

    if nargin ~= 1 || ~istable(counts)
        error('comprehension:InvalidInput', ...
            'Supply an aggregate-count table.');
    end

    columns = {
        'TaskType', 'Correct', 'Incorrect', ...
        'ExplicitUncertainty', 'Missing'
    };

    if numel(counts.Properties.VariableNames) ~= numel(columns) || ...
            ~all(ismember(columns, counts.Properties.VariableNames))
        error('comprehension:InvalidColumns', ...
            'Supply exactly the five documented columns.');
    end

    required = [
        "meaning"
        "derived"
        "inference"
        "consent"
        "correction"
    ];

    if height(counts) ~= numel(required) || ...
            ~isstring(counts.TaskType) || ...
            ~isequal(size(counts.TaskType), [5, 1]) || ...
            any(ismissing(counts.TaskType)) || ...
            numel(unique(counts.TaskType)) ~= 5
        error('comprehension:InvalidTaskTypes', ...
            'Supply one row for each required task type.');
    end

    [present, position] = ismember(required, counts.TaskType);
    if ~all(present)
        error('comprehension:MissingTaskType', ...
            'The required task vocabulary is incomplete.');
    end

    counts = counts(position, columns);
    values = zeros(5, 4);

    for k = 2:5
        value = counts.(columns{k});
        if ~isnumeric(value) || ~isreal(value) || ...
                ~isequal(size(value), [5, 1]) || ...
                any(~isfinite(value)) || ...
                any(value < 0) || ...
                any(value ~= fix(value)) || ...
                any(value > floor(flintmax / 4))
            error('comprehension:InvalidCounts', ...
                'Counts must be supported nonnegative integers.');
        end
        values(:, k - 1) = double(value);
    end

    correct = values(:, 1);
    incorrect = values(:, 2);
    uncertainty = values(:, 3);
    missing = values(:, 4);

    scorable = correct + incorrect;
    total = sum(values, 2);

    correctRate = divideOrUndefined(correct, scorable);
    coverage = divideOrUndefined(scorable, total);
    uncertaintyRate = divideOrUndefined(uncertainty, total);
    missingRate = divideOrUndefined(missing, total);

    report = counts;
    report.TotalApplicableResponses = total;
    report.ScorableResponses = scorable;
    report.ScorableCorrectRate = correctRate;
    report.ScorableCoverage = coverage;
    report.ExplicitUncertaintyRate = uncertaintyRate;
    report.MissingRate = missingRate;

    result = struct();
    result.SchemaVersion = "1.0.0";
    result.SovereignAttribution = ...
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
    result.AttributionUse = "document_credit_only";
    result.TaskOrder = required;
    result.ComprehensionVector = correctRate;
    result.Report = report;
    result.Composite = "not_calculated";
    result.UndefinedRateRepresentation = "NaN";
    result.InstrumentValidity = "not_evaluated";
    result.RuntimeVersion = version;
end

function output = divideOrUndefined(numerator, denominator)
    output = NaN(size(numerator));
    usable = denominator > 0;
    output(usable) = numerator(usable) ./ denominator(usable);
end
