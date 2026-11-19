function report = compare_valid_window_spectra( ...
    recording, reference, valid, sampleRate, windowSamples, ...
    hopSamples, bandHz)
%COMPARE_VALID_WINDOW_SPECTRA Offline full-window rejection baseline.
% recording and reference must be synchronized and in the same units.
% reference is a supplied independent comparison channel or bench truth.
% It must not be assumed artifact-free merely because it is called reference.
% No interpolation, zero filling, stimulation control, or acquisition.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit metadata only; not consent or operating authority.

arguments
    recording {mustBeA(recording,"double"), mustBeReal}
    reference {mustBeA(reference,"double"), mustBeReal, mustBeFinite}
    valid {mustBeA(valid,"logical")}
    sampleRate {mustBePositiveScalarDouble}
    windowSamples {mustBePositiveIntegerDouble}
    hopSamples {mustBePositiveIntegerDouble}
    bandHz {mustBeA(bandHz,"double"), mustBeReal, mustBeFinite}
end

if isempty(recording) || ~isvector(recording) || ...
        ~isvector(reference) || ~isvector(valid) || ...
        numel(recording) ~= numel(reference) || ...
        numel(recording) ~= numel(valid)
    error("AugmentedHub:InputShape", ...
        "Supply matching nonempty signal and validity vectors.");
end

x = recording(:);
r = reference(:);
valid = valid(:);

if windowSamples < 4 || windowSamples > numel(x) || ...
        hopSamples > windowSamples
    error("AugmentedHub:InputValue", ...
        "Require 4<=windowSamples<=signal length and hop<=window.");
end

if any(~isfinite(x(valid))) || numel(bandHz) ~= 2 || ...
        bandHz(1) < 0 || bandHz(2) <= bandHz(1) || ...
        bandHz(2) > sampleRate/2
    error("AugmentedHub:InputValue", ...
        "Valid samples must be finite; require an ordered band within Nyquist.");
end

N = windowSamples;
w = 0.5-0.5*cos(2*pi*(0:N-1)'/(N-1));
frequency = (0:floor(N/2))'*(sampleRate/N);
selectedBand = frequency >= bandHz(1) & frequency < bandHz(2);

if ~any(selectedBand)
    error("AugmentedHub:FrequencyResolution", ...
        "No frequency bins lie within the declared half-open band.");
end

starts = (1:hopSamples:(numel(x)-N+1)).';
K = numel(frequency);
sumRecording = zeros(K,1);
sumReferenceMatched = zeros(K,1);
sumReferenceAll = zeros(K,1);
retained = false(numel(starts),1);

for index = 1:numel(starts)
    rows = starts(index):(starts(index)+N-1);
    referencePSD = oneSidedPSD(r(rows),w,sampleRate);
    sumReferenceAll = sumReferenceAll+referencePSD;

    if all(valid(rows))
        retained(index) = true;
        sumRecording = sumRecording+oneSidedPSD(x(rows),w,sampleRate);
        sumReferenceMatched = sumReferenceMatched+referencePSD;
    end
end

count = sum(retained);
recordingPSD = NaN(K,1);
referenceMatchedPSD = NaN(K,1);

if count > 0
    recordingPSD = sumRecording/count;
    referenceMatchedPSD = sumReferenceMatched/count;
end

referenceAllPSD = sumReferenceAll/numel(starts);
deltaF = sampleRate/N;

recordingBandPower = sum(recordingPSD(selectedBand))*deltaF;
referenceMatchedBandPower = ...
    sum(referenceMatchedPSD(selectedBand))*deltaF;
referenceAllBandPower = sum(referenceAllPSD(selectedBand))*deltaF;

relativeBandError = NaN;
if count > 0 && referenceMatchedBandPower > 0
    relativeBandError = ...
        (recordingBandPower-referenceMatchedBandPower) ...
        /referenceMatchedBandPower;
end

report = struct();
report.mode = "offline-full-window-rejection-comparison";
report.bandConvention = "lower-inclusive, upper-exclusive";
report.retainedWindowFraction = count/numel(starts);
report.retainedWindowCount = count;
report.recordingBandPower = recordingBandPower;
report.referenceMatchedBandPower = referenceMatchedBandPower;
report.referenceAllWindowBandPower = referenceAllBandPower;
report.relativeMatchedBandPowerError = relativeBandError;
report.referenceSelectionDifference = ...
    referenceMatchedBandPower-referenceAllBandPower;
report.referenceIndependenceVerified = false;
report.confidenceIntervalsEstimated = false;
report.overlappingWindowsAreIndependent = false;
report.windowStartsSamples = starts;
report.retainedWindows = retained;
report.spectra = table( ...
    frequency,recordingPSD,referenceMatchedPSD,referenceAllPSD);
end

function psd = oneSidedPSD(signal,w,fs)
N = numel(signal);
spectrum = fft(signal.*w);
psd = abs(spectrum(1:floor(N/2)+1)).^2/(fs*sum(w.^2));

if mod(N,2) == 0
    psd(2:end-1) = 2*psd(2:end-1);
else
    psd(2:end) = 2*psd(2:end);
end
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
