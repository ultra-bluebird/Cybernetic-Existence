#ifndef AUGMENTED_HUB_GENERATED_METRIC_DISPATCH_CONTRACT_HPP
#define AUGMENTED_HUB_GENERATED_METRIC_DISPATCH_CONTRACT_HPP

/*
 * GENERATED FILE.
 *
 * Source contract:
 * - config/metric_dispatch.toml
 * - schemas/
 * - approved metric-dispatch fixtures
 *
 * Do not manually edit this file. Regenerate it through the approved
 * contract-generation workflow and verify it against Python and Rust
 * contract tests.
 */

#include <array>
#include <cstddef>
#include <cstdint>
#include <string_view>

namespace augmented_hub::metric_contract {

inline constexpr std::uint32_t kContractVersion = 1U;

inline constexpr std::array<std::string_view, 8> kMetricNames{
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
 * This declaration represents the generated contract surface only.
 * The generator replaces this list with the exact shared policy tokens.
 *
 * C++ production builds must reject generation if the source contract omits
 * the canonical token policy or if generated-policy parity verification fails.
 */
inline constexpr std::array<std::string_view, 0> kProhibitedKeyTokens{};

enum class FieldKind : std::uint8_t {
    Number,
    String,
    Boolean,
    Null,
};

struct FieldRule {
    std::string_view name;
    FieldKind kind;
    bool required;
    bool nullable;
    bool has_minimum;
    double minimum;
    bool has_maximum;
    double maximum;
};

struct MetricRule {
    std::string_view metric_name;
    const FieldRule* input_fields;
    std::size_t input_field_count;
};

[[nodiscard]] constexpr bool is_metric_name(
    std::string_view candidate
) noexcept {
    for (const std::string_view metric : kMetricNames) {
        if (metric == candidate) {
            return true;
        }
    }

    return false;
}

}  // namespace augmented_hub::metric_contract

#endif
