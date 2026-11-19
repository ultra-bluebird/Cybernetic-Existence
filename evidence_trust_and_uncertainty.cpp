#include "evidence_trust_and_uncertainty.hpp"

#include <algorithm>
#include <cmath>
#include <numeric>
#include <unordered_set>

namespace augmented_hub::evidence_uq {
namespace {

constexpr double kEpsilon = 1e-12;
constexpr double kNinetyFivePercentZScore = 1.959963984540054;

bool finite_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

bool finite_nonnegative(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

bool valid_opinion(const SubjectiveOpinion& opinion) noexcept {
    return finite_unit_interval(opinion.belief) &&
        finite_unit_interval(opinion.disbelief) &&
        finite_unit_interval(opinion.uncertainty) &&
        finite_unit_interval(opinion.base_rate) &&
        std::abs(
            opinion.belief +
            opinion.disbelief +
            opinion.uncertainty -
            1.0) <= 1e-9;
}

double reliability_from_cv(double coefficient_of_variation) noexcept {
    return 1.0 / (1.0 + coefficient_of_variation * coefficient_of_variation);
}

SubjectiveOpinion combine_opinions(
    const SubjectiveOpinion& left,
    const SubjectiveOpinion& right) noexcept {

    const double belief =
        left.belief * right.belief +
        left.belief * right.uncertainty +
        left.uncertainty * right.belief;

    const double disbelief =
        left.disbelief * right.disbelief +
        left.disbelief * right.uncertainty +
        left.uncertainty * right.disbelief;

    const double uncertainty = left.uncertainty * right.uncertainty;

    const double normalization =
        belief + disbelief + uncertainty;

    if (normalization <= kEpsilon) {
        return SubjectiveOpinion{
            .belief = 0.0,
            .disbelief = 0.0,
            .uncertainty = 1.0,
            .base_rate =
                (left.base_rate + right.base_rate) / 2.0
        };
    }

    return SubjectiveOpinion{
        .belief = belief / normalization,
        .disbelief = disbelief / normalization,
        .uncertainty = uncertainty / normalization,
        .base_rate =
            (left.base_rate + right.base_rate) / 2.0
    };
}

bool is_symmetric_matrix(
    const std::vector<std::vector<double>>& matrix) {

    for (std::size_t row = 0; row < matrix.size(); ++row) {
        if (matrix[row].size() != matrix.size()) {
            return false;
        }

        for (std::size_t column = 0; column < matrix.size(); ++column) {
            if (!std::isfinite(matrix[row][column]) ||
                std::abs(matrix[row][column] - matrix[column][row]) > 1e-9) {
                return false;
            }
        }
    }

    return true;
}

bool has_nonnegative_diagonal(
    const std::vector<std::vector<double>>& matrix) {

    for (std::size_t index = 0; index < matrix.size(); ++index) {
        if (matrix[index][index] < 0.0) {
            return false;
        }
    }

    return true;
}

}  // namespace

std::expected<TrustAssessment, EvidenceError> propagate_evidence_trust(
    double initial_trust,
    const std::vector<EvidenceStage>& stages) {

    if (stages.empty()) {
        return std::unexpected(EvidenceError::empty_input);
    }

    if (!finite_unit_interval(initial_trust)) {
        return std::unexpected(EvidenceError::invalid_numeric_input);
    }

    std::unordered_set<std::string> stage_identifiers;
    double propagated_reliability = 1.0;
    SubjectiveOpinion combined_opinion{
        .belief = initial_trust,
        .disbelief = 0.0,
        .uncertainty = 1.0 - initial_trust,
        .base_rate = 0.5
    };

    for (const auto& stage : stages) {
        if (stage.stage_id.empty() ||
            !stage_identifiers.insert(stage.stage_id).second ||
            !finite_nonnegative(stage.coefficient_of_variation) ||
            !valid_opinion(stage.opinion)) {
            return std::unexpected(EvidenceError::invalid_numeric_input);
        }

        double stage_reliability =
            reliability_from_cv(stage.coefficient_of_variation);

        if (stage.kind == ProcessingKind::deterministic_transformation ||
            stage.kind == ProcessingKind::validation_kernel) {
            stage_reliability = stage.reproducible ? 1.0 : stage_reliability;
        }

        if (stage.kind == ProcessingKind::calibration &&
            !stage.calibration_traceable) {
            stage_reliability *= 0.75;
        }

        propagated_reliability *= stage_reliability;
        combined_opinion = combine_opinions(
            combined_opinion,
            stage.opinion);
    }

    const double final_trust =
        std::clamp(
            initial_trust * propagated_reliability,
            0.0,
            1.0);

    return TrustAssessment{
        .initial_trust = initial_trust,
        .propagated_reliability = propagated_reliability,
        .final_trust = final_trust,
        .combined_opinion = combined_opinion,
        .plain_language_explanation =
            "Trust is propagated through named evidence stages. Reproducible deterministic stages preserve computational reliability while calibrated stochastic stages contribute measured variation, provenance, and epistemic uncertainty."
    };
}

std::expected<UncertaintyAssessment> propagate_linear_gaussian_uncertainty(
    const std::vector<GaussianInput>& inputs,
    const std::vector<std::vector<double>>& covariance_matrix,
    const LinearModel& model) {

    if (inputs.empty()) {
        return std::unexpected(EvidenceError::empty_input);
    }

    if (model.coefficients.size() != inputs.size() ||
        covariance_matrix.size() != inputs.size() ||
        !is_symmetric_matrix(covariance_matrix) ||
        !has_nonnegative_diagonal(covariance_matrix)) {
        return std::unexpected(EvidenceError::invalid_correlation_matrix);
    }

    std::unordered_set<std::string> identifiers;
    double output_mean = model.intercept;

    for (std::size_t index = 0; index < inputs.size(); ++index) {
        const auto& input = inputs[index];

        if (input.variable_id.empty() ||
            !identifiers.insert(input.variable_id).second ||
            !std::isfinite(input.mean) ||
            !finite_nonnegative(input.standard_deviation) ||
            !std::isfinite(model.coefficients[index])) {
            return std::unexpected(EvidenceError::invalid_numeric_input);
        }

        const double expected_variance =
            input.standard_deviation * input.standard_deviation;

        if (std::abs(
                covariance_matrix[index][index] -
                expected_variance) > 1e-8) {
            return std::unexpected(EvidenceError::invalid_correlation_matrix);
        }

        output_mean += model.coefficients[index] * input.mean;
    }

    double output_variance = 0.0;

    for (std::size_t row = 0; row < inputs.size(); ++row) {
        for (std::size_t column = 0;
             column < inputs.size();
             ++column) {
            output_variance +=
                model.coefficients[row] *
                covariance_matrix[row][column] *
                model.coefficients[column];
        }
    }

    if (output_variance < -kEpsilon) {
        return std::unexpected(EvidenceError::singular_covariance_matrix);
    }

    output_variance = std::max(output_variance, 0.0);

    const double output_standard_deviation =
        std::sqrt(output_variance);

    std::vector<double> sensitivities;
    sensitivities.reserve(inputs.size());

    double total_absolute_contribution = 0.0;

    for (std::size_t index = 0; index < inputs.size(); ++index) {
        const double contribution =
            std::abs(model.coefficients[index]) *
            inputs[index].standard_deviation;

        sensitivities.push_back(contribution);
        total_absolute_contribution += contribution;
    }

    if (total_absolute_contribution > kEpsilon) {
        for (double& sensitivity : sensitivities) {
            sensitivity /= total_absolute_contribution;
        }
    }

    return UncertaintyAssessment{
        .output_mean = output_mean,
        .output_standard_deviation = output_standard_deviation,
        .lower_95_percent =
            output_mean -
            kNinetyFivePercentZScore * output_standard_deviation,
        .upper_95_percent =
            output_mean +
            kNinetyFivePercentZScore * output_standard_deviation,
        .sensitivity_by_input = std::move(sensitivities),
        .method = "analytic correlated linear Gaussian propagation",
        .plain_language_explanation =
            "The output uncertainty includes both individual input variation and stated correlations among inputs. The result includes a 95 percent interval and normalized input sensitivity values."
    };
}

std::size_t required_monte_carlo_samples(
    double output_standard_deviation,
    double z_score,
    double absolute_error_tolerance) {

    if (!finite_nonnegative(output_standard_deviation) ||
        !finite_nonnegative(z_score) ||
        !finite_nonnegative(absolute_error_tolerance) ||
        absolute_error_tolerance <= 0.0) {
        return 0U;
    }

    const double required =
        std::pow(
            output_standard_deviation * z_score /
            absolute_error_tolerance,
            2.0);

    if (required >=
        static_cast<double>(std::numeric_limits<std::size_t>::max())) {
        return std::numeric_limits<std::size_t>::max();
    }

    return static_cast<std::size_t>(std::ceil(required));
}

}  // namespace augmented_hub::evidence_uq
