function report = extract_spectral_features( ...
    signalMicrovolts, sampleRateHz, windowSamples, hopSamples, ...
    bandsHz, channelNames, referencePowerMicrovoltsSquared, ...
    timeOriginSeconds)
%EXTRACT_SPECTRAL_FEATURES Offline causal-window band-power extraction.
% signalMicrovolts: samples-by-channels, all finite.
% bandsHz: bands-by-2, lower-inclusive and upper-exclusive.
% referencePowerMicrovoltsSquared: bands-by-channels, strictly positive.
% No acquisition, calibration fitting, model inference, or hardware control.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not consent or execution evidence.

arguments
    signalMicrovolts {mustBeA(signalMicrovolts,"double"), ...
        mustBeReal, mustBeFinite}
    sampleRateHz {mustBePositiveScalarDouble}
    windowSamples {mustBePositiveIntegerDouble}
    hopSamples {mustBePositiveIntegerDouble}
    bandsHz {mustBeA(bandsHz,"double"), mustBeReal, mustBeFinite}
    channelNames {mustBeA(channelNames,"string")}
    referencePowerMicrovoltsSquared ...
        {mustBeA(referencePowerMicrovoltsSquared,"double"), ...
        mustBeReal, mustBeFinite}
    timeOriginSeconds {mustBeA(timeOriginSeconds,"double"), ...
        mustBeReal, mustBeFinite}
end

x = signalMicrovolts;

if isempty(x) || ~ismatrix(x)
    error("AugmentedHub:InputShape", ...
        "Supply a nonempty samples-by-channels matrix.");
end

[sampleCount,channelCount] = size(x);

if windowSamples < 4 || windowSamples > sampleCount || ...
        hopSamples > windowSamples || ~isscalar(timeOriginSeconds)
    error("AugmentedHub:InputValue", ...
        "Require 4<=window<=sample count, hop<=window, and scalar origin.");
end

if isempty(bandsHz) || ~ismatrix(bandsHz) || size(bandsHz,2) ~= 2 || ...
        any(bandsHz(:,1) < 0) || ...
        any(bandsHz(:,2) <= bandsHz(:,1)) || ...
        any(bandsHz(:,2) > sampleRateHz/2)
    error("AugmentedHub:InputValue", ...
        "Bands must be ordered pairs within the Nyquist range.");
end

bandCount = size(bandsHz,1);
names = channelNames(:);

if ~isvector(channelNames) || numel(names) ~= channelCount || ...
        any(ismissing(names)) || any(strlength(names) == 0) || ...
        numel(unique(names)) ~= channelCount
    error("AugmentedHub:InputConsistency", ...
        "Supply one distinct nonempty name per channel.");
end

reference = referencePowerMicrovoltsSquared;
if ~isequal(size(reference),[bandCount,channelCount]) || ...
        any(reference <= 0,"all")
    error("AugmentedHub:InputConsistency", ...
        "Reference power must be positive with shape bands-by-channels.");
end

N = windowSamples;
frequency = (0:floor(N/2))'*(sampleRateHz/N);
deltaFrequency = sampleRateHz/N;
taper = 0.5-0.5*cos(2*pi*(0:N-1)'/N);
normalizer = sampleRateHz*sum(taper.^2);

bandMembership = false(numel(frequency),bandCount);
for band = 1:bandCount
    bandMembership(:,band) = ...
        frequency >= bandsHz(band,1) & frequency < bandsHz(band,2);
end

if any(sum(bandMembership,1) == 0)
    error("AugmentedHub:FrequencyResolution", ...
        "Every band must contain at least one available Fourier bin.");
end

starts = (1:hopSamples:(sampleCount-N+1)).';
frameCount = numel(starts);
power = zeros(frameCount,bandCount,channelCount);
logRatio = zeros(size(power));

for frame = 1:frameCount
    rows = starts(frame):(starts(frame)+N-1);
    segment = x(rows,:);
    segment = segment-mean(segment,1);

    transformed = fft(segment.*taper,[],1);
    psd = abs(transformed(1:numel(frequency),:)).^2/normalizer;

    if mod(N,2) == 0
        psd(2:end-1,:) = 2*psd(2:end-1,:);
    else
        psd(2:end,:) = 2*psd(2:end,:);
    end

    bandPower = double(bandMembership).'*psd*deltaFrequency;

    if any(~isfinite(bandPower),"all")
        error("AugmentedHub:NumericalRange", ...
            "Spectral calculations exceeded finite arithmetic.");
    end

    power(frame,:,:) = reshape(bandPower,[1,bandCount,channelCount]);
    logRatio(frame,:,:) = reshape( ...
        log(bandPower)-log(reference),[1,bandCount,channelCount]);
end

startTime = timeOriginSeconds+(starts-1)/sampleRateHz;
lastSampleTime = timeOriginSeconds+(starts+N-2)/sampleRateHz;

if any(~isfinite(startTime)) || any(~isfinite(lastSampleTime))
    error("AugmentedHub:NumericalRange", ...
        "Feature timestamps exceeded finite arithmetic.");
end

report = struct();
report.mode = "offline-causal-window-spectral-features";
report.channelNames = names;
report.bandsHz = bandsHz;
report.bandPowerMicrovoltsSquared = power;
report.logPowerRatio = logRatio;
report.referencePowerMicrovoltsSquared = reference;
report.zeroPowerFeatureCount = sum(power == 0,"all");
report.windowStartSeconds = startTime;
report.lastRequiredSampleSeconds = lastSampleTime;
report.frequencyBinSpacingHz = deltaFrequency;
report.taper = "periodic-Hann";
report.preprocessing = "per-window per-channel mean removal";
report.bandConvention = "lower-inclusive, upper-exclusive";
report.computeLatencyMeasured = false;
report.decoderPerformanceValidated = false;
end

function mustBePositiveScalarDouble(value)
if ~isa(value,"double") || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(value) || value <= 0
    error("AugmentedHub:InputValue", ...
        "Require an actual positive finite scalar double.");
end
end

function mustBePositiveIntegerDouble(value)
mustBePositiveScalarDouble(value);
if value ~= fix(value) || value > flintmax
    error("AugmentedHub:InputValue", ...
        "Require a positive exactly representable integer double.");
end
end
