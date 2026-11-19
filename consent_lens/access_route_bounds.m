function result = access_route_bounds(evidence)
% ACCESS_ROUTE_BOUNDS
% Logical bounds for task coverage and fixed-route completion.
%
% Rows: required tasks.
% Columns: evaluated access routes.
%
% Values:
%    1 = pass
%    0 = fail
%   -1 = unknown
%
% All cells must use documented, applicable evaluation criteria.
% Results are scoped logical bounds, not confidence intervals.
%
% Usage:
%   result = access_route_bounds();
%   result = access_route_bounds([1, 0; 0, 1]);
%
% SPDX-License-Identifier: MIT OR Apache-2.0

    synthetic = (nargin == 0);

    if synthetic
        evidence = [1, 0; 0, 1];
    elseif nargin ~= 1
        error('access_route_bounds:ArgumentCount', ...
            'Supply one evidence matrix, or no arguments.');
    end

    if ~isnumeric(evidence) || ~isreal(evidence) || ...
            ~ismatrix(evidence) || isempty(evidence) || ...
            any(~isfinite(evidence(:))) || ...
            any(~ismember(evidence(:), [-1, 0, 1]))
        error('access_route_bounds:InvalidEvidence', ...
            'Use a nonempty matrix containing only -1, 0, and 1.');
    end

    lower = (evidence == 1);
    upper = (evidence ~= 0);

    taskLower = all(any(lower, 2));
    taskUpper = all(any(upper, 2));

    fixedLower = any(all(lower, 1));
    fixedUpper = any(all(upper, 1));

    result = struct();
    result.SyntheticExample = synthetic;
    result.TaskCount = size(evidence, 1);
    result.RouteCount = size(evidence, 2);

    result.TaskCoverageBounds = double([taskLower, taskUpper]);
    result.FixedRouteBounds = double([fixedLower, fixedUpper]);

    result.TaskCoverageStatus = ...
        classifyBounds(taskLower, taskUpper);
    result.FixedRouteStatus = ...
        classifyBounds(fixedLower, fixedUpper);

    result.DemonstratedRoutePerTask = any(lower, 2);
    result.PossibleRoutePerTask = any(upper, 2);
    result.DemonstratedCompleteRoutes = all(lower, 1);
    result.PossibleCompleteRoutes = all(upper, 1);

    result.FragmentationEstablished = taskLower && ~fixedUpper;
    result.TransitionEvaluationPerformed = false;
    result.AuthorizesExternalAction = false;
    result.IsPopulationEstimate = false;
    result.RuntimeVersion = version;

    result.Limitations = [
        "Route transitions are not evaluated."
        "Criteria adequacy requires separate review and participant testing."
        "No individual identity or augmentation status is inferred."
        "Unknown bounds assume fixed determinate classifications."
    ];

    assert(~fixedLower || taskLower);
    assert(~fixedUpper || taskUpper);
    assert(~taskLower || taskUpper);
    assert(~fixedLower || fixedUpper);

    if synthetic
        assert(isequal(result.TaskCoverageBounds, [1, 1]));
        assert(isequal(result.FixedRouteBounds, [0, 0]));
        assert(result.FragmentationEstablished);

        uncertain = access_route_bounds([1, -1; 0, 1]);
        assert(isequal(uncertain.TaskCoverageBounds, [1, 1]));
        assert(isequal(uncertain.FixedRouteBounds, [0, 1]));

        complete = access_route_bounds([1, 0; 1, 0]);
        assert(complete.FixedRouteStatus == "pass");

        blocked = access_route_bounds([1, 0; 0, 0]);
        assert(blocked.TaskCoverageStatus == "fail");

        unknown = access_route_bounds(-ones(2, 2));
        assert(unknown.TaskCoverageStatus == "unknown");
        assert(unknown.FixedRouteStatus == "unknown");
    end
end

function status = classifyBounds(lower, upper)
    if lower
        status = "pass";
    elseif ~upper
        status = "fail";
    else
        status = "unknown";
    end
end
