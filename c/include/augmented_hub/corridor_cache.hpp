#ifndef AUGMENTED_HUB_CORRIDOR_CACHE_HPP
#define AUGMENTED_HUB_CORRIDOR_CACHE_HPP

#include <atomic>
#include <chrono>
#include <cstdint>
#include <memory>
#include <optional>
#include <shared_mutex>
#include <string>
#include <string_view>
#include <unordered_map>
#include <utility>

namespace augmented_hub {

using Clock = std::chrono::system_clock;
using TimePoint = Clock::time_point;

enum class CorridorState {
    Permitted,
    Denied,
    NeedsHumanReview
};

struct SensorValue {
    double value{};
    std::string unit;
    TimePoint observed_at{};
    std::uint64_t source_version{};
    bool valid{false};
};

struct KerAuthorization {
    bool approved{false};
    bool consent_revocable{false};
    bool human_review_required{false};
    double harm_risk{1.0};
    TimePoint valid_until{};
    std::uint64_t source_version{};
};

struct WaterStressStage {
    int stage{-1};
    TimePoint observed_at{};
    std::uint64_t source_version{};
    bool valid{false};
};

struct CorridorSnapshot {
    std::uint64_t cache_version{};
    TimePoint published_at{};

    std::unordered_map<std::string, SensorValue> latest_sensor_values;
    std::unordered_map<std::string, KerAuthorization> latest_ker_authorizations;
    std::unordered_map<std::string, WaterStressStage> latest_water_stress_stages;
};

struct CacheLookupResult {
    std::shared_ptr<const CorridorSnapshot> snapshot;
    bool cache_available{false};
    bool cache_version_matches{false};
    bool cache_fresh{false};
    std::string explanation_code;
};

class CorridorCache final {
public:
    explicit CorridorCache(std::chrono::seconds maximum_snapshot_age)
        : maximum_snapshot_age_(maximum_snapshot_age) {
    }

    void publish(CorridorSnapshot snapshot) {
        snapshot.cache_version = next_version_.fetch_add(1, std::memory_order_relaxed);
        snapshot.published_at = Clock::now();

        auto immutable_snapshot =
            std::make_shared<const CorridorSnapshot>(std::move(snapshot));

        std::unique_lock lock(write_lock_);
        current_snapshot_ = std::move(immutable_snapshot);
    }

    [[nodiscard]] CacheLookupResult lookup(
        std::uint64_t required_version,
        TimePoint now = Clock::now()
    ) const {
        std::shared_lock lock(write_lock_);
        const auto snapshot = current_snapshot_;

        if (!snapshot) {
            return {
                nullptr,
                false,
                false,
                false,
                "CORRIDOR_CACHE_MISS_DENY"
            };
        }

        const bool version_matches =
            required_version == 0 || snapshot->cache_version >= required_version;

        const bool fresh =
            now >= snapshot->published_at &&
            now - snapshot->published_at <= maximum_snapshot_age_;

        if (!version_matches) {
            return {
                snapshot,
                true,
                false,
                fresh,
                "CORRIDOR_CACHE_VERSION_STALE_DENY"
            };
        }

        if (!fresh) {
            return {
                snapshot,
                true,
                true,
                false,
                "CORRIDOR_CACHE_TIME_STALE_DENY"
            };
        }

        return {
            snapshot,
            true,
            true,
            true,
            "CORRIDOR_CACHE_VALID"
        };
    }

    [[nodiscard]] std::uint64_t latest_version() const {
        std::shared_lock lock(write_lock_);
        return current_snapshot_ ? current_snapshot_->cache_version : 0;
    }

private:
    std::chrono::seconds maximum_snapshot_age_;
    std::atomic<std::uint64_t> next_version_{1};
    mutable std::shared_mutex write_lock_;
    std::shared_ptr<const CorridorSnapshot> current_snapshot_;
};

}  // namespace augmented_hub

#endif
