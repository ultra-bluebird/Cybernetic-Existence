function result = actionable_choice( ...
    success, signals, routeAllowed, cueAllowed, ...
    cueCost, routeCost, budget, routeLabels, cueLabels)
% ACTIONABLE_CHOICE
% Exact policy test for: choose one cue, observe, choose one route.
%
% Target: MATLAB R2020b or newer; base MATLAB.
% Does not collect observations or establish review authority.
%
% SOVEREIGN-ATTRIBUTION:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
%
% Attribution is document credit only, not identity or authority.
% SPDX-License-Identifier: MIT OR Apache-2.0

    if nargin ~= 9
        error('consentlens:ArgumentCount', ...
            'Supply all nine model inputs.');
    end

    if ~islogical(success) || ~ismatrix(success) || isempty(success)
        error('consentlens:InvalidSuccess', ...
            'Success must be a nonempty world-by-route logical matrix.');
    end

    [worldCount, routeCount] = size(success);

    if ~isstring(signals) || ~ismatrix(signals) || ...
            size(signals, 1) ~= worldCount || size(signals, 2) < 1 || ...
            any(ismissing(signals(:))) || ...
            any(strlength(strtrim(signals(:))) == 0)
        error('consentlens:InvalidSignals', ...
            'Supply nonempty observation labels for every world and cue.');
    end

    cueCount = size(signals, 2);

    if ~islogical(routeAllowed) || ...
            ~isequal(size(routeAllowed), size(success))
        error('consentlens:InvalidRoutePermission', ...
            'Route eligibility must match the success matrix.');
    end

    if ~islogical(cueAllowed) || ...
            ~isequal(size(cueAllowed), [worldCount, cueCount])
        error('consentlens:InvalidCuePermission', ...
            'Cue eligibility must be world-by-cue logical values.');
    end

    validateCost(cueCost, cueCount, 'cueCost');
    validateCost(routeCost, routeCount, 'routeCost');

    if ~isnumeric(budget) || ~isreal(budget) || ...
            ~isequal(size(budget), [1, 4]) || ...
            any(~isfinite(budget)) || any(budget < 0)
        error('consentlens:InvalidBudget', ...
            'Budget must contain four finite nonnegative limits.');
    end

    validateLabels(routeLabels, routeCount, 'routeLabels');
    validateLabels(cueLabels, cueCount, 'cueLabels');

    routeLabels = routeLabels(:);
    cueLabels = cueLabels(:);

    admissible = success & routeAllowed;

    template = struct( ...
        'Cue', "", ...
        'Status', "not_actionable", ...
        'Reason', "", ...
        'Branches', struct('Signal', {}, 'Route', {}));

    reviews = repmat(template, cueCount, 1);

    for c = 1:cueCount
        reviews(c).Cue = cueLabels(c);

        if ~all(cueAllowed(:, c))
            reviews(c).Reason = "cue_not_permitted_in_every_world";
            continue;
        end

        combinedCost = double(routeCost) + double(cueCost(c, :));
        withinBudget = all(combinedCost <= double(budget), 2);
        outcomes = unique(signals(:, c), 'stable');
        branches = struct('Signal', {}, 'Route', {});
        winning = true;

        for b = 1:numel(outcomes)
            worlds = signals(:, c) == outcomes(b);
            common = all(admissible(worlds, :), 1).';
            candidates = find(common & withinBudget);

            if isempty(candidates)
                winning = false;
                reviews(c).Reason = ...
                    "observation_branch_has_no_common_admissible_route";
                break;
            end

            branches(b).Signal = outcomes(b);
            branches(b).Route = routeLabels(candidates(1));
        end

        if winning
            reviews(c).Status = "actionable";
            reviews(c).Reason = "all_observation_branches_supported";
            reviews(c).Branches = branches;
        end
    end

    result = struct();
    result.SchemaVersion = "1.0.0";
    result.SovereignAttribution = ...
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
    result.AttributionUse = "document_credit_only";
    result.WorldCount = worldCount;
    result.StructuralRoutePossibility = any(admissible(:));
    result.EveryWorldHasRoute = all(any(admissible, 2));
    result.ActionableWithListedCues = ...
        any(string({reviews.Status}) == "actionable");
    result.CueReviews = reviews;
    result.Model = "one cue followed by one route";
    result.AuthorityEstablished = false;
    result.EmpiricalUsabilityEstablished = false;
    result.RuntimeVersion = version;
end

function validateCost(value, rows, label)
    if ~isnumeric(value) || ~isreal(value) || ...
            ~isequal(size(value), [rows, 4]) || ...
            any(~isfinite(value(:))) || any(value(:) < 0)
        error('consentlens:InvalidCost', ...
            '%s must be a finite nonnegative matrix with four columns.', label);
    end
end

function validateLabels(value, count, label)
    if ~isstring(value) || ~isvector(value) || ...
            numel(value) ~= count || any(ismissing(value(:))) || ...
            any(strlength(strtrim(value(:))) == 0) || ...
            numel(unique(value)) ~= count
        error('consentlens:InvalidLabels', ...
            '%s must contain unique nonempty string labels.', label);
    end
end
