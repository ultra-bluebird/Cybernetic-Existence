function report = compute_accounting_envelope( ...
    baselineWh, workloadWh, baselineIntensity, workloadIntensity, ...
    functionalUnits, embodied)
% SPDX-License-Identifier: MIT OR Apache-2.0
% Bounded accounting under supplied interval assumptions.
%
% Energy: Wh.
% Electricity intensity: gCO2e/kWh.
% functionalUnits: positive output quantity under a declared definition.
%
% Each numeric input is a double row vector [lower upper].
%
% embodied is exactly [] when unavailable, otherwise a scalar struct:
%   hardware_total_g : [lower upper], gCO2e
%   reserved_hours   : [lower upper], hours
%   lifetime_hours   : [lower upper], hours
%   resource_share   : [lower upper], dimensionless
%
% The caller must review boundaries, quality comparability, factor basis,
% input provenance, and whether a rectangular interval model is appropriate.

    if nargin ~= 6
        error('Augma:ArgumentCount', ...
            'Exactly six inputs are required.');
    end

    checkRange(baselineWh, 'baselineWh', false);
    checkRange(workloadWh, 'workloadWh', false);
    checkRange(baselineIntensity, 'baselineIntensity', false);
    checkRange(workloadIntensity, 'workloadIntensity', false);
    checkRange(functionalUnits, 'functionalUnits', true);

    baselineOperational = nonnegativeProduct( ...
        baselineWh / 1000, baselineIntensity);
    workloadOperational = nonnegativeProduct( ...
        workloadWh / 1000, workloadIntensity);

    incrementalEnergy = [
        workloadWh(1) - baselineWh(2), ...
        workloadWh(2) - baselineWh(1)
    ];
    incrementalOperational = [
        workloadOperational(1) - baselineOperational(2), ...
        workloadOperational(2) - baselineOperational(1)
    ];

    embodiedAllocated = [];
    allocatedTotal = [];
    allocatedPerUnit = [];
    embodiedStatus = 'unavailable_not_zero';

    unavailable = isa(embodied, 'double') && ...
        isequal(size(embodied), [0 0]);

    if ~unavailable
        required = {
            'hardware_total_g'
            'reserved_hours'
            'lifetime_hours'
            'resource_share'
        };

        if ~isstruct(embodied) || ~isscalar(embodied) || ...
                ~isequal(sort(fieldnames(embodied)), sort(required))
            error('Augma:EmbodiedFields', ...
                'Use [] or a scalar struct with exactly the documented fields.');
        end

        checkRange(embodied.hardware_total_g, 'hardware_total_g', false);
        checkRange(embodied.reserved_hours, 'reserved_hours', false);
        checkRange(embodied.lifetime_hours, 'lifetime_hours', true);
        checkRange(embodied.resource_share, 'resource_share', false);

        if embodied.resource_share(2) > 1
            error('Augma:ResourceShare', ...
                'Resource-share bounds must lie between zero and one.');
        end

        if embodied.reserved_hours(2) > embodied.lifetime_hours(1)
            error('Augma:TimeShare', ...
                ['Independent interval bounds permit reserved time to ' ...
                 'exceed lifetime. Refine the bounds or use a reviewed ' ...
                 'joint-scenario model.']);
        end

        timeShare = [
            embodied.reserved_hours(1) / embodied.lifetime_hours(2), ...
            embodied.reserved_hours(2) / embodied.lifetime_hours(1)
        ];

        embodiedAllocated = nonnegativeProduct( ...
            nonnegativeProduct(embodied.hardware_total_g, timeShare), ...
            embodied.resource_share);

        allocatedTotal = workloadOperational + embodiedAllocated;
        allocatedPerUnit = [
            allocatedTotal(1) / functionalUnits(2), ...
            allocatedTotal(2) / functionalUnits(1)
        ];
        embodiedStatus = 'allocated_under_supplied_interval_assumptions';
    end

    calculated = [
        baselineOperational, workloadOperational, ...
        incrementalEnergy, incrementalOperational, ...
        embodiedAllocated, allocatedTotal, allocatedPerUnit
    ];
    if any(~isfinite(calculated))
        error('Augma:NumericRange', ...
            'A calculated interval exceeds the supported numeric range.');
    end

    report = struct();
    report.engine_version = '2.0.0';
    report.classification = 'interval_accounting_under_supplied_assumptions';
    report.interval_semantics = ...
        'rectangular_enclosures_not_confidence_intervals';

    report.baseline_Wh = baselineWh;
    report.workload_Wh = workloadWh;
    report.incremental_Wh = incrementalEnergy;
    report.baseline_intensity_gCO2e_per_kWh = baselineIntensity;
    report.workload_intensity_gCO2e_per_kWh = workloadIntensity;
    report.functional_units = functionalUnits;

    report.baseline_operational_gCO2e = baselineOperational;
    report.workload_operational_gCO2e = workloadOperational;
    report.incremental_operational_gCO2e = incrementalOperational;

    report.embodied_status = embodiedStatus;
    report.allocated_embodied_gCO2e = embodiedAllocated;
    report.allocated_total_gCO2e = allocatedTotal;
    report.allocated_gCO2e_per_functional_unit = allocatedPerUnit;

    report.factor_basis = 'caller_declared_not_validated';
    report.baseline_comparability = 'not_established';
    report.output_quality = 'not_established';
    report.incremental_hardware_impact = 'not_estimated';
    report.environmental_benefit = 'not_established';
    report.hardware_control = 'none';
    report.external_action_authorized = false;
end


function checkRange(value, name, strictlyPositive)
    validateattributes(value, {'double'}, ...
        {'real', 'finite', 'size', [1 2]}, mfilename, name);

    if value(1) > value(2)
        error('Augma:IntervalOrder', ...
            '%s must contain ordered lower and upper bounds.', name);
    end

    if strictlyPositive
        if value(1) <= 0
            error('Augma:PositiveInterval', ...
                '%s must have strictly positive bounds.', name);
        end
    elseif value(1) < 0
        error('Augma:NonnegativeInterval', ...
            '%s must have nonnegative bounds.', name);
    end
end


function result = nonnegativeProduct(first, second)
    result = [first(1) * second(1), first(2) * second(2)];
end
