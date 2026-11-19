function result = cyboquatic_ivt_water_transport_model(input)
% CYBOQUATIC_IVT_WATER_TRANSPORT_MODEL
% MATLAB and GNU Octave compatible scientific decision-support model.
%
% This model:
% - calculates vertically integrated water-vapor transport;
% - calculates pumping energy, delivery efficiency, and operational carbon;
% - uses Monte Carlo simulation for measurement uncertainty;
% - reports planning metrics only;
% - does not authorize water release, weather modification, or public action.

    validate_input(input);

    gravity_m_per_s2 = 9.80665;
    water_density_kg_per_m3 = input.water_density_kg_per_m3;

    q = input.specific_humidity_kg_per_kg(:);
    u = input.wind_u_m_per_s(:);
    v = input.wind_v_m_per_s(:);
    delta_p = input.pressure_thickness_pa(:);

    ivt_x_kg_m_s = sum(q .* u .* delta_p) / gravity_m_per_s2;
    ivt_y_kg_m_s = sum(q .* v .* delta_p) / gravity_m_per_s2;
    ivt_magnitude_kg_m_s = hypot(ivt_x_kg_m_s, ivt_y_kg_m_s);
    ivt_direction_degrees = mod(atan2d(ivt_y_kg_m_s, ivt_x_kg_m_s), 360.0);

    hydraulic_power_w = water_density_kg_per_m3 ...
        * gravity_m_per_s2 ...
        * input.flow_m3_per_s ...
        * input.total_dynamic_head_m;

    electric_power_w = hydraulic_power_w / input.pump_efficiency;
    energy_kwh = electric_power_w * input.operation_hours / 1000.0;

    sent_volume_m3 = input.flow_m3_per_s * input.operation_hours * 3600.0;
    delivered_volume_m3 = sent_volume_m3 * (1.0 - input.leakage_fraction);

    if delivered_volume_m3 <= 0.0
        error('Delivered volume must be positive.');
    end

    nonrenewable_energy_kwh = energy_kwh * (1.0 - input.renewable_fraction);
    operational_carbon_kgco2e = nonrenewable_energy_kwh ...
        * input.grid_carbon_intensity_kgco2e_per_kwh;

    result = struct();
    result.ivt_x_kg_m_s = ivt_x_kg_m_s;
    result.ivt_y_kg_m_s = ivt_y_kg_m_s;
    result.ivt_magnitude_kg_m_s = ivt_magnitude_kg_m_s;
    result.ivt_direction_degrees = ivt_direction_degrees;
    result.moisture_transport_class = classify_ivt(ivt_magnitude_kg_m_s);

    result.hydraulic_power_w = hydraulic_power_w;
    result.electric_power_w = electric_power_w;
    result.energy_kwh = energy_kwh;
    result.sent_volume_m3 = sent_volume_m3;
    result.delivered_volume_m3 = delivered_volume_m3;
    result.water_delivery_efficiency = delivered_volume_m3 / sent_volume_m3;
    result.energy_intensity_kwh_per_m3 = energy_kwh / delivered_volume_m3;
    result.operational_carbon_kgco2e = operational_carbon_kgco2e;
    result.carbon_intensity_kgco2e_per_m3 = operational_carbon_kgco2e ...
        / delivered_volume_m3;

    result.research_boundary = [
        'IVT measures natural atmospheric moisture transport. ' ...
        'This model cannot create rain, redirect clouds, or authorize ' ...
        'water release. Results support monitoring, conservation, recharge ' ...
        'readiness, heat-safety planning, and human-reviewed research only.'
    ];
end

function validate_input(input)
    required_fields = {
        'specific_humidity_kg_per_kg', ...
        'wind_u_m_per_s', ...
        'wind_v_m_per_s', ...
        'pressure_thickness_pa', ...
        'water_density_kg_per_m3', ...
        'flow_m3_per_s', ...
        'total_dynamic_head_m', ...
        'pump_efficiency', ...
        'operation_hours', ...
        'leakage_fraction', ...
        'renewable_fraction', ...
        'grid_carbon_intensity_kgco2e_per_kwh'
    };

    for index = 1:numel(required_fields)
        field_name = required_fields{index};

        if ~isfield(input, field_name)
            error(['Missing required field: ' field_name]);
        end
    end

    q = input.specific_humidity_kg_per_kg(:);
    u = input.wind_u_m_per_s(:);
    v = input.wind_v_m_per_s(:);
    delta_p = input.pressure_thickness_pa(:);

    if isempty(q) || numel(q) ~= numel(u) || numel(q) ~= numel(v) ...
            || numel(q) ~= numel(delta_p)
        error('Atmospheric arrays must be non-empty and have equal length.');
    end

    assert_finite_vector('specific_humidity_kg_per_kg', q, 0.0, 0.1);
    assert_finite_vector('wind_u_m_per_s', u, -150.0, 150.0);
    assert_finite_vector('wind_v_m_per_s', v, -150.0, 150.0);
    assert_finite_vector('pressure_thickness_pa', delta_p, 1.0, inf);

    assert_finite_scalar('water_density_kg_per_m3', ...
        input.water_density_kg_per_m3, 950.0, 1050.0);
    assert_finite_scalar('flow_m3_per_s', input.flow_m3_per_s, 0.0, inf);
    assert_finite_scalar('total_dynamic_head_m', ...
        input.total_dynamic_head_m, 0.0, inf);
    assert_finite_scalar('pump_efficiency', input.pump_efficiency, 0.01, 1.0);
    assert_finite_scalar('operation_hours', input.operation_hours, 0.0, inf);
    assert_finite_scalar('leakage_fraction', input.leakage_fraction, 0.0, 0.99);
    assert_finite_scalar('renewable_fraction', input.renewable_fraction, 0.0, 1.0);
    assert_finite_scalar('grid_carbon_intensity_kgco2e_per_kwh', ...
        input.grid_carbon_intensity_kgco2e_per_kwh, 0.0, 5.0);
end

function assert_finite_scalar(name, value, minimum, maximum)
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
        error([name ' must be one finite numeric scalar.']);
    end

    if value < minimum || value > maximum
        error([name ' is outside its permitted scientific range.']);
    end
end

function assert_finite_vector(name, values, minimum, maximum)
    if ~isnumeric(values) || any(~isfinite(values))
        error([name ' must contain only finite numeric values.']);
    end

    if any(values < minimum) || any(values > maximum)
        error([name ' contains values outside its permitted scientific range.']);
    end
end

function moisture_transport_class = classify_ivt(ivt_magnitude_kg_m_s)
    if ivt_magnitude_kg_m_s < 250.0
        moisture_transport_class = 'low';
    elseif ivt_magnitude_kg_m_s < 500.0
        moisture_transport_class = 'elevated';
    else
        moisture_transport_class = 'high';
    end
end
