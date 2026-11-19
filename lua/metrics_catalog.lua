local M = {}

local function number_field(minimum, maximum, required)
    return {
        kind = "number",
        required = required ~= false,
        minimum = minimum,
        maximum = maximum,
    }
end

local function enum_field(values, required)
    return {
        kind = "enum",
        required = required ~= false,
        values = values,
    }
end

M.contract_version = 1

M.metrics = {
    evapotranspiration_cooling = {
        description = "Aggregate evapotranspiration cooling and recovery-opportunity estimate.",
        default_options = {},
        input_schema = {
            evapotranspiration_mm_day = number_field(0.0, 30.0),
            anthropogenic_heat_w_m2 = number_field(0.0, 5000.0),
            albedo_fraction = number_field(0.0, 1.0),
            vegetation_fraction = number_field(0.0, 1.0),
            baseline_surface_temperature_c = number_field(-90.0, 100.0),
            reference_et_mm_day = number_field(0.000000001, nil),
            observation_coverage = number_field(0.0, 1.0),
            evidence_quality = number_field(0.0, 1.0),
        },
        result_fields = {
            "zone_temperature_change_c",
            "estimated_surface_temperature_c",
            "evapotranspiration_cooling_c",
            "anthropogenic_heat_warming_c",
            "albedo_cooling_c",
            "vegetation_support_c",
            "recovery_opportunity",
            "coverage_adjusted_recovery_opportunity",
            "coverage_status",
            "interpretation",
        },
    },

    remote_sensing_et = {
        description = "Aggregate remote-sensing evapotranspiration estimate.",
        default_options = {},
        input_schema = {
            air_temperature_c = number_field(-60.0, 60.0),
            relative_humidity_fraction = number_field(0.0, 1.0),
            wind_speed_m_s = number_field(0.0, 80.0),
            net_radiation_mj_m2_day = number_field(-20.0, 60.0),
            soil_heat_flux_mj_m2_day = number_field(-20.0, 20.0),
            elevation_m = number_field(-500.0, 9000.0),
            ndvi = number_field(-1.0, 1.0),
            land_surface_temperature_c = number_field(-90.0, 100.0),
            cloud_free_fraction = number_field(0.0, 1.0),
            observation_coverage = number_field(0.0, 1.0),
            evidence_quality = number_field(0.0, 1.0),
        },
        result_fields = {
            "reference_et_mm_day",
            "vegetation_coefficient",
            "adjusted_urban_et_mm_day",
            "vapor_pressure_deficit_kpa",
            "saturation_vapor_pressure_slope_kpa_c",
            "psychrometric_constant_kpa_c",
            "coverage_adjusted_et_mm_day",
            "coverage_status",
            "method_notes",
        },
    },

    watershed_health = {
        description = "Aggregate watershed condition and restoration-review indicator.",
        default_options = {},
        input_schema = {
            flow_regime_score = number_field(0.0, 1.0),
            water_quality_score = number_field(0.0, 1.0),
            riparian_condition_score = number_field(0.0, 1.0),
            biodiversity_condition_score = number_field(0.0, 1.0),
            groundwater_condition_score = number_field(0.0, 1.0),
            landscape_connectivity_score = number_field(0.0, 1.0),
            sensor_coverage_score = number_field(0.0, 1.0),
            source_quality_score = number_field(0.0, 1.0),
            anomaly_penalty_score = number_field(0.0, 1.0),
        },
        result_fields = {
            "watershed_health_index",
            "coverage_adjusted_index",
            "status",
            "flow_component",
            "quality_component",
            "riparian_component",
            "biodiversity_component",
            "groundwater_component",
            "landscape_component",
            "data_coverage",
            "anomaly_penalty",
            "interpretation",
        },
    },

    aquifer_recharge = {
        description = "Aggregate urban water-balance recharge estimate.",
        default_options = {},
        input_schema = {
            precipitation_mm = number_field(0.0, 10000.0),
            evapotranspiration_mm = number_field(0.0, 10000.0),
            direct_runoff_mm = number_field(0.0, 10000.0),
            storage_change_mm = number_field(-10000.0, 10000.0),
            imported_recharge_water_mm = number_field(0.0, 10000.0),
            managed_infiltration_efficiency = number_field(0.0, 1.0),
            impervious_fraction = number_field(0.0, 1.0),
            permeable_surface_condition = number_field(0.0, 1.0),
            soil_infiltration_condition = number_field(0.0, 1.0),
            source_quality = number_field(0.0, 1.0),
            observation_coverage = number_field(0.0, 1.0),
        },
        result_fields = {
            "climatic_recharge_mm",
            "managed_recharge_mm",
            "potential_recharge_mm",
            "urban_adjusted_recharge_mm",
            "imperviousness_penalty_mm",
            "recharge_efficiency",
            "coverage_adjusted_recharge_mm",
            "coverage_status",
            "interpretation",
        },
    },

    soil_carbon = {
        description = "Aggregate soil-carbon dynamics scenario estimate.",
        default_options = {},
        input_schema = {
            initial_soil_carbon_t_c_ha = number_field(0.0, 5000.0),
            annual_carbon_input_t_c_ha_year = number_field(0.0, 500.0),
            baseline_decomposition_rate_year = number_field(0.0, 10.0),
            mean_soil_temperature_c = number_field(-50.0, 80.0),
            reference_soil_temperature_c = number_field(-50.0, 80.0),
            temperature_q10 = number_field(0.000000001, nil),
            soil_moisture_fraction = number_field(0.0, 1.0),
            optimum_soil_moisture_fraction = number_field(0.000000001, nil),
            ground_cover_fraction = number_field(0.0, 1.0),
            erosion_loss_t_c_ha_year = number_field(0.0, 500.0),
            disturbance_multiplier = number_field(0.0, 10.0),
            management_input_multiplier = number_field(0.0, 10.0),
            observation_coverage = number_field(0.0, 1.0),
            evidence_quality = number_field(0.0, 1.0),
        },
        result_fields = {
            "effective_carbon_input_t_c_ha_year",
            "temperature_adjusted_decomposition_rate_year",
            "moisture_adjusted_decomposition_rate_year",
            "net_carbon_change_t_c_ha_year",
            "projected_carbon_t_c_ha",
            "equilibrium_carbon_t_c_ha",
            "carbon_retention_index",
            "coverage_adjusted_net_change_t_c_ha_year",
            "coverage_status",
            "interpretation",
        },
    },

    outdoor_hydration_advisory = {
        description = "Aggregate environmental water-loss demand advisory; not a personal health or hydration assessment.",
        default_options = {},
        input_schema = {
            air_temperature_c = number_field(-40.0, 65.0),
            relative_humidity_fraction = number_field(0.0, 1.0),
            solar_radiation_w_m2 = number_field(0.0, 1500.0),
            wind_speed_m_s = number_field(0.0, 60.0),
            activity_level = number_field(0.0, 1.0),
            shade_fraction = number_field(0.0, 1.0),
            work_rest_fraction = number_field(0.0, 1.0),
            water_access_score = number_field(0.0, 1.0),
            forecast_coverage = number_field(0.0, 1.0),
            evidence_quality = number_field(0.0, 1.0),
        },
        result_fields = {
            "environmental_water_loss_demand_l_h",
            "advisory_band",
            "recovery_priority_score",
            "coverage_adjusted_demand_l_h",
            "coverage_status",
            "advisory_text",
            "safety_notes",
        },
    },

    surface_burn_clock = {
        description = "Aggregate material-aware surface temperature and public contact-hazard estimate.",
        default_options = {},
        input_schema = {
            material = enum_field({
                asphalt = true,
                concrete = true,
                metal = true,
                turf = true,
                soil = true,
                brick = true,
            }),
            air_temperature_c = number_field(-60.0, 70.0),
            solar_radiation_w_m2 = number_field(0.0, 1500.0),
            wind_speed_m_s = number_field(0.0, 60.0),
            shade_fraction = number_field(0.0, 1.0),
            surface_moisture_fraction = number_field(0.0, 1.0),
            sun_exposure_minutes = number_field(0.0, 1440.0),
            prior_surface_temperature_c = number_field(-60.0, 120.0, false),
            observation_coverage = number_field(0.0, 1.0),
            evidence_quality = number_field(0.0, 1.0),
        },
        result_fields = {
            "estimated_surface_temperature_c",
            "estimated_surface_temperature_f",
            "direct_solar_gain_c",
            "convective_relief_c",
            "moisture_relief_c",
            "retained_heat_c",
            "contact_hazard_score",
            "hazard_band",
            "coverage_adjusted_hazard_score",
            "coverage_status",
            "public_message",
            "model_notes",
        },
    },

    dry_recovery_service_need = {
        description = "Aggregate wetness and humidity service-load versus dry-recovery capacity model.",
        default_options = {},
        input_schema = {
            wet_exposure_score = number_field(0.0, 1.0),
            drying_lack_score = number_field(0.0, 1.0),
            humidity_persistence_score = number_field(0.0, 1.0),
            overnight_low_temperature_c = number_field(-60.0, 50.0),
            consecutive_wet_hours = number_field(0.0, 720.0),
            covered_rest_capacity_score = number_field(0.0, 1.0),
            dry_storage_capacity_score = number_field(0.0, 1.0),
            laundry_or_drying_access_score = number_field(0.0, 1.0),
            hygiene_access_score = number_field(0.0, 1.0),
            accessible_service_route_score = number_field(0.0, 1.0),
            forecast_coverage = number_field(0.0, 1.0),
            service_inventory_coverage = number_field(0.0, 1.0),
            evidence_quality = number_field(0.0, 1.0),
        },
        result_fields = {
            "weather_load_score",
            "recovery_capacity_score",
            "dry_recovery_gap_score",
            "coverage_adjusted_gap_score",
            "service_band",
            "coverage_status",
            "suggested_service_actions",
            "interpretation",
        },
    },
}

function M.get(metric_name)
    return M.metrics[metric_name]
end

function M.is_supported(metric_name)
    return type(metric_name) == "string"
        and M.metrics[metric_name] ~= nil
end

return M
