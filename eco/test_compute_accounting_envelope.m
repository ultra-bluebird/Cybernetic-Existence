function tests = test_compute_accounting_envelope
% SPDX-License-Identifier: MIT OR Apache-2.0
% Regression tests only. Tolerances do not certify outward rounding.

    tests = functiontests(localfunctions);
end


function testPointIntervalsReproducePointArithmetic(testCase)
    embodied = struct( ...
        'hardware_total_g', [300000 300000], ...
        'reserved_hours', [2 2], ...
        'lifetime_hours', [35040 35040], ...
        'resource_share', [0.5 0.5]);

    report = compute_accounting_envelope( ...
        [40 40], [160 160], [400 400], [400 400], [1 1], embodied);

    expectedEmbodied = 300000 * (2 / 35040) * 0.5;

    verifyEqual(testCase, report.baseline_operational_gCO2e, ...
        [16 16], 'AbsTol', 1e-10);
    verifyEqual(testCase, report.workload_operational_gCO2e, ...
        [64 64], 'AbsTol', 1e-10);
    verifyEqual(testCase, report.incremental_operational_gCO2e, ...
        [48 48], 'AbsTol', 1e-10);
    verifyEqual(testCase, report.allocated_embodied_gCO2e, ...
        [expectedEmbodied expectedEmbodied], 'AbsTol', 1e-10);
    verifyEqual(testCase, report.allocated_total_gCO2e, ...
        [64 + expectedEmbodied 64 + expectedEmbodied], ...
        'AbsTol', 1e-10);
end


function testExactReferenceScenario(testCase)
    [inputs, embodied] = referenceScenario();

    report = compute_accounting_envelope( ...
        inputs(1,:), inputs(2,:), inputs(3,:), inputs(4,:), ...
        inputs(9,:), embodied);

    verifyEqual(testCase, report.baseline_operational_gCO2e, ...
        [13.3 18.9], 'AbsTol', 1e-10);
    verifyEqual(testCase, report.workload_operational_gCO2e, ...
        [45 85], 'AbsTol', 1e-10);
    verifyEqual(testCase, report.incremental_operational_gCO2e, ...
        [26.1 71.7], 'AbsTol', 1e-10);
    verifyEqual(testCase, report.allocated_embodied_gCO2e, ...
        [3.75 17.5], 'AbsTol', 1e-10);
    verifyEqual(testCase, report.allocated_total_gCO2e, ...
        [48.75 102.5], 'AbsTol', 1e-10);
    verifyEqual(testCase, report.allocated_gCO2e_per_functional_unit, ...
        [4.0625 12.8125], 'AbsTol', 1e-10);
end


function testMissingEmbodiedIsNotZero(testCase)
    report = compute_accounting_envelope( ...
        [38 42], [150 170], [350 450], [300 500], [8 12], []);

    verifyEqual(testCase, report.embodied_status, ...
        'unavailable_not_zero');
    verifyEmpty(testCase, report.allocated_embodied_gCO2e);
    verifyEmpty(testCase, report.allocated_total_gCO2e);
    verifyEmpty(testCase, report.allocated_gCO2e_per_functional_unit);
    verifyEqual(testCase, report.workload_operational_gCO2e, ...
        [45 85], 'AbsTol', 1e-10);
end


function testNegativeDifferenceRemainsNegative(testCase)
    report = compute_accounting_envelope( ...
        [100 120], [20 30], [300 400], [300 400], [1 1], []);

    verifyEqual(testCase, report.incremental_Wh, [-100 -70]);
    verifyEqual(testCase, report.incremental_operational_gCO2e, ...
        [-42 -18], 'AbsTol', 1e-10);
    verifyEqual(testCase, report.environmental_benefit, ...
        'not_established');
end


function testSeparateFactorsAffectDifference(testCase)
    report = compute_accounting_envelope( ...
        [100 100], [100 100], [200 200], [500 500], [1 1], []);

    verifyEqual(testCase, report.incremental_Wh, [0 0]);
    verifyEqual(testCase, report.incremental_operational_gCO2e, ...
        [30 30], 'AbsTol', 1e-10);
end


function testAllReferenceCornersFitReportedBounds(testCase)
    [inputs, embodied] = referenceScenario();
    report = compute_accounting_envelope( ...
        inputs(1,:), inputs(2,:), inputs(3,:), inputs(4,:), ...
        inputs(9,:), embodied);

    tolerance = 1e-10;

    for pattern = 0:(2^9 - 1)
        selection = 1 + bitget(pattern, 1:9);
        point = zeros(1, 9);
        for row = 1:9
            point(row) = inputs(row, selection(row));
        end

        baseline = point(1) * point(3) / 1000;
        workload = point(2) * point(4) / 1000;
        hardware = point(5) * point(6) / point(7) * point(8);
        total = workload + hardware;

        values = [
            baseline
            workload
            workload - baseline
            hardware
            total
            total / point(9)
        ];

        bounds = [
            report.baseline_operational_gCO2e
            report.workload_operational_gCO2e
            report.incremental_operational_gCO2e
            report.allocated_embodied_gCO2e
            report.allocated_total_gCO2e
            report.allocated_gCO2e_per_functional_unit
        ];

        verifyGreaterThanOrEqual(testCase, ...
            values, bounds(:,1) - tolerance);
        verifyLessThanOrEqual(testCase, ...
            values, bounds(:,2) + tolerance);
    end
end


function testInvalidOutputAndReversedIntervalsRejected(testCase)
    verifyError(testCase, @() compute_accounting_envelope( ...
        [1 2], [3 4], [100 200], [100 200], [0 1], []), ...
        'Augma:PositiveInterval');

    verifyError(testCase, @() compute_accounting_envelope( ...
        [2 1], [3 4], [100 200], [100 200], [1 1], []), ...
        'Augma:IntervalOrder');
end


function testInvalidEmbodiedAssumptionsRejected(testCase)
    [inputs, embodied] = referenceScenario();
    embodied.resource_share = [0.2 1.1];

    verifyError(testCase, @() compute_accounting_envelope( ...
        inputs(1,:), inputs(2,:), inputs(3,:), inputs(4,:), ...
        inputs(9,:), embodied), 'Augma:ResourceShare');

    embodied.resource_share = [0.4 0.6];
    embodied.reserved_hours = [1 3];
    embodied.lifetime_hours = [2 4];

    verifyError(testCase, @() compute_accounting_envelope( ...
        inputs(1,:), inputs(2,:), inputs(3,:), inputs(4,:), ...
        inputs(9,:), embodied), 'Augma:TimeShare');
end


function testUnexpectedEmptyRepresentationRejected(testCase)
    verifyError(testCase, @() compute_accounting_envelope( ...
        [1 2], [3 4], [100 200], [100 200], [1 1], zeros(0,1)), ...
        'Augma:EmbodiedFields');
end


function testNoAuthorityOrBenefitIsInferred(testCase)
    report = compute_accounting_envelope( ...
        [100 100], [10 10], [400 400], [400 400], [1 1], []);

    verifyFalse(testCase, report.external_action_authorized);
    verifyEqual(testCase, report.hardware_control, 'none');
    verifyEqual(testCase, report.environmental_benefit, ...
        'not_established');
    verifyEqual(testCase, report.output_quality, 'not_established');
    verifyEqual(testCase, report.baseline_comparability, ...
        'not_established');
end


function [inputs, embodied] = referenceScenario()
    inputs = [
        38 42
        150 170
        350 450
        300 500
        250000 350000
        1.5 2.5
        30000 40000
        0.4 0.6
        8 12
    ];

    embodied = struct( ...
        'hardware_total_g', inputs(5,:), ...
        'reserved_hours', inputs(6,:), ...
        'lifetime_hours', inputs(7,:), ...
        'resource_share', inputs(8,:));
end
