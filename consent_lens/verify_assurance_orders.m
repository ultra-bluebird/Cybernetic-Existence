function report = verify_assurance_orders()
% VERIFY_ASSURANCE_ORDERS
% Exhaustive verification for K=1..7.
%
% Encoding:
%   F = 0
%   U = 1
%   P = 2
%
% Tests snapshot classification and two distinct orders.
% Does not implement a finding-resolution workflow.
%
% Sovereign attribution, document credit only:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
%
% SPDX-License-Identifier: MIT OR Apache-2.0

    results = zeros(7, 4);

    for K = 1:7
        stateCount = 3^K;
        assuranceChecks = 0;
        informationChecks = 0;

        for code = 0:(stateCount - 1)
            row = zeros(1, K);
            remaining = code;

            for j = 1:K
                row(j) = mod(remaining, 3);
                remaining = floor(remaining / 3);
            end

            status = classify(row);

            assert((status == 0) == any(row == 0));
            assert((status == 2) == all(row == 2));
            assert(classify(fliplr(row)) == status);
            assert(classify([row, row(1)]) == status);

            for j = 1:K
                if row(j) < 2
                    raised = row;
                    raised(j) = raised(j) + 1;

                    assert(status <= classify(raised));
                    assuranceChecks = assuranceChecks + 1;
                end

                if row(j) == 1
                    for resolvedValue = [0, 2]
                        resolved = row;
                        resolved(j) = resolvedValue;

                        assert(informationLE( ...
                            status, classify(resolved)));
                        informationChecks = informationChecks + 1;
                    end
                end

                if row(j) == 2
                    withdrawn = row;
                    withdrawn(j) = 1;

                    if status ~= 2
                        assert(classify(withdrawn) ~= 2);
                    end
                end
            end
        end

        results(K, :) = ...
            [K, stateCount, assuranceChecks, informationChecks];
    end

    % Monotonicity alone permits a failure-to-unknown transition.
    assert(classify([0, 2]) == 0);
    assert(classify([1, 2]) == 1);

    % A retained applicable finding overrides snapshot uncertainty.
    assert(classifyWithFinding([1, 2], true) == 0);
    assert(classifyWithFinding([2, 2], true) == 0);
    assert(classifyWithFinding([2, 2], false) == 2);

    % Explicit edge cases.
    assert(classify(1) == 1);
    assert(classify([0, 1]) == 0);
    assert(classify([2, 2]) == 2);

    emptyRejected = false;
    try
        classify([]);
    catch problem
        emptyRejected = strcmp( ...
            problem.identifier, ...
            'verify_assurance_orders:InvalidEvidence');
    end
    assert(emptyRejected);

    assert(sum(results(:, 2)) == 3279);
    assert(sum(results(:, 3)) == 14216);
    assert(sum(results(:, 4)) == 14216);

    report = array2table(results, 'VariableNames', {
        'CheckCount', ...
        'EvidenceVectors', ...
        'AssuranceOrderComparisons', ...
        'InformationOrderComparisons'
    });
end

function status = classify(row)
    if ~isnumeric(row) || ~isreal(row) || ...
            ~isvector(row) || isempty(row) || ...
            any(~isfinite(row(:))) || ...
            any(~ismember(row(:), [0, 1, 2]))
        error('verify_assurance_orders:InvalidEvidence', ...
            'Provide a nonempty vector containing only 0, 1, 2.');
    end

    if any(row == 0)
        status = 0;
    elseif all(row == 2)
        status = 2;
    else
        status = 1;
    end
end

function permitted = informationLE(a, b)
    permitted = (a == b) || (a == 1);
end

function status = classifyWithFinding(row, unresolvedApplicableFailure)
    validateattributes(unresolvedApplicableFailure, ...
        {'logical'}, {'scalar'});

    status = classify(row);

    if unresolvedApplicableFailure
        status = 0;
    end
end
