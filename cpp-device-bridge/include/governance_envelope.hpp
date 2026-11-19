#ifndef AUGMENTED_HUB_GOVERNANCE_ENVELOPE_HPP
#define AUGMENTED_HUB_GOVERNANCE_ENVELOPE_HPP

#include <cstdint>
#include <string>
#include <string_view>

namespace augmented_hub::environmental_metrics {

enum class GovernanceScope : std::uint8_t {
    AggregateEnvironmentalDecisionSupportOnly,
};

struct GovernanceEnvelope {
    GovernanceScope scope{
        GovernanceScope::AggregateEnvironmentalDecisionSupportOnly,
    };
    bool individual_profiling{false};
    bool automated_adverse_action{false};
    bool external_action{false};
};

[[nodiscard]] constexpr GovernanceEnvelope standard_governance_envelope() noexcept {
    return GovernanceEnvelope{};
}

[[nodiscard]] constexpr bool is_valid_governance_envelope(
    const GovernanceEnvelope& envelope
) noexcept {
    return envelope.scope
            == GovernanceScope::AggregateEnvironmentalDecisionSupportOnly
        && !envelope.individual_profiling
        && !envelope.automated_adverse_action
        && !envelope.external_action;
}

[[nodiscard]] constexpr std::string_view governance_scope_name(
    GovernanceScope scope
) noexcept {
    switch (scope) {
        case GovernanceScope::AggregateEnvironmentalDecisionSupportOnly:
            return "aggregate_environmental_decision_support_only";
    }

    return "invalid_scope";
}

[[nodiscard]] std::string governance_envelope_json(
    const GovernanceEnvelope& envelope
);

[[nodiscard]] std::string attach_governance_envelope(
    std::string_view response_json,
    const GovernanceEnvelope& envelope = standard_governance_envelope()
);

}  // namespace augmented_hub::environmental_metrics

#endif
