#ifndef AUGMENTED_HUB_QUBO_AND_FEDERATED_POLICY_HPP
#define AUGMENTED_HUB_QUBO_AND_FEDERATED_POLICY_HPP

#include <cstddef>
#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::optimization {

enum class OptimizationError {
    empty_input,
    invalid_numeric_input,
    duplicate_identifier,
    invalid_qubo_index,
    invalid_privacy_budget,
    insufficient_participants,
    incompatible_model_dimension
};

struct QuboTerm {
    std::size_t row{};
    std::size_t column{};
    double coefficient{};
};

struct InfrastructureCandidate {
    std::string candidate_id;
    double deployment_cost{};
    double ecological_benefit{};
    double accessibility_benefit{};
    std::vector<std::string> covered_regions;
};

struct MutuallyExclusivePair {
    std::size_t first_candidate_index{};
    std::size_t second_candidate_index{};
};

struct QuboPolicy {
    double ecological_benefit_weight{1.0};
    double accessibility_benefit_weight{1.0};
    double budget_penalty{10.0};
    double adjacency_penalty{10.0};
    double target_budget{};
};

struct QuboModel {
    std::size_t variable_count{};
    std::vector<QuboTerm> terms;
    std::vector<std::string> variable_identifiers;
    std::string plain_language_explanation;
};

struct PrivacyBudget {
    double epsilon{};
    double delta{};
    double cumulative_epsilon{};
    double maximum_cumulative_epsilon{};
};

struct FederatedHubUpdate {
    std::string hub_id;
    std::size_t sample_count{};
    std::vector<double> model_delta;
    double clipped_norm{};
    double local_validation_score{};
    PrivacyBudget privacy_budget;
    bool raw_data_retained_locally{true};
};

struct FederatedPolicy {
    double minimum_local_validation_score{0.50};
    double maximum_clip_norm{1.0};
    double sensitive_hub_maximum_epsilon{1.0};
    double maximum_delta{1e-6};
    std::size_t minimum_participating_hubs{3};
};

struct FederatedRoundResult {
    std::vector<double> weighted_model_delta;
    std::size_t participating_hub_count{};
    std::size_t total_sample_count{};
    double minimum_local_validation_score{};
    double maximum_epsilon_used{};
    double maximum_delta_used{};
    bool privacy_policy_satisfied{};
    std::string plain_language_explanation;
};

[[nodiscard]] std::expected<QuboModel, OptimizationError>
build_infrastructure_layout_qubo(
    const std::vector<InfrastructureCandidate>& candidates,
    const std::vector<MutuallyExclusivePair>& mutually_exclusive_pairs,
    const QuboPolicy& policy);

[[nodiscard]] std::expected<FederatedRoundResult, OptimizationError>
aggregate_federated_updates(
    const std::vector<FederatedHubUpdate>& updates,
    const FederatedPolicy& policy);

}  // namespace augmented_hub::optimization

#endif
