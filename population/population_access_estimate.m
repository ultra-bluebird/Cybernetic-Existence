function result = population_access_estimate(cells, margin, planningP)
% POPULATION_ACCESS_ESTIMATE
% Stratified binary-outcome estimation using aggregate counts.
%
% Assumptions:
%   Independent simple random sampling without replacement per stratum.
%   Known population counts and consistently measured binary outcomes.
%   No adjustment for nonresponse, clustering, or frame coverage error.
%
% Usage:
%   result = population_access_estimate();
%   result = population_access_estimate(cells, 0.05, 0.5);
%
% Required table variables:
%   Stratum, Population, Sample, BarrierCount
%
% Confidence intervals are normal approximations.
% Sparse non-census strata with all-zero or all-one outcomes are rejected.
%
% SPDX-License-Identifier: MIT OR Apache-2.0

    if nargin < 1
        cells = table( ...
            ["Ages 30-44"; "Ages 45+"], ...
            [6000; 4000], ...
            [120; 80], ...
            [36; 40], ...
            'VariableNames', ...
            {'Stratum', 'Population', 'Sample', 'BarrierCount'});
        synthetic = true;
    else
        synthetic = false;
    end

    if nargin < 2
        margin = 0.05;
    end
    if nargin < 3
        planningP = 0.5;
    end

    if ~istable(cells) || height(cells) == 0
        error('population_access_estimate:InvalidTable', ...
            'Provide a nonempty aggregate-count table.');
    end

    required = {'Stratum', 'Population', 'Sample', 'BarrierCount'};
    if ~all(ismember(required, cells.Properties.VariableNames))
        error('population_access_estimate:MissingColumns', ...
            'Required columns: Stratum, Population, Sample, BarrierCount.');
    end

    labels = string(cells.Stratum);
    if ~isvector(labels) || numel(labels) ~= height(cells) || ...
            any(ismissing(labels(:))) || ...
            any(strlength(strtrim(labels(:))) == 0) || ...
            numel(unique(labels)) ~= height(cells)
        error('population_access_estimate:InvalidStrata', ...
            'Stratum labels must be unique, nonempty, and nonmissing.');
    end

    names = {'Population', 'Sample', 'BarrierCount'};
    for k = 1:numel(names)
        value = cells.(names{k});
        if ~isnumeric(value) || ~isreal(value) || ...
                ~iscolumn(value) || any(~isfinite(value))
            error('population_access_estimate:InvalidCounts', ...
                'Each count column must be a finite real numeric column.');
        end
        value = double(value);
        if any(value < 0 | value > flintmax | value ~= fix(value))
            error('population_access_estimate:InvalidCounts', ...
                'Counts must be nonnegative exactly representable integers.');
        end
    end

    validateattributes(margin, {'numeric'}, ...
        {'real', 'finite', 'scalar', '>', 0, '<', 1});
    validateattributes(planningP, {'numeric'}, ...
        {'real', 'finite', 'scalar', '>', 0, '<', 1});

    N = double(cells.Population);
    n = double(cells.Sample);
    x = double(cells.BarrierCount);

    if any(N < 1 | n < 1 | n > N | x > n)
        error('population_access_estimate:InconsistentCounts', ...
            'Require Population >= Sample >= 1 and BarrierCount <= Sample.');
    end

    population = sum(N);
    if population > flintmax || ~isfinite(population)
        error('population_access_estimate:PopulationTooLarge', ...
            'Total population exceeds supported exact integer range.');
    end

    census = (n == N);
    if any(~census & n < 2)
        error('population_access_estimate:InsufficientSample', ...
            'Non-census strata require at least two observations.');
    end

    sparse = ~census & (x < 5 | (n - x) < 5);
    if any(sparse)
        error('population_access_estimate:SparseOutcomes', ...
            ['Normal approximation is unsuitable for a non-census ', ...
             'stratum with fewer than five outcomes in either category. ', ...
             'Use a design-appropriate alternative interval method.']);
    end

    p = x ./ n;
    affectedByCell = N .* p;

    varianceByCell = zeros(size(N));
    sampled = ~census;
    varianceByCell(sampled) = ...
        N(sampled).^2 .* ...
        (1 - n(sampled) ./ N(sampled)) .* ...
        p(sampled) .* (1 - p(sampled)) ./ ...
        (n(sampled) - 1);

    affected = sum(affectedByCell);
    standardError = sqrt(sum(varianceByCell));
    proportion = affected / population;

    z = 1.959963984540054;
    lower = max(0, affected - z * standardError);
    upper = min(population, affected + z * standardError);

    n0 = z^2 * planningP * (1 - planningP) / margin^2;
    plannedSample = min(population, ...
        ceil(population * n0 / (population + n0 - 1)));

    cellResults = cells(:, required);
    cellResults.PopulationWeight = N / population;
    cellResults.BarrierProportion = p;
    cellResults.EstimatedAffected = affectedByCell;
    cellResults.VarianceContribution = varianceByCell;

    result = struct();
    result.SyntheticExample = synthetic;
    result.Method = ...
        "Stratified SRS without replacement; normal approximate interval";
    result.ConfidenceLevel = 0.95;
    result.Population = population;
    result.Sample = sum(n);
    result.ObservedBarrierCount = sum(x);
    result.EstimatedProportion = proportion;
    result.EstimatedAffected = affected;
    result.StandardErrorAffected = standardError;
    result.AffectedInterval = [lower, upper];
    result.ProportionInterval = [lower, upper] / population;
    result.PlanningMargin = margin;
    result.PlanningProportion = planningP;
    result.PlannedSimpleRandomSample = plannedSample;
    result.Cells = cellResults;
    result.RuntimeVersion = version;

    if synthetic
        assert(abs(proportion - 0.38) < 1e-12);
        assert(abs(affected - 3800) < 1e-9);
        assert(abs(standardError - 334.483298) < 1e-6);
        assert(plannedSample == 370);
    end
end
