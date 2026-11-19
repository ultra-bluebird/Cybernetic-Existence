#ifndef AUGMENTED_HUB_METRIC_VALIDATION_HPP
#define AUGMENTED_HUB_METRIC_VALIDATION_HPP

#include "../generated/metric_dispatch_contract.hpp"

#include <cstddef>
#include <cstdint>
#include <string_view>

namespace augmented_hub::metric_validation {

/*
 * The schema layer uses an adapter interface rather than std::map, std::vector,
 * exceptions, heap ownership, or any specific JSON library. Host adapters can
 * implement this for parsed JSON. Firmware adapters can bypass dynamic-tree
 * traversal by validating fixed-layout typed request structs against the
 * generated FieldRule tables.
 */
class JsonView {
public:
    enum class Kind : std::uint8_t {
        Null,
        Boolean,
        Number,
        String,
        Array,
        Object,
    };

    virtual ~JsonView() = default;

    [[nodiscard]] virtual Kind kind() const noexcept = 0;

    [[nodiscard]] virtual std::size_t size() const noexcept = 0;

    [[nodiscard]] virtual std::string_view key_at(
        std::size_t index
    ) const noexcept = 0;

    [[nodiscard]] virtual const JsonView* value_at(
        std::size_t index
    ) const noexcept = 0;
};

enum class ValidationCode : std::uint8_t {
    Allowed,
    InvalidMetricName,
    ProhibitedKey,
    UnknownField,
    MissingRequiredField,
    InvalidFieldKind,
    NullNotAllowed,
    OutOfRange,
    UnsupportedContract,
    InvalidStructure,
};

struct ValidationResult {
    ValidationCode code;
    std::string_view field_name;
    std::string_view matched_policy_token;
    std::size_t path_depth;

    [[nodiscard]] constexpr bool allowed() const noexcept {
        return code == ValidationCode::Allowed;
    }
};

[[nodiscard]] ValidationResult validate_metric_request(
    std::string_view metric_name,
    const JsonView& input
) noexcept;

[[nodiscard]] ValidationResult validate_aggregate_only(
    const JsonView& value
) noexcept;

[[nodiscard]] bool prohibited_key(
    std::string_view key,
    std::string_view* matched_policy_token
) noexcept;

[[nodiscard]] bool validate_surface_burn_clock_input(
    std::string_view material,
    double air_temperature_c,
    double solar_radiation_w_m2,
    double wind_speed_m_s,
    double shade_fraction,
    double surface_moisture_fraction,
    double sun_exposure_minutes,
    bool has_prior_surface_temperature_c,
    double prior_surface_temperature_c,
    double observation_coverage,
    double evidence_quality
) noexcept;

}  // namespace augmented_hub::metric_validation

#endif
