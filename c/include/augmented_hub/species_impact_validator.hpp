#ifndef AUGMENTED_HUB_SPECIES_IMPACT_VALIDATOR_HPP
#define AUGMENTED_HUB_SPECIES_IMPACT_VALIDATOR_HPP

#include <cmath>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace augmented_hub {

enum class ImpactType {
    ThermalPollution,
    WaterTableChange,
    LightPollution,
    PesticideDrift,
    HabitatFragmentation
};

enum class Comparison {
    GreaterThan,
    LessThan
};

struct SpeciesImpactThreshold {
    std::string species_or_ecosystem;
    ImpactType impact_type;
    Comparison comparison;
    double significance_threshold;
    std::string unit;
};

struct DataCenterTelemetry {
    std::optional<double> downstream_temperature_change_c;
    std::optional<double> root_zone_moisture_percent_change;
    std::optional<double> nighttime_illumination_lux_above_baseline;
    std::optional<double> nectar_pesticide_concentration_ppb;
    std::optional<double> connected_habitat_area_loss_percent;
};

struct SpeciesImpactFinding {
    std::string species_or_ecosystem;
    ImpactType impact_type;
    double observed_value;
    double significance_threshold;
    bool threshold_exceeded;
    std::string reason_code;
};

class SpeciesImpactValidator final {
public:
    [[nodiscard]] static std::vector<SpeciesImpactFinding> validate(
        const DataCenterTelemetry& telemetry,
        const std::vector<SpeciesImpactThreshold>& thresholds
    ) {
        std::vector<SpeciesImpactFinding> findings;
        findings.reserve(thresholds.size());

        for (const SpeciesImpactThreshold& threshold : thresholds) {
            const std::optional<double> observed =
                observed_value_for(threshold.impact_type, telemetry);

            if (!observed.has_value()) {
                findings.push_back({
                    threshold.species_or_ecosystem,
                    threshold.impact_type,
                    0.0,
                    threshold.significance_threshold,
                    true,
                    "MISSING_REQUIRED_SPECIES_IMPACT_TELEMETRY_FAIL_CLOSED"
                });
                continue;
            }

            require_finite(observed.value(), "observed value");
            require_finite(
                threshold.significance_threshold,
                "significance threshold"
            );

            const bool exceeded = threshold_exceeded(
                observed.value(),
                threshold.significance_threshold,
                threshold.comparison
            );

            findings.push_back({
                threshold.species_or_ecosystem,
                threshold.impact_type,
                observed.value(),
                threshold.significance_threshold,
                exceeded,
                exceeded
                    ? "SPECIES_IMPACT_THRESHOLD_EXCEEDED"
                    : "SPECIES_IMPACT_WITHIN_THRESHOLD"
            });
        }

        return findings;
    }

    [[nodiscard]] static bool eco_benefit_claim_valid(
        const std::vector<SpeciesImpactFinding>& findings
    ) {
        for (const SpeciesImpactFinding& finding : findings) {
            if (finding.threshold_exceeded) {
                return false;
            }
        }

        return true;
    }

private:
    [[nodiscard]] static std::optional<double> observed_value_for(
        ImpactType impact_type,
        const DataCenterTelemetry& telemetry
    ) {
        switch (impact_type) {
            case ImpactType::ThermalPollution:
                return telemetry.downstream_temperature_change_c;
            case ImpactType::WaterTableChange:
                return telemetry.root_zone_moisture_percent_change;
            case ImpactType::LightPollution:
                return telemetry.nighttime_illumination_lux_above_baseline;
            case ImpactType::PesticideDrift:
                return telemetry.nectar_pesticide_concentration_ppb;
            case ImpactType::HabitatFragmentation:
                return telemetry.connected_habitat_area_loss_percent;
        }

        throw std::invalid_argument("Unsupported impact type.");
    }

    [[nodiscard]] static bool threshold_exceeded(
        double observed,
        double threshold,
        Comparison comparison
    ) {
        switch (comparison) {
            case Comparison::GreaterThan:
                return observed > threshold;
            case Comparison::LessThan:
                return observed < threshold;
        }

        throw std::invalid_argument("Unsupported threshold comparison.");
    }

    static void require_finite(double value, std::string_view field_name) {
        if (!std::isfinite(value)) {
            throw std::invalid_argument(
                std::string(field_name) + " must be finite."
            );
        }
    }
};

}  // namespace augmented_hub

#endif
