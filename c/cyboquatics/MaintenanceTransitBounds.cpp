#include <cmath>
#include <iostream>
#include <string>
#include <vector>

namespace cyboquatics {

enum class WorkloadDecision {
    WithinReviewBounds,
    HumanReviewRequired,
    RejectedInput
};

enum class TransitRoute {
    ReviewableInput,
    QuarantinedInput,
    RejectedInput
};

struct MaintenanceWorkload {
    double energyreqJ;
    double energyBudgetJ;
    double deltaVt;
    double thermalDeltaVtThreshold;
    double harmRiskR;
    bool reviewerAvailable;
    bool interlocksVerified;
};

struct WorkloadResult {
    WorkloadDecision decision;
    std::vector<std::string> reasons;
};

struct TransitReading {
    double value;
    double minimum;
    double maximum;
    double harmRiskR;
};

struct TransitResult {
    TransitRoute route;
    std::vector<std::string> reasons;
};

bool finite(double value) {
    return std::isfinite(value);
}

bool inUnitInterval(double value) {
    return finite(value) && value >= 0.0 && value <= 1.0;
}

WorkloadResult evaluateMaintenanceWorkload(const MaintenanceWorkload& input) {
    if (!finite(input.energyreqJ) || !finite(input.energyBudgetJ) ||
        !finite(input.deltaVt) || !finite(input.thermalDeltaVtThreshold) ||
        !inUnitInterval(input.harmRiskR) || input.energyreqJ < 0.0 ||
        input.energyBudgetJ <= 0.0 || input.thermalDeltaVtThreshold <= 0.0) {
        return {WorkloadDecision::RejectedInput, {"Invalid workload bounds or risk value."}};
    }

    std::vector<std::string> reasons;
    if (input.energyreqJ >= input.energyBudgetJ) {
        reasons.emplace_back("Energy demand reaches or exceeds the approved budget.");
    }
    if (std::abs(input.deltaVt) >= input.thermalDeltaVtThreshold) {
        reasons.emplace_back("Absolute deltaVt reaches or exceeds the thermal threshold.");
    }
    if (input.harmRiskR > 0.30) {
        reasons.emplace_back("Harm risk exceeds 0.30.");
    }
    if (!input.reviewerAvailable) {
        reasons.emplace_back("No current human reviewer is available.");
    }
    if (!input.interlocksVerified) {
        reasons.emplace_back("Required safety interlocks are not verified.");
    }

    if (!reasons.empty()) {
        return {WorkloadDecision::HumanReviewRequired, reasons};
    }

    return {
        WorkloadDecision::WithinReviewBounds,
        {"Within configured review bounds; this result does not authorize physical actuation."}
    };
}

TransitResult routeTransitReading(const TransitReading& input) {
    if (!finite(input.value) || !finite(input.minimum) || !finite(input.maximum) ||
        !inUnitInterval(input.harmRiskR) || input.minimum > input.maximum ||
        input.value < input.minimum || input.value > input.maximum) {
        return {TransitRoute::RejectedInput, {"Non-finite, missing, or out-of-range sensor input."}};
    }

    if (input.harmRiskR > 0.30) {
        return {
            TransitRoute::QuarantinedInput,
            {"Input is finite and bounded, but harm risk exceeds 0.30.", "No autonomous vehicle control is permitted."}
        };
    }

    return {
        TransitRoute::ReviewableInput,
        {"Input is finite, bounded, and within the configured risk limit.", "No autonomous vehicle control is permitted."}
    };
}

std::string toString(WorkloadDecision decision) {
    switch (decision) {
        case WorkloadDecision::WithinReviewBounds: return "WITHIN_REVIEW_BOUNDS";
        case WorkloadDecision::HumanReviewRequired: return "HUMAN_REVIEW_REQUIRED";
        case WorkloadDecision::RejectedInput: return "REJECTED_INPUT";
    }
    return "REJECTED_INPUT";
}

std::string toString(TransitRoute route) {
    switch (route) {
        case TransitRoute::ReviewableInput: return "REVIEWABLE_INPUT";
        case TransitRoute::QuarantinedInput: return "QUARANTINED_INPUT";
        case TransitRoute::RejectedInput: return "REJECTED_INPUT";
    }
    return "REJECTED_INPUT";
}

}  // namespace cyboquatics

int main() {
    const cyboquatics::MaintenanceWorkload workload{
        8000.0, 10000.0, 12.0, 20.0, 0.22, true, true
    };
    const auto workloadResult = cyboquatics::evaluateMaintenanceWorkload(workload);
    std::cout << cyboquatics::toString(workloadResult.decision) << '\n';

    const cyboquatics::TransitReading transitReading{
        24.0, -40.0, 125.0, 0.31
    };
    const auto transitResult = cyboquatics::routeTransitReading(transitReading);
    std::cout << cyboquatics::toString(transitResult.route) << '\n';

    return 0;
}
