#ifndef AUGMENTED_HUB_SOCIAL_ACCEPTANCE_METRICS_HPP
#define AUGMENTED_HUB_SOCIAL_ACCEPTANCE_METRICS_HPP

#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::social_acceptance {

enum class AcceptanceError {
    empty_input,
    invalid_numeric_input,
    incompatible_time_order,
    insufficient_aggregation
};

struct AcceptanceVector {
    double legal{};
    double social{};
    double infrastructural{};
    double psychological{};
    double economic{};
};

struct AcceptanceChange {
    AcceptanceVector policy_change{};
    AcceptanceVector social_feedback_change{};
    AcceptanceVector infrastructure_change{};
};

struct AcceptanceWeights {
    AcceptanceVector policy_weights{};
    AcceptanceVector social_weights{};
    AcceptanceVector infrastructure_weights{};
    AcceptanceVector composite_weights{};
};

struct AggregateEvidence {
    std::size_t participant_count{};
    bool voluntary{};
    bool non_identifying{};
    bool publication_approved{};
};

struct AcceptanceAssessment {
    AcceptanceVector updated_vector{};
    double composite_acceptance_score{};
    double tolerance_floor_score{};
    double positive_acceptance_score{};
    bool publication_eligible{};
    std::string plain_language_explanation;
};

[[nodiscard]] std::expected<AcceptanceAssessment, AcceptanceError>
evaluate_acceptance_conditions(
    const AcceptanceVector& previous,
    const AcceptanceChange& changes,
    const AcceptanceWeights& weights,
    const AggregateEvidence& evidence);

}  // namespace augmented_hub::social_acceptance

#endif
