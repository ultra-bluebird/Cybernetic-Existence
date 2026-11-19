function report = report_unintended_poisson_rate( ...
    eventCount, observedExposureHours, alpha)
%REPORT_UNINTENDED_POISSON_RATE Fixed-sample Poisson rate intervals.
% Exposure must be enabled, at-risk, independently observed hours.
% This function does not verify event annotations or the Poisson model.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not consent or execution evidence.

arguments
    eventCount {mustBeA(eventCount,"double"), mustBeReal, mustBeFinite}
    observedExposureHours {mustBeA(observedExposureHours,"double"), ...
        mustBeReal, mustBeFinite}
    alpha {mustBeA(alpha,"double"), mustBeReal, mustBeFinite}
end

if ~isscalar(eventCount) || eventCount < 0 || ...
        eventCount ~= fix(eventCount) || eventCount > flintmax-1
    error("AugmentedHub:InputValue", ...
        "eventCount must be an exactly representable nonnegative integer double.");
end

if ~isscalar(observedExposureHours) || observedExposureHours <= 0
    error("AugmentedHub:InputValue", ...
        "Supply positive finite observed exposure in hours.");
end

if ~isscalar(alpha) || alpha <= 0 || alpha >= 1 || ...
        1-alpha == 1 || 1-alpha/2 == 1
    error("AugmentedHub:InputValue", ...
        "Supply alpha in (0,1) resolvable at the requested precision.");
end

K = eventCount;
T = observedExposureHours;

lowerCentral = 0;
if K > 0
    lowerCentral = gammaincinv(alpha/2,K)/T;
end

upperCentral = gammaincinv(1-alpha/2,K+1)/T;
upperOneSided = gammaincinv(1-alpha,K+1)/T;

if K == 0
    upperCentral = -log(alpha/2)/T;
    upperOneSided = -log(alpha)/T;
end

report = struct();
report.model = "homogeneous-Poisson";
report.inferenceScope = "fixed-sample";
report.eventCount = K;
report.observedExposureHours = T;
report.ratePerHour = K/T;
report.confidenceLevel = 1-alpha;
report.centralIntervalPerHour = [lowerCentral,upperCentral];
report.oneSidedUpperPerHour = upperOneSided;
report.zeroEventsObserved = K == 0;
report.annotationValidated = false;
report.constantRateAssumptionValidated = false;
report.independentIncrementsValidated = false;
report.unobservedExposureIncluded = false;
report.repeatedMonitoringGuaranteeClaimed = false;
end
