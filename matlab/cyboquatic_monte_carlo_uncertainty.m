function uncertainty = cyboquatic_monte_carlo_uncertainty(input, simulation_count, random_seed)
% CYBOQUATIC_MONTE_CARLO_UNCERTAINTY
% Propagates stated measurement uncertainty through the Cyboquatic model.
%
% Each input uncertainty is a one-standard-deviation estimate. The function
% samples physically valid inputs, calculates each scenario, and returns
% output quantiles. It does not convert uncertain scenarios into autonomous
% infrastructure instructions.

    if nargin < 2
        simulation_count = 10000;
    end

    if nargin < 3
        random_seed = 20260826;
    end

    validate_monte_carlo_request(input, simulation_count, random_seed);
    set_random_seed(random_seed);

    ivt_samples = zeros(simulation_count, 1);
    energy_intensity_samples = zeros(simulation_count, 1);
    carbon_intensity_samples = zeros(simulation_count, 1);
    delivery_efficiency_samples = zeros(simulation_count, 1);

    accepted_samples = 0;
    attempts = 0;
    maximum_attempts = simulation_count * 50;

    while accepted_samples < simulation_count && attempts < maximum_attempts
        attempts = attempts + 1;

        candidate = sample_input(input);

        try
            output = cyboquatic_ivt_water_transport_model(candidate);
            accepted_samples = accepted_samples + 1;

            ivt_samples(accepted_samples) = output.ivt_magnitude_kg_m_s;
            energy_intensity_samples(accepted_samples) = ...
                output.energy_intensity_kwh_per_m3;
            carbon_intensity_samples(accepted_samples) = ...
                output.carbon_intensity_kgco2e_per_m3;
            delivery_efficiency_samples(accepted_samples) = ...
                output.water_delivery_efficiency;
        catch
        end
    end

    if accepted_samples < simulation_count
        error('Insufficient physically valid samples. Review measurement uncertainty and input corridors.');
    end

    uncertainty = struct();
    uncertainty.simulation_count = simulation_count;
    uncertainty.random_seed = random_seed;
    uncertainty.acceptance_rate = accepted_samples / attempts;

    uncertainty.ivt_magnitude_kg_m_s = summarize(ivt_samples);
    uncertainty.energy_intensity_kwh_per_m3 = summarize(energy_intensity_samples);
    uncertainty.carbon_intensity_kgco2e_per_m3 = summarize(carbon_intensity_samples);
    uncertainty.water_delivery_efficiency = summarize(delivery_efficiency_samples);

    uncertainty.interpretation = [
        'Reported intervals quantify uncertainty created by the supplied input ' ...
        'distributions and model structure. They do not establish weather ' ...
        'causation, rainfall creation, ecological authorization, or public safety.'
    ];
end

function validate_monte_carlo_request(input, simulation_count, random_seed)
    if ~isstruct(input)
        error('input must be a structure.');
    end

    if ~isnumeric(simulation_count) || ~isscalar(simulation_count) ...
            || ~isfinite(simulation_count) || simulation_count < 100
        error('simulation_count must be a finite scalar of at least 100.');
    end

    if ~isnumeric(random_seed) || ~isscalar(random_seed) || ~isfinite(random_seed)
        error('random_seed must be one finite numeric scalar.');
    end

    required_uncertainties = {
        'specific_humidity_std', ...
        'wind_u_std', ...
        'wind_v_std', ...
        'pressure_thickness_std', ...
        'flow_std', ...
        'head_std', ...
        'pump_efficiency_std', ...
        'leakage_fraction_std', ...
        'renewable_fraction_std', ...
        'grid_carbon_intensity_std'
    };

    for index = 1:numel(required_uncertainties)
        field_name = required_uncertainties{index};

        if ~isfield(input, field_name)
            error(['Missing uncertainty field: ' field_name]);
        end

        value = input.(field_name);

        if ~isnumeric(value) || any(~isfinite(value(:))) || any(value(:) < 0.0)
            error([field_name ' must contain finite non-negative values.']);
        end
    end
end

function set_random_seed(random_seed)
    if exist('rng', 'file') || exist('rng', 'builtin')
        rng(random_seed, 'twister');
    else
        rand('seed', random_seed);
        randn('seed', random_seed);
    end
end

function candidate = sample_input(input)
    candidate = input;

    candidate.specific_humidity_kg_per_kg = clamp_vector(
        input.specific_humidity_kg_per_kg(:) ...
            + input.specific_humidity_std(:) .* randn(numel(input.specific_humidity_kg_per_kg), 1),
        0.0,
        0.1
    );

    candidate.wind_u_m_per_s = clamp_vector(
        input.wind_u_m_per_s(:) ...
            + input.wind_u_std(:) .* randn(numel(input.wind_u_m_per_s), 1),
        -150.0,
        150.0
    );

    candidate.wind_v_m_per_s = clamp_vector(
        input.wind_v_m_per_s(:) ...
            + input.wind_v_std(:) .* randn(numel(input.wind_v_m_per_s), 1),
        -150.0,
        150.0
    );

    candidate.pressure_thickness_pa = clamp_vector(
        input.pressure_thickness_pa(:) ...
            + input.pressure_thickness_std(:) .* randn(numel(input.pressure_thickness_pa), 1),
        1.0,
        inf
    );

    candidate.flow_m3_per_s = clamp_scalar(
        input.flow_m3_per_s + input.flow_std * randn(),
        0.0,
        inf
    );

    candidate.total_dynamic_head_m = clamp_scalar(
        input.total_dynamic_head_m + input.head_std * randn(),
        0.0,
        inf
    );

    candidate.pump_efficiency = clamp_scalar(
        input.pump_efficiency + input.pump_efficiency_std * randn(),
        0.01,
        1.0
    );

    candidate.leakage_fraction = clamp_scalar(
        input.leakage_fraction + input.leakage_fraction_std * randn(),
        0.0,
        0.99
    );

    candidate.renewable_fraction = clamp_scalar(
        input.renewable_fraction + input.renewable_fraction_std * randn(),
        0.0,
        1.0
    );

    candidate.grid_carbon_intensity_kgco2e_per_kwh = clamp_scalar(
        input.grid_carbon_intensity_kgco2e_per_kwh ...
            + input.grid_carbon_intensity_std * randn(),
        0.0,
        5.0
    );
end

function summary = summarize(samples)
    sorted_samples = sort(samples(:));
    sample_count = numel(sorted_samples);

    summary = struct();
    summary.mean = mean(sorted_samples);
    summary.median = quantile_value(sorted_samples, 0.50);
    summary.lower_95 = quantile_value(sorted_samples, 0.025);
    summary.upper_95 = quantile_value(sorted_samples, 0.975);
    summary.minimum = sorted_samples(1);
    summary.maximum = sorted_samples(sample_count);
end

function value = quantile_value(sorted_values, probability)
    value_count = numel(sorted_values);
    index = 1.0 + (value_count - 1.0) * probability;
    lower_index = floor(index);
    upper_index = ceil(index);

    if lower_index == upper_index
        value = sorted_values(lower_index);
        return;
    end

    weight = index - lower_index;
    value = (1.0 - weight) * sorted_values(lower_index) ...
        + weight * sorted_values(upper_index);
end

function output = clamp_scalar(value, minimum, maximum)
    output = min(max(value, minimum), maximum);
end

function output = clamp_vector(values, minimum, maximum)
    output = min(max(values, minimum), maximum);
end
