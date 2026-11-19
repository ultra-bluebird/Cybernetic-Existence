#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <iomanip>
#include <iostream>
#include <limits>
#include <optional>
#include <stdexcept>
#include <string>
#include <string_view>

namespace augmented_hub::ieq {

constexpr double kEpsilon = 1e-12;
constexpr std::size_t kDimensionCount = 5;

enum class EvidenceStatus {
    VerifiedMeasurement,
    CalibratedEstimate,
    ScreeningEstimate,
    Unmodeled,
    Expired
};

enum class DecisionStatus {
    Observe,
    ObserveWithUncertainty,
    HoldForReview,
    EscalateToFacilitiesAndEnvironmentalReview,
    RecommendPassiveMeasure
};

struct Measurement {
    double value{};
    double target{};
    double scale{};
    double standard_uncertainty{};
    EvidenceStatus evidence_status{EvidenceStatus::Unmodeled};
};

struct ZoneState {
    std::array<Measurement, kDimensionCount> values{};
    bool time_aligned{};
    bool calibration_current{};
    bool provenance_present{};
};

struct CorridorLimits {
    double discontinuity_limit{};
    double minimum_conservative_buffering_gain{};
    double coverage_factor{};
};

struct TransitionAssessment {
    double direct_discontinuity{};
    double indoor_to_transition_discontinuity{};
    double transition_to_outdoor_discontinuity{};
    double staged_discontinuity{};
    double buffering_gain{};
    double maximum_step_discontinuity{};
    double conservative_discontinuity{};
    double conservative_buffering_gain{};
    double combined_standard_uncertainty{};
    DecisionStatus status{DecisionStatus::HoldForReview};
    std::string reason;
};

bool isFinite(double value) {
    return std::isfinite(value);
}

void requireFinite(double value, std::string_view name) {
    if (!isFinite(value)) {
        throw std::invalid_argument(std::string(name) + " must be finite");
    }
}

bool evidenceUsable(EvidenceStatus status) {
    return status == EvidenceStatus::VerifiedMeasurement ||
           status == EvidenceStatus::CalibratedEstimate ||
           status == EvidenceStatus::ScreeningEstimate;
}

double normalizedValue(const Measurement& measurement) {
    requireFinite(measurement.value, "measurement value");
    requireFinite(measurement.target, "measurement target");
    requireFinite(measurement.scale, "measurement scale");

    if (measurement.scale <= 0.0) {
        throw std::invalid_argument("measurement scale must be positive");
    }

    return std::clamp(
        (measurement.value - measurement.target) / measurement.scale,
        -1.0,
        1.0
    );
}

double normalizedUncertainty(const Measurement& measurement) {
    requireFinite(measurement.standard_uncertainty, "measurement standard uncertainty");

    if (measurement.standard_uncertainty < 0.0) {
        throw std::invalid_argument("measurement standard uncertainty must be non-negative");
    }

    if (measurement.scale <= 0.0) {
        throw std::invalid_argument("measurement scale must be positive");
    }

    return measurement.standard_uncertainty / measurement.scale;
}

bool zoneUsable(const ZoneState& zone) {
    if (!zone.time_aligned || !zone.calibration_current || !zone.provenance_present) {
        return false;
    }

    for (const Measurement& measurement : zone.values) {
        if (!evidenceUsable(measurement.evidence_status)) {
            return false;
        }
    }

    return true;
}

double weightedDistance(
    const ZoneState& left,
    const ZoneState& right,
    const std::array<double, kDimensionCount>& weights
) {
    double total = 0.0;
    double weightSum = 0.0;

    for (std::size_t index = 0; index < kDimensionCount; ++index) {
        requireFinite(weights[index], "weight");

        if (weights[index] < 0.0) {
            throw std::invalid_argument("weights must be non-negative");
        }

        const double delta =
            normalizedValue(left.values[index]) -
            normalizedValue(right.values[index]);

        total += weights[index] * delta * delta;
        weightSum += weights[index];
    }

    if (std::abs(weightSum - 1.0) > 1e-9) {
        throw std::invalid_argument("weights must sum to one");
    }

    return std::sqrt(total);
}

double independentDistanceUncertainty(
    const ZoneState& left,
    const ZoneState& right,
    const std::array<double, kDimensionCount>& weights
) {
    double variance = 0.0;

    for (std::size_t index = 0; index < kDimensionCount; ++index) {
        const double leftUncertainty = normalizedUncertainty(left.values[index]);
        const double rightUncertainty = normalizedUncertainty(right.values[index]);
        const double pairVariance =
            leftUncertainty * leftUncertainty +
            rightUncertainty * rightUncertainty;

        variance += weights[index] * pairVariance;
    }

    return std::sqrt(variance);
}

TransitionAssessment assessTransition(
    const ZoneState& indoor,
    const ZoneState& transition,
    const ZoneState& outdoor,
    const std::array<double, kDimensionCount>& weights,
    const CorridorLimits& limits,
    bool protectiveThresholdExceeded
) {
    requireFinite(limits.discontinuity_limit, "discontinuity limit");
    requireFinite(limits.minimum_conservative_buffering_gain, "buffering gain limit");
    requireFinite(limits.coverage_factor, "coverage factor");

    if (limits.discontinuity_limit <= 0.0) {
        throw std::invalid_argument("discontinuity limit must be positive");
    }

    if (limits.coverage_factor < 1.0 || limits.coverage_factor > 10.0) {
        throw std::invalid_argument("coverage factor must be within [1, 10]");
    }

    if (!zoneUsable(indoor) || !zoneUsable(transition) || !zoneUsable(outdoor)) {
        return {
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            DecisionStatus::HoldForReview,
            "At least one zone has unmodeled, expired, uncalibrated, unaligned, or unprovenanced evidence."
        };
    }

    const double direct = weightedDistance(indoor, outdoor, weights);
    const double indoorToTransition = weightedDistance(indoor, transition, weights);
    const double transitionToOutdoor = weightedDistance(transition, outdoor, weights);
    const double staged = indoorToTransition + transitionToOutdoor;
    const double bufferingGain = 1.0 - staged / std::max(direct, kEpsilon);
    const double maximumStep = std::max(indoorToTransition, transitionToOutdoor);

    const double directUncertainty = independentDistanceUncertainty(indoor, outdoor, weights);
    const double stagedUncertainty =
        independentDistanceUncertainty(indoor, transition, weights) +
        independentDistanceUncertainty(transition, outdoor, weights);

    const double combinedUncertainty =
        std::sqrt(
            directUncertainty * directUncertainty +
            stagedUncertainty * stagedUncertainty
        );

    const double expandedUncertainty =
        limits.coverage_factor * combinedUncertainty;

    const double conservativeDiscontinuity = direct + expandedUncertainty;
    const double conservativeBufferingGain = bufferingGain - expandedUncertainty;

    if (protectiveThresholdExceeded) {
        return {
            direct,
            indoorToTransition,
            transitionToOutdoor,
            staged,
            bufferingGain,
            maximumStep,
            conservativeDiscontinuity,
            conservativeBufferingGain,
            combinedUncertainty,
            DecisionStatus::EscalateToFacilitiesAndEnvironmentalReview,
            "A receptor-protection threshold is exceeded; human and environmental review is required."
        };
    }

    if (conservativeDiscontinuity > limits.discontinuity_limit) {
        return {
            direct,
            indoorToTransition,
            transitionToOutdoor,
            staged,
            bufferingGain,
            maximumStep,
            conservativeDiscontinuity,
            conservativeBufferingGain,
            combinedUncertainty,
            DecisionStatus::HoldForReview,
            "Conservative indoor-outdoor discontinuity exceeds the configured planning corridor."
        };
    }

    if (conservativeBufferingGain < limits.minimum_conservative_buffering_gain) {
        return {
            direct,
            indoorToTransition,
            transitionToOutdoor,
            staged,
            bufferingGain,
            maximumStep,
            conservativeDiscontinuity,
            conservativeBufferingGain,
            combinedUncertainty,
            DecisionStatus::RecommendPassiveMeasure,
            "Transition-zone buffering is not demonstrated conservatively; assess shade, glare control, wind buffering, filtration, or layout changes."
        };
    }

    return {
        direct,
        indoorToTransition,
        transitionToOutdoor,
        staged,
        bufferingGain,
        maximumStep,
        conservativeDiscontinuity,
        conservativeBufferingGain,
        combinedUncertainty,
        DecisionStatus::Observe,
        "Current evidence supports observation under the declared metric, uncertainty, and non-actuating planning limits."
    };
}

std::string_view decisionName(DecisionStatus status) {
    switch (status) {
        case DecisionStatus::Observe:
            return "OBSERVE";
        case DecisionStatus::ObserveWithUncertainty:
            return "OBSERVE_WITH_UNCERTAINTY";
        case DecisionStatus::HoldForReview:
            return "HOLD_FOR_REVIEW";
        case DecisionStatus::EscalateToFacilitiesAndEnvironmentalReview:
            return "ESCALATE_TO_FACILITIES_AND_ENVIRONMENTAL_REVIEW";
        case DecisionStatus::RecommendPassiveMeasure:
            return "RECOMMEND_PASSIVE_MEASURE";
    }

    return "HOLD_FOR_REVIEW";
}

Measurement reading(
    double value,
    double target,
    double scale,
    double uncertainty,
    EvidenceStatus status = EvidenceStatus::VerifiedMeasurement
) {
    return {value, target, scale, uncertainty, status};
}

ZoneState zone(
    std::array<Measurement, kDimensionCount> values
) {
    return {
        values,
        true,
        true,
        true
    };
}

void printAssessment(const TransitionAssessment& assessment) {
    std::cout << std::fixed << std::setprecision(6)
              << "{"
              << "\"status\":\"" << decisionName(assessment.status) << "\","
              << "\"reason\":\"" << assessment.reason << "\","
              << "\"direct_discontinuity\":" << assessment.direct_discontinuity << ","
              << "\"indoor_to_transition_discontinuity\":"
              << assessment.indoor_to_transition_discontinuity << ","
              << "\"transition_to_outdoor_discontinuity\":"
              << assessment.transition_to_outdoor_discontinuity << ","
              << "\"staged_discontinuity\":" << assessment.staged_discontinuity << ","
              << "\"buffering_gain\":" << assessment.buffering_gain << ","
              << "\"maximum_step_discontinuity\":"
              << assessment.maximum_step_discontinuity << ","
              << "\"combined_standard_uncertainty\":"
              << assessment.combined_standard_uncertainty << ","
              << "\"conservative_discontinuity\":"
              << assessment.conservative_discontinuity << ","
              << "\"conservative_buffering_gain\":"
              << assessment.conservative_buffering_gain
              << "}\n";
}

}  // namespace augmented_hub::ieq

int main() {
    using namespace augmented_hub::ieq;

    try {
        const ZoneState indoor = zone({
            reading(24.0, 24.0, 8.0, 0.25),
            reading(42.0, 45.0, 30.0, 2.0),
            reading(10.0, 12.0, 20.0, 1.0),
            reading(650.0, 700.0, 500.0, 45.0),
            reading(0.20, 0.20, 0.50, 0.03)
        });

        const ZoneState transition = zone({
            reading(27.0, 24.0, 8.0, 0.35),
            reading(35.0, 45.0, 30.0, 2.5),
            reading(16.0, 12.0, 20.0, 1.5),
            reading(500.0, 700.0, 500.0, 55.0),
            reading(0.28, 0.20, 0.50, 0.04)
        });

        const ZoneState outdoor = zone({
            reading(34.0, 24.0, 8.0, 0.40),
            reading(24.0, 45.0, 30.0, 3.0),
            reading(22.0, 12.0, 20.0, 2.0),
            reading(430.0, 700.0, 500.0, 35.0),
            reading(0.32, 0.20, 0.50, 0.05)
        });

        const std::array<double, kDimensionCount> weights{
            0.35,
            0.10,
            0.25,
            0.15,
            0.15
        };

        const CorridorLimits limits{
            .discontinuity_limit = 1.50,
            .minimum_conservative_buffering_gain = 0.00,
            .coverage_factor = 2.0
        };

        const TransitionAssessment result = assessTransition(
            indoor,
            transition,
            outdoor,
            weights,
            limits,
            false
        );

        printAssessment(result);
        return 0;
    } catch (const std::exception& error) {
        std::cerr
            << "{\"status\":\"HOLD_FOR_REVIEW\",\"error\":\""
            << error.what()
            << "\"}\n";
        return 1;
    }
}
