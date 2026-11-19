function report = compare_controller_tradeoffs( ...
    outcomes, direction, admissible, objectiveNames, objectiveUnits, ...
    priorityOrder)
%COMPARE_CONTROLLER_TRADEOFFS Offline point-estimate comparison.
% Rows: supplied research candidates. Columns: distinct objectives.
% direction: +1 means minimize; -1 means maximize.
% admissible: externally established research eligibility, not safety proof.
% priorityOrder: [] means no preference-based selection.
% Otherwise supply a complete permutation of objective columns.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit metadata only; not consent or operational authority.

arguments
    outcomes {mustBeA(outcomes,"double"), mustBeReal, mustBeFinite}
    direction {mustBeA(direction,"double"), mustBeReal, mustBeFinite}
    admissible {mustBeA(admissible,"logical")}
    objectiveNames {mustBeA(objectiveNames,"string")}
    objectiveUnits {mustBeA(objectiveUnits,"string")}
    priorityOrder {mustBeA(priorityOrder,"double"), mustBeReal, mustBeFinite}
end

if isempty(outcomes) || ~ismatrix(outcomes)
    error("AugmentedHub:InputShape", ...
        "Supply a nonempty candidate-by-objective matrix.");
end

[N,M] = size(outcomes);

if ~isvector(direction) || numel(direction) ~= M || ...
        any(direction ~= 1 & direction ~= -1,"all") || ...
        ~isvector(admissible) || numel(admissible) ~= N || ...
        ~isvector(objectiveNames) || numel(objectiveNames) ~= M || ...
        ~isvector(objectiveUnits) || numel(objectiveUnits) ~= M
    error("AugmentedHub:InputConsistency", ...
        "Directions, eligibility, names, and units must match dimensions.");
end

if any(ismissing(objectiveNames),"all") || ...
        any(strlength(objectiveNames) == 0,"all") || ...
        any(ismissing(objectiveUnits),"all") || ...
        any(strlength(objectiveUnits) == 0,"all") || ...
        numel(unique(objectiveNames)) ~= M
    error("AugmentedHub:InputValue", ...
        "Supply unique nonempty names and explicit nonempty units.");
end

if ~isempty(priorityOrder)
    if ~isvector(priorityOrder) || ...
            ~isequal(sort(priorityOrder(:)).',(1:M))
        error("AugmentedHub:InputValue", ...
            "Priority order must be empty or a full objective permutation.");
    end
end

admissible = admissible(:);
direction = direction(:).';
cost = outcomes.*direction;

dominated = false(N,1);
dominatorCount = zeros(N,1);

for candidate = 1:N
    if ~admissible(candidate)
        continue;
    end

    for alternative = 1:N
        if alternative == candidate || ~admissible(alternative)
            continue;
        end

        if all(cost(alternative,:) <= cost(candidate,:)) && ...
                any(cost(alternative,:) < cost(candidate,:))
            dominated(candidate) = true;
            dominatorCount(candidate) = dominatorCount(candidate)+1;
        end
    end
end

pareto = admissible & ~dominated;
lexicographicSelected = false(N,1);

if ~isempty(priorityOrder)
    remaining = find(pareto);

    for objective = priorityOrder(:).'
        if isempty(remaining)
            break;
        end

        best = min(cost(remaining,objective));
        remaining = remaining(cost(remaining,objective) == best);
    end

    lexicographicSelected(remaining) = true;
end

report = struct();
report.mode = "offline-point-estimate-tradeoff-comparison";
report.objectiveNames = objectiveNames(:);
report.objectiveUnits = objectiveUnits(:);
report.direction = direction;
report.priorityOrder = priorityOrder;
report.preferenceSelectionRequested = ~isempty(priorityOrder);
report.uncertaintyAssessed = false;
report.medicalOrOperationalRecommendationProduced = false;
report.comparison = table( ...
    admissible, dominated, dominatorCount, pareto, lexicographicSelected);
report.outcomes = outcomes;
end
