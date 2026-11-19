function result = review_event_times(bounds, edges)
% REVIEW_EVENT_TIMES
% bounds: N-by-2 integer-second timestamp intervals.
%         NaN lower/upper means an unresolved bound.
% edges:  M-by-2 local row positions [earlier, later].
%
% Tests declared ordering, not event authenticity or history completeness.
% Target: MATLAB R2020b or newer; base MATLAB.
% SPDX-License-Identifier: MIT OR Apache-2.0

    if nargin ~= 2 || ~isnumeric(bounds) || ~isreal(bounds) || ...
            ~ismatrix(bounds) || size(bounds, 2) ~= 2 || isempty(bounds)
        error('worldsave:InvalidBounds', ...
            'Supply a nonempty N-by-2 timestamp-bound matrix.');
    end

    N = size(bounds, 1);
    if N > 256
        error('worldsave:EventLimit', 'Maximum local event count is 256.');
    end

    known = ~isnan(bounds);
    safe = 2^52 - 1;

    if any(isinf(bounds(:))) || ...
            any(abs(bounds(known)) > safe) || ...
            any(bounds(known) ~= fix(bounds(known)))
        error('worldsave:InvalidTimestamp', ...
            'Use supported integer seconds or NaN.');
    end

    completeBounds = all(known, 2);
    if any(bounds(completeBounds, 1) > bounds(completeBounds, 2))
        error('worldsave:ContradictoryInterval', ...
            'An event has a lower bound above its upper bound.');
    end

    if ~isnumeric(edges) || ~isreal(edges) || ...
            ~ismatrix(edges) || size(edges, 2) ~= 2 || ...
            size(edges, 1) > 4096 || ...
            any(~isfinite(edges(:))) || ...
            any(edges(:) ~= fix(edges(:))) || ...
            any(edges(:) < 1 | edges(:) > N)
        error('worldsave:InvalidEdges', ...
            'Edges must contain supported local event positions.');
    end

    edges = unique(double(edges), 'rows');
    adjacency = false(N, N);

    for k = 1:size(edges, 1)
        adjacency(edges(k, 1), edges(k, 2)) = true;
    end

    indegree = sum(adjacency, 1);
    queue = find(indegree == 0);
    order = zeros(1, N);
    used = 0;
    cursor = 1;

    while cursor <= numel(queue)
        source = queue(cursor);
        cursor = cursor + 1;
        used = used + 1;
        order(used) = source;

        for target = find(adjacency(source, :))
            indegree(target) = indegree(target) - 1;
            if indegree(target) == 0
                queue(end + 1) = target;
            end
        end
    end

    if used ~= N
        error('worldsave:CausalCycle', ...
            'Declared event dependencies contain a cycle.');
    end

    lower = double(bounds(:, 1));
    upper = double(bounds(:, 2));
    lower(isnan(lower)) = -Inf;
    upper(isnan(upper)) = Inf;
    earliest = lower;

    for source = order
        for target = find(adjacency(source, :))
            earliest(target) = max(earliest(target), earliest(source));
        end
    end

    impossible = earliest > upper;
    robustEdges = false(size(edges, 1), 1);

    for k = 1:size(edges, 1)
        source = edges(k, 1);
        target = edges(k, 2);
        robustEdges(k) = ...
            ~isnan(bounds(source, 2)) && ...
            ~isnan(bounds(target, 1)) && ...
            bounds(source, 2) <= bounds(target, 1);
    end

    if any(impossible)
        status = "F";
        reason = "no_jointly_coherent_time_assignment";
    elseif ~isempty(edges) && all(robustEdges)
        status = "P";
        reason = "declared_edges_established_by_time_bounds";
    else
        status = "U";
        reason = "order_not_established_by_available_time_bounds";
    end

    result = struct();
    result.SchemaVersion = "1.0.0";
    result.SovereignAttribution = ...
        "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
    result.AttributionUse = "document_credit_only";
    result.OrderAssessment = status;
    result.Reason = reason;
    result.InconsistentEventPositions = find(impossible);
    result.DeclaredEdges = edges;
    result.EventAuthenticity = "not_evaluated";
    result.HistoryCompleteness = "not_evaluated";
    result.RuntimeVersion = version;
end
