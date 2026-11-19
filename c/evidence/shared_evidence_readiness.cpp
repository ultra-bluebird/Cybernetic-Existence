#include <algorithm>
#include <array>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>

namespace augmented_hub::evidence {

enum class EvidenceState {
    Verified,
    PartiallyVerified,
    Unverified,
    Unmodeled,
    Expired,
    RequiresLicensedReview,
    RequiresCommunityReview,
    Prohibited
};

enum class ReadinessStatus {
    ResearchOnly,
    HoldForReview,
    ReadyForReadOnlyImplementation
};

struct DomainEvidence {
    EvidenceState governance{};
    EvidenceState boundaries{};
    EvidenceState sensors{};
    EvidenceState hvac_and_life_safety{};
    EvidenceState privacy_and_retention{};
    EvidenceState zigbee_security{};
    EvidenceState uncertainty_model{};
    EvidenceState community_review{};
};

struct SensorConfidence {
    double datasheet{};
    double calibration{};
    double placement{};
    double freshness{};
    double health{};
};

struct BoundaryEvidence {
    bool upstream_known{};
    bool downstream_known{};
    bool mechanism_known{};
    bool variable_defined{};
    bool method_defined{};
    bool provenance_present{};
    bool uncertainty_present{};
    bool review_current{};
};

struct ReadinessResult {
    double governance_completeness{};
    double boundary_completeness{};
    double sensor_completeness{};
    double hvac_completeness{};
    double privacy_completeness{};
    double zigbee_completeness{};
    double uncertainty_completeness{};
    double community_completeness{};
    double minimum_domain_completeness{};
    double research_progress{};
    ReadinessStatus status{ReadinessStatus::ResearchOnly};
    std::string reason;
};

bool isComplete(EvidenceState state) {
    return state == EvidenceState::Verified;
}

double completeness(EvidenceState state) {
    switch (state) {
        case EvidenceState::Verified:
            return 1.0;
        case EvidenceState::PartiallyVerified:
            return 0.5;
        case EvidenceState::RequiresLicensedReview:
        case EvidenceState::RequiresCommunityReview:
            return 0.0;
        case EvidenceState::Unverified:
        case EvidenceState::Unmodeled:
        case EvidenceState::Expired:
        case EvidenceState::Prohibited:
            return 0.0;
    }

    return 0.0;
}

double sensorKnowledge(const SensorConfidence& sensor) {
    const std::array<double, 5> factors{
        sensor.datasheet,
        sensor.calibration,
        sensor.placement,
        sensor.freshness,
        sensor.health
    };

    double product = 1.0;

    for (double factor : factors) {
        if (!std::isfinite(factor) || factor < 0.0 || factor > 1.0) {
            throw std::invalid_argument("Sensor confidence factors must be finite and within [0, 1]");
        }

        product *= factor;
    }

    return product;
}

bool boundaryComplete(const BoundaryEvidence& boundary) {
    return boundary.upstream_known &&
           boundary.downstream_known &&
           boundary.mechanism_known &&
           boundary.variable_defined &&
           boundary.method_defined &&
           boundary.provenance_present &&
           boundary.uncertainty_present &&
           boundary.review_current;
}

ReadinessResult assessReadiness(
    const DomainEvidence& domains,
    const SensorConfidence& sensor,
    const BoundaryEvidence& boundary
) {
    const std::array<double, 8> values{
        completeness(domains.governance),
        completeness(domains.boundaries),
        completeness(domains.sensors),
        completeness(domains.hvac_and_life_safety),
        completeness(domains.privacy_and_retention),
        completeness(domains.zigbee_security),
        completeness(domains.uncertainty_model),
        completeness(domains.community_review)
    };

    const double minimumCompleteness =
        *std::min_element(values.begin(), values.end());

    double progress = 0.0;
    for (double value : values) {
        progress += value;
    }
    progress /= static_cast<double>(values.size());

    const double sensorCompleteness = sensorKnowledge(sensor);
    const bool completeBoundary = boundaryComplete(boundary);

    if (minimumCompleteness < 1.0) {
        return {
            values[0],
            values[1],
            sensorCompleteness,
            values[3],
            values[4],
            values[5],
            values[6],
            values[7],
            minimumCompleteness,
            progress,
            ReadinessStatus::ResearchOnly,
            "Research-only: at least one mandatory domain lacks verified evidence."
        };
    }

    if (sensorCompleteness < 1.0 || !completeBoundary) {
        return {
            values[0],
            values[1],
            sensorCompleteness,
            values[3],
            values[4],
            values[5],
            values[6],
            values[7],
            minimumCompleteness,
            progress,
            ReadinessStatus::HoldForReview,
            "Hold for review: sensor evidence or required boundary evidence is incomplete."
        };
    }

    return {
        values[0],
        values[1],
        sensorCompleteness,
        values[3],
        values[4],
        values[5],
        values[6],
        values[7],
        minimumCompleteness,
        progress,
        ReadinessStatus::ReadyForReadOnlyImplementation,
        "All required evidence domains, sensor confidence fields, and boundary fields are verified for read-only implementation."
    };
}

std::string_view statusName(ReadinessStatus status) {
    switch (status) {
        case ReadinessStatus::ResearchOnly:
            return "RESEARCH_ONLY";
        case ReadinessStatus::HoldForReview:
            return "HOLD_FOR_REVIEW";
        case ReadinessStatus::ReadyForReadOnlyImplementation:
            return "READY_FOR_READ_ONLY_IMPLEMENTATION";
    }

    return "HOLD_FOR_REVIEW";
}

void printResult(const ReadinessResult& result) {
    std::cout << std::fixed << std::setprecision(6)
              << "{"
              << "\"status\":\"" << statusName(result.status) << "\","
              << "\"reason\":\"" << result.reason << "\","
              << "\"governance_completeness\":" << result.governance_completeness << ","
              << "\"boundary_domain_completeness\":" << result.boundary_completeness << ","
              << "\"sensor_completeness\":" << result.sensor_completeness << ","
              << "\"hvac_life_safety_completeness\":" << result.hvac_completeness << ","
              << "\"privacy_retention_completeness\":" << result.privacy_completeness << ","
              << "\"zigbee_security_completeness\":" << result.zigbee_completeness << ","
              << "\"uncertainty_model_completeness\":" << result.uncertainty_completeness << ","
              << "\"community_review_completeness\":" << result.community_completeness << ","
              << "\"minimum_domain_completeness\":" << result.minimum_domain_completeness << ","
              << "\"research_progress\":" << result.research_progress
              << "}\n";
}

}  // namespace augmented_hub::evidence

int main() {
    using namespace augmented_hub::evidence;

    try {
        const DomainEvidence domains{
            .governance = EvidenceState::Verified,
            .boundaries = EvidenceState::Verified,
            .sensors = EvidenceState::Verified,
            .hvac_and_life_safety = EvidenceState::Verified,
            .privacy_and_retention = EvidenceState::Verified,
            .zigbee_security = EvidenceState::Verified,
            .uncertainty_model = EvidenceState::Verified,
            .community_review = EvidenceState::Verified
        };

        const SensorConfidence sensor{
            .datasheet = 1.0,
            .calibration = 1.0,
            .placement = 1.0,
            .freshness = 1.0,
            .health = 1.0
        };

        const BoundaryEvidence boundary{
            .upstream_known = true,
            .downstream_known = true,
            .mechanism_known = true,
            .variable_defined = true,
            .method_defined = true,
            .provenance_present = true,
            .uncertainty_present = true,
            .review_current = true
        };

        printResult(assessReadiness(domains, sensor, boundary));
        return 0;
    } catch (const std::exception& error) {
        std::cerr
            << "{\"status\":\"HOLD_FOR_REVIEW\",\"error\":\""
            << error.what()
            << "\"}\n";
        return 1;
    }
}
