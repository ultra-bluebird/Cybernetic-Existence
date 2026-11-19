% Path: analysis/matlab/roh_from_statevector_biohost.m
%
% Biohost-extended RoH from StateVectorN for offline analysis.
% All inputs are assumed normalized into [0,1].

function roh = roh_from_statevector_biohost(sv, w)
% sv: struct with fields Tnorm, ATPnorm, Psychnorm, Biofilmnorm, Motionnorm
% w:  struct with fields wT, wATP, wPsych, wBiofilm, wMotion

    % Basic validation (lightweight, not exhaustive).
    fields_sv = {'Tnorm','ATPnorm','Psychnorm','Biofilmnorm','Motionnorm'};
    for k = 1:numel(fields_sv)
        f = fields_sv{k};
        if ~isfield(sv, f)
            error('StateVectorN missing field: %s', f);
        end
        x = sv.(f);
        if ~isfinite(x) || x < 0.0 || x > 1.0
            error('StateVectorN.%s must be in [0,1]', f);
        end
    end

    fields_w = {'wT','wATP','wPsych','wBiofilm','wMotion'};
    wsum = 0.0;
    for k = 1:numel(fields_w)
        f = fields_w{k};
        if ~isfield(w, f)
            error('Weights missing field: %s', f);
        end
        wi = w.(f);
        if ~isfinite(wi) || wi < 0.0
            error('Weight %s must be non-negative', f);
        end
        wsum = wsum + wi;
    end
    if abs(wsum - 1.0) > 1e-9
        error('Weights must sum to 1.0 (got %.12f)', wsum);
    end

    % Component risks (convex maps).
    RT      = sv.Tnorm.^2;
    RATP    = (1.0 - sv.ATPnorm).^2;
    Rpsych  = sv.Psychnorm.^2;
    Rbio    = sv.Biofilmnorm.^2;
    Rmotion = sv.Motionnorm.^2;

    roh = ...
        w.wT      .* RT + ...
        w.wATP    .* RATP + ...
        w.wPsych  .* Rpsych + ...
        w.wBiofilm.* Rbio + ...
        w.wMotion .* Rmotion;
end
