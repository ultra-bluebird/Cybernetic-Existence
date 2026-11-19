function result = review_prerequisites(inventory)
% REVIEW_PREREQUISITES
% Aggregate supplied world-save prerequisite review results.
%
% Target: MATLAB R2020b or newer; base MATLAB.
% Required string columns: Category, Requirement, Result.
%
% This function does not establish milestone acceptance, authority,
% evidence truth, clinical safety, or physical irreversibility.
%
% SOVEREIGN-ATTRIBUTION:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
%
% Attribution is document credit only.
% SPDX-License-Identifier: MIT OR Apache-2.0

    if nargin ~= 1 || ~istable(inventory)
        error('worldsave:InvalidInventory', ...
            'Supply a table of reviewed prerequisite results.');
    end

    requiredColumns = {'Category', 'Requirement', 'Result'};

    if numel(inventory.Properties.VariableNames) ~= 3 || ...
            ~all(ismember(requiredColumns, ...
                inventory.Properties.VariableNames))
        error('worldsave:InvalidColumns', ...
            'Supply exactly Category, Requirement, and Result.');
    end

    if height(inventory) > 4096
        error('worldsave:InventoryLimit', ...
            'The local review limit is 4096 requirements.');
    end

    for k = 1:numel(requiredColumns)
        value = inventory.(requiredColumns{k});
        if ~isstring(value) || ...
                ~isequal(size(value), [height(inventory), 1]) || ...
                any(ismissing(value))
            error('worldsave:InvalidColumnType', ...
                'Each column must be a nonmissing string column.');
        end
    end

    categories = ["compliance"; "safety"; "consent"; "usage"];

    if any(~ismember(inventory.Category, categories))
        error('worldsave:UnknownCategory', ...
            'Use compliance, safety, consent, or usage.');
    end

    if any(strlength(strtrim(inventory.Requirement)) == 0)
        error('worldsave:EmptyRequirement', ...
            'Requirement descriptions must be nonempty.');
    end

    if any(~ismember(inventory.Result, ["pass", "fail", "unknown"]))
        error('worldsave:InvalidResult', ...
            'Results must be pass, fail, or unknown.');
    end

    for k = 1:numel(categories)
        descriptions = inventory.Requirement( ...
            inventory.Category == categories(k));
        if numel(unique(descriptions)) ~= numel(descriptions)
            error('worldsave:DuplicateRequirement', ...
                'Requirement descriptions must be unique within a category.');
        end
    end

    count = zeros(4, 1);
    passed = zeros(4, 1);
    failed = zeros(4, 1);
    unknown = zeros(4, 1);
    categoryStatus = repmat("unknown", 4, 1);

    for k = 1:4
        values = inventory.Result( ...
            inventory.Category == categories(k));

        count(k) = numel(values);
        passed(k) = sum(values == "pass");
        failed(k) = sum(values == "fail");
        unknown(k) = sum(values == "unknown");

        if failed(k) > 0
            categoryStatus(k) = "fail";
        elseif count(k) > 0 && all(values == "pass")
            categoryStatus(k) = "pass";
        end
    end

    if any(categoryStatus == "fail")
        aggregate = "fail";
    elseif all(categoryStatus == "pass")
        aggregate = "pass";
    else
        aggregate = "unknown";
    end

    result = struct();
    result.SchemaVersion = "1.0.0";
    result.SovereignAttribution = ...
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
    result.AttributionUse = "document_credit_only";
    result.AggregatePrerequisiteResult = aggregate;
    result.AllRequiredCategoriesRepresented = all(count > 0);
    result.AllSuppliedPrerequisitesPass = ...
        aggregate == "pass" && all(count > 0);
    result.MissingCategories = categories(count == 0);

    result.CategoryReview = table( ...
        categories, count, passed, failed, unknown, categoryStatus, ...
        'VariableNames', ...
        {'Category', 'RequirementCount', 'PassedCount', ...
         'FailedCount', 'UnknownCount', 'Result'});

    result.MilestoneAcceptanceEvaluated = false;
    result.WorldSaveEstablishedByThisCalculation = false;
    result.ExecutionAuthorized = false;
    result.EvidenceCompletenessEstablished = false;
    result.RuntimeVersion = version;
end
