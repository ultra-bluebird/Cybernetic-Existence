#ifndef AUGMENTED_HUB_METRIC_DISPATCH_BRIDGE_HPP
#define AUGMENTED_HUB_METRIC_DISPATCH_BRIDGE_HPP

#include <algorithm>
#include <array>
#include <cctype>
#include <cstddef>
#include <map>
#include <optional>
#include <set>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace augmented_hub::environmental_metrics {

enum class MetricName {
    EvapotranspirationCooling,
    RemoteSensingEt,
    WatershedHealth,
    AquiferRecharge,
    SoilCarbon,
    OutdoorHydrationAdvisory,
    SurfaceBurnClock,
    DryRecoveryServiceNeed,
};

struct FieldSchema {
    std::string_view name;
    std::string_view json_type;
    bool required;
    std::optional<double> minimum;
    std::optional<double> maximum;
    std::string_view description;
};

struct MetricSchema {
    MetricName name;
    std::string_view canonical_name;
    std::string_view purpose;
    std::vector<FieldSchema> input_fields;
};

struct ValidationIssue {
    std::string path;
    std::string reason;
    std::string token;
};

struct ValidationResult {
    bool allowed{true};
    std::optional<ValidationIssue> issue{};

    [[nodiscard]] static ValidationResult allow() {
        return ValidationResult{};
    }

    [[nodiscard]] static ValidationResult deny(
        std::string path,
        std::string reason,
        std::string token = {}
    ) {
        ValidationResult result;
        result.allowed = false;
        result.issue = ValidationIssue{
            std::move(path),
            std::move(reason),
            std::move(token),
        };
        return result;
    }
};

/*
 * Minimal structured representation used for recursive privacy validation.
 * A production adapter may translate from nlohmann::json, RapidJSON, or a
 * firmware-local JSON representation into this model before transmission.
 */
struct JsonNode {
    enum class Kind {
        Null,
        Boolean,
        Number,
        String,
        Array,
        Object,
    };

    Kind kind{Kind::Null};
    std::map<std::string, JsonNode> object_values{};
    std::vector<JsonNode> array_values{};

    [[nodiscard]] static JsonNode object(
        std::map<std::string, JsonNode> values
    ) {
        JsonNode node;
        node.kind = Kind::Object;
        node.object_values = std::move(values);
        return node;
    }

    [[nodiscard]] static JsonNode array(std::vector<JsonNode> values) {
        JsonNode node;
        node.kind = Kind::Array;
        node.array_values = std::move(values);
        return node;
    }

    [[nodiscard]] static JsonNode scalar(Kind scalar_kind) {
        JsonNode node;
        node.kind = scalar_kind;
        return node;
    }
};

class MetricDispatchBridge final {
public:
    static constexpr std::array<std::string_view, 8> kMetricNames{
        "evapotranspiration_cooling",
        "remote_sensing_et",
        "watershed_health",
        "aquifer_recharge",
        "soil_carbon",
        "outdoor_hydration_advisory",
        "surface_burn_clock",
        "dry_recovery_service_need",
    };

    /*
     * This list must be generated from or checked against the canonical Python
     * dispatch contract and shared metrics manifest during CI. The bridge
     * performs normalized fragment matching, matching the project-wide policy
     * approach: lowercase ASCII and removal of non-alphanumeric characters.
     */
    static constexpr std::array<std::string_view, 23> kProhibitedKeyTokens{
        "person",
        "individual",
        "household",
        "identity",
        "name",
        "email",
        "phone",
        "address",
        "device",
        "macaddress",
        "bluetooth",
        "wifi",
        "trajectory",
        "locationhistory",
        "image",
        "audio",
        "face",
        "gait",
        "health",
        "medical",
        "neural",
        "biometric",
        "eligib",
    };

    [[nodiscard]] static bool is_supported_metric(
        std::string_view metric_name
    ) {
        return std::find(
            kMetricNames.begin(),
            kMetricNames.end(),
            metric_name
        ) != kMetricNames.end();
    }

    [[nodiscard]] static std::optional<MetricName> parse_metric_name(
        std::string_view metric_name
    ) {
        if (metric_name == "evapotranspiration_cooling") {
            return MetricName::EvapotranspirationCooling;
        }
        if (metric_name == "remote_sensing_et") {
            return MetricName::RemoteSensingEt;
        }
        if (metric_name == "watershed_health") {
            return MetricName::WatershedHealth;
        }
        if (metric_name == "aquifer_recharge") {
            return MetricName::AquiferRecharge;
        }
        if (metric_name == "soil_carbon") {
            return MetricName::SoilCarbon;
        }
        if (metric_name == "outdoor_hydration_advisory") {
            return MetricName::OutdoorHydrationAdvisory;
        }
        if (metric_name == "surface_burn_clock") {
            return MetricName::SurfaceBurnClock;
        }
        if (metric_name == "dry_recovery_service_need") {
            return MetricName::DryRecoveryServiceNeed;
        }

        return std::nullopt;
    }

    [[nodiscard]] static std::string_view canonical_name(MetricName metric) {
        switch (metric) {
            case MetricName::EvapotranspirationCooling:
                return "evapotranspiration_cooling";
            case MetricName::RemoteSensingEt:
                return "remote_sensing_et";
            case MetricName::WatershedHealth:
                return "watershed_health";
            case MetricName::AquiferRecharge:
                return "aquifer_recharge";
            case MetricName::SoilCarbon:
                return "soil_carbon";
            case MetricName::OutdoorHydrationAdvisory:
                return "outdoor_hydration_advisory";
            case MetricName::SurfaceBurnClock:
                return "surface_burn_clock";
            case MetricName::DryRecoveryServiceNeed:
                return "dry_recovery_service_need";
        }

        return "";
    }

    [[nodiscard]] static std::string normalize_key(std::string_view value) {
        std::string normalized;
        normalized.reserve(value.size());

        for (const unsigned char character : value) {
            if (std::isalnum(character) != 0) {
                normalized.push_back(
                    static_cast<char>(std::tolower(character))
                );
            }
        }

        return normalized;
    }

    [[nodiscard]] static bool prohibited_key(
        std::string_view key,
        std::string* matched_token = nullptr
    ) {
        const std::string normalized = normalize_key(key);

        if (normalized.empty()) {
            if (matched_token != nullptr) {
                *matched_token = "non_string_or_empty_key";
            }
            return true;
        }

        for (const std::string_view token : kProhibitedKeyTokens) {
            const std::string normalized_token = normalize_key(token);

            if (!normalized_token.empty()
                && normalized.find(normalized_token) != std::string::npos) {
                if (matched_token != nullptr) {
                    *matched_token = std::string(token);
                }
                return true;
            }
        }

        return false;
    }

    [[nodiscard]] static ValidationResult validate_aggregate_only(
        const JsonNode& node,
        std::string path = "$"
    ) {
        if (node.kind == JsonNode::Kind::Object) {
            for (const auto& [key, nested] : node.object_values) {
                std::string matched_token;

                if (prohibited_key(key, &matched_token)) {
                    return ValidationResult::deny(
                        path + "." + key,
                        "prohibited_key",
                        std::move(matched_token)
                    );
                }

                ValidationResult child_result = validate_aggregate_only(
                    nested,
                    path + "." + key
                );

                if (!child_result.allowed) {
                    return child_result;
                }
            }
        } else if (node.kind == JsonNode::Kind::Array) {
            for (std::size_t index = 0; index < node.array_values.size(); ++index) {
                ValidationResult child_result = validate_aggregate_only(
                    node.array_values[index],
                    path + "[" + std::to_string(index) + "]"
                );

                if (!child_result.allowed) {
                    return child_result;
                }
            }
        }

        return ValidationResult::allow();
    }

    [[nodiscard]] static MetricSchema schema(MetricName metric) {
        switch (metric) {
            case MetricName::EvapotranspirationCooling:
                return evapotranspiration_cooling_schema();
            case MetricName::RemoteSensingEt:
                return remote_sensing_et_schema();
            case MetricName::WatershedHealth:
                return watershed_health_schema();
            case MetricName::AquiferRecharge:
                return aquifer_recharge_schema();
            case MetricName::SoilCarbon:
                return soil_carbon_schema();
            case MetricName::OutdoorHydrationAdvisory:
                return outdoor_hydration_advisory_schema();
            case MetricName::SurfaceBurnClock:
                return surface_burn_clock_schema();
            case MetricName::DryRecoveryServiceNeed:
                return dry_recovery_service_need_schema();
        }

        return {};
    }

private:
    [[nodiscard]] static MetricSchema evapotranspiration_cooling_schema() {
        return MetricSchema{
            MetricName::EvapotranspirationCooling,
            "evapotranspiration_cooling",
            "Aggregate evapotranspiration cooling and recovery-opportunity estimate.",
            {
                {"evapotranspiration_mm_day", "number", true, 0.0, 30.0, "Aggregate evapotranspiration"},
                {"anthropogenic_heat_w_m2", "number", true, 0.0, 5000.0, "Aggregate anthropogenic heat"},
                {"albedo_fraction", "number", true, 0.0, 1.0, "Surface reflectance fraction"},
                {"vegetation_fraction", "number", true, 0.0, 1.0, "Aggregate vegetation fraction"},
                {"baseline_surface_temperature_c", "number", true, -90.0, 100.0, "Baseline surface temperature"},
                {"reference_et_mm_day", "number", true, 0.0, std::nullopt, "Reference evapotranspiration"},
                {"observation_coverage", "number", true, 0.0, 1.0, "Observation coverage"},
                {"evidence_quality", "number", true, 0.0, 1.0, "Evidence quality"},
            },
        };
    }

    [[nodiscard]] static MetricSchema remote_sensing_et_schema() {
        return MetricSchema{
            MetricName::RemoteSensingEt,
            "remote_sensing_et",
            "Aggregate remote-sensing evapotranspiration estimate.",
            {
                {"air_temperature_c", "number", true, -60.0, 60.0, "Air temperature"},
                {"relative_humidity_fraction", "number", true, 0.0, 1.0, "Relative humidity"},
                {"wind_speed_m_s", "number", true, 0.0, 80.0, "Wind speed"},
                {"net_radiation_mj_m2_day", "number", true, -20.0, 60.0, "Net radiation"},
                {"soil_heat_flux_mj_m2_day", "number", true, -20.0, 20.0, "Soil heat flux"},
                {"elevation_m", "number", true, -500.0, 9000.0, "Elevation"},
                {"ndvi", "number", true, -1.0, 1.0, "Normalized difference vegetation index"},
                {"land_surface_temperature_c", "number", true, -90.0, 100.0, "Land surface temperature"},
                {"cloud_free_fraction", "number", true, 0.0, 1.0, "Cloud-free observation fraction"},
                {"observation_coverage", "number", true, 0.0, 1.0, "Observation coverage"},
                {"evidence_quality", "number", true, 0.0, 1.0, "Evidence quality"},
            },
        };
    }

    [[nodiscard]] static MetricSchema watershed_health_schema() {
        return MetricSchema{
            MetricName::WatershedHealth,
            "watershed_health",
            "Aggregate watershed-condition indicator.",
            {
                {"flow_regime_score", "number", true, 0.0, 1.0, "Flow-regime condition"},
                {"water_quality_score", "number", true, 0.0, 1.0, "Water-quality condition"},
                {"riparian_condition_score", "number", true, 0.0, 1.0, "Riparian condition"},
                {"biodiversity_condition_score", "number", true, 0.0, 1.0, "Biodiversity condition"},
                {"groundwater_condition_score", "number", true, 0.0, 1.0, "Groundwater condition"},
                {"landscape_connectivity_score", "number", true, 0.0, 1.0, "Landscape connectivity"},
                {"sensor_coverage_score", "number", true, 0.0, 1.0, "Sensor coverage"},
                {"source_quality_score", "number", true, 0.0, 1.0, "Source quality"},
                {"anomaly_penalty_score", "number", true, 0.0, 1.0, "Validated anomaly penalty"},
            },
        };
    }

    [[nodiscard]] static MetricSchema aquifer_recharge_schema() {
        return MetricSchema{
            MetricName::AquiferRecharge,
            "aquifer_recharge",
            "Aggregate urban water-balance recharge estimate.",
            {
                {"precipitation_mm", "number", true, 0.0, 10000.0, "Precipitation"},
                {"evapotranspiration_mm", "number", true, 0.0, 10000.0, "Evapotranspiration"},
                {"direct_runoff_mm", "number", true, 0.0, 10000.0, "Direct runoff"},
                {"storage_change_mm", "number", true, -10000.0, 10000.0, "Declared storage change"},
                {"imported_recharge_water_mm", "number", true, 0.0, 10000.0, "Managed imported recharge water"},
                {"managed_infiltration_efficiency", "number", true, 0.0, 1.0, "Managed infiltration efficiency"},
                {"impervious_fraction", "number", true, 0.0, 1.0, "Impervious surface fraction"},
                {"permeable_surface_condition", "number", true, 0.0, 1.0, "Permeable surface condition"},
                {"soil_infiltration_condition", "number", true, 0.0, 1.0, "Soil infiltration condition"},
                {"source_quality", "number", true, 0.0, 1.0, "Source quality"},
                {"observation_coverage", "number", true, 0.0, 1.0, "Observation coverage"},
            },
        };
    }

    [[nodiscard]] static MetricSchema soil_carbon_schema() {
        return MetricSchema{
            MetricName::SoilCarbon,
            "soil_carbon",
            "Aggregate first-order soil-carbon scenario model.",
            {
                {"initial_soil_carbon_t_c_ha", "number", true, 0.0, 5000.0, "Initial soil carbon"},
                {"annual_carbon_input_t_c_ha_year", "number", true, 0.0, 500.0, "Annual carbon input"},
                {"baseline_decomposition_rate_year", "number", true, 0.0, 10.0, "Baseline decomposition rate"},
                {"mean_soil_temperature_c", "number", true, -50.0, 80.0, "Mean soil temperature"},
                {"reference_soil_temperature_c", "number", true, -50.0, 80.0, "Reference soil temperature"},
                {"temperature_q10", "number", true, 0.0, std::nullopt, "Temperature response coefficient"},
                {"soil_moisture_fraction", "number", true, 0.0, 1.0, "Soil moisture fraction"},
                {"optimum_soil_moisture_fraction", "number", true, 0.0, std::nullopt, "Optimum soil moisture"},
                {"ground_cover_fraction", "number", true, 0.0, 1.0, "Ground-cover fraction"},
                {"erosion_loss_t_c_ha_year", "number", true, 0.0, 500.0, "Erosion loss"},
                {"disturbance_multiplier", "number", true, 0.0, 10.0, "Disturbance multiplier"},
                {"management_input_multiplier", "number", true, 0.0, 10.0, "Management input multiplier"},
                {"observation_coverage", "number", true, 0.0, 1.0, "Observation coverage"},
                {"evidence_quality", "number", true, 0.0, 1.0, "Evidence quality"},
            },
        };
    }

    [[nodiscard]] static MetricSchema outdoor_hydration_advisory_schema() {
        return MetricSchema{
            MetricName::OutdoorHydrationAdvisory,
            "outdoor_hydration_advisory",
            "Population-level environmental water-loss demand advisory.",
            {
                {"air_temperature_c", "number", true, -40.0, 65.0, "Air temperature"},
                {"relative_humidity_fraction", "number", true, 0.0, 1.0, "Relative humidity"},
                {"solar_radiation_w_m2", "number", true, 0.0, 1500.0, "Solar radiation"},
                {"wind_speed_m_s", "number", true, 0.0, 60.0, "Wind speed"},
                {"activity_level", "number", true, 0.0, 1.0, "Voluntarily selected broad task category"},
                {"shade_fraction", "number", true, 0.0, 1.0, "Shade fraction"},
                {"work_rest_fraction", "number", true, 0.0, 1.0, "Planned work-rest fraction"},
                {"water_access_score", "number", true, 0.0, 1.0, "Aggregate potable-water access"},
                {"forecast_coverage", "number", true, 0.0, 1.0, "Forecast coverage"},
                {"evidence_quality", "number", true, 0.0, 1.0, "Evidence quality"},
            },
        };
    }

    [[nodiscard]] static MetricSchema surface_burn_clock_schema() {
        return MetricSchema{
            MetricName::SurfaceBurnClock,
            "surface_burn_clock",
            "Material-aware surface-temperature and public contact-hazard estimate.",
            {
                {"material", "string", true, std::nullopt, std::nullopt, "asphalt, concrete, metal, turf, soil, or brick"},
                {"air_temperature_c", "number", true, -60.0, 70.0, "Air temperature"},
                {"solar_radiation_w_m2", "number", true, 0.0, 1500.0, "Solar radiation"},
                {"wind_speed_m_s", "number", true, 0.0, 60.0, "Wind speed"},
                {"shade_fraction", "number", true, 0.0, 1.0, "Shade fraction"},
                {"surface_moisture_fraction", "number", true, 0.0, 1.0, "Surface moisture"},
                {"sun_exposure_minutes", "number", true, 0.0, 1440.0, "Sun exposure duration"},
                {"prior_surface_temperature_c", "number", false, -60.0, 120.0, "Prior observed surface temperature"},
                {"observation_coverage", "number", true, 0.0, 1.0, "Observation coverage"},
                {"evidence_quality", "number", true, 0.0, 1.0, "Evidence quality"},
            },
        };
    }

    [[nodiscard]] static MetricSchema dry_recovery_service_need_schema() {
        return MetricSchema{
            MetricName::DryRecoveryServiceNeed,
            "dry_recovery_service_need",
            "Aggregate weather-load and dry-recovery service-capacity gap model.",
            {
                {"wet_exposure_score", "number", true, 0.0, 1.0, "Aggregate wet-exposure condition"},
                {"drying_lack_score", "number", true, 0.0, 1.0, "Aggregate drying-resource gap"},
                {"humidity_persistence_score", "number", true, 0.0, 1.0, "Humidity persistence"},
                {"overnight_low_temperature_c", "number", true, -60.0, 50.0, "Overnight low temperature"},
                {"consecutive_wet_hours", "number", true, 0.0, 720.0, "Consecutive wet hours"},
                {"covered_rest_capacity_score", "number", true, 0.0, 1.0, "Covered rest capacity"},
                {"dry_storage_capacity_score", "number", true, 0.0, 1.0, "Dry storage capacity"},
                {"laundry_or_drying_access_score", "number", true, 0.0, 1.0, "Laundry or drying access"},
                {"hygiene_access_score", "number", true, 0.0, 1.0, "Hygiene access"},
                {"accessible_service_route_score", "number", true, 0.0, 1.0, "Accessible route condition"},
                {"forecast_coverage", "number", true, 0.0, 1.0, "Forecast coverage"},
                {"service_inventory_coverage", "number", true, 0.0, 1.0, "Service-inventory coverage"},
                {"evidence_quality", "number", true, 0.0, 1.0, "Evidence quality"},
            },
        };
    }
};

}  // namespace augmented_hub::environmental_metrics

#endif
