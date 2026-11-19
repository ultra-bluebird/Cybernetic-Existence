#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <optional>
#include <string>
#include <utility>
#include <vector>

namespace augmented_hub::gf33 {

enum class RejectionCode {
    None,
    InvalidInput,
    UnvalidatedZone,
    VisibilityLimitExceeded,
    SeparationInsufficient,
    EmergencyStopDeadlineExceeded,
    MissingSafetyField,
    EcologicalOnlyCandidate
};

struct ZoneSafetyProfile {
    std::string zone_id;
    bool validated_for_operation{false};
    bool restricted_zone{false};
    bool restricted_zone_controls_validated{false};

    double max_speed_mps{0.0};
    double min_visibility_m{0.0};
    double minimum_separation_m{0.0};
    double critical_obstacle_distance_m{0.0};
    double maximum_stop_time_s{0.0};

    double validated_deceleration_mps2{0.0};
    double detection_latency_s{0.0};
    double decision_latency_s{0.0};
    double brake_initiation_latency_s{0.0};
    double position_uncertainty_m{0.0};
    double safety_margin_m{0.0};

    double ecological_energy_weight{1.0};
    double ecological_noise_weight{1.0};
    double ecological_surface_wear_weight{1.0};
    double ecological_sensitive_area_weight{1.0};
};

struct RouteSample {
    std::string zone_id;
    double speed_mps{0.0};
    double visibility_m{0.0};
    double nearest_person_distance_m{std::numeric_limits<double>::infinity()};
    double nearest_obstacle_distance_m{std::numeric_limits<double>::infinity()};
    bool personnel_protection_active{false};

    double projected_energy_wh{0.0};
    double projected_noise_index{0.0};
    double projected_surface_wear_index{0.0};
    double projected_sensitive_area_index{0.0};
};

struct RouteCandidate {
    std::string route_id;
    std::vector<RouteSample> samples;
};

struct ValidationResult {
    bool admissible{false};
    RejectionCode code{RejectionCode::InvalidInput};
    std::string detail;
    double ecological_cost{std::numeric_limits<double>::infinity()};
};

class RouteSafetyPlanner {
public:
    static ValidationResult validate(
        const RouteCandidate& candidate,
        const std::vector<ZoneSafetyProfile>& profiles) {

        if (candidate.route_id.empty() || candidate.samples.empty()) {
            return reject(RejectionCode::InvalidInput, "Route identifier and samples are required.");
        }

        double ecological_cost = 0.0;

        for (const RouteSample& sample : candidate.samples) {
            const ZoneSafetyProfile* profile = find_profile(sample.zone_id, profiles);
            if (profile == nullptr || !profile->validated_for_operation) {
                return reject(
                    RejectionCode::UnvalidatedZone,
                    "Route enters a zone without a validated operating profile.");
            }

            if (profile->restricted_zone && !profile->restricted_zone_controls_validated) {
                return reject(
                    RejectionCode::UnvalidatedZone,
                    "Restricted-zone controls are not validated.");
            }

            if (!valid_nonnegative(sample.speed_mps) ||
                !valid_nonnegative(sample.visibility_m) ||
                !valid_nonnegative(sample.nearest_person_distance_m) ||
                !valid_nonnegative(sample.nearest_obstacle_distance_m) ||
                !valid_positive(profile->validated_deceleration_mps2) ||
                !valid_nonnegative(profile->detection_latency_s) ||
                !valid_nonnegative(profile->decision_latency_s) ||
                !valid_nonnegative(profile->brake_initiation_latency_s) ||
                !valid_nonnegative(profile->position_uncertainty_m) ||
                !valid_nonnegative(profile->safety_margin_m)) {
                return reject(RejectionCode::InvalidInput, "A route sample or safety profile is invalid.");
            }

            if (!sample.personnel_protection_active) {
                return reject(
                    RejectionCode::MissingSafetyField,
                    "Personnel-protection state is not active for this route sample.");
            }

            if (sample.visibility_m < profile->min_visibility_m ||
                sample.speed_mps > profile->max_speed_mps) {
                return reject(
                    RejectionCode::VisibilityLimitExceeded,
                    "Visibility or commanded speed is outside the validated zone envelope.");
            }

            const double required_distance_m = required_stopping_distance(sample.speed_mps, *profile);

            if (sample.nearest_person_distance_m <
                    std::max(profile->minimum_separation_m, required_distance_m) ||
                sample.nearest_obstacle_distance_m < required_distance_m) {
                return reject(
                    RejectionCode::SeparationInsufficient,
                    "Available person or obstacle separation is below the conservative stopping envelope.");
            }

            if (sample.nearest_obstacle_distance_m < profile->critical_obstacle_distance_m) {
                const double stop_time_s = conservative_stop_time(sample.speed_mps, *profile);
                if (stop_time_s > profile->maximum_stop_time_s) {
                    return reject(
                        RejectionCode::EmergencyStopDeadlineExceeded,
                        "The conservative emergency-stop time exceeds the validated deadline.");
                }
            }

            ecological_cost +=
                profile->ecological_energy_weight * sample.projected_energy_wh +
                profile->ecological_noise_weight * sample.projected_noise_index +
                profile->ecological_surface_wear_weight * sample.projected_surface_wear_index +
                profile->ecological_sensitive_area_weight * sample.projected_sensitive_area_index;
        }

        return ValidationResult{
            true,
            RejectionCode::None,
            "Route is inside the configured validated safety envelope.",
            ecological_cost
        };
    }

    static std::optional<RouteCandidate> select_lowest_impact_safe_route(
        const std::vector<RouteCandidate>& candidates,
        const std::vector<ZoneSafetyProfile>& profiles,
        std::vector<std::pair<std::string, ValidationResult>>* audit = nullptr) {

        std::optional<RouteCandidate> selected;
        double lowest_cost = std::numeric_limits<double>::infinity();

        for (const RouteCandidate& candidate : candidates) {
            const ValidationResult result = validate(candidate, profiles);

            if (audit != nullptr) {
                audit->emplace_back(candidate.route_id, result);
            }

            if (result.admissible && result.ecological_cost < lowest_cost) {
                selected = candidate;
                lowest_cost = result.ecological_cost;
            }
        }

        return selected;
    }

private:
    static bool valid_nonnegative(double value) {
        return std::isfinite(value) && value >= 0.0;
    }

    static bool valid_positive(double value) {
        return std::isfinite(value) && value > 0.0;
    }

    static const ZoneSafetyProfile* find_profile(
        const std::string& zone_id,
        const std::vector<ZoneSafetyProfile>& profiles) {

        const auto iterator = std::find_if(
            profiles.begin(),
            profiles.end(),
            [&zone_id](const ZoneSafetyProfile& profile) {
                return profile.zone_id == zone_id;
            });

        return iterator == profiles.end() ? nullptr : &(*iterator);
    }

    static double required_stopping_distance(
        double speed_mps,
        const ZoneSafetyProfile& profile) {

        const double response_time_s =
            profile.detection_latency_s +
            profile.decision_latency_s +
            profile.brake_initiation_latency_s;

        const double response_distance_m = speed_mps * response_time_s;
        const double braking_distance_m =
            (speed_mps * speed_mps) / (2.0 * profile.validated_deceleration_mps2);

        return response_distance_m +
            braking_distance_m +
            profile.position_uncertainty_m +
            profile.safety_margin_m;
    }

    static double conservative_stop_time(
        double speed_mps,
        const ZoneSafetyProfile& profile) {

        const double response_time_s =
            profile.detection_latency_s +
            profile.decision_latency_s +
            profile.brake_initiation_latency_s;

        return response_time_s + (speed_mps / profile.validated_deceleration_mps2);
    }

    static ValidationResult reject(RejectionCode code, std::string detail) {
        return ValidationResult{false, code, std::move(detail),
                                std::numeric_limits<double>::infinity()};
    }
};

} // namespace augmented_hub::gf33
