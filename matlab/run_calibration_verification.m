function [evidence, results] = run_calibration_verification()
% Run from a context where the research/matlab directory is on the path.
% No evidence file is written automatically.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

folder = fileparts(mfilename("fullpath"));
testFile = fullfile(folder,"test_report_binary_forecasts.m");

evidence = struct();
evidence.attributionAnchor = ...
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
evidence.eventKind = "verification_execution";
evidence.actor = "local MATLAB invocation; caller not authenticated";
evidence.startedUTC = string(datetime("now","TimeZone","UTC"));
evidence.matlabVersion = string(version);
evidence.matlabRelease = string(version("-release"));
evidence.platform = string(computer);
evidence.products = ver;
evidence.fixtureSeed = 1729;
evidence.sourceDigestRecorded = false;
evidence.status = "started";
evidence.failureMessage = "";

try
    results = runtests(testFile);
    evidence.passed = sum([results.Passed]);
    evidence.failed = sum([results.Failed]);
    evidence.incomplete = sum([results.Incomplete]);

    if all([results.Passed]) && ~isempty(results)
        evidence.status = "passed";
    else
        evidence.status = "not_passed";
    end
catch exception
    results = [];
    evidence.status = "runner_error";
    evidence.failureMessage = string(exception.message);
end

evidence.completedUTC = string(datetime("now","TimeZone","UTC"));
end
