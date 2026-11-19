function result = plan_stratified_allocation(N, planningP, nTotal, minimumN)
% PLAN_STRATIFIED_ALLOCATION
% Equal-cost stratified sample planning with finite-population correction.
%
% N:          stratum population counts.
% planningP:  planning barrier proportions, strictly between 0 and 1.
% nTotal:     fixed total completed sample.
% minimumN:   scalar or per-stratum minimum, at least two.
%
% Numeric outputs are planning results, not observed population findings.
% Target: MATLAB R2020b or newer; base MATLAB.
% SPDX-License-Identifier: MIT OR Apache-2.0

    if nargin ~= 4
        error('population:ArgumentCount', ...
            'Supply populations, planning proportions, total, and minimums.');
    end

    validateattributes(N, {'numeric'}, ...
        {'real', 'finite', 'vector', 'nonempty', 'integer', ...
         '>=', 2, '<=', 1000000000});
    validateattributes(planningP, {'numeric'}, ...
        {'real', 'finite', 'vector', 'nonempty', '>', 0, '<', 1});
    validateattributes(nTotal, {'numeric'}, ...
        {'real', 'finite', 'scalar', 'integer', '>=', 2, '<=', 50000});
    validateattributes(minimumN, {'numeric'}, ...
        {'real', 'finite', 'vector', 'nonempty', 'integer', '>=', 2});

    N = double(N(:));
    planningP = double(planningP(:));
    nTotal = double(nTotal);
    minimumN = double(minimumN(:));

    H = numel(N);

    if H > 64 || numel(planningP) ~= H
        error('population:StratumDimensions', ...
            'Provide matching vectors for at most 64 strata.');
    end

    if isscalar(minimumN)
        minimumN = repmat(minimumN, H, 1);
    end

    if numel(minimumN) ~= H || any(minimumN > N) || ...
            sum(minimumN) > nTotal || nTotal > sum(N)
        error('population:InfeasibleSample', ...
            'Population bounds, minimums, and total are incompatible.');
    end

    weights = N / sum(N);

    % Finite binary-population planning variance.
    % Planning proportions need not be known true population proportions.
    S2 = (N ./ (N - 1)) .* planningP .* (1 - planningP);
    A = N.^2 .* S2;

    proportional = boundedWeighted(N, minimumN, N, nTotal);
    equal = boundedWeighted(ones(H, 1), minimumN, N, nTotal);

    % Diminishing marginal variance reduction for equal-cost integer units.
    neyman = minimumN;
    for step = 1:(nTotal - sum(minimumN))
        gain = A ./ (neyman .* (neyman + 1));
        gain(neyman >= N) = -Inf;
        [best, position] = max(gain);

        if ~isfinite(best)
            error('population:AllocationStalled', ...
                'No remaining feasible sample increment.');
        end

        neyman(position) = neyman(position) + 1;
    end

    names = [
        "proportional_bounded"
        "neyman_marginal_equal_cost"
        "equal_bounded"
    ];
    allocations = {proportional; neyman; equal};

    overallSE = zeros(3, 1);
    margin95 = zeros(3, 1);
    caution = false(3, 1);
    plans = cell(3, 1);
    z = 1.959963984540054;

    for method = 1:3
        n = allocations{method};

        if sum(n) ~= nTotal || any(n < minimumN) || any(n > N)
            error('population:AllocationInvariant', ...
                'An allocation violates its declared constraints.');
        end

        varianceByStratum = S2 .* (1 ./ n - 1 ./ N);
        overallVariance = sum(weights.^2 .* varianceByStratum);

        overallSE(method) = sqrt(overallVariance);
        margin95(method) = z * overallSE(method);
        caution(method) = any( ...
            n .* planningP < 5 | n .* (1 - planningP) < 5);

        plans{method} = table( ...
            (1:H).', N, weights, planningP, n, ...
            sqrt(varianceByStratum), z * sqrt(varianceByStratum), ...
            'VariableNames', ...
            {'StratumPosition', 'Population', 'PopulationWeight', ...
             'PlanningProportion', 'Sample', 'PlanningSE', ...
             'ApproximateMargin95'});
    end

    result = struct();
    result.SchemaVersion = "1.0.0";
    result.SovereignAttribution = ...
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
    result.AttributionUse = "document_credit_only";
    result.CostAssumption = "equal_cost_per_completed_observation";
    result.Minimums = minimumN;
    result.TotalSample = nTotal;
    result.Plans = plans;
    result.Summary = table( ...
        names, allocations, overallSE, margin95, caution, ...
        'VariableNames', ...
        {'Strategy', 'Allocation', 'OverallPlanningSE', ...
         'ApproximateMargin95', 'NormalApproximationCaution'});
    result.TieBreak = "first_stratum_in_input_order";
    result.RuntimeVersion = version;
end

function allocation = boundedWeighted(weights, lower, upper, target)
    low = 0;
    high = target / min(weights);

    for iteration = 1:100
        middle = (low + high) / 2;
        continuous = min(upper, max(lower, middle * weights));

        if sum(continuous) < target
            low = middle;
        else
            high = middle;
        end
    end

    continuous = min(upper, max(lower, ((low + high) / 2) * weights));
    allocation = floor(continuous);
    remaining = target - sum(allocation);

    eligible = find(allocation < upper);
    fractions = continuous(eligible) - allocation(eligible);
    ranking = sortrows([-fractions, eligible], [1, 2]);

    if remaining < 0 || remaining > size(ranking, 1)
        error('population:RoundingFailure', ...
            'Bounded allocation rounding requires review.');
    end

    for position = 1:remaining
        stratum = ranking(position, 2);
        allocation(stratum) = allocation(stratum) + 1;
    end
end
