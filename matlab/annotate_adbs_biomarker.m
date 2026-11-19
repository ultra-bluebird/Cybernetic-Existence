function result = annotate_adbs_biomarker( ...
    timeSeconds, feature, usable, lowerThreshold, ...
    upperThreshold, timeConstantSeconds, maximumGapSeconds)
%ANNOTATE_ADBS_BIOMARKER Offline annotation, not a device controller.
% feature: dimensionless, externally normalized biomarker values.
% usable: data-quality and permitted-analysis mask.
% Labels describe feature regions, not symptoms or treatment needs.
% Invalid rows break smoothing continuity. No data are interpolated.
% No hardware, network, file writing, or stimulation commands are used.

arguments
    timeSeconds (:,1) double
    feature (:,1) double
    usable (:,1) logical
    lowerThreshold (1,1) double {mustBeFinite}
    upperThreshold (1,1) double {mustBeFinite}
    timeConstantSeconds (1,1) double ...
        {mustBeFinite, mustBePositive}
    maximumGapSeconds (1,1) double ...
        {mustBeFinite, mustBePositive}
end

count = numel(timeSeconds);

if count < 2 || numel(feature) ~= count || numel(usable) ~= count
    error("AugmentedHub:InvalidDimensions", ...
        "Supply at least two matching observation rows.");
end

if any(~isfinite(timeSeconds)) || any(diff(timeSeconds) <= 0)
    error("AugmentedHub:InvalidTime", ...
        "Timestamps must be finite and strictly increasing.");
end

if lowerThreshold >= upperThreshold
    error("AugmentedHub:InvalidThresholds", ...
        "The lower threshold must be below the upper threshold.");
end

effectiveUsable = usable & isfinite(feature);
smoothed = NaN(count, 1);
region = repmat("unavailable", count, 1);
segmentStart = false(count, 1);

previousValid = false;
previousValue = NaN;

for index = 1:count
    if ~effectiveUsable(index)
        previousValid = false;
        continue;
    end

    restart = ~previousValid;
    if index > 1
        restart = restart || ...
            timeSeconds(index) - timeSeconds(index - 1) ...
            > maximumGapSeconds;
    end

    if restart
        currentValue = feature(index);
        segmentStart(index) = true;
    else
        deltaSeconds = timeSeconds(index) - timeSeconds(index - 1);
        alpha = -expm1(-deltaSeconds / timeConstantSeconds);
        currentValue = alpha * feature(index) ...
            + (1 - alpha) * previousValue;
    end

    smoothed(index) = currentValue;

    if currentValue < lowerThreshold
        region(index) = "below-band";
    elseif currentValue > upperThreshold
        region(index) = "above-band";
    else
        region(index) = "within-band";
    end

    previousValue = currentValue;
    previousValid = true;
end

result = struct();
result.mode = "offline-biomarker-annotation";
result.hardwareControlAvailable = false;
result.usableFraction = sum(effectiveUsable) / count;
result.segmentCount = sum(segmentStart);
result.observations = table( ...
    timeSeconds, feature, usable, effectiveUsable, ...
    smoothed, region, segmentStart);
end
