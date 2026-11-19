#include <cmath>
#include <iostream>
#include <string>
#include <vector>

namespace cyboquatics {

enum class Decision {
    WithinLocalReviewBounds,
    DeferToHumanReview,
    RejectedInput
};

struct Input {
    double energyreqJ;
    double localEnergyBudgetJ;
    double deltaVt;
    double localAbsDeltaVtHeatThreshold;
    double harmRiskR;
    bool reviewerAvailable;
    bool interlocksVerified;
};

struct Result {
    Decision decision;
    bool physicalActuationAuthorized;
    std::vector<std::string> reasons;
};

bool finite(double value) {
    return std::isfinite(value);
}

bool unitInterval(double value) {
    return finite(value) && value >= 0.0 && value <= 1.0;
}

Result evaluate(const Input& input) {
    if (!finite(input.energyreqJ) ||
        !finite(input.localEnergyBudgetJ) ||
        !finite(input.deltaVt) ||
        !finite(input.localAbsDeltaVtHeatThreshold) ||
        !unitInterval(input.harmRiskR) ||
        input.energyreqJ < 0.0 ||
        input.localEnergyBudgetJ <= 0.0 ||
        input.localAbsDeltaVtHeatThreshold <= 0.0) {
        return {
            Decision::RejectedInput,
            false,
            {"Energy, deltaVt, threshold, or risk input is invalid."}
        };
    }

    std::vector<std::string> reasons;
    if (input.energyreqJ > input.localEnergyBudgetJ) {
        reasons.emplace_back("Energy demand exceeds the local approved budget.");
    }
    if (std::abs(input.deltaVt) > input.localAbsDeltaVtHeatThreshold) {
        reasons.emplace_back("Absolute deltaVt exceeds the local heat threshold.");
    }
    if (input.harmRiskR > 0.30) {
        reasons.emplace_back("Harm risk exceeds 0.30.");
    }
    if (!input.reviewerAvailable) {
        reasons.emplace_back("A human reviewer is unavailable.");
    }
    if (!input.interlocksVerified) {
        reasons.emplace_back("Required safety interlocks are not verified.");
    }

    if (!reasons.empty()) {
        return {Decision::DeferToHumanReview, false, reasons};
    }

    return {
        Decision::WithinLocalReviewBounds,
        false,
        {"Within local review bounds. Human approval remains required before any physical action."}
    };
}

std::string toString(Decision decision) {
    switch (decision) {
        case Decision::WithinLocalReviewBounds: return "WITHIN_LOCAL_REVIEW_BOUNDS";
        case Decision::DeferToHumanReview: return "DEFER_TO_HUMAN_REVIEW";
        case Decision::RejectedInput: return "REJECTED_INPUT";
    }
    return "REJECTED_INPUT";
}

}  // namespace cyboquatics

int main() {
    const cyboquatics::Input input{
        9500.0, 10000.0, 14.0, 18.0, 0.21, true, true
    };

    const auto result = cyboquatics::evaluate(input);
    std::cout << cyboquatics::toString(result.decision) << '\n';
    return 0;
}
