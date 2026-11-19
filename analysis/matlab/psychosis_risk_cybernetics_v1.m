% Path: analysis/matlab/psychosis_risk_cybernetics_v1.m
%
% Psychosis risk model for cybernetic control and nanoswarm safety.
% This file:
%   - normalizes psych/physio inputs into [0,1]
%   - computes dimension-wise risk indices
%   - aggregates them into a convex psychosis-risk scalar R_psychosis in [0,1]
%   - provides helper functions for calibration and visualization
%
% It is designed to be structurally compatible with:
%   - PsychCaps & NeurorightsMicroshield (pain, fear, cognitive load, identity disruption)
%   - RoH(StateVectorN) with a psych component R_psych
% described in your existing specs. [file:1][file:3]

function out = psychosis_risk_cybernetics_v1(raw, params)
% out = psychosis_risk_cybernetics_v1(raw, params)
%
% raw: struct of raw telemetry and psychometrics, for example:
%   raw.pain_vas            ∈ [0,10]   visual analog scale
%   raw.fear_anxiety_scale  ∈ [0,21]   e.g., GAD-7 or similar
%   raw.cog_load_index      ∈ [0,100]  task-based cognitive load metric
%   raw.identity_diss_scale ∈ [0,10]   identity disruption / dissociation
%   raw.halluc_scale        ∈ [0,24]   hallucination rating scale
%   raw.delusion_scale      ∈ [0,24]   delusion rating scale
%   raw.sleep_hours         ∈ [0,14]   sleep in last 24h
%   raw.stress_cortisol     arbitrary  relative cortisol or stress index
%   raw.manic_scale         ∈ [0,60]   mania / agitation scale
%
% params: struct of calibration parameters (see default_params() below).
%
% out: struct with fields:
%   out.norm   .. normalized axes in [0,1]
%   out.comp   .. component risks (convex maps) in [0,1]
%   out.R_psychosis .. scalar psychosis risk ∈ [0,1]
%   out.R_state_vector .. 3-axis summary suitable for plugging into RoH:
%       R_state_vector = [R_thought_disorder, R_affective, R_identity]
%
% All transformations are monotone; higher symptom burden → higher risk. [file:3]

    if nargin < 2
        params = default_params();
    end

    % 1. Normalize raw inputs into [0,1]
    n = normalize_inputs(raw, params);

    % 2. Compute dimension-wise risk components (convex, increasing)
    c = component_risks(n, params);

    % 3. Aggregate into scalar psychosis risk using convex combination
    R_psy = aggregate_risk(c, params);

    % 4. Map to a 3-axis vector for StateVectorN Psychnorm-style usage
    R_state_vector = three_axis_projection(c, params);

    out = struct();
    out.norm = n;
    out.comp = c;
    out.R_psychosis = R_psy;
    out.R_state_vector = R_state_vector;
end

%% ------------------------------------------------------------------------
%% Default calibration parameters
%% ------------------------------------------------------------------------
function p = default_params()
% Default calibration values; tune per-host using clinical & biomarker data. [file:3]

    % Normalization ranges for raw inputs
    p.norm.pain_vas_max            = 10.0;
    p.norm.fear_anxiety_scale_max  = 21.0;
    p.norm.cog_load_index_max      = 100.0;
    p.norm.identity_diss_scale_max = 10.0;
    p.norm.halluc_scale_max        = 24.0;
    p.norm.delusion_scale_max      = 24.0;
    p.norm.sleep_low_hours         = 3.0;    % <=3h strongly abnormal
    p.norm.sleep_high_hours        = 9.0;    % >=9h considered non-acute for psychosis
    p.norm.stress_cortisol_ref     = 1.0;    % reference "normal" stress index
    p.norm.stress_cortisol_high    = 3.0;    % high stress index
    p.norm.manic_scale_max         = 60.0;

    % Nonlinear exponents for risk maps (convexity)
    p.comp.exponent_positive   = 2.0;  % x^2 growth for positive symptoms
    p.comp.exponent_identity   = 2.0;  % identity disruption
    p.comp.exponent_affective  = 2.0;  % affective / stress
    p.comp.exponent_sleep      = 2.0;  % sleep deprivation
    
    % Weights for aggregation into R_psychosis
    % Sum must equal 1.0.
    p.agg.w_thought      = 0.40;  % hallucinations + delusions + cognitive disorg.
    p.agg.w_identity     = 0.20;  % identity disruption / dissociation
    p.agg.w_affective    = 0.20;  % anxiety + stress + mania
    p.agg.w_sleep        = 0.10;  % sleep deprivation
    p.agg.w_pain_cog     = 0.10;  % pain + cognitive load interaction
    
    % Projection weights into 3-axis psych vector
    % These are used to map component risks into:
    %   R_thought_disorder, R_affective, R_identity
    p.proj.w_thought_from_positive = 0.7;
    p.proj.w_thought_from_cog      = 0.3;
    p.proj.w_aff_from_anx_stress   = 0.8;
    p.proj.w_aff_from_sleep        = 0.2;
    p.proj.w_id_from_identity      = 1.0;
end

%% ------------------------------------------------------------------------
%% Normalization helpers
%% ------------------------------------------------------------------------
function n = normalize_inputs(raw, p)
% Map raw inputs to normalized [0,1] variables. [file:3]

    % Helper for clamping
    clamp01 = @(x) max(0.0, min(1.0, x));

    % Pain
    n.pain = 0.0;
    if isfield(raw, 'pain_vas')
        n.pain = clamp01(raw.pain_vas / p.norm.pain_vas_max);
    end

    % Fear / anxiety
    n.anxiety = 0.0;
    if isfield(raw, 'fear_anxiety_scale')
        n.anxiety = clamp01(raw.fear_anxiety_scale / p.norm.fear_anxiety_scale_max);
    end

    % Cognitive load
    n.cog_load = 0.0;
    if isfield(raw, 'cog_load_index')
        n.cog_load = clamp01(raw.cog_load_index / p.norm.cog_load_index_max);
    end

    % Identity disruption
    n.identity_disr = 0.0;
    if isfield(raw, 'identity_diss_scale')
        n.identity_disr = clamp01(raw.identity_diss_scale / p.norm.identity_diss_scale_max);
    end

    % Hallucinations
    n.halluc = 0.0;
    if isfield(raw, 'halluc_scale')
        n.halluc = clamp01(raw.halluc_scale / p.norm.halluc_scale_max);
    end

    % Delusions
    n.delusion = 0.0;
    if isfield(raw, 'delusion_scale')
        n.delusion = clamp01(raw.delusion_scale / p.norm.delusion_scale_max);
    end

    % Sleep: map low hours to high risk, normal to low risk
    n.sleep_depr = 0.0;
    if isfield(raw, 'sleep_hours')
        h = raw.sleep_hours;
        if h <= p.norm.sleep_low_hours
            n.sleep_depr = 1.0;
        elseif h >= p.norm.sleep_high_hours
            n.sleep_depr = 0.0;
        else
            % linear interpolation between low and high
            t = (h - p.norm.sleep_low_hours) / ...
                (p.norm.sleep_high_hours - p.norm.sleep_low_hours);
            n.sleep_depr = clamp01(1.0 - t);
        end
    end

    % Stress / cortisol
    n.stress = 0.0;
    if isfield(raw, 'stress_cortisol')
        x = raw.stress_cortisol;
        lo = p.norm.stress_cortisol_ref;
        hi = p.norm.stress_cortisol_high;
        if x <= lo
            n.stress = 0.0;
        elseif x >= hi
            n.stress = 1.0;
        else
            n.stress = clamp01((x - lo) / (hi - lo));
        end
    end

    % Mania / agitation
    n.mania = 0.0;
    if isfield(raw, 'manic_scale')
        n.mania = clamp01(raw.manic_scale / p.norm.manic_scale_max);
    end
end

%% ------------------------------------------------------------------------
%% Component risk functions (convex, increasing)
%% ------------------------------------------------------------------------
function c = component_risks(n, p)
% Compute dimension-wise risk components using convex maps. [file:3]

    e_pos   = p.comp.exponent_positive;
    e_id    = p.comp.exponent_identity;
    e_aff   = p.comp.exponent_affective;
    e_sleep = p.comp.exponent_sleep;

    % Positive symptoms (hallucinations + delusions)
    pos = 0.5 * (n.halluc + n.delusion);
    c.R_positive = pos .^ e_pos;

    % Identity disruption
    c.R_identity = n.identity_disr .^ e_id;

    % Affective / stress bundle (anxiety, stress, mania)
    aff = (n.anxiety + n.stress + n.mania) / 3.0;
    c.R_affective = aff .^ e_aff;

    % Sleep deprivation
    c.R_sleep = n.sleep_depr .^ e_sleep;

    % Pain + cognitive load interaction:
    %   treat as mean, with convex map to force higher risk with combined burden.
    pain_cog = (n.pain + n.cog_load) / 2.0;
    c.R_pain_cog = pain_cog .^ e_pos;
end

%% ------------------------------------------------------------------------
%% Aggregate psychosis risk
%% ------------------------------------------------------------------------
function R = aggregate_risk(c, p)
% Convex combination of component risks into R_psychosis ∈ [0,1]. [file:3]

    w = p.agg;
    % Enforce that weights sum to 1 (within numeric tolerance).
    wsum = w.w_thought + w.w_identity + w.w_affective + w.w_sleep + w.w_pain_cog;
    if abs(wsum - 1.0) > 1e-9
        error('Aggregation weights must sum to 1.0, got %.12f', wsum);
    end

    % Thought=positive symptoms; identity; affective; sleep; pain+cog.
    R = ...
        w.w_thought   .* c.R_positive + ...
        w.w_identity  .* c.R_identity + ...
        w.w_affective .* c.R_affective + ...
        w.w_sleep     .* c.R_sleep + ...
        w.w_pain_cog  .* c.R_pain_cog;

    % Clamp minor numeric drift.
    R = max(0.0, min(1.0, R));
end

%% ------------------------------------------------------------------------
%% Projection into a 3-axis psych vector
%% ------------------------------------------------------------------------
function R_vec = three_axis_projection(c, p)
% Map detailed components into:
%   R_thought_disorder
%   R_affective
%   R_identity
% These can be folded into StateVectorN.Psychnorm or separate axes. [file:1][file:3]

    q = p.proj;

    % Thought disorder: dominated by positive symptoms and cognitive burden.
    R_thought = q.w_thought_from_positive * c.R_positive + ...
                q.w_thought_from_cog      * c.R_pain_cog;

    % Affective: anxiety/stress/mania + sleep deprivation.
    R_aff = q.w_aff_from_anx_stress * c.R_affective + ...
            q.w_aff_from_sleep      * c.R_sleep;

    % Identity: pure identity disruption for now (can add chronic psychosis terms).
    R_id = q.w_id_from_identity * c.R_identity;

    R_vec = [ ...
        max(0.0, min(1.0, R_thought)); ...
        max(0.0, min(1.0, R_aff)); ...
        max(0.0, min(1.0, R_id)) ...
    ];
end

%% ------------------------------------------------------------------------
%% Optional: simple visualization helper (not required by core API)
%% ------------------------------------------------------------------------
function visualize_psychosis_surface(varargin)
% Optional helper to inspect R_psychosis as a function of two variables.
% Example:
%   visualize_psychosis_surface('halluc', 'delusion');
%
% This does not run automatically; call it from MATLAB as needed. [file:3]

    if nargin < 2
        xfield = 'halluc';
        yfield = 'delusion';
    else
        xfield = varargin{1};
        yfield = varargin{2};
    end

    params = default_params();
    n_points = 51;
    [X, Y] = meshgrid(linspace(0,1,n_points), linspace(0,1,n_points));
    Z = zeros(size(X));

    for i = 1:n_points
        for j = 1:n_points
            raw = struct();
            % Set selected fields in normalized space, then de-normalize.
            raw.(sprintf('%s_scale_proxy', xfield)) = X(i,j); %#ok<NASGU>
            raw.(sprintf('%s_scale_proxy', yfield)) = Y(i,j); %#ok<NASGU>
            % For simplicity, directly construct norm struct:
            n = struct();
            n.pain          = 0; n.anxiety = 0; n.cog_load = 0;
            n.identity_disr = 0; n.halluc  = 0; n.delusion = 0;
            n.sleep_depr    = 0; n.stress  = 0; n.mania    = 0;

            if strcmp(xfield, 'halluc');      n.halluc   = X(i,j); end
            if strcmp(xfield, 'delusion');    n.delusion = X(i,j); end
            if strcmp(xfield, 'anxiety');     n.anxiety  = X(i,j); end
            if strcmp(xfield, 'identity');    n.identity_disr = X(i,j); end
            if strcmp(xfield, 'sleep');       n.sleep_depr = X(i,j); end

            if strcmp(yfield, 'halluc');      n.halluc   = Y(i,j); end
            if strcmp(yfield, 'delusion');    n.delusion = Y(i,j); end
            if strcmp(yfield, 'anxiety');     n.anxiety  = Y(i,j); end
            if strcmp(yfield, 'identity');    n.identity_disr = Y(i,j); end
            if strcmp(yfield, 'sleep');       n.sleep_depr = Y(i,j); end

            c = component_risks(n, params);
            Z(i,j) = aggregate_risk(c, params);
        end
    end

    surf(X, Y, Z);
    xlabel(sprintf('%s (normalized)', xfield));
    ylabel(sprintf('%s (normalized)', yfield));
    zlabel('R\_psychosis');
    title('Psychosis Risk Surface');
end
