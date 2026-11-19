function result = describe_drift_calibration( ...
    calibrationBlocks, requestedAlpha, blockSize, persistenceBlocks)
%DESCRIBE_DRIFT_CALIBRATION Rank and idealized block-delay diagnostics.
% Strictly accepts real, finite scalar doubles.
% Scheduling intervals assume every eligible affected block qualifies.
% They are not guarantees of statistical detection.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit metadata only; not consent, identity, or operating authority.

if nargin ~= 4
    error("AugmentedHub:ArgumentCount", ...
        "Supply calibrationBlocks, alpha, blockSize, persistenceBlocks.");
end

values = {calibrationBlocks, requestedAlpha, ...
    blockSize, persistenceBlocks};

for index = 1:numel(values)
    value = values{index};
    if ~isa(value, "double") || ~isreal(value) || ...
            ~isscalar(value) || ~isfinite(value)
        error("AugmentedHub:StrictScalarDouble", ...
            "Every input must be an actual real finite scalar double.");
    end
end

integers = [calibrationBlocks, blockSize, persistenceBlocks];
if any(integers < 1) || any(integers ~= fix(integers)) || ...
        any(integers > flintmax - 1)
    error("AugmentedHub:InvalidCount", ...
        "Counts must be positive exactly representable integer doubles.");
end

if requestedAlpha <= 0 || requestedAlpha >= 1
    error("AugmentedHub:InvalidAlpha", ...
        "requestedAlpha must lie strictly between zero and one.");
end

rawRank = (calibrationBlocks + 1) * (1 - requestedAlpha);
rank = ceil(rawRank);
finiteThresholdPossible = rank <= calibrationBlocks;

% This describes a rank-tail probability/bound under stated assumptions.
% It is not an empirical false-alert rate.
rankTailBound = 0;
if finiteThresholdPossible
    rankTailBound = ...
        (calibrationBlocks + 1 - rank) / (calibrationBlocks + 1);
end

requiredBlocks = max(1, ceil(1 / requestedAlpha) - 1);

if ~isfinite(requiredBlocks) || ...
        blockSize > flintmax / (persistenceBlocks + 1)
    error("AugmentedHub:NumericalRange", ...
        "Requested precision or scheduling products exceed supported range.");
end

result = struct();
result.mode = "offline-calibration-and-scheduling-description";
result.requestedAlpha = requestedAlpha;
result.rank = rank;
result.rawRankBeforeCeiling = rawRank;
result.finiteThresholdPossible = finiteThresholdPossible;
result.requiredCalibrationBlocks = requiredBlocks;
result.exchangeabilityRankTailBound = rankTailBound;
result.rankTailInterpretation = ...
    "Marginal; exact only with appropriate tie-free exchangeability.";
result.empiricalFalseAlertRate = NaN;
result.repeatedMonitoringGuaranteeClaimed = false;

result.partialBlockEligibleDelayIntervalSamples = ...
    [(persistenceBlocks - 1)*blockSize, ...
      persistenceBlocks*blockSize];

result.fullPostChangeBlocksDelayIntervalSamples = ...
    [persistenceBlocks*blockSize, ...
     (persistenceBlocks + 1)*blockSize];

result.delayIntervalConvention = ...
    "Lower-inclusive, upper-exclusive idealized continuous sample distance.";
result.guaranteedDetectionDelaySamples = NaN;
result.hardwareControlAvailable = false;
end
