#include <cmath>
#include <iostream>
#include <string>
#include <vector>

namespace cyboquatics {

enum class IntegrityStatus {
    IntegrityEvidencePresent,
    IntegrityReviewRequired,
    RejectedInput
};

struct CanalObservation {
    std::string nodePseudonym;
    std::string observationTimeBucketUtc;
    double flowM3S;
    double temperatureC;
    double quality;
    double minimumQuality;
    bool exactLocationPresent;
    bool directIdentityPresent;
    bool continuousSurveillancePresent;
};

struct IntegrityResult {
    IntegrityStatus status;
    std::vector<std::string> reasons;
};

bool finite(double value) {
    return std::isfinite(value);
}

bool unitInterval(double value) {
    return finite(value) && value >= 0.0 && value <= 1.0;
}

bool validPseudonym(const std::string& value) {
    if (value.size() < 12 || value.size() > 96) {
        return false;
    }
    for (const char character : value) {
        const bool accepted =
            (character >= 'a' && character <= 'z') ||
            (character >= 'A' && character <= 'Z') ||
            (character >= '0' && character <= '9') ||
            character == '-' || character == '_';
        if (!accepted) {
            return false;
        }
    }
    return true;
}

IntegrityResult evaluate(const CanalObservation& observation) {
    if (!validPseudonym(observation.nodePseudonym) ||
        observation.observationTimeBucketUtc.empty() ||
        !finite(observation.flowM3S) ||
        !finite(observation.temperatureC) ||
        !unitInterval(observation.quality) ||
        !unitInterval(observation.minimumQuality) ||
        observation.flowM3S < 0.0) {
        return {
            IntegrityStatus::RejectedInput,
            {"Observation contains invalid pseudonym, time bucket, or telemetry values."}
        };
    }

    std::vector<std::string> reasons;
    if (observation.quality < observation.minimumQuality) {
        reasons.emplace_back("Telemetry quality is below the configured threshold.");
    }
    if (observation.exactLocationPresent) {
        reasons.emplace_back("Exact location is prohibited in this integrity indicator.");
    }
    if (observation.directIdentityPresent) {
        reasons.emplace_back("Direct identity data is prohibited in this integrity indicator.");
    }
    if (observation.continuousSurveillancePresent) {
        reasons.emplace_back("Continuous surveillance data is prohibited in this integrity indicator.");
    }

    if (!reasons.empty()) {
        return {IntegrityStatus::IntegrityReviewRequired, reasons};
    }

    return {
        IntegrityStatus::IntegrityEvidencePresent,
        {"Pseudonymous, time-bucketed integrity evidence is present."}
    };
}

std::string toString(IntegrityStatus status) {
    switch (status) {
        case IntegrityStatus::IntegrityEvidencePresent: return "INTEGRITY_EVIDENCE_PRESENT";
        case IntegrityStatus::IntegrityReviewRequired: return "INTEGRITY_REVIEW_REQUIRED";
        case IntegrityStatus::RejectedInput: return "REJECTED_INPUT";
    }
    return "REJECTED_INPUT";
}

}  // namespace cyboquatics

int main() {
    const cyboquatics::CanalObservation observation{
        "canal-q7x9m3n5p8r2",
        "2026-08-26T01:00Z",
        0.42,
        23.5,
        0.91,
        0.80,
        false,
        false,
        false
    };

    const auto result = cyboquatics::evaluate(observation);
    std::cout << cyboquatics::toString(result.status) << '\n';
    return 0;
}
