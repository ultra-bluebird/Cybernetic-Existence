#ifndef AUGMENTED_HUB_METRIC_SERIALIZATION_HPP
#define AUGMENTED_HUB_METRIC_SERIALIZATION_HPP

#include <iomanip>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>

namespace augmented_hub::environmental_metrics {

struct EvapotranspirationCoolingInput {
    double evapotranspiration_mm_day;
    double anthropogenic_heat_w_m2;
    double albedo_fraction;
    double vegetation_fraction;
    double baseline_surface_temperature_c;
    double reference_et_mm_day;
    double observation_coverage;
    double evidence_quality;
};

struct RemoteSensingEtInput {
    double air_temperature_c;
    double relative_humidity_fraction;
    double wind_speed_m_s;
    double net_radiation_mj_m2_day;
    double soil_heat_flux_mj_m2_day;
    double elevation_m;
    double ndvi;
    double land_surface_temperature_c;
    double cloud_free_fraction;
    double observation_coverage;
    double evidence_quality;
};

struct WatershedHealthInput {
    double flow_regime_score;
    double water_quality_score;
    double riparian_condition_score;
    double biodiversity_condition_score;
    double groundwater_condition_score;
    double landscape_connectivity_score;
    double sensor_coverage_score;
    double source_quality_score;
    double anomaly_penalty_score;
};

struct AquiferRechargeInput {
    double precipitation_mm;
    double evapotranspiration_mm;
    double direct_runoff_mm;
    double storage_change_mm;
    double imported_recharge_water_mm;
    double managed_infiltration_efficiency;
    double impervious_fraction;
    double permeable_surface_condition;
    double soil_infiltration_condition;
    double source_quality;
    double observation_coverage;
};

struct SoilCarbonInput {
    double initial_soil_carbon_t_c_ha;
    double annual_carbon_input_t_c_ha_year;
    double baseline_decomposition_rate_year;
    double mean_soil_temperature_c;
    double reference_soil_temperature_c;
    double temperature_q10;
    double soil_moisture_fraction;
    double optimum_soil_moisture_fraction;
    double ground_cover_fraction;
    double erosion_loss_t_c_ha_year;
    double disturbance_multiplier;
    double management_input_multiplier;
    double observation_coverage;
    double evidence_quality;
};

struct OutdoorHydrationAdvisoryInput {
    double air_temperature_c;
    double relative_humidity_fraction;
    double solar_radiation_w_m2;
    double wind_speed_m_s;
    double activity_level;
    double shade_fraction;
    double work_rest_fraction;
    double water_access_score;
    double forecast_coverage;
    double evidence_quality;
};

struct SurfaceBurnClockInput {
    std::string material;
    double air_temperature_c;
    double solar_radiation_w_m2;
    double wind_speed_m_s;
    double shade_fraction;
    double surface_moisture_fraction;
    double sun_exposure_minutes;
    std::optional<double> prior_surface_temperature_c;
    double observation_coverage;
    double evidence_quality;
};

struct DryRecoveryServiceNeedInput {
    double wet_exposure_score;
    double drying_lack_score;
    double humidity_persistence_score;
    double overnight_low_temperature_c;
    double consecutive_wet_hours;
    double covered_rest_capacity_score;
    double dry_storage_capacity_score;
    double laundry_or_drying_access_score;
    double hygiene_access_score;
    double accessible_service_route_score;
    double forecast_coverage;
    double service_inventory_coverage;
    double evidence_quality;
};

inline std::string escape_json(std::string_view value) {
    std::string escaped;
    escaped.reserve(value.size());

    for (const char character : value) {
        switch (character) {
            case '"':
                escaped += "\\\"";
                break;
            case '\\':
                escaped += "\\\\";
                break;
            case '\b':
                escaped += "\\b";
                break;
            case '\f':
                escaped += "\\f";
                break;
            case '\n':
                escaped += "\\n";
                break;
            case '\r':
                escaped += "\\r";
                break;
            case '\t':
                escaped += "\\t";
                break;
            default:
                escaped += character;
                break;
        }
    }

    return escaped;
}

inline std::string json_number(double value) {
    if (!(value == value) || value == std::numeric_limits<double>::infinity()
        || value == -std::numeric_limits<double>::infinity()) {
        throw std::invalid_argument("JSON numeric values must be finite");
    }

    std::ostringstream stream;
    stream << std::setprecision(17) << value;
    return stream.str();
}

inline std::string json_field(
    std::string_view name,
    double value,
    bool trailing_comma = true
) {
    return "\"" + escape_json(name) + "\":" + json_number(value)
        + (trailing_comma ? "," : "");
}

inline std::string json_string_field(
    std::string_view name,
    std::string_view value,
    bool trailing_comma = true
) {
    return "\"" + escape_json(name) + "\":\""
        + escape_json(value) + "\""
        + (trailing_comma ? "," : "");
}

inline std::string to_json(const EvapotranspirationCoolingInput& input) {
    return "{"
        + json_field("evapotranspiration_mm_day", input.evapotranspiration_mm_day)
        + json_field("anthropogenic_heat_w_m2", input.anthropogenic_heat_w_m2)
        + json_field("albedo_fraction", input.albedo_fraction)
        + json_field("vegetation_fraction", input.vegetation_fraction)
        + json_field("baseline_surface_temperature_c", input.baseline_surface_temperature_c)
        + json_field("reference_et_mm_day", input.reference_et_mm_day)
        + json_field("observation_coverage", input.observation_coverage)
        + json_field("evidence_quality", input.evidence_quality, false)
        + "}";
}

inline std::string to_json(const RemoteSensingEtInput& input) {
    return "{"
        + json_field("air_temperature_c", input.air_temperature_c)
        + json_field("relative_humidity_fraction", input.relative_humidity_fraction)
        + json_field("wind_speed_m_s", input.wind_speed_m_s)
        + json_field("net_radiation_mj_m2_day", input.net_radiation_mj_m2_day)
        + json_field("soil_heat_flux_mj_m2_day", input.soil_heat_flux_mj_m2_day)
        + json_field("elevation_m", input.elevation_m)
        + json_field("ndvi", input.ndvi)
        + json_field("land_surface_temperature_c", input.land_surface_temperature_c)
        + json_field("cloud_free_fraction", input.cloud_free_fraction)
        + json_field("observation_coverage", input.observation_coverage)
        + json_field("evidence_quality", input.evidence_quality, false)
        + "}";
}

inline std::string to_json(const WatershedHealthInput& input) {
    return "{"
        + json_field("flow_regime_score", input.flow_regime_score)
        + json_field("water_quality_score", input.water_quality_score)
        + json_field("riparian_condition_score", input.riparian_condition_score)
        + json_field("biodiversity_condition_score", input.biodiversity_condition_score)
        + json_field("groundwater_condition_score", input.groundwater_condition_score)
        + json_field("landscape_connectivity_score", input.landscape_connectivity_score)
        + json_field("sensor_coverage_score", input.sensor_coverage_score)
        + json_field("source_quality_score", input.source_quality_score)
        + json_field("anomaly_penalty_score", input.anomaly_penalty_score, false)
        + "}";
}

inline std::string to_json(const AquiferRechargeInput& input) {
    return "{"
        + json_field("precipitation_mm", input.precipitation_mm)
        + json_field("evapotranspiration_mm", input.evapotranspiration_mm)
        + json_field("direct_runoff_mm", input.direct_runoff_mm)
        + json_field("storage_change_mm", input.storage_change_mm)
        + json_field("imported_recharge_water_mm", input.imported_recharge_water_mm)
        + json_field("managed_infiltration_efficiency", input.managed_infiltration_efficiency)
        + json_field("impervious_fraction", input.impervious_fraction)
        + json_field("permeable_surface_condition", input.permeable_surface_condition)
        + json_field("soil_infiltration_condition", input.soil_infiltration_condition)
        + json_field("source_quality", input.source_quality)
        + json_field("observation_coverage", input.observation_coverage, false)
        + "}";
}

inline std::string to_json(const SoilCarbonInput& input) {
    return "{"
        + json_field("initial_soil_carbon_t_c_ha", input.initial_soil_carbon_t_c_ha)
        + json_field("annual_carbon_input_t_c_ha_year", input.annual_carbon_input_t_c_ha_year)
        + json_field("baseline_decomposition_rate_year", input.baseline_decomposition_rate_year)
        + json_field("mean_soil_temperature_c", input.mean_soil_temperature_c)
        + json_field("reference_soil_temperature_c", input.reference_soil_temperature_c)
        + json_field("temperature_q10", input.temperature_q10)
        + json_field("soil_moisture_fraction", input.soil_moisture_fraction)
        + json_field("optimum_soil_moisture_fraction", input.optimum_soil_moisture_fraction)
        + json_field("ground_cover_fraction", input.ground_cover_fraction)
        + json_field("erosion_loss_t_c_ha_year", input.erosion_loss_t_c_ha_year)
        + json_field("disturbance_multiplier", input.disturbance_multiplier)
        + json_field("management_input_multiplier", input.management_input_multiplier)
        + json_field("observation_coverage", input.observation_coverage)
        + json_field("evidence_quality", input.evidence_quality, false)
        + "}";
}

inline std::string to_json(const OutdoorHydrationAdvisoryInput& input) {
    return "{"
        + json_field("air_temperature_c", input.air_temperature_c)
        + json_field("relative_humidity_fraction", input.relative_humidity_fraction)
        + json_field("solar_radiation_w_m2", input.solar_radiation_w_m2)
        + json_field("wind_speed_m_s", input.wind_speed_m_s)
        + json_field("activity_level", input.activity_level)
        + json_field("shade_fraction", input.shade_fraction)
        + json_field("work_rest_fraction", input.work_rest_fraction)
        + json_field("water_access_score", input.water_access_score)
        + json_field("forecast_coverage", input.forecast_coverage)
        + json_field("evidence_quality", input.evidence_quality, false)
        + "}";
}

inline std::string to_json(const SurfaceBurnClockInput& input) {
    std::string result = "{"
        + json_string_field("material", input.material)
        + json_field("air_temperature_c", input.air_temperature_c)
        + json_field("solar_radiation_w_m2", input.solar_radiation_w_m2)
        + json_field("wind_speed_m_s", input.wind_speed_m_s)
        + json_field("shade_fraction", input.shade_fraction)
        + json_field("surface_moisture_fraction", input.surface_moisture_fraction)
        + json_field("sun_exposure_minutes", input.sun_exposure_minutes);

    if (input.prior_surface_temperature_c.has_value()) {
        result += json_field(
            "prior_surface_temperature_c",
            *input.prior_surface_temperature_c
        );
    } else {
        result += "\"prior_surface_temperature_c\":null,";
    }

    result += json_field("observation_coverage", input.observation_coverage);
    result += json_field("evidence_quality", input.evidence_quality, false);
    result += "}";

    return result;
}

inline std::string to_json(const DryRecoveryServiceNeedInput& input) {
    return "{"
        + json_field("wet_exposure_score", input.wet_exposure_score)
        + json_field("drying_lack_score", input.drying_lack_score)
        + json_field("humidity_persistence_score", input.humidity_persistence_score)
        + json_field("overnight_low_temperature_c", input.overnight_low_temperature_c)
        + json_field("consecutive_wet_hours", input.consecutive_wet_hours)
        + json_field("covered_rest_capacity_score", input.covered_rest_capacity_score)
        + json_field("dry_storage_capacity_score", input.dry_storage_capacity_score)
        + json_field("laundry_or_drying_access_score", input.laundry_or_drying_access_score)
        + json_field("hygiene_access_score", input.hygiene_access_score)
        + json_field("accessible_service_route_score", input.accessible_service_route_score)
        + json_field("forecast_coverage", input.forecast_coverage)
        + json_field("service_inventory_coverage", input.service_inventory_coverage)
        + json_field("evidence_quality", input.evidence_quality, false)
        + "}";
}

/*
 * Full JSON deserialization should use the existing project JSON dependency when
 * one is present. A hand-written general parser is intentionally not included:
 * a partial parser would be less safe and less interoperable than a vetted,
 * already-vendored parser.
 *
 * The forwarding `from_json` interface is intentionally constrained to the
 * response fields a firmware client requires.
 */
struct SurfaceBurnClockResult {
    double estimated_surface_temperature_c{};
    double estimated_surface_temperature_f{};
    std::string hazard_band{};
    std::string coverage_status{};
};

bool from_json(
    std::string_view response_json,
    SurfaceBurnClockResult& output,
    std::string& error_message
);

}  // namespace augmented_hub::environmental_metrics

#endif
