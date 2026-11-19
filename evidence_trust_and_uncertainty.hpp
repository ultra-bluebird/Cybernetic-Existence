#ifndef AUGMENTED_HUB_EVIDENCE_TRUST_AND_UNCERTAINTY_HPP
#define AUGMENTED_HUB_EVIDENCE_TRUST_AND_UNCERTAINTY_HPP

#include <cstddef>
#include <expected>
#include <string>
#include <vector>

namespace augmented_hub::evidence_uq {

enum class EvidenceError {
    empty_input,
    invalid_numeric_input,
    invalid_opinion,
    invalid_correlation_matrix,
    singular_covariance_matrix,
    unsupported_sample_count
};

enum class ProcessingKind {
    stochastic_measurement,
    deterministic_transformation,
    calibration,
    validation_kernel,
    governance_review
};

struct SubjectiveOpinion {
    double belief{};
    double disbelief{};
    double uncertainty{};
    double base_rate{0.5};
};

struct EvidenceStage {
    std::string stage_id;
    ProcessingKind kind{};
    double coefficient_of_variation{};
    bool calibration_traceable{};
    bool reproducible{};
    SubjectiveOpinion opinion;
};

struct TrustAssessment {
    double initial_trust{};
    double propagated_reliability{};
    double final_trust{};
    SubjectiveOpinion combined_opinion;
    std::string plain_language_explanation;
};

struct GaussianInput {
    std::string variable_id;
    double mean{};
    double standard_deviation{};
};

struct LinearModel {
    std::vector<double> coefficients;
    double intercept{};
};

struct UncertaintyAssessment {
    double output_mean{};
    double output_standard_deviation{};
    double lower_95_percent{};
    double upper_95_percent{};
    std::vector<double> sensitivity_by_input;
    std::string method;
    std::string plain_language_explanation;
};

[[nodiscard]] std::expected<TrustAssessment, EvidenceError>
propagate_evidence_trust(
    double initial_trust,
    const std::vector<EvidenceStage>& stages);

[[nodiscard]] std::expected<UncertaintyAssessment, EvidenceError>
propagate_linear_gaussian_uncertainty(
    const std::vector<GaussianInput>& inputs,
    const std::vector<std::vector<double>>& covariance_matrix,
    const LinearModel& model);

[[nodiscard]] std::size_t required_monte_carlo_samples(
    double output_standard_deviation,
    double z_score,
    double absolute_error_tolerance);

}  // namespace augmented_hub::evidence_uq

#endif
