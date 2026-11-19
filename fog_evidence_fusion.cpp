#include <algorithm>
#include <cmath>
#include <optional>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace augmented_hub::fog {

enum class Hypothesis {
    Clear,
    Fog,
    Ignorance
};

enum class FusionStatus {
    Fused,
    ConflictReviewRequired,
    InvalidEvidence
};

struct BasicProbabilityAssignment {
    double clear{0.0};
    double fog{0.0};
    double ignorance{1.0};

    [[nodiscard]] bool valid(double tolerance = 1e-9) const {
        const bool finite = std::isfinite(clear) && std::isfinite(fog) &&
            std::isfinite(ignorance);

        return finite && clear >= 0.0 && fog >= 0.0 && ignorance >= 0.0 &&
            std::abs((clear + fog + ignorance) - 1.0) <= tolerance;
    }
};

struct FusionResult {
    FusionStatus status{FusionStatus::InvalidEvidence};
    BasicProbabilityAssignment assignment{};
    double conflict{0.0};
    std::string reason;
};

class EvidenceFusionEngine {
public:
    explicit EvidenceFusionEngine(double maximumConflict)
        : maximum_conflict_(maximumConflict) {
        if (!std::isfinite(maximumConflict) ||
            maximumConflict < 0.0 || maximumConflict >= 1.0) {
            throw std::invalid_argument(
                "maximumConflict must be finite and in [0, 1).");
        }
    }

    [[nodiscard]] FusionResult combine(
        const BasicProbabilityAssignment& left,
        const BasicProbabilityAssignment& right) const {

        if (!left.valid() || !right.valid()) {
            return {
                FusionStatus::InvalidEvidence,
                {},
                0.0,
                "Mass assignments must be finite, non-negative, and sum to one."
            };
        }

        const double conflict =
            left.clear * right.fog +
            left.fog * right.clear;

        if (conflict >= 1.0 - epsilon_) {
            return {
                FusionStatus::ConflictReviewRequired,
                cautious_unknown(),
                conflict,
                "Evidence is total conflict; a normalized combination is unsafe."
            };
        }

        const double denominator = 1.0 - conflict;

        BasicProbabilityAssignment combined{
            .clear = (
                left.clear * right.clear +
                left.clear * right.ignorance +
                left.ignorance * right.clear
            ) / denominator,
            .fog = (
                left.fog * right.fog +
                left.fog * right.ignorance +
                left.ignorance * right.fog
            ) / denominator,
            .ignorance = (
                left.ignorance * right.ignorance
            ) / denominator
        };

        if (!combined.valid()) {
            return {
                FusionStatus::InvalidEvidence,
                {},
                conflict,
                "Numerical validation failed after evidence combination."
            };
        }

        if (conflict > maximum_conflict_) {
            return {
                FusionStatus::ConflictReviewRequired,
                cautious_unknown(),
                conflict,
                "Conflict exceeds the approved operational threshold."
            };
        }

        return {
            FusionStatus::Fused,
            combined,
            conflict,
            "Evidence combined with retained uncertainty."
        };
    }

    [[nodiscard]] FusionResult combine_all(
        const std::vector<BasicProbabilityAssignment>& evidence) const {

        if (evidence.empty()) {
            return {
                FusionStatus::InvalidEvidence,
                {},
                0.0,
                "At least one evidence assignment is required."
            };
        }

        BasicProbabilityAssignment accumulated = evidence.front();
        if (!accumulated.valid()) {
            return {
                FusionStatus::InvalidEvidence,
                {},
                0.0,
                "The first evidence assignment is invalid."
            };
        }

        double maximum_observed_conflict = 0.0;

        for (std::size_t index = 1; index < evidence.size(); ++index) {
            const FusionResult result = combine(accumulated, evidence[index]);
            maximum_observed_conflict = std::max(
                maximum_observed_conflict,
                result.conflict);

            if (result.status != FusionStatus::Fused) {
                return {
                    result.status,
                    result.assignment,
                    maximum_observed_conflict,
                    result.reason
                };
            }

            accumulated = result.assignment;
        }

        return {
            FusionStatus::Fused,
            accumulated,
            maximum_observed_conflict,
            "All evidence sources combined successfully."
        };
    }

    [[nodiscard]] static double belief_fog(
        const BasicProbabilityAssignment& assignment) {
        return assignment.fog;
    }

    [[nodiscard]] static double plausibility_fog(
        const BasicProbabilityAssignment& assignment) {
        return assignment.fog + assignment.ignorance;
    }

private:
    [[nodiscard]] static BasicProbabilityAssignment cautious_unknown() {
        return {
            .clear = 0.0,
            .fog = 0.0,
            .ignorance = 1.0
        };
    }

    static constexpr double epsilon_ = 1e-12;
    double maximum_conflict_;
};

} // namespace augmented_hub::fog
