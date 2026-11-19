function report = audit_spectral_release( ...
    frameMicrovolts, sampleRateHz, meanPolicy, nominalRailMicrovolts, ...
    channelNames, numericalArrayBudgetBytes, includeIntermediateFrames)
%AUDIT_SPECTRAL_RELEASE Versioned wrapper around the existing frame audit.
% Requires audit_spectral_frame_contract.m on the MATLAB path.
% Text policy is strict: "raw", "weighted", "none"; no case/space repair.
% Numerical memory estimate is not a bound on total MATLAB process memory.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream namespace metadata, not cryptographic attestation,
% identity, biological binding, consent, authority, or execution evidence.

arguments
    frameMicrovolts {mustBeA(frameMicrovolts,"double"), ...
        mustBeReal, mustBeFinite}
    sampleRateHz {mustBePositiveScalarDouble}
    meanPolicy {mustBeA(meanPolicy,"string")}
    nominalRailMicrovolts {mustBePositiveScalarDouble}
    channelNames {mustBeA(channelNames,"string")}
    numericalArrayBudgetBytes {mustBePositiveScalarDouble}
    includeIntermediateFrames ...
        {mustBeA(includeIntermediateFrames,"logical")} = false
end

x = frameMicrovolts;
if isempty(x) || ~ismatrix(x) || size(x,1) < 4
    error("AugmentedHub:InputShape", ...
        "Require at least four samples in a samples-by-channels matrix.");
end

[N,C] = size(x);
names = channelNames(:);

if ~isvector(channelNames) || numel(names) ~= C || ...
        any(ismissing(names)) || any(strlength(names) == 0) || ...
        numel(unique(names)) ~= C || ~isscalar(includeIntermediateFrames)
    error("AugmentedHub:InputConsistency", ...
        "Supply distinct nonempty channel names and a scalar retention option.");
end

% Prototype estimate: 18 real and 3 complex arrays per sample/channel.
estimatedNumericalArrayBytes = N*C*(18*8+3*16);
if ~isfinite(estimatedNumericalArrayBytes) || ...
        estimatedNumericalArrayBytes > numericalArrayBudgetBytes
    error("AugmentedHub:ResourceBudget", ...
        "Declared numerical-array budget is insufficient for this audit.");
end

base = audit_spectral_frame_contract( ...
    x,sampleRateHz,meanPolicy,nominalRailMicrovolts);

w = 0.5-0.5*cos(2*pi*(0:N-1)'/N);

% Independent denominator path for the coherent-normalized spectrum.
direct = abs(base.processedFrameDFT(1:floor(N/2)+1,:)).^2 ...
    /sum(w)^2;

if mod(N,2) == 0
    direct(2:end-1,:) = 2*direct(2:end-1,:);
else
    direct(2:end,:) = 2*direct(2:end,:);
end

difference = direct-base.coherentNormalizedSpectrum;
conversionScale = max(1,max(abs(direct),[],1));

report = base;
report.documentVersion = "0.2.0";
report.channelNames = names;
report.nominalRailMicrovolts = nominalRailMicrovolts;
report.railCountMeaning = ...
    "Samples at or beyond a supplied nominal symmetric magnitude.";
report.railCountsAreSaturationProof = false;
report.textPolicy = "strict; case and whitespace are not normalized";
report.estimatedNumericalArrayBytes = estimatedNumericalArrayBytes;
report.numericalArrayBudgetBytes = numericalArrayBudgetBytes;
report.memoryEstimateIsProcessLimit = false;
report.directCoherentNormalizedSpectrum = direct;
report.normalizationConversionRelativeResidual = ...
    max(abs(difference),[],1)./conversionScale;

report.quantityScopes = struct( ...
    "processedFrameDFT", ...
    "Two-sided complex DFT of the centered, tapered supplied frame", ...
    "oneSidedPSD", ...
    "Real-input one-sided density; DC/Nyquist not doubled", ...
    "coherentNormalizedSpectrum", ...
    "Real-input one-sided squared magnitude divided by coherent gain squared", ...
    "taperWeightedMeanSquare", ...
    "Squared norm of tapered centered frame divided by sum(taper squared)");

report.parsevalToleranceStatus = ...
    "Engineering diagnostic tolerance; not a rigorous universal error bound";
report.intermediateFramesIncluded = includeIntermediateFrames;

if includeIntermediateFrames
    centered = x-base.removedMeanMicrovolts;
    report.centeredFrameMicrovolts = centered;
    report.processedFrameMicrovolts = w.*centered;
end

report.executionEvidenceStatus = ...
    "Must be supplied by an external test runner; source existence is not execution";
end

function mustBePositiveScalarDouble(value)
if ~isa(value,"double") || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(value) || value <= 0
    error("AugmentedHub:InputValue", ...
        "Require an actual positive finite scalar double.");
end
end
