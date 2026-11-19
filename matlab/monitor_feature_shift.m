function result = monitor_feature_shift( ...
    reference, calibration, monitoring, blockSize, ...
    alertTailFraction, ridge, persistenceBlocks)
% Offline feature-shift screening with a frozen reference.
% Rows: observations. Columns: externally prepared feature dimensions.
% Arrays must have matching feature definitions, units, and normalization.
% Rows must belong to contiguous valid segments with no hidden gaps.
% Blocks do not overlap. Incomplete trailing blocks are not scored.
% No labels, clinical interpretation, recalibration, or device control.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Attribution is credit metadata, not consent or operating authority.

arguments
    reference (:,:) double
    calibration (:,:) double
    monitoring (:,:) double
    blockSize (1,1) double ...
        {mustBeInteger, mustBePositive}
    alertTailFraction (1,1) double ...
        {mustBeGreaterThan(alertTailFraction, 0), ...
        mustBeLessThan(alertTailFraction, 1)}
    ridge (1,1) double {mustBeFinite, mustBePositive}
    persistenceBlocks (1,1) double ...
        {mustBeInteger, mustBePositive}
end

dimension = size(reference, 2);

if dimension < 1 || size(reference, 1) < 2 || ...
        size(calibration, 2) ~= dimension || ...
        size(monitoring, 2) ~= dimension
    error("AugmentedHub:InvalidDimensions", ...
        "Supply matching nonempty feature dimensions and reference rows.");
end

if ~isreal(reference) || ~isreal(calibration) || ...
        ~isreal(monitoring) || ...
        any(~isfinite(reference), "all") || ...
        any(~isfinite(calibration), "all") || ...
        any(~isfinite(monitoring), "all")
    error("AugmentedHub:InvalidFeatures", ...
        "All supplied features must be real and finite.");
end

if size(calibration, 1) < blockSize || ...
        size(monitoring, 1) < blockSize
    error("AugmentedHub:InsufficientBlocks", ...
        "Calibration and monitoring each need at least one full block.");
end

mu = mean(reference, 1);
centered = reference - mu;
covariance = (centered.' * centered) / (size(reference, 1)-1);
regularized = covariance + ridge*eye(dimension);
[L, flag] = chol(regularized, "lower");

if flag ~= 0
    error("AugmentedHub:CovarianceFailure", ...
        "Regularized covariance was not numerically positive definite.");
end

calibrationScores = blockScores(calibration, mu, L, blockSize);
monitoringScores = blockScores(monitoring, mu, L, blockSize);

sortedScores = sort(calibrationScores);
rank = ceil((numel(sortedScores)+1)*(1-alertTailFraction));

threshold = Inf;
if rank <= numel(sortedScores)
    threshold = sortedScores(rank);
end

exceeds = monitoringScores > threshold;
reviewFlag = false(size(exceeds));
runLength = 0;

for index = 1:numel(exceeds)
    if exceeds(index)
        runLength = runLength + 1;
    else
        runLength = 0;
    end
    reviewFlag(index) = runLength >= persistenceBlocks;
end

result = struct();
result.mode = "offline-feature-shift-screening";
result.hardwareControlAvailable = false;
result.referenceMean = mu;
result.referenceCovariance = regularized;
result.threshold = threshold;
result.thresholdResolvable = isfinite(threshold);
result.calibrationBlockCount = numel(calibrationScores);
result.monitoring = table( ...
    (1:numel(monitoringScores)).', monitoringScores, exceeds, reviewFlag, ...
    "VariableNames", ["block", "score", "exceeds", "reviewFlag"]);
result.unscoredCalibrationRows = mod(size(calibration,1), blockSize);
result.unscoredMonitoringRows = mod(size(monitoring,1), blockSize);
end

function scores = blockScores(data, mu, L, blockSize)
whitened = (L \ (data - mu).').';
distanceSquared = sum(whitened.^2, 2);
count = floor(numel(distanceSquared)/blockSize);
used = distanceSquared(1:count*blockSize);
scores = mean(reshape(used, blockSize, count), 1).';
end
