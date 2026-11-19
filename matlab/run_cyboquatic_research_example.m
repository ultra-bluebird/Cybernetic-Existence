input = struct();

input.specific_humidity_kg_per_kg = [0.010; 0.007; 0.003];
input.wind_u_m_per_s = [16.0; 20.0; 25.0];
input.wind_v_m_per_s = [4.0; 5.0; 7.0];
input.pressure_thickness_pa = [15000.0; 18000.0; 12000.0];

input.water_density_kg_per_m3 = 997.0;
input.flow_m3_per_s = 0.25;
input.total_dynamic_head_m = 95.0;
input.pump_efficiency = 0.78;
input.operation_hours = 6.0;
input.leakage_fraction = 0.02;
input.renewable_fraction = 0.70;
input.grid_carbon_intensity_kgco2e_per_kwh = 0.35;

input.specific_humidity_std = [0.001; 0.001; 0.0005];
input.wind_u_std = [1.0; 1.0; 1.5];
input.wind_v_std = [1.0; 1.0; 1.0];
input.pressure_thickness_std = [100.0; 100.0; 100.0];

input.flow_std = 0.01;
input.head_std = 2.0;
input.pump_efficiency_std = 0.03;
input.leakage_fraction_std = 0.01;
input.renewable_fraction_std = 0.05;
input.grid_carbon_intensity_std = 0.03;

deterministic_result = cyboquatic_ivt_water_transport_model(input);
uncertainty_result = cyboquatic_monte_carlo_uncertainty(input, 10000, 20260826);

disp('Deterministic integrated vapor transport');
disp(deterministic_result.ivt_magnitude_kg_m_s);

disp('Moisture transport classification');
disp(deterministic_result.moisture_transport_class);

disp('Energy intensity in kWh per cubic meter delivered');
disp(deterministic_result.energy_intensity_kwh_per_m3);

disp('Carbon intensity in kg CO2e per cubic meter delivered');
disp(deterministic_result.carbon_intensity_kgco2e_per_m3);

disp('IVT 95 percent uncertainty interval');
disp([uncertainty_result.ivt_magnitude_kg_m_s.lower_95, ...
    uncertainty_result.ivt_magnitude_kg_m_s.upper_95]);

disp('Energy intensity 95 percent uncertainty interval');
disp([uncertainty_result.energy_intensity_kwh_per_m3.lower_95, ...
    uncertainty_result.energy_intensity_kwh_per_m3.upper_95]);

disp('Carbon intensity 95 percent uncertainty interval');
disp([uncertainty_result.carbon_intensity_kgco2e_per_m3.lower_95, ...
    uncertainty_result.carbon_intensity_kgco2e_per_m3.upper_95]);
