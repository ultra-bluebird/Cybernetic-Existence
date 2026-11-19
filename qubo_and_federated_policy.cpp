#include "qubo_and_federated_policy.hpp"

#include <algorithm>
#include <cmath>
#include <unordered_set>
#include <utility>

namespace augmented_hub::optimization {
namespace {

constexpr double kEpsilon = 1e-12;

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

void add_qubo_term(
    std::vector<QuboTerm>& terms,
    std::size_t row,
    std::size_t column,
    double coefficient) {

    for (auto& term : terms) {
        if (term.row == row && term.column == column) {
            term.coefficient += coefficient;
            return;
        }
    }

    terms.push_back(QuboTerm{
        .row = row,
        .column = column,
        .coefficient = coefficient
    });
}

double squared_norm(const std::vector<double>& values) noexcept {
    double total = 0.0;

    for (const double value : values) {
        total += value * value;
    }

    return total;
}

}  // namespace

std::expected<QuboModel, OptimizationError>
build_infrastructure_layout_qubo(
    const std::vector<InfrastructureCandidate>& candidates,
    const std::vector<MutuallyExclusivePair>& mutually_exclusive_pairs,
    const QuboPolicy& policy) {

    if (candidates.empty()) {
        return std::unexpected(OptimizationError::empty_input);
    }

    if (!finite_nonnegative(policy.ecological_benefit_weight) ||
        !finite_nonnegative(policy.accessibility_benefit_weight) ||
        !finite_nonnegative(policy.budget_penalty) ||
        !finite_nonnegative(policy.adjacency_penalty) ||
        !finite_nonnegative(policy.target_budget)) {
        return std::unexpected(OptimizationError::invalid_numeric_input);
    }

    std::unordered_set<std::string> identifiers;
    std::vector<QuboTerm> terms;
    std::vector<std::string> variable_identifiers;
    variable_identifiers.reserve(candidates.size());

    for (std::size_t index = 0; index < candidates.size(); ++index) {
        const auto& candidate = candidates[index];

        if (candidate.candidate_id.empty() ||
            !identifiers.insert(candidate.candidate_id).second ||
            !finite_nonnegative(candidate.deployment_cost) ||
            !finite_nonnegative(candidate.ecological_benefit) ||
            !finite_nonnegative(candidate.accessibility_benefit)) {
            return std::unexpected(OptimizationError::invalid_numeric_input);
        }

        variable_identifiers.push_back(candidate.candidate_id);

        const double linear_objective =
            policy.ecological_benefit_weight *
                candidate.ecological_benefit +
            policy.accessibility_benefit_weight *
                candidate.accessibility_benefit;

        const double budget_linear =
            policy.budget_penalty *
            (candidate.deployment_cost * candidate.deployment_cost -
             2.0 * policy.target_budget * candidate.deployment_cost);

        add_qubo_term(
            terms,
            index,
            index,
            budget_linear - linear_objective);
    }

    for (std::size_t first = 0; first < candidates.size(); ++first) {
        for (std::size_t second = first + 1U;
             second < candidates.size();
             ++second) {
            const double budget_quadratic =
                2.0 * policy.budget_penalty *
                candidates[first].deployment_cost *
                candidates[second].deployment_cost;

            add_qubo_term(terms, first, second, budget_quadratic);
        }
    }

    for (const auto& pair : mutually_exclusive_pairs) {
        if (pair.first_candidate_index >= candidates.size() ||
            pair.second_candidate_index >= candidates.size() ||
            pair.first_candidate_index == pair.second_candidate_index) {
            return std::unexpected(OptimizationError::invalid_qubo_index);
        }

        const std::size_t row = std::min(
            pair.first_candidate_index,
            pair.second_candidate_index);

        const std::size_t column = std::max(
            pair.first_candidate_index,
            pair.second_candidate_index);

        add_qubo_term(
            terms,
            row,
            column,
            policy.adjacency_penalty);
    }

    return QuboModel{
        .variable_count = candidates.size(),
        .terms = std::move(terms),
        .variable_identifiers = std::move(variable_identifiers),
        .plain_language_explanation =
            "The QUBO encodes ecological and accessibility benefits, deployment cost, a target-budget penalty, and mutually exclusive placements. It is solver-neutral planning evidence and requires separate review before infrastructure deployment."
    };
}

std::expected<FederatedRoundResult, OptimizationError>
aggregate_federated_updates(
    const std::vector<FederatedHubUpdate>& updates,
    const FederatedPolicy& policy) {

    if (updates.size() < policy.minimum_participating_hubs) {
        return std::unexpected(OptimizationError::insufficient_participants);
    }

    if (!finite_unit_interval(policy.minimum_local_validation_score) ||
        !finite_nonnegative(policy.maximum_clip_norm) ||
        !finite_nonnegative(policy.sensitive_hub_maximum_epsilon) ||
        !finite_nonnegative(policy.maximum_delta) ||
        policy.minimum_participating_hubs < 3U) {
        return std::unexpected(OptimizationError::invalid_privacy_budget);
    }

    std::unordered_set<std::string> hub_identifiers;
    const std::size_t model_dimension = updates.front().model_delta.size();

    if (model_dimension == 0U) {
        return std::unexpected(OptimizationError::incompatible_model_dimension);
    }

    std::vector<double> aggregate(model_dimension, 0.0);
    std::size_t total_samples = 0U;
    double minimum_validation_score = 1.0;
    double maximum_epsilon_used = 0.0;
    double maximum_delta_used = 0.0;

    for (const auto& update : updates) {
        if (update.hub_id.empty() ||
            !hub_identifiers.insert(update.hub_id).second ||
            update.sample_count == 0U ||
            update.model_delta.size() != model_dimension ||
            !finite_nonnegative(update.clipped_norm) ||
            !finite_unit_interval(update.local_validation_score) ||
            !finite_nonnegative(update.privacy_budget.epsilon) ||
            !finite_nonnegative(update.privacy_budget.delta) ||
            !finite_nonnegative(update.privacy_budget.cumulative_epsilon) ||
            !finite_nonnegative(
                update.privacy_budget.maximum_cumulative_epsilon) ||
            !update.raw_data_retained_locally) {
            return std::unexpected(OptimizationError::invalid_numeric_input);
        }

        if (update.clipped_norm > policy.maximum_clip_norm + kEpsilon ||
            update.privacy_budget.epsilon >
                policy.sensitive_hub_maximum_epsilon + kEpsilon ||
            update.privacy_budget.delta >
                policy.maximum_delta + kEpsilon ||
            update.privacy_budget.cumulative_epsilon >
                update.privacy_budget.maximum_cumulative_epsilon +
                    kEpsilon) {
            return std::unexpected(OptimizationError::invalid_privacy_budget);
        }

        if (std::sqrt(squared_norm(update.model_delta)) >
            policy.maximum_clip_norm + kEpsilon) {
            return std::unexpected(OptimizationError::invalid_numeric_input);
        }

        for (const double value : update.model_delta) {
            if (!std::isfinite(value)) {
                return std::unexpected(OptimizationError::invalid_numeric_input);
            }
        }

        total_samples += update.sample_count;
        minimum_validation_score = std::min(
            minimum_validation_score,
            update.local_validation_score);

        maximum_epsilon_used = std::max(
            maximum_epsilon_used,
            update.privacy_budget.epsilon);

        maximum_delta_used = std::max(
            maximum_delta_used,
            update.privacy_budget.delta);
    }

    if (total_samples == 0U) {
        return std::unexpected(OptimizationError::invalid_numeric_input);
    }

    for (const auto& update : updates) {
        const double weight =
            static_cast<double>(update.sample_count) /
            static_cast<double>(total_samples);

        for (std::size_t index = 0;
             index < model_dimension;
             ++index) {
            aggregate[index] += weight * update.model_delta[index];
        }
    }

    const bool model_quality_accepted =
        minimum_validation_score >= policy.minimum_local_validation_score;

    return FederatedRoundResult{
        .weighted_model_delta = std::move(aggregate),
        .participating_hub_count = updates.size(),
        .total_sample_count = total_samples,
        .minimum_local_validation_score = minimum_validation_score,
        .maximum_epsilon_used = maximum_epsilon_used,
        .maximum_delta_used = maximum_delta_used,
        .privacy_policy_satisfied = model_quality_accepted,
        .plain_language_explanation =
            model_quality_accepted
                ? "The round aggregates clipped, locally retained model updates using sample-weighted averaging. Each participating hub satisfies the configured privacy-budget and local-validation rules."
                : "The updates satisfy the configured privacy controls, but at least one hub is below the local model-quality threshold. The global update remains held for review rather than promoted."
    };
}

}  // namespace augmented_hub::optimization
