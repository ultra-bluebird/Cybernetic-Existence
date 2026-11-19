#ifndef AUGMENTED_HUB_CORRIDOR_EVALUATOR_HPP
#define AUGMENTED_HUB_CORRIDOR_EVALUATOR_HPP

#include "augmented_hub/corridor_cache.hpp"

#include <algorithm>
#include <cmath>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace augmented_hub {

struct CorridorPolicy {
    double minimum_voltage_v{0.0};
    double maximum_voltage_v{0.0};
    double maximum_current_a{0.0};
    double maximum_surface_temperature_c{0.0};
    double maximum_fog_unmodeled_fraction{0.20};
    double minimum_canal_dissolved_oxygen_mg_l{4.0};
    double maximum_ker_harm_risk{0.25};
    int maximum_permitted_water_stress_stage{0};
};

struct CorridorRequest {
    std::string corridor_key;
    std::string authorization_key;
    std::string water_stress_key;
    std::uint64_t minimum_cache_version{0};
};

struct CorridorDecision {
    CorridorState state{CorridorState::Denied};
    std::string explanation_code;
    std::vector<std::string> failed_conditions;
    std::uint64_t evaluated_cache_version{0};
    bool sqlite_fallback_attempted{false};
};

class CorridorEvaluator final {
public:
    explicit CorridorEvaluator(const CorridorCache& cache)
        : cache_(cache) {
    }

    [[nodiscard]] CorridorDecision evaluate(
        const CorridorRequest& request,
        const CorridorPolicy& policy,
        TimePoint now = Clock::now()
    ) const {
        const CacheLookupResult lookup =
            cache_.lookup(request.minimum_cache_version, now);

        if (!lookup.cache_available) {
            return deny(
                "CORRIDOR_CACHE_MISS_DENY",
                {"cache_snapshot_unavailable"},
                0
            );
        }

        if (!lookup.cache_version_matches) {
            return deny(
                "CORRIDOR_CACHE_VERSION_STALE_DENY",
                {"cache_version_does_not_meet_required_version"},
                lookup.snapshot->cache_version
            );
        }

        if (!lookup.cache_fresh) {
            return deny(
                "CORRIDOR_CACHE_TIME_STALE_DENY",
                {"cache_snapshot_exceeds_freshness_window"},
                lookup.snapshot->cache_version
            );
        }

        const auto authorization =
            find_authorization(*lookup.snapshot, request.authorization_key);

        if (!authorization.has_value()) {
            return deny(
                "KER_AUTHORIZATION_MISSING_DENY",
                {"ker_authorization_missing"},
                lookup.snapshot->cache_version
            );
        }

        if (!authorization->approved ||
            !authorization->consent_revocable ||
            !authorization->human_review_required ||
            authorization->harm_risk > policy.maximum_ker_harm_risk ||
            now > authorization->valid_until) {
            return deny(
                "KER_AUTHORIZATION_INVALID_DENY",
                {"ker_authorization_not_current_or_not_approved"},
                lookup.snapshot->cache_version
            );
        }

        const auto water_stress =
            find_water_stress(*lookup.snapshot, request.water_stress_key);

        if (!water_stress.has_value() || !water_stress->valid) {
            return deny(
                "WATER_STRESS_STAGE_MISSING_DENY",
                {"water_stress_stage_missing_or_invalid"},
                lookup.snapshot->cache_version
            );
        }

        if (water_stress->stage > policy.maximum_permitted_water_stress_stage) {
            return deny(
                "WATER_STRESS_STAGE_EXCEEDED_DENY",
                {"water_stress_stage_exceeds_corridor_limit"},
                lookup.snapshot->cache_version
            );
        }

        const auto voltage = sensor(*lookup.snapshot, "voltage_v");
        const auto current = sensor(*lookup.snapshot, "current_a");
        const auto temperature = sensor(*lookup.snapshot, "surface_temperature_c");
        const auto fog_fraction = sensor(*lookup.snapshot, "fog_unmodeled_fraction");
        const auto oxygen = sensor(*lookup.snapshot, "dissolved_oxygen_mg_l");

        if (!voltage || !current || !temperature || !fog_fraction || !oxygen) {
            return deny(
                "REQUIRED_CORRIDOR_SENSOR_MISSING_DENY",
                {"required_sensor_missing_or_invalid"},
                lookup.snapshot->cache_version
            );
        }

        std::vector<std::string> failures;

        if (voltage->value < policy.minimum_voltage_v ||
            voltage->value > policy.maximum_voltage_v) {
            failures.emplace_back("electrical_voltage_out_of_bounds");
        }

        if (current->value > policy.maximum_current_a) {
            failures.emplace_back("electrical_current_exceeds_bound");
        }

        if (temperature->value > policy.maximum_surface_temperature_c) {
            failures.emplace_back("thermal_bound_exceeded");
        }

        if (fog_fraction->value > policy.maximum_fog_unmodeled_fraction) {
            failures.emplace_back("fog_media_threshold_exceeded");
        }

        if (oxygen->value < policy.minimum_canal_dissolved_oxygen_mg_l) {
            failures.emplace_back("canal_dissolved_oxygen_below_minimum");
        }

        if (!failures.empty()) {
            return deny(
                "CORRIDOR_CONDITION_DENIED",
                std::move(failures),
                lookup.snapshot->cache_version
            );
        }

        return {
            CorridorState::Permitted,
            "CORRIDOR_PERMITTED",
            {},
            lookup.snapshot->cache_version,
            false
        };
    }

    [[nodiscard]] static CorridorDecision sqlite_unavailable_fallback() {
        return {
            CorridorState::NeedsHumanReview,
            "SQLITE_UNAVAILABLE_FAIL_CLOSED",
            {"persistent_audit_store_unavailable"},
            0,
            true
        };
    }

private:
    const CorridorCache& cache_;

    [[nodiscard]] static std::optional<KerAuthorization> find_authorization(
        const CorridorSnapshot& snapshot,
        const std::string& authorization_key
    ) {
        const auto iterator =
            snapshot.latest_ker_authorizations.find(authorization_key);

        if (iterator == snapshot.latest_ker_authorizations.end()) {
            return std::nullopt;
        }

        return iterator->second;
    }

    [[nodiscard]] static std::optional<WaterStressStage> find_water_stress(
        const CorridorSnapshot& snapshot,
        const std::string& water_stress_key
    ) {
        const auto iterator =
            snapshot.latest_water_stress_stages.find(water_stress_key);

        if (iterator == snapshot.latest_water_stress_stages.end()) {
            return std::nullopt;
        }

        return iterator->second;
    }

    [[nodiscard]] static std::optional<SensorValue> sensor(
        const CorridorSnapshot& snapshot,
        std::string_view key
    ) {
        const auto iterator =
            snapshot.latest_sensor_values.find(std::string(key));

        if (iterator == snapshot.latest_sensor_values.end() ||
            !iterator->second.valid ||
            !std::isfinite(iterator->second.value)) {
            return std::nullopt;
        }

        return iterator->second;
    }

    [[nodiscard]] static CorridorDecision deny(
        std::string explanation_code,
        std::vector<std::string> failed_conditions,
        std::uint64_t cache_version
    ) {
        return {
            CorridorState::Denied,
            std::move(explanation_code),
            std::move(failed_conditions),
            cache_version,
            false
        };
    }
};

}  // namespace augmented_hub

#endif
