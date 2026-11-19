#ifndef AUGMENTED_HUB_PSYCH_CONTINUITY_PROTOCOL_HPP
#define AUGMENTED_HUB_PSYCH_CONTINUITY_PROTOCOL_HPP

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <expected>
#include <limits>
#include <span>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace augmented_hub::continuity {

enum class ReviewStatus {
    candidate_for_review,
    hold_for_review,
    qualified,
    approved_for_planning,
    superseded
};

enum class ContinuityError {
    empty_sample_window,
    non_finite_value,
    negative_weight,
    invalid_threshold,
    incoherent_timestamp_order
};

struct ContinuitySample {
    double elapsed_seconds{};
    double system_state_coherence{};
    double identity_affirming_signal_strength{};
};

struct ContinuityAssessment {
    double continuity_score{};
    double weighted_interval_seconds{};
    std::size_t sample_count{};
    double threshold{};
    bool migration_ready{};
    ReviewStatus review_status{ReviewStatus::hold_for_review};
    std::string plain_language_explanation;
};

struct EnvironmentalContribution {
    double ecological_norm{};
    double social_norm{};
};

struct SystemValue {
    double total_value{};
    bool self_asserted_identity_present{};
    std::string evaluation_scope;
};

inline constexpr bool in_closed_unit_interval(double value) noexcept {
    return std::isfinite(value) && value >= 0.0 && value <= 1.0;
}

inline constexpr bool is_non_negative_finite(double value) noexcept {
    return std::isfinite(value) && value >= 0.0;
}

inline std::expected<ContinuityAssessment, ContinuityError> assess_continuity(
    std::span<const ContinuitySample> samples,
    double threshold) {

    if (samples.empty()) {
        return std::unexpected(ContinuityError::empty_sample_window);
    }

    if (!in_closed_unit_interval(threshold)) {
        return std::unexpected(ContinuityError::invalid_threshold);
    }

    double weighted_signal = 0.0;
    double total_weight = 0.0;
    double previous_time = -std::numeric_limits<double>::infinity();

    for (const auto& sample : samples) {
        if (!std::isfinite(sample.elapsed_seconds) ||
            !in_closed_unit_interval(sample.system_state_coherence) ||
            !in_closed_unit_interval(sample.identity_affirming_signal_strength)) {
            return std::unexpected(ContinuityError::non_finite_value);
        }

        if (sample.elapsed_seconds < previous_time) {
            return std::unexpected(ContinuityError::incoherent_timestamp_order);
        }

        previous_time = sample.elapsed_seconds;

        const double phi = sample.system_state_coherence;
        const double psi = sample.identity_affirming_signal_strength;

        weighted_signal += phi * psi;
        total_weight += phi;
    }

    if (total_weight <= 0.0) {
        return std::unexpected(ContinuityError::negative_weight);
    }

    const double score = weighted_signal / total_weight;
    const bool migration_ready = score >= threshold;

    ContinuityAssessment assessment{
        .continuity_score = score,
        .weighted_interval_seconds = total_weight,
        .sample_count = samples.size(),
        .threshold = threshold,
        .migration_ready = migration_ready,
        .review_status = migration_ready
            ? ReviewStatus::candidate_for_review
            : ReviewStatus::hold_for_review,
        .plain_language_explanation = migration_ready
            ? "The continuity evidence meets the configured threshold. A separate accountable review remains required before migration."
            : "The continuity evidence does not meet the configured threshold. The migration remains on hold for review; no supersession state is applied."
    };

    return assessment;
}

inline std::expected<SystemValue, ContinuityError> calculate_system_value(
    const EnvironmentalContribution& contribution,
    double ecological_weight,
    double social_weight,
    double identity_weight,
    bool self_asserted_identity_present) {

    if (!is_non_negative_finite(contribution.ecological_norm) ||
        !is_non_negative_finite(contribution.social_norm) ||
        !is_non_negative_finite(ecological_weight) ||
        !is_non_negative_finite(social_weight) ||
        !is_non_negative_finite(identity_weight)) {
        return std::unexpected(ContinuityError::non_finite_value);
    }

    const double identity_indicator = self_asserted_identity_present ? 1.0 : 0.0;
    const double value =
        ecological_weight * contribution.ecological_norm +
        social_weight * contribution.social_norm +
        identity_weight * identity_indicator;

    return SystemValue{
        .total_value = value,
        .self_asserted_identity_present = self_asserted_identity_present,
        .evaluation_scope =
            "Environmental and social contribution evaluation only. "
            "This value is not an eligibility score, identity certification, "
            "service-access decision, reputation score, or personal ranking."
    };
}

inline constexpr bool may_proceed_to_migration_review(
    const ContinuityAssessment& assessment) noexcept {
    return assessment.migration_ready &&
           assessment.review_status == ReviewStatus::candidate_for_review;
}

inline constexpr bool preserves_hold_before_supersession(
    const ContinuityAssessment& assessment) noexcept {
    return !assessment.migration_ready &&
           assessment.review_status == ReviewStatus::hold_for_review;
}

}  // namespace augmented_hub::continuity

#endif
