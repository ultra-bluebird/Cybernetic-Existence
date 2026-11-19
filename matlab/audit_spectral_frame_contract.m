function report = audit_spectral_frame_contract( ...
    frameMicrovolts, sampleRateHz, meanPolicy, fullScaleMicrovolts)
%AUDIT_SPECTRAL_FRAME_CONTRACT Offline numerical contract audit.
% Rows are samples; columns are channels.
% meanPolicy: "none", "raw", or "weighted".
% fullScaleMicrovolts is a supplied symmetric acquisition rail magnitude.
% Complex DFT output preserves the phase of the processed, tapered frame,
% not information removed by detrending or tapering.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not identity, consent, or execution evidence.

arguments
    frameMicrovolts {mustBeA(frameMicrovolts,"double"), ...
        mustBeReal, mustBeFinite}
    sampleRateHz {mustBePositiveScalarDouble}
    meanPolicy {mustBeA(meanPolicy,"string")}
    fullScaleMicrovolts {mustBePositiveScalarDouble}
end

x = frameMicrovolts;
if isempty(x) || ~ismatrix(x) || size(x,1) < 4
    error("AugmentedHub:InputShape", ...
        "Supply at least four samples in a samples-by-channels matrix.");
end

if ~isscalar(meanPolicy) || ismissing(meanPolicy) || ...
        ~any(meanPolicy == ["none","raw","weighted"])
    error("AugmentedHub:InputValue", ...
        "meanPolicy must be none, raw, or weighted.");
end

N = size(x,1);
w = 0.5-0.5*cos(2*pi*(0:N-1)'/N);

switch meanPolicy
    case "none"
        removedMean = zeros(1,size(x,2));
    case "raw"
        removedMean = mean(x,1);
    case "weighted"
        removedMean = sum(w.*x,1)/sum(w);
end

processed = w.*(x-removedMean);
Z = fft(processed,[],1);

densityTwoSided = abs(Z).^2/(sampleRateHz*sum(w.^2));
density = densityTwoSided(1:floor(N/2)+1,:);

if mod(N,2) == 0
    density(2:end-1,:) = 2*density(2:end-1,:);
else
    density(2:end,:) = 2*density(2:end,:);
end

deltaF = sampleRateHz/N;
integratedPSD = sum(density,1)*deltaF;
weightedMeanSquare = sum(processed.^2,1)/sum(w.^2);

if any(~isfinite(density),"all") || ...
        any(~isfinite(weightedMeanSquare))
    error("AugmentedHub:NumericalRange", ...
        "Spectral arithmetic exceeded finite double range.");
end

enbwHz = sampleRateHz*sum(w.^2)/sum(w)^2;
coherentSpectrum = density*enbwHz;

scale = max(1,abs(integratedPSD)+abs(weightedMeanSquare));
tolerance = 128*eps*max(1,ceil(log2(N)))*scale;
residual = integratedPSD-weightedMeanSquare;

report = struct();
report.mode = "offline-spectral-numerical-contract-audit";
report.signalUnit = "microvolt";
report.psdUnit = "microvolt_squared_per_hertz";
report.coherentSpectrumUnit = "microvolt_squared";
report.taper = "periodic-Hann";
report.meanPolicy = meanPolicy;
report.removedMeanMicrovolts = removedMean;
report.enbwHz = enbwHz;
report.enbwBins = enbwHz/deltaF;
report.integratedPSD = integratedPSD;
report.taperWeightedMeanSquare = weightedMeanSquare;
report.parsevalResidual = residual;
report.parsevalDiagnosticTolerance = tolerance;
report.parsevalDiagnosticPassed = abs(residual) <= tolerance;
report.atOrBeyondDeclaredRailCount = ...
    sum(abs(x) >= fullScaleMicrovolts,1);
report.frontEndLinearityVerified = false;
report.physiologicalEquivalenceValidated = false;
report.identityLeakageAssessed = false;
report.frequencyHz = (0:floor(N/2))'*deltaF;
report.oneSidedPSD = density;
report.coherentNormalizedSpectrum = coherentSpectrum;
report.processedFrameDFT = Z;
report.phaseRepresentationScope = ...
    "Two-sided complex DFT of detrended and tapered supplied frame";
end

function mustBePositiveScalarDouble(value)
if ~isa(value,"double") || ~isscalar(value) || ...
        ~isreal(value) || ~isfinite(value) || value <= 0
    error("AugmentedHub:InputValue", ...
        "Require an actual positive finite scalar double.");
end
end
