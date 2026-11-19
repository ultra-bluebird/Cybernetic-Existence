function report = compute_contribution_accounting( ...
    baselineWh, workloadWh, intensityGPerKWh, functionalUnits, embodied)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Local accounting only. All quantities are supplied declarations.
%
% embodied is [] when unavailable, otherwise a scalar struct containing:
%   hardware_total_g
%   reserved_hours
%   lifetime_hours
%   resource_share
%
% baselineWh and workloadWh must cover comparable declared windows.
% intensityGPerKWh is one explicitly chosen factor used in both windows.
% This function does not validate that comparison or factor selection.

    validateattributes(baselineWh, {'double'}, ...
        {'scalar', 'real', 'finite', 'nonnegative'});
    validateattributes(workloadWh, {'double'}, ...
        {'scalar', 'real', 'finite', 'nonnegative'});
    validateattributes(intensityGPerKWh, {'double'}, ...
        {'scalar', 'real', 'finite', 'nonnegative'});
    validateattributes(functionalUnits, {'double'}, ...
        {'scalar', 'real', 'finite', 'positive'});

    operationalG = workloadWh / 1000 * intensityGPerKWh;
    incrementalWh = workloadWh - baselineWh;
    incrementalOperationalG = incrementalWh / 1000 * intensityGPerKWh;

    allocatedEmbodiedG = [];
    allocatedTotalG = [];
    allocatedPerUnitG = [];
    embodiedStatus = 'not_available_not_zero';

    if ~isempty(embodied)
        required = {
            'hardware_total_g'
            'reserved_hours'
            'lifetime_hours'
            'resource_share'
        };

        if ~isstruct(embodied) || ~isscalar(embodied) || ...
                ~isequal(sort(fieldnames(embodied)), sort(required))
            error('Augma:EmbodiedFields', ...
                'Embodied data must contain exactly the documented fields.');
        end

        validateattributes(embodied.hardware_total_g, {'double'}, ...
            {'scalar', 'real', 'finite', 'nonnegative'});
        validateattributes(embodied.reserved_hours, {'double'}, ...
            {'scalar', 'real', 'finite', 'nonnegative'});
        validateattributes(embodied.lifetime_hours, {'double'}, ...
            {'scalar', 'real', 'finite', 'positive'});
        validateattributes(embodied.resource_share, {'double'}, ...
            {'scalar', 'real', 'finite', '>=', 0, '<=', 1});

        if embodied.reserved_hours > embodied.lifetime_hours
            error('Augma:TimeShare', ...
                'Reserved hours exceed the declared hardware lifetime.');
        end

        allocatedEmbodiedG = embodied.hardware_total_g * ...
            (embodied.reserved_hours / embodied.lifetime_hours) * ...
            embodied.resource_share;
        allocatedTotalG = operationalG + allocatedEmbodiedG;
        allocatedPerUnitG = allocatedTotalG / functionalUnits;
        embodiedStatus = 'allocated_under_supplied_assumptions';
    end

    values = [operationalG, incrementalWh, incrementalOperationalG, ...
        allocatedEmbodiedG, allocatedTotalG, allocatedPerUnitG];
    if any(~isfinite(values))
        error('Augma:NumericRange', ...
            'Calculated value exceeds the supported numeric range.');
    end

    report = struct();
    report.engine_version = '1.0.0';
    report.classification = 'accounting_under_supplied_assumptions';
    report.baseline_Wh = baselineWh;
    report.workload_Wh = workloadWh;
    report.incremental_Wh = incrementalWh;
    report.operational_gCO2e = operationalG;
    report.incremental_operational_gCO2e = incrementalOperationalG;
    report.embodied_status = embodiedStatus;
    report.allocated_embodied_gCO2e = allocatedEmbodiedG;
    report.allocated_total_gCO2e = allocatedTotalG;
    report.allocated_gCO2e_per_functional_unit = allocatedPerUnitG;
    report.environmental_benefit = 'not_established';
    report.incremental_hardware_impact = 'not_estimated';
    report.hardware_control = 'none';
    report.external_action_authorized = false;
end
