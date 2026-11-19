function report = audit_streaming_smoother()
% Deterministic synthetic property checks and two deliberate mutations.
% No clinical data, acquisition, networking, or hardware.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Attribution is credit metadata, not authorization.

t = (0:0.1:2).';
x = sin(3*t) + 0.2*cos(7*t);
restart = false(size(t));
restart([1, 12]) = true;
tau = 0.4;

modes = ["reference"; "future-leak"; "ignore-restart"];
properties = ["causality", "convexity", "boundedness", ...
    "translation", "restartIndependence", "determinism"];
passed = false(numel(modes), numel(properties));
tolerance = 1e-11;

for index = 1:numel(modes)
    mode = modes(index);
    y = smoothLocal(t, x, restart, tau, mode);

    prefixLength = 8;
    prefix = smoothLocal(t(1:prefixLength), x(1:prefixLength), ...
        restart(1:prefixLength), tau, mode);
    passed(index, 1) = all( ...
        abs(y(1:prefixLength) - prefix) < tolerance);

    convex = true;
    bounded = true;
    segmentBegin = 1;
    for row = 1:numel(t)
        if restart(row)
            segmentBegin = row;
        elseif row > 1
            convex = convex && ...
                y(row) >= min(x(row), y(row-1)) - tolerance && ...
                y(row) <= max(x(row), y(row-1)) + tolerance;
        end
        segmentInput = x(segmentBegin:row);
        bounded = bounded && ...
            y(row) >= min(segmentInput) - tolerance && ...
            y(row) <= max(segmentInput) + tolerance;
    end
    passed(index, 2) = convex;
    passed(index, 3) = bounded;

    shifted = smoothLocal(t, x + 5, restart, tau, mode);
    passed(index, 4) = all(abs(shifted - (y + 5)) < tolerance);

    segmentIndex = 12;
    standaloneRestart = false(numel(t)-segmentIndex+1, 1);
    standaloneRestart(1) = true;
    standalone = smoothLocal(t(segmentIndex:end), ...
        x(segmentIndex:end), standaloneRestart, tau, mode);
    passed(index, 5) = all( ...
        abs(y(segmentIndex:end) - standalone) < tolerance);

    repeated = smoothLocal(t, x, restart, tau, mode);
    passed(index, 6) = isequal(y, repeated);
end

assert(all(passed(1, :)), ...
    "Reference smoother failed its declared properties.");
assert(any(~passed(2, :)), ...
    "Future-leak mutation was not detected.");
assert(any(~passed(3, :)), ...
    "Restart mutation was not detected.");

report = array2table(passed, ...
    "VariableNames", cellstr(properties));
report = addvars(report, modes, "Before", 1, ...
    "NewVariableNames", "implementation");
end

function y = smoothLocal(t, x, restart, tau, mode)
% Private test implementation; caller supplies validated synthetic arrays.

source = x;
if mode == "future-leak"
    source = [x(2:end); x(end)];
end

y = zeros(size(x));
for row = 1:numel(x)
    mustRestart = row == 1 || ...
        (restart(row) && mode ~= "ignore-restart");

    if mustRestart
        y(row) = source(row);
    else
        alpha = -expm1(-(t(row)-t(row-1))/tau);
        y(row) = alpha*source(row) + (1-alpha)*y(row-1);
    end
end
end
