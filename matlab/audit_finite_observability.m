function report = audit_finite_observability( ...
    A, C, observationCovariance, stateScales, horizonSteps, ...
    sampleIntervalSeconds, relativeRankTolerance, arrayBudgetBytes)
%AUDIT_FINITE_OBSERVABILITY Offline finite-horizon linear-model audit.
% x = diag(stateScales)*z, where z is dimensionless.
% observationCovariance describes one observation time.
% Whitening assumes independent observation errors across time.
% No physiological model fitting, sensing, stimulation, or device control.
%
% Attribution:
% bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
% Credit/workstream metadata only; not consent or execution evidence.

arguments
    A {mustBeA(A,"double"), mustBeReal, mustBeFinite}
    C {mustBeA(C,"double"), mustBeReal, mustBeFinite}
    observationCovariance {mustBeA(observationCovariance,"double"), ...
        mustBeReal, mustBeFinite}
    stateScales {mustBeA(stateScales,"double"), mustBeReal, mustBeFinite}
    horizonSteps {mustBePositiveIntegerDouble}
    sampleIntervalSeconds {mustBePositiveScalarDouble}
    relativeRankTolerance {mustBeOpenUnitScalarDouble}
    arrayBudgetBytes {mustBePositiveScalarDouble}
end

[n,nColumns] = size(A);
[m,cColumns] = size(C);

if isempty(A) || ~ismatrix(A) || n ~= nColumns || ...
        isempty(C) || ~ismatrix(C) || cColumns ~= n || ...
        ~isvector(stateScales) || numel(stateScales) ~= n || ...
        any(stateScales <= 0)
    error("AugmentedHub:InputShape", ...
        "Supply compatible model matrices and positive state scales.");
end

R = observationCovariance;
if ~isequal(size(R),[m,m]) || ~isequal(R,R.')
    error("AugmentedHub:InputValue", ...
        "Observation covariance must be exactly symmetric and match C.");
end

[L,flag] = chol(R,"lower");
if flag ~= 0
    error("AugmentedHub:InputValue", ...
        "Observation covariance must be positive definite.");
end

rows = m*horizonSteps;

% Planning estimate for major numerical arrays, not total process memory.
estimatedBytes = 8*(4*rows*n + 8*n*n + 4*m*n);
if ~isfinite(estimatedBytes) || estimatedBytes > arrayBudgetBytes
    error("AugmentedHub:ResourceBudget", ...
        "Estimated numerical-array storage exceeds the declared budget.");
end

scales = stateScales(:);
Az = (A.*scales.')./scales;
Cz = C.*scales.';
whitenedC = L\Cz;

O = zeros(rows,n);
powerA = eye(n);

for step = 1:horizonSteps
    selectedRows = (step-1)*m+(1:m);
    O(selectedRows,:) = whitenedC*powerA;

    if any(~isfinite(O(selectedRows,:)),"all")
        error("AugmentedHub:NumericalRange", ...
            "Observability construction exceeded finite arithmetic.");
    end

    if step < horizonSteps
        powerA = powerA*Az;
    end
end

singularValues = svd(O,"econ");
singularValues = [singularValues; ...
    zeros(n-numel(singularValues),1)];

largest = max(singularValues);
absoluteCutoff = relativeRankTolerance*largest;

if largest == 0
    numericalRank = 0;
    unresolvedBasis = eye(n);
else
    numericalRank = sum(singularValues > absoluteCutoff);
    unresolvedBasis = null(O,absoluteCutoff);
end

conditionRatio = Inf;
if numericalRank == n
    conditionRatio = singularValues(1)/singularValues(end);
end

report = struct();
report.mode = "offline-finite-horizon-scaled-observability";
report.horizonSteps = horizonSteps;
report.firstToLastObservationSeconds = ...
    (horizonSteps-1)*sampleIntervalSeconds;
report.stateScales = scales;
report.relativeRankTolerance = relativeRankTolerance;
report.absoluteSingularValueCutoff = absoluteCutoff;
report.singularValues = singularValues;
report.numericalRank = numericalRank;
report.stateDimension = n;
report.fullRankAtDeclaredTolerance = numericalRank == n;
report.singularValueConditionRatio = conditionRatio;
report.unresolvedDirectionsInNormalizedCoordinates = unresolvedBasis;
report.whitenedObservabilityMatrix = O;
report.estimatedArrayBytes = estimatedBytes;
report.independentObservationErrorsAssumed = true;
report.modelParametersValidated = false;
report.physiologicalInterpretationValidated = false;
report.clinicalBenefitEstablished = false;
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

function mustBeOpenUnitScalarDouble(value)
mustBePositiveScalarDouble(value);
if value >= 1
    error("AugmentedHub:InputValue", ...
        "Relative tolerance must lie strictly between zero and one.");
end
end
