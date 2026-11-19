package org.augmentedhub.metrics

data class MetricField(
    val name: String,
    val label: String,
    val required: Boolean,
    val unit: String?,
    val description: String,
)

data class MetricCatalogEntry(
    val name: String,
    val title: String,
    val description: String,
    val requiredFields: List<MetricField>,
    val aggregateEnvironmentalOnly: Boolean = true,
    val decisionSupportOnly: Boolean = true,
    val personLevelInferenceProhibited: Boolean = true,
)

object MetricCatalog {
    val entries: List<MetricCatalogEntry> = listOf(
        MetricCatalogEntry(
            name = "evapotranspiration_cooling",
            title = "Evapotranspiration Cooling",
            description = "Estimates aggregate vegetation, albedo, and anthropogenic-heat effects on modeled surface cooling and recovery opportunity.",
            requiredFields = listOf(
                field("evapotranspiration_mm_day", "Evapotranspiration", true, "mm/day"),
                field("anthropogenic_heat_w_m2", "Anthropogenic heat", true, "W/m²"),
                field("albedo_fraction", "Albedo", true, "fraction"),
                field("vegetation_fraction", "Vegetation cover", true, "fraction"),
                field("baseline_surface_temperature_c", "Baseline surface temperature", true, "°C"),
                field("reference_et_mm_day", "Reference evapotranspiration", true, "mm/day"),
                field("observation_coverage", "Observation coverage", true, "fraction"),
                field("evidence_quality", "Evidence quality", true, "fraction"),
            ),
        ),
        MetricCatalogEntry(
            name = "remote_sensing_et",
            title = "Remote-Sensing Evapotranspiration",
            description = "Uses aggregate weather and remotely sensed surface conditions to estimate reference and urban evapotranspiration.",
            requiredFields = listOf(
                field("air_temperature_c", "Air temperature", true, "°C"),
                field("relative_humidity_fraction", "Relative humidity", true, "fraction"),
                field("wind_speed_m_s", "Wind speed", true, "m/s"),
                field("net_radiation_mj_m2_day", "Net radiation", true, "MJ/m²/day"),
                field("soil_heat_flux_mj_m2_day", "Soil heat flux", true, "MJ/m²/day"),
                field("elevation_m", "Elevation", true, "m"),
                field("ndvi", "NDVI", true, null),
                field("land_surface_temperature_c", "Land surface temperature", true, "°C"),
                field("cloud_free_fraction", "Cloud-free fraction", true, "fraction"),
                field("observation_coverage", "Observation coverage", true, "fraction"),
                field("evidence_quality", "Evidence quality", true, "fraction"),
            ),
        ),
        MetricCatalogEntry(
            name = "watershed_health",
            title = "Watershed Health",
            description = "Combines aggregate flow, water-quality, riparian, biodiversity, groundwater, and landscape condition indicators.",
            requiredFields = listOf(
                field("flow_regime_score", "Flow regime", true, "0–1"),
                field("water_quality_score", "Water quality", true, "0–1"),
                field("riparian_condition_score", "Riparian condition", true, "0–1"),
                field("biodiversity_condition_score", "Biodiversity condition", true, "0–1"),
                field("groundwater_condition_score", "Groundwater condition", true, "0–1"),
                field("landscape_connectivity_score", "Landscape connectivity", true, "0–1"),
                field("sensor_coverage_score", "Sensor coverage", true, "0–1"),
                field("source_quality_score", "Source quality", true, "0–1"),
                field("anomaly_penalty_score", "Anomaly penalty", true, "0–1"),
            ),
        ),
        MetricCatalogEntry(
            name = "aquifer_recharge",
            title = "Aquifer Recharge",
            description = "Estimates aggregate climatic and managed recharge opportunity after runoff, storage, and urban-surface constraints.",
            requiredFields = listOf(
                field("precipitation_mm", "Precipitation", true, "mm"),
                field("evapotranspiration_mm", "Evapotranspiration", true, "mm"),
                field("direct_runoff_mm", "Direct runoff", true, "mm"),
                field("storage_change_mm", "Storage change", true, "mm"),
                field("imported_recharge_water_mm", "Imported recharge water", true, "mm"),
                field("managed_infiltration_efficiency", "Managed infiltration efficiency", true, "fraction"),
                field("impervious_fraction", "Impervious fraction", true, "fraction"),
                field("permeable_surface_condition", "Permeable surface condition", true, "fraction"),
                field("soil_infiltration_condition", "Soil infiltration condition", true, "fraction"),
                field("source_quality", "Source quality", true, "fraction"),
                field("observation_coverage", "Observation coverage", true, "fraction"),
            ),
        ),
        MetricCatalogEntry(
            name = "soil_carbon",
            title = "Soil Carbon Dynamics",
            description = "Models aggregate soil-carbon inputs, decomposition, disturbance, moisture, temperature, and erosion conditions.",
            requiredFields = listOf(
                field("initial_soil_carbon_t_c_ha", "Initial soil carbon", true, "tC/ha"),
                field("annual_carbon_input_t_c_ha_year", "Annual carbon input", true, "tC/ha/year"),
                field("baseline_decomposition_rate_year", "Baseline decomposition rate", true, "1/year"),
                field("mean_soil_temperature_c", "Mean soil temperature", true, "°C"),
                field("reference_soil_temperature_c", "Reference soil temperature", true, "°C"),
                field("temperature_q10", "Temperature Q10", true, null),
                field("soil_moisture_fraction", "Soil moisture", true, "fraction"),
                field("optimum_soil_moisture_fraction", "Optimum soil moisture", true, "fraction"),
                field("ground_cover_fraction", "Ground cover", true, "fraction"),
                field("erosion_loss_t_c_ha_year", "Erosion loss", true, "tC/ha/year"),
                field("disturbance_multiplier", "Disturbance multiplier", true, null),
                field("management_input_multiplier", "Management input multiplier", true, null),
                field("observation_coverage", "Observation coverage", true, "fraction"),
                field("evidence_quality", "Evidence quality", true, "fraction"),
            ),
        ),
        MetricCatalogEntry(
            name = "outdoor_hydration_advisory",
            title = "Outdoor Hydration Advisory",
            description = "Provides an environmental water-loss-demand advisory for aggregate conditions and broad voluntary task categories. It is not a personal medical assessment.",
            requiredFields = listOf(
                field("air_temperature_c", "Air temperature", true, "°C"),
                field("relative_humidity_fraction", "Relative humidity", true, "fraction"),
                field("solar_radiation_w_m2", "Solar radiation", true, "W/m²"),
                field("wind_speed_m_s", "Wind speed", true, "m/s"),
                field("activity_level", "Broad task category", true, "0–1"),
                field("shade_fraction", "Shade fraction", true, "fraction"),
                field("work_rest_fraction", "Work-rest fraction", true, "fraction"),
                field("water_access_score", "Water access", true, "0–1"),
                field("forecast_coverage", "Forecast coverage", true, "fraction"),
                field("evidence_quality", "Evidence quality", true, "fraction"),
            ),
        ),
        MetricCatalogEntry(
            name = "surface_burn_clock",
            title = "Surface Burn Clock",
            description = "Estimates aggregate material-aware surface temperature and public contact-hazard conditions.",
            requiredFields = listOf(
                field("material", "Surface material", true, null),
                field("air_temperature_c", "Air temperature", true, "°C"),
                field("solar_radiation_w_m2", "Solar radiation", true, "W/m²"),
                field("wind_speed_m_s", "Wind speed", true, "m/s"),
                field("shade_fraction", "Shade fraction", true, "fraction"),
                field("surface_moisture_fraction", "Surface moisture", true, "fraction"),
                field("sun_exposure_minutes", "Sun exposure", true, "minutes"),
                field("prior_surface_temperature_c", "Prior surface temperature", false, "°C"),
                field("observation_coverage", "Observation coverage", true, "fraction"),
                field("evidence_quality", "Evidence quality", true, "fraction"),
            ),
        ),
        MetricCatalogEntry(
            name = "dry_recovery_service_need",
            title = "Dry-Recovery Service Need",
            description = "Estimates aggregate wetness and humidity service load against covered-rest, storage, drying, hygiene, and accessible-route capacity.",
            requiredFields = listOf(
                field("wet_exposure_score", "Wet exposure", true, "0–1"),
                field("drying_lack_score", "Drying lack", true, "0–1"),
                field("humidity_persistence_score", "Humidity persistence", true, "0–1"),
                field("overnight_low_temperature_c", "Overnight low temperature", true, "°C"),
                field("consecutive_wet_hours", "Consecutive wet hours", true, "hours"),
                field("covered_rest_capacity_score", "Covered rest capacity", true, "0–1"),
                field("dry_storage_capacity_score", "Dry storage capacity", true, "0–1"),
                field("laundry_or_drying_access_score", "Laundry or drying access", true, "0–1"),
                field("hygiene_access_score", "Hygiene access", true, "0–1"),
                field("accessible_service_route_score", "Accessible service routes", true, "0–1"),
                field("forecast_coverage", "Forecast coverage", true, "0–1"),
                field("service_inventory_coverage", "Service inventory coverage", true, "0–1"),
                field("evidence_quality", "Evidence quality", true, "0–1"),
            ),
        ),
    )

    fun find(metricName: String): MetricCatalogEntry? =
        entries.firstOrNull { it.name == metricName }

    private fun field(
        name: String,
        label: String,
        required: Boolean,
        unit: String?,
    ): MetricField =
        MetricField(
            name = name,
            label = label,
            required = required,
            unit = unit,
            description = label,
        )
}
