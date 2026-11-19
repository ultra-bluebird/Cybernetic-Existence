#ifndef AUGMENTED_HUB_CASCADE_CONTAINMENT_HPP
#define AUGMENTED_HUB_CASCADE_CONTAINMENT_HPP

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <map>
#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace augmented_hub {

enum class SensorHealth {
    Healthy,
    Degraded,
    Stale,
    Failed,
    Maintenance,
    Unknown
};

enum class CorridorPriority {
    EmergencyAndEgress = 1,
    PublicService = 2,
    WaterAndCanal = 3,
    Electrical = 4,
    Thermal = 5,
    FogAndMedia = 6,
    KerAuthorization = 7
};

struct SensorHealthRecord {
    std::string sensor_key;
    CorridorPriority corridor_priority;
    bool mandatory;
    SensorHealth health;
    double individual_failure_probability;
    double common_cause_failure_probability;
};

struct CascadeAssessment {
    bool fail_closed;
    double system_failure_risk;
    std::vector<std::string> blocking_sensor_keys;
    std::vector<CorridorPriority> corridor_check_order;
    std::string explanation_code;
};

class CascadeContainment final {
public:
    explicit CascadeContainment(double fail_closed_threshold)
        : fail_closed_threshold_(fail_closed_threshold) {
        if (!std::isfinite(fail_closed_threshold_) ||
            fail_closed_threshold_ <= 0.0 ||
            fail_closed_threshold_ > 1.0) {
            throw std::invalid_argument(
                "fail_closed_threshold must be finite and within (0.0, 1.0]."
            );
        }
    }

    [[nodiscard]] CascadeAssessment assess(
        const std::vector<SensorHealthRecord>& records
    ) const {
        if (records.empty()) {
            return {
                true,
                1.0,
                {},
                default_priority_order(),
                "SENSOR_REQUIREMENT_SET_EMPTY_FAIL_CLOSED"
            };
        }

        std::vector<std::string> blocking_sensors;
        double independent_survival_probability = 1.0;
        double common_cause_survival_probability = 1.0;

        for (const SensorHealthRecord& record : records) {
            validate(record);

            if (record.mandatory && is_blocking(record.health)) {
                blocking_sensors.push_back(record.sensor_key);
            }

            if (record.mandatory) {
                independent_survival_probability *=
                    1.0 - record.individual_failure_probability;

                common_cause_survival_probability *=
                    1.0 - record.common_cause_failure_probability;
            }
        }

        const double system_failure_risk =
            1.0 - (
                independent_survival_probability
                * common_cause_survival_probability
            );

        if (!blocking_sensors.empty()) {
            return {
                true,
                system_failure_risk,
                std::move(blocking_sensors),
                default_priority_order(),
                "MANDATORY_SENSOR_UNHEALTHY_FAIL_CLOSED"
            };
        }

        if (system_failure_risk >= fail_closed_threshold_) {
            return {
                true,
                system_failure_risk,
                {},
                default_priority_order(),
                "SENSOR_CASCADE_RISK_THRESHOLD_EXCEEDED"
            };
        }

        return {
            false,
            system_failure_risk,
            {},
            default_priority_order(),
            "SENSOR_CASCADE_RISK_WITHIN_DECLARED_THRESHOLD"
        };
    }

    [[nodiscard]] static std::vector<CorridorPriority> default_priority_order() {
        return {
            CorridorPriority::EmergencyAndEgress,
            CorridorPriority::PublicService,
            CorridorPriority::WaterAndCanal,
            CorridorPriority::Electrical,
            CorridorPriority::Thermal,
            CorridorPriority::FogAndMedia,
            CorridorPriority::KerAuthorization
        };
    }

private:
    double fail_closed_threshold_;

    static void validate(const SensorHealthRecord& record) {
        if (record.sensor_key.empty()) {
            throw std::invalid_argument("sensor_key must not be empty.");
        }

        if (!std::isfinite(record.individual_failure_probability) ||
            record.individual_failure_probability < 0.0 ||
            record.individual_failure_probability > 1.0) {
            throw std::invalid_argument(
                "individual_failure_probability must be within 0.0..1.0."
            );
        }

        if (!std::isfinite(record.common_cause_failure_probability) ||
            record.common_cause_failure_probability < 0.0 ||
            record.common_cause_failure_probability > 1.0) {
            throw std::invalid_argument(
                "common_cause_failure_probability must be within 0.0..1.0."
            );
        }
    }

    [[nodiscard]] static bool is_blocking(SensorHealth health) {
        return health == SensorHealth::Failed ||
            health == SensorHealth::Stale ||
            health == SensorHealth::Maintenance ||
            health == SensorHealth::Unknown;
    }
};

}  // namespace augmented_hub

#endif
