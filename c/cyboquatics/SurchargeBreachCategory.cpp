#include <cmath>
#include <iostream>
#include <string>
#include <vector>

namespace cyboquatics {

enum class SurchargeCategory {
    LocalReview,
    ExtendedReview,
    CriticalReview,
    RejectedInput
};

struct SurchargeInput {
    double flowM3S;
    double durationS;
    double bankSensitivity;
    double criticalShearStressPa;
    double radiusCoefficient;
    double sensitivityCoefficient;
    double shearCoefficient;
    double localReviewRadiusM;
    double extendedReviewRadiusM;
};

struct SurchargeResult {
    SurchargeCategory category;
    double screeningRadiusM;
    bool qualifiedEngineeringReviewRequired;
    std::vector<std::string> reasons;
};

bool finite(double value) {
    return std::isfinite(value);
}

bool unitInterval(double value) {
    return finite(value) && value >= 0.0 && value <= 1.0;
}

SurchargeResult classify(const SurchargeInput& input) {
    if (!finite(input.flowM3S) ||
        !finite(input.durationS) ||
        !unitInterval(input.bankSensitivity) ||
        !finite(input.criticalShearStressPa) ||
        !finite(input.radiusCoefficient) ||
        !finite(input.sensitivityCoefficient) ||
        !finite(input.shearCoefficient) ||
        !finite(input.localReviewRadiusM) ||
        !finite(input.extendedReviewRadiusM) ||
        input.flowM3S < 0.0 ||
        input.durationS < 0.0 ||
        input.criticalShearStressPa < 0.0 ||
        input.radiusCoefficient < 0.0 ||
        input.sensitivityCoefficient < 0.0 ||
        input.shearCoefficient < 0.0 ||
        input.localReviewRadiusM < 0.0 ||
        input.extendedReviewRadiusM < input.localReviewRadiusM) {
        return {
            SurchargeCategory::RejectedInput,
            0.0,
            false,
            {"Hydraulic input, coefficient, or threshold is invalid."}
        };
    }

    const double radius =
        input.radiusCoefficient * std::sqrt(input.flowM3S * input.durationS) *
            (1.0 + input.sensitivityCoefficient * input.bankSensitivity) +
        input.shearCoefficient * input.criticalShearStressPa;

    if (radius <= input.localReviewRadiusM) {
        return {
            SurchargeCategory::LocalReview,
            radius,
            false,
            {"Conservative local screening category. This is not a real-world impact prediction."}
        };
    }

    if (radius <= input.extendedReviewRadiusM) {
        return {
            SurchargeCategory::ExtendedReview,
            radius,
            true,
            {"Qualified human engineering review is required."}
        };
    }

    return {
        SurchargeCategory::CriticalReview,
        radius,
        true,
        {"Qualified human engineering review and site safety process are required."}
    };
}

std::string toString(SurchargeCategory category) {
    switch (category) {
        case SurchargeCategory::LocalReview: return "LOCAL_REVIEW";
        case SurchargeCategory::ExtendedReview: return "EXTENDED_REVIEW";
        case SurchargeCategory::CriticalReview: return "CRITICAL_REVIEW";
        case SurchargeCategory::RejectedInput: return "REJECTED_INPUT";
    }
    return "REJECTED_INPUT";
}

}  // namespace cyboquatics

int main() {
    const cyboquatics::SurchargeInput input{
        0.75, 120.0, 0.40, 8.0, 2.0, 0.50, 0.30, 25.0, 75.0
    };

    const auto result = cyboquatics::classify(input);
    std::cout << cyboquatics::toString(result.category)
              << " radius_m=" << result.screeningRadiusM << '\n';
    return 0;
}
